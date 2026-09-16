package memory

is_valid_write :: proc(addr: u32) -> bool {
	switch addr {
		case CART_ROM_START ..= CART_ROM_END:
			return false
		case:
			return true
	}
}

is_valid_read :: proc(addr: u32) -> bool {
	// FIXME: This is a no-op until MMIO is implemented
	return true
}

calculate_address :: proc(page: u8, offset: u16) -> u32 {
	return u32(page << 16) | u32(offset)
}

MemoryBus :: struct {
	ram:   MainRam,
	latch: u16,
}

bus_read_byte :: proc(bus: ^MemoryBus, addr: u32) -> byte {
	if !is_valid_read(addr) do return byte(bus.latch)

	return ram_read_byte(bus.ram[:], addr)
}

bus_read_word :: proc(bus: ^MemoryBus, addr: u32) -> u16 {
	if !is_valid_read(addr) do return bus.latch

	return ram_read_word(bus.ram[:], addr)
}

bus_write_byte :: proc(bus: ^MemoryBus, addr: u32, val: byte) {
	if !is_valid_write(addr) do return

	ram_write_byte(bus.ram[:], addr, val)
}

bus_write_word :: proc(bus: ^MemoryBus, addr: u32, val: u16) {
	if !is_valid_write(addr) do return

	ram_write_word(bus.ram[:], addr, val)
}
