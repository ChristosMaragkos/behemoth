package syntax

// TODO: Temp labels with @label

import "../common"

LABELS: map[string]Label

Label :: struct {
	addr: u32,
}

label_page :: proc(l: Label) -> u8 {
	return u8(l.addr >> 16)
}

label_offset :: proc(l: Label) -> u16 {
	return u16(l.addr)
}

label_full :: proc(l: Label) -> u32 {
	return l.addr & 0xFFFFFF
}

init_labels :: proc() {
	LABELS = make(map[string]Label)
}

free_labels :: proc() {
	if LABELS == nil do return
	err := delete(LABELS)
	if err != .None do fmt.panicf("Error freeing label table: %s", err)
	LABELS = nil
}

define_label :: proc(name: string, address: u32) -> common.AssemblerError {
	if name in LABELS do return common.make_errorf("Redefinition of non-temporary label '%s'", name)
	if name in CONSTANTS do return common.make_errorf("Redefinition of constant '%s' as label", name)

	LABELS[name] = {
		addr = address,
	}
	return common.no_error()
}

resolve_label :: proc(name: string) -> (Label, common.AssemblerError) {
	val, ok := LABELS[name]
	if !ok do return {}, common.make_errorf("Unknown label '%s'", name)

	return val, common.no_error()
}
