package common

import "core:fmt"

AssemblerError :: struct {
	msg:           string,
	raised:        bool,
	requires_free: bool,
}

make_error :: proc(message: string) -> AssemblerError {
	return {msg = message, raised = true, requires_free = false}
}

free_error :: proc(e: ^AssemblerError) {
	if e.requires_free do delete(e.msg)
}

make_errorf :: proc(message: string, args: ..any) -> AssemblerError {
	formatted := fmt.aprintf(message, ..args)
	return {msg = formatted, raised = true, requires_free = true}
}

no_error :: proc() -> AssemblerError {
	return {msg = "", raised = false, requires_free = false}
}
