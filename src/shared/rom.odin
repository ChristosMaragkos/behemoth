package shared

import "core:mem"
HEADER_MAGIC: [3]byte = "BHM"
CURRENT_ROM_FORMAT_VERSION :: 2
HEADER_REQUIRED_SIZE :: 32

Header :: struct #packed {
	magic:      [3]byte,
	version:    byte,
	name:       [8]byte,
	rom_pages:  byte,
	sram_pages: byte,
	_:          [18]byte,
}
#assert(size_of(Header) == HEADER_REQUIRED_SIZE)

Header_validate_magic :: proc(h: ^Header) -> bool {
	return mem.compare(h.magic[:], HEADER_MAGIC[:]) == 0
}
