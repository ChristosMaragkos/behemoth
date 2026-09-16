package behemoth

import exec "/execution"
import gfx "/graphics"
import "/memory"
import "core:mem"
import "core:os"
import "core:slice"

MMIO_PAGE :: 0x05
CPU_PPU_CYCLE_RATIO :: 2

System :: struct {
	cpu:           ^exec.Cpu,
	ppu:           ^gfx.Ppu,
	bus:           ^memory.MemoryBus,
	cycle_counter: u64,
}

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

	bus, bus_err := new(memory.MemoryBus)
	if bus_err != .None {
		panic("Could not allocate memory for the memory bus, require 16mb.")
	}

	sys.cpu = cpu
	sys.bus = bus
	sys.ppu = ppu
	ppu.mmio_view = slice.bytes_from_ptr(
		&bus.ram[memory.calculate_address(MMIO_PAGE, gfx.PPU_MMIO_OFFSET)],
		0xff,
	)

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
