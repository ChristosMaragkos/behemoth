package behemoth

import "./audio"
import c "./common"
import exec "./execution"
import gfx "./graphics"
import "./input"
import "./memory"
import "core:mem"
import "core:os"
import "core:sync"

AUDIO_FIFO_FRAMES :: 4096 // stereo frames (~93ms @44.1kHz)

AudioFifo :: struct {
	// Interleaved LRLR...; head/tail count stereo frames, not floats,
	// so L/R can never tear apart mid-frame.
	buf:  [AUDIO_FIFO_FRAMES * 2]f32,
	head: u32,
	tail: u32,
}

System :: struct {
	cpu:                ^exec.Cpu,
	ppu:                ^gfx.Ppu,
	apu:                ^audio.Apu,
	bus:                ^memory.MemoryBus,
	cycle_counter:      u64,
	ppu_prev_status:    gfx.PpuStatus,
	ppu_phase:          u32,
	audio_fifo:         AudioFifo,
	audio_cycle_scaled: u64,
}

g_audio_fifo: ^AudioFifo

system_init :: proc() -> ^System {
	sys, sys_err := new(System)
	if sys_err != .None {
		panic("Could not allocate memory for the emulator.")
	}

	cpu, cpu_err := new(exec.Cpu)
	if cpu_err != .None {
		panic("Could not allocate memory for the CPU.")
	}

	ppu, ppu_err := new(gfx.Ppu)
	if ppu_err != .None {
		panic("Could not allocate memory for the PPU.")
	}

	apu, apu_err := new(audio.Apu)
	if apu_err != .None {
		panic("Could not allocate memory for the APU.")
	}

	bus, bus_err := new(memory.MemoryBus)
	if bus_err != .None {
		panic("Could not allocate memory for the memory bus, require 16mb.")
	}

	sys.cpu = cpu
	sys.bus = bus
	sys.ppu = ppu
	sys.apu = apu
	g_audio_fifo = &sys.audio_fifo
	gfx.ppu_init(ppu, &bus.ram[memory.calculate_address(c.MMIO_PAGE, c.PPU_MMIO_OFFSET)])
	audio.apu_init(apu, &bus.ram[memory.calculate_address(c.MMIO_PAGE, c.APU_MMIO_OFFSET)])

	sys.bus.vram = &ppu.vram
	sys.bus.cram = &ppu.cram
	sys.bus.oam = &ppu.oam
	sys.bus.aram = &apu.aram

	ppu.current_line = 240
	ppu.current_col = 0
	ppu.status = {.InVblank}
	ppu.hblank_count = 0
	sys.ppu_prev_status = {.InVblank}
	sys.ppu_phase = 0
	gfx.ppu_encode_to_mmio(ppu)

	exec.cpu_init(sys.cpu, sys.bus)
	return sys
}

system_cleanup :: proc(sys: ^System) {
	bus_err := free(sys.bus)
	if bus_err != .None {
		panic("Could not free the emulator's backing memory. Perhaps a bad pointer was passed.")
	}

	cpu_err := free(sys.cpu)
	if cpu_err != .None {
		panic("Could not free the CPU's backing memory. Perhaps a bad pointer was passed.")
	}

	ppu_err := free(sys.ppu)
	if ppu_err != .None {
		panic("Could not free the PPU's backing memory. Perhaps a bad pointer was passed.")
	}

	apu_err := free(sys.apu)
	if apu_err != .None {
		panic("Could not free the APU's backing memory. Perhaps a bad pointer was passed.")
	}

	sys_err := free(sys)
	if sys_err != .None {
		panic("Could not finalize freeing the emulator. Perhaps a bad pointer was passed.")
	}
}

@(require_results)
system_load_cart_from_file :: proc(sys: ^System, path: string) -> os.Error {
	file := os.open(path) or_return
	defer os.close(file)
	flsz := os.file_size(file) or_return

	length := min(flsz, memory.TOTAL_ROM_SPACE)
	low: i64 = memory.CART_ROM_START
	high := low + length

	os.read(file, sys.bus.ram[low:high]) or_return
	return os.General_Error.None
}

@(require_results)
system_load_cart_from_bytes :: proc(sys: ^System, bytes: []byte) -> os.Error {
	if len(bytes) == 0 do return .Short_Buffer
	length := min(len(bytes), memory.TOTAL_ROM_SPACE)
	low := memory.CART_ROM_START

	mem.copy(&sys.bus.ram[low], &bytes[0], length)
	return os.General_Error.None
}

system_step_instruction :: proc(sys: ^System) -> (consumed: u64, entered_vblank: bool) {
	instr := exec.cpu_fetch_instruction(sys.cpu)
	exec.cpu_decode_execute(sys.cpu, instr)

	cpu_cycles := sys.cpu.cycle_delta + sys.bus.contention
	sys.bus.contention = 0

	total := cpu_cycles + sys.ppu_phase
	ppu_cycles := total / c.CPU_PPU_CYCLE_RATIO
	sys.ppu_phase = total % c.CPU_PPU_CYCLE_RATIO

	consumed = u64(cpu_cycles)
	sys.cpu.cycle_delta = 0
	gfx.ppu_decode_from_mmio(sys.ppu)

	for i in 0 ..< ppu_cycles {
		gfx.ppu_step(sys.ppu)
	}
	gfx.ppu_encode_to_mmio(sys.ppu)

	entered_vblank = .InVblank in sys.ppu.status && .InVblank not_in sys.ppu_prev_status
	entered_hblank := .InHblank in sys.ppu.status && .InHblank not_in sys.ppu_prev_status
	sys.ppu_prev_status = sys.ppu.status

	if entered_vblank && .DisableVblank not_in sys.ppu.ctrl {
		exec.cpu_trigger_interrupt(sys.cpu, exec.VBLNK_VEC_IDX, false)
	} else if entered_hblank && .DisableHblank not_in sys.ppu.ctrl {
		exec.cpu_trigger_interrupt(sys.cpu, exec.HBLNK_VEC_IDX, false, true)
	}

	sys.audio_cycle_scaled += consumed * c.AUDIO_SAMPLES_PER_FRAME
	for sys.audio_cycle_scaled >= c.CPU_CYCLES_PER_FRAME {
		sys.audio_cycle_scaled -= c.CPU_CYCLES_PER_FRAME
		audio_fifo_produce(&sys.audio_fifo, audio.apu_generate_sample(sys.apu))
	}

	return consumed, entered_vblank
}

audio_fifo_produce :: proc(fifo: ^AudioFifo, l, r: f32) {
	head := sync.atomic_load(&fifo.head)
	tail := sync.atomic_load(&fifo.tail)
	if head - tail >= AUDIO_FIFO_FRAMES {
		sync.atomic_store(&fifo.tail, tail + 1)
	}
	base := (head & (AUDIO_FIFO_FRAMES - 1)) * 2
	fifo.buf[base] = l
	fifo.buf[base + 1] = r
	sync.atomic_store(&fifo.head, head + 1)
}

audio_fifo_consume :: proc(fifo: ^AudioFifo) -> (l, r: f32, ok: bool) {
	head := sync.atomic_load(&fifo.head)
	tail := sync.atomic_load(&fifo.tail)
	if head == tail do return 0.0, 0.0, false
	base := (tail & (AUDIO_FIFO_FRAMES - 1)) * 2
	l, r = fifo.buf[base], fifo.buf[base + 1]
	sync.atomic_store(&fifo.tail, tail + 1)
	return l, r, true
}

audio_fifo_pending :: proc(fifo: ^AudioFifo) -> u32 {
	return sync.atomic_load(&fifo.head) - sync.atomic_load(&fifo.tail)
}

system_step_frame :: proc(sys: ^System) {
	start := sys.cycle_counter
	for {
		delta, entered := system_step_instruction(sys)
		sys.cycle_counter += delta
		if entered do break
		if sys.cycle_counter - start >= c.CPU_CYCLES_PER_FRAME do break
	}
}

system_write_input :: proc(sys: ^System, j1, j2, j3, j4: input.Joypad) {
	memory.bus_write_word(sys.bus, c.JOYPAD1, transmute(u16)j1)
	memory.bus_write_word(sys.bus, c.JOYPAD2, transmute(u16)j2)
	memory.bus_write_word(sys.bus, c.JOYPAD3, transmute(u16)j3)
	memory.bus_write_word(sys.bus, c.JOYPAD4, transmute(u16)j4)
}

system_stream_audio :: audio.apu_generate_sample
