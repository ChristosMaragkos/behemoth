package shared

import "core:fmt"
import "core:mem"
HEADER_MAGIC: [3]byte = "BHM"
CURRENT_ROM_FORMAT_VERSION :: 1
HEADER_REQUIRED_SIZE :: 32

Header :: struct #packed {
	magic:   [3]byte,
	version: byte,
	name:    [8]byte,
	_:       [20]byte,
}
#assert(size_of(Header) == HEADER_REQUIRED_SIZE)

Header_validate_magic :: proc(h: ^Header) -> bool {
	return mem.compare(h.magic[:], HEADER_MAGIC[:]) == 0
}

Header_format :: proc(h: ^Header) -> (bool, string) {
	valid := Header_validate_magic(h)
	magic_str := fmt.aprintf("%s -> %s", h.magic, valid ? "Valid!" : "Not Valid!")
	result: string
	switch h.version {
		case:
			result = fmt.aprintf(
				"BHMTH cartridge file:\n| Magic:   %s\n| Version: %d\n| Name:    %s",
				magic_str,
				h.version,
				h.name,
			)
	}
	delete(magic_str)
	return valid, result
}
