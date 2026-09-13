package memory

PAGE_SIZE :: 64 * 1024 // 64kb per page
RAM_SIZE_TOTAL :: 256 * PAGE_SIZE // 256 pages total -> 16mb address space

CART_ROM_START :: 6 * PAGE_SIZE
CART_ROM_END :: 197 * PAGE_SIZE - 1 // The final address, not the start of the next region
TOTAL_ROM_PAGES :: 192
TOTAL_ROM_SPACE :: TOTAL_ROM_PAGES * PAGE_SIZE

ADDRESS_BITMASK :: 0b111111111111111111111111 // 24-bit address space

IVT_PAGE :: 0x05
IVT_START_OFFS :: 0x0000

MainRam :: [RAM_SIZE_TOTAL]byte

ram_read_byte :: proc(memory: []byte, address: u32) -> byte {
	return memory[address]
}

ram_read_word :: proc(memory: []byte, address: u32) -> u16 {
	low := memory[address]
	high := memory[address + 1]
	return (u16(high) << 8) | u16(low)
}

ram_write_byte :: proc(memory: []byte, address: u32, value: byte) {
	memory[address] = value
}

ram_write_word :: proc(memory: []byte, address: u32, value: u16) {
	memory[address] = u8(value)
	memory[address + 1] = u8(value >> 8)
}
