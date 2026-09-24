package syntax

import "../common"

CONSTANTS: map[string]Constant

Constant :: struct {
	using _:   struct #raw_union {
		unsigned: u32,
		signed:   i32,
	},
	is_signed: bool,
}

init_constants :: proc() {
	CONSTANTS = make(map[string]Constant)
}

free_constants :: proc() {
	delete(CONSTANTS)
}

define_constant_unsigned :: proc(name: string, #any_int value: u32) -> common.AssemblerError {
	if name in CONSTANTS do return common.make_errorf("Redefinition of constant '%s'", name)

	c: Constant = {
		unsigned  = value,
		is_signed = false,
	}
	CONSTANTS[name] = c
	return common.no_error()
}

define_constant_signed :: proc(name: string, #any_int value: i32) -> common.AssemblerError {
	if name in CONSTANTS do return common.make_errorf("Redefinition of constant '%s'", name)

	c: Constant = {
		signed    = value,
		is_signed = true,
	}
	CONSTANTS[name] = c
	return common.no_error()
}

define_constant :: proc {
	define_constant_unsigned,
	define_constant_signed,
}

resolve_constant :: proc(name: string) -> (Constant, common.AssemblerError) {
	val, ok := CONSTANTS[name]
	if !ok do return {}, common.make_errorf("Unknown constant '%s'", name)

	return val, common.no_error()
}
