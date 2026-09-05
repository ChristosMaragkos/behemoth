package behemoth

PAGE_SIZE :: 64 * 1024 // 64kb per page
RAM_SIZE_TOTAL :: 256 * PAGE_SIZE // 256 pages total -> 16mb address space

ADDRESS_BITMASK :: 0b111111111111111111111111 // 24-bit address space

MainRam :: distinct [RAM_SIZE_TOTAL]byte

calculate_address :: #force_inline proc(page: u8, offset: u16) -> u32 {
	return u32(page << 16) | u32(offset)
}

ram_read_byte :: proc(memory: []byte, page: u8, offset: u16) -> byte {
	address := calculate_address(page, offset)
	return memory[address]
}

ram_read_word :: proc(memory: []byte, page: u8, offset: u16) -> u16 {
	address := calculate_address(page, offset)
	low := memory[address]
	high := memory[address + 1]
	return (u16(high) << 8) | u16(low)
}

ram_write_byte :: proc(memory: []byte, page: u8, offset: u16, value: byte) {
	address := calculate_address(page, offset)
	memory[address] = value
}

ram_write_word :: proc(memory: []byte, page: u8, offset: u16, value: u16) {
	address := calculate_address(page, offset)
	memory[address] = u8(value)
	memory[address + 1] = u8(value >> 8)
}
