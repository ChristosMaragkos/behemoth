package behemoth

import "/audio"
import c "/common"
import exec "/execution"
import gfx "/graphics"
import "/memory"
import "core:mem"
import "core:os"

System :: struct {
	cpu:           ^exec.Cpu,
	ppu:           ^gfx.Ppu,
	apu:           ^audio.Apu,
	bus:           ^memory.MemoryBus,
	cycle_counter: u64,
}

// Necessary for audio callbacks with fixed signatures
g_apu: ^audio.Apu

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
	g_apu = apu
	gfx.ppu_init(ppu, &bus.ram[memory.calculate_address(c.MMIO_PAGE, c.PPU_MMIO_OFFSET)])
	audio.apu_init(apu, &bus.ram[memory.calculate_address(c.MMIO_PAGE, c.APU_MMIO_OFFSET)])

	sys.bus.vram = &ppu.vram
	sys.bus.cram = &ppu.cram
	sys.bus.oam = &ppu.oam

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

system_load_cart_from_file :: proc(sys: ^System, path: string) -> os.Error {
	file := os.open(path) or_return
	flsz := os.file_size(file) or_return

	length := min(flsz, memory.TOTAL_ROM_SPACE)
	low: i64 = memory.CART_ROM_START
	high := low + length

	os.read(file, sys.bus.ram[low:high]) or_return
	return os.General_Error.None
}

system_load_cart_from_bytes :: proc(sys: ^System, bytes: []byte) {
	length := min(len(bytes), memory.TOTAL_ROM_SPACE)
	low := memory.CART_ROM_START

	mem.copy(&sys.bus.ram[low], &bytes[0], length)
}

system_step_instruction :: proc(sys: ^System) {
	instr := exec.cpu_fetch_instruction(sys.cpu)
	exec.cpu_decode_execute(sys.cpu, instr)

	sys.cpu.cycle_delta += sys.bus.contention
	sys.bus.contention = 0

	ppu_cycles := sys.cpu.cycle_delta / c.CPU_PPU_CYCLE_RATIO
	remaining := sys.cpu.cycle_delta % c.CPU_PPU_CYCLE_RATIO

	sys.cpu.cycle_delta = remaining
	gfx.ppu_decode_from_mmio(sys.ppu)

	for i in 0 ..< ppu_cycles {
		gfx.ppu_step(sys.ppu)
	}
	gfx.ppu_encode_to_mmio(sys.ppu)

	if .InVblank in sys.ppu.status {
		exec.cpu_trigger_interrupt(sys.cpu, exec.VBLNK_VEC_IDX, false)
	} else if .InHblank in sys.ppu.status {
		exec.cpu_trigger_interrupt(sys.cpu, exec.HBLNK_VEC_IDX, false)
	}
}
