package romfix

import s "../../shared"
import "core:fmt"
import "core:os"
import "core:strings"

main :: proc() {
	validate := false

	fmt.printfln("romfix - validate BHMTH cartridge file header contents")
	if len(os.args) < 2 {
		fmt.printfln("usage: romfix <file name> [--validate]")
		os.exit(1)
	}

	if len(os.args) >= 3 {
		for arg in os.args[2:] {
			if strings.starts_with(arg, "--") {
				if strings.compare(arg[2:], "validate") != 0 {
					fmt.printfln("unknown option '%s'", arg[2:])
					fmt.printfln("usage: romfix <file name> [--validate]")
					os.exit(1)
				}
				if validate {
					fmt.println("duplicate option 'validate'")
					fmt.printfln("usage: romfix <file name> [--validate]")
					os.exit(1)
				}
				validate = true
			}
		}
	}

	filename := os.args[1]
	cart, err := os.open(filename)
	if err != nil {
		fmt.printfln("Error reading file <%s>: %s", filename, err)
		os.exit(1)
	}

	header_bytes: [size_of(s.Header)]byte = {}
	amnt: int
	amnt, err = os.read_at_least(cart, header_bytes[:], size_of(s.Header))
	if err != nil || amnt != size_of(s.Header) {
		fmt.printfln("Error reading file <%s>: %s", filename, err)
		os.exit(1)
	}

	h := transmute(s.Header)(header_bytes)
	valid, str := Header_format(&h)
	fmt.printfln(str)
	delete(str)
	os.exit(validate && !valid ? 1 : 0)
}

Header_format :: proc(h: ^s.Header) -> (bool, string) {
	valid := s.Header_validate_magic(h)
	magic_str := fmt.aprintf("%s -> %s", h.magic, valid ? "Valid!" : "Not Valid!")
	result: string
	switch h.version {
		case 1:
			result = fmt.aprintf(
				"BHMTH cartridge file:\n| Magic:   %s\n| Version: %d\n| Name:    %s",
				magic_str,
				h.version,
				h.name,
			)
		case 2:
			result = fmt.aprintf(
				"BHMTH cartridge file:\n| Magic:   %s\n| Version: %d\n| Name:    %s\n| Cartridge memory pages: %d\n| Battery-backed SRAM pages: %d",
				magic_str,
				h.version,
				h.name,
				h.rom_pages,
				h.sram_pages,
			)
	}
	delete(magic_str)
	return valid, result
}
