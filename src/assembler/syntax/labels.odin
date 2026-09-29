package syntax

import "core:fmt"

import "../common"

LABELS: map[string]Label

TEMP_ID_POOL: [dynamic]string

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

init_temp_labels :: proc() {
	TEMP_ID_POOL = make([dynamic]string)
}

free_temp_labels :: proc() {
	if TEMP_ID_POOL == nil do return
	for id in TEMP_ID_POOL do delete(id)
	delete(TEMP_ID_POOL)
	TEMP_ID_POOL = nil
}

is_temp_name :: #force_inline proc(s: string) -> bool {
	return len(s) > 1 && s[0] == '@'
}

TempDef :: struct {
	index: int,
	id:    string,
}

resolve_temp_labels :: proc(stmts: []Statement) -> common.AssemblerError {
	defs := make(map[string][dynamic]TempDef)
	defer {
		for _, list in defs do delete(list)
		delete(defs)
	}
	counters := make(map[string]int)
	defer delete(counters)

	for i in 0 ..< len(stmts) {
		lbl, ok := stmts[i].(LabelDef)
		if !ok do continue
		if !is_temp_name(lbl.label.text) do continue
		base := lbl.label.text
		n := counters[base]
		counters[base] = n + 1
		if TEMP_ID_POOL == nil do TEMP_ID_POOL = make([dynamic]string)
		id := fmt.aprintf("%s#%d", base, n)
		append(&TEMP_ID_POOL, id)
		lbl.label.text = id
		stmts[i] = lbl
		list, _ := defs[base]
		append(&list, TempDef{index = i, id = id})
		defs[base] = list
	}

	for i in 0 ..< len(stmts) {
		#partial switch st in stmts[i] {
		case Mnemonic:
			for j in 0 ..< int(st.amount) {
				raw, ok := st.operands[j].(RawOperand)
				if !ok do continue
				bind_temp_uses(([]Token)(raw), i, defs)
			}
		case Directive:
			for j in 0 ..< len(st.operands) {
				raw, ok := st.operands[j].(RawOperand)
				if !ok do continue
				bind_temp_uses(([]Token)(raw), i, defs)
			}
		}
	}

	return common.no_error()
}

bind_temp_uses :: proc(toks: []Token, use_index: int, defs: map[string][dynamic]TempDef) {
	for k in 0 ..< len(toks) {
		if toks[k].type != .Identifier do continue
		if !is_temp_name(toks[k].text) do continue
		list, found := defs[toks[k].text]
		if !found do continue
		chosen := -1
		for d, m in list {
			if d.index < use_index {
				chosen = m
			} else {
				if chosen == -1 do chosen = m
				break
			}
		}
		if chosen != -1 do toks[k].text = list[chosen].id
	}
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
