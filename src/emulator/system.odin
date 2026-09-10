package behemoth

import "./memory"
import exec "/execution"

CYCLES_PER_FRAME :: 122880

System :: struct {
	cpu:           ^exec.Cpu,
	bus:           ^memory.MemoryBus,
	cycle_counter: u64,
}

system_init :: proc() -> ^System {
	sys, err := new(System)
	if err != .None {
		panic("Could not allocate memory for the emulator.")
	}
	exec.cpu_init(sys.cpu, sys.bus)
	return sys
}

system_cleanup :: proc(sys: ^System) {
	err := free(sys)
	if err != .None {
		panic("Could not free the emulator's backing memory. Perhaps a bad pointer was passed.")
	}
}
