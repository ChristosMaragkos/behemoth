package syntax

import "../../shared"
import "../common"
import "../cpu"
import "core:path/filepath"

Emitter :: struct {
	rom_offset:  u32,
	mem_offset:  u32,
	output:      [dynamic]byte,
	cursor:      u32,
	fixups:      [dynamic]Fixup,
	wram_cursor: u32,
	in_wram:     bool,
}

FixupKind :: enum {
	Invalid,
	Abs8,
	Abs16,
	Abs24,
	Abs32,
	Rel8,
	Rel16,
}

Fixup :: struct {
	pos:  u32,
	tok:  Token,
	kind: FixupKind,
	end:  u32,
}

emitter_pass_0 :: proc(stmts: []Statement) -> common.AssemblerError {
	for &st in stmts {
		drctv, ok := st.(Directive)
		if !ok do continue
		if drctv.directive.text != ".equ" do continue

		err := validate_directive_operands(&drctv)
		if err.raised do return err

		name, name_ok := drctv.operands[0].(ResolvedOperand).(Op_Imm)
		if !name_ok do return token_error(&drctv.directive, "Internal error: malformed .equ name operand")
		val, val_ok := drctv.operands[1].(ResolvedOperand).(Op_Imm)
		if !val_ok do return token_error(&drctv.directive, "Internal error: malformed .equ value operand")

		if val.expr.is_signed {
			if val.expr.val < i64(min(i32)) || val.expr.val > i64(max(i32)) do return token_errorf(&drctv.directive, "Constant '%s' value %d outside 32-bit signed range", name.expr.symbol, val.expr.val)
			if derr := define_constant_signed(name.expr.symbol, i32(val.expr.val)); derr.raised do return derr
		} else {
			if val.expr.val < 0 || val.expr.val > i64(max(u32)) do return token_errorf(&drctv.directive, "Constant '%s' value %d outside 32-bit unsigned range", name.expr.symbol, val.expr.val)
			if derr := define_constant_unsigned(name.expr.symbol, u32(val.expr.val)); derr.raised do return derr
		}
	}

	return common.no_error()
}

validate_directive_operands :: proc(directive: ^Directive) -> common.AssemblerError {
	if len(directive.operands) != 0 {
		_, ok := directive.operands[0].(ResolvedOperand)
		if !ok do return token_errorf(&directive.directive, "Cannot validate non-resolved operands for directive '%s'", directive.directive.text)
	}
	switch directive.directive.text {
		case ".equ":
			if len(directive.operands) != 2 do return token_errorf(&directive.directive, "Expected 2 operands for .equ directive, found %d instead. Correct syntax: .equ <name>, <value>", len(directive.operands))

			name, name_ok := directive.operands[0].(ResolvedOperand).(Op_Imm)
			if !name_ok || name.expr.type != .Symbol do return token_error(&directive.directive, "Expected identifier for .equ constant name")

			val, value_ok := directive.operands[1].(ResolvedOperand).(Op_Imm)
			if !value_ok || val.expr.type != .Integer do return token_error(&directive.directive, "Expected integer for .equ constant value")
		case ".org":
			if len(directive.operands) != 1 do return token_errorf(&directive.directive, "Expected only 1 operand for .org directive, found %d instead", len(directive.operands))

			first, ok := directive.operands[0].(ResolvedOperand).(Op_Imm)
			if !ok do return token_error(&directive.directive, "Expected integer, label, or constant for .org directive")

			switch first.expr.type {
				case .Symbol:
					return token_error(
						&directive.directive,
						"Using the .org directive with a label or constant is not implemented yet",
					)
				case .Integer:
					if first.expr.is_signed do return token_error(&directive.directive, ".org operand value cannot be signed")
					if first.expr.val > 0xFFFFFF do return token_error(&directive.directive, ".org operand value can not be larger than the 24-bit integer limit (0xFFFFFF)")
			}
		case ".dw":
			if len(directive.operands) == 0 do return token_errorf(&directive.directive, ".dw directive requires one or more operands")

			for op in directive.operands {
				imm, ok := op.(ResolvedOperand).(Op_Imm)
				if !ok do return token_errorf(&directive.directive, "Expected integer, label or constant for .dw directive")

				switch imm.expr.type {
					case .Symbol:
						if imm.expr.is_signed do return token_error(&directive.directive, "Negated label in .dw directive is not supported")
					case .Integer:
						fits := fits_width(imm.expr.val, 16)
						if !fits do return token_errorf(&directive.directive, "Value '%d' out of 16-bit range required by .dw directive", imm.expr.val)
				}
			}
		case ".db":
			if len(directive.operands) == 0 do return token_errorf(&directive.directive, ".db directive requires one or more operands")

			for op in directive.operands {
				_, ok := op.(ResolvedOperand).(Op_String)
				if ok do continue

				imm: Op_Imm
				imm, ok = op.(ResolvedOperand).(Op_Imm)
				if !ok do return token_errorf(&directive.directive, "Expected integer, constant or string literal for .db directive")

				switch imm.expr.type {
					case .Symbol:
						if imm.expr.is_signed do return token_error(&directive.directive, "Negated label in .db directive is not supported")
					case .Integer:
						fits := fits_width(imm.expr.val, 8)
						if !fits do return token_errorf(&directive.directive, "Value '%d' out of 8-bit range required by .db directive", imm.expr.val)
				}
			}
		case ".include":
			return token_error(&directive.directive, "Internal error: unexpanded .include")
		case ".incbin":
			if len(directive.operands) != 1 do return token_errorf(&directive.directive, "Expected 1 operand for .incbin directive, found %d instead", len(directive.operands))
			_, ok := directive.operands[0].(ResolvedOperand).(Op_String)
			if !ok do return token_error(&directive.directive, "Expected string literal for .incbin directive")
		case ".dl":
			if len(directive.operands) == 0 do return token_errorf(&directive.directive, ".dl directive requires one or more operands")

			for op in directive.operands {
				imm, ok := op.(ResolvedOperand).(Op_Imm)
				if !ok do return token_errorf(&directive.directive, "Expected integer, label or constant for .dl directive")

				switch imm.expr.type {
					case .Symbol:
						if imm.expr.is_signed do return token_error(&directive.directive, "Negated label in .dl directive is not supported")
					case .Integer:
						fits := fits_width(imm.expr.val, 32)
						if !fits do return token_errorf(&directive.directive, "Value '%d' out of 32-bit range required by .dl directive", imm.expr.val)
				}
			}
		case ".d24":
			if len(directive.operands) == 0 do return token_errorf(&directive.directive, ".d24 directive requires one or more operands")

			for op in directive.operands {
				imm, ok := op.(ResolvedOperand).(Op_Imm)
				if !ok do return token_errorf(&directive.directive, "Expected integer, label or constant for .d24 directive")

				switch imm.expr.type {
					case .Symbol:
						if imm.expr.is_signed do return token_error(&directive.directive, "Negated label in .d24 directive is not supported")
					case .Integer:
						fits := fits_width(imm.expr.val, 24)
						if !fits do return token_errorf(&directive.directive, "Value '%d' out of 24-bit range required by .d24 directive", imm.expr.val)
				}
			}
		case ".pad":
			if len(directive.operands) != 1 do return token_errorf(&directive.directive, "Expected 1 operand for .pad directive, found %d instead", len(directive.operands))

			pad, ok := directive.operands[0].(ResolvedOperand).(Op_Imm)
			if !ok do return token_error(&directive.directive, "Expected integer for .pad directive")

			if pad.expr.type != .Integer do return token_error(&directive.directive, "Expected integer for .pad directive")
			if pad.expr.is_signed do return token_error(&directive.directive, ".pad operand value cannot be signed")
			if pad.expr.val > 65535 do return token_error(&directive.directive, ".pad operand value can not be larger than the 16-bit limit (0xFFFF)")
		case ".wram":
		case ".rom":
			if len(directive.operands) != 0 do return token_errorf(&directive.directive, "Directive '%s' takes no operands", directive.directive.text)
		case:
			return token_errorf(
				&directive.directive,
				"Unknown directive '%s'",
				directive.directive.text,
			)
	}

	return common.no_error()
}

statement_length :: proc(
	stmt: ^Statement,
	cursor: u32,
	in_wram: bool,
) -> (
	length: u32,
	new_cursor: u32,
	err: common.AssemblerError,
) {
	s := stmt^
	#partial switch &v in s {
		case LabelDef:
			return 0, cursor, common.no_error()
		case Directive:
			dtok := v.directive
			if in_wram {
				switch v.directive.text {
					case ".db", ".dw", ".dl", ".d24", ".incbin":
						return 0, cursor, token_error(
							&dtok,
							"Data emission is not allowed in WRAM",
						)
				}
			}
			switch v.directive.text {
				case ".org":
					if len(v.operands) != 1 do return 0, cursor, token_error(&dtok, "Internal error: .org without operand")
					op, ok := v.operands[0].(ResolvedOperand).(Op_Imm)
					if !ok || op.expr.type != .Integer do return 0, cursor, token_error(&dtok, "Internal error: .org operand not resolved")
					val := u32(op.expr.val)
					if val < cursor do return 0, cursor, token_error(&dtok, ".org cannot move cursor backwards")
					if in_wram {
						if val < cpu.WRAM_START || val > cpu.WRAM_END + 1 do return 0, cursor, token_error(&dtok, ".org address outside WRAM bounds")
					} else if val < cpu.ROM_START || val > cpu.ROM_END + 1 do return 0, cursor, token_error(&dtok, ".org address outside ROM bounds")
					return 0, val, common.no_error()
				case ".equ":
					return 0, cursor, common.no_error()
				case ".db":
					n: u32 = 0
					for op in v.operands {
						imm, ok := op.(ResolvedOperand).(Op_Imm)
						if ok {
							n += 1
							continue
						}
						str, sok := op.(ResolvedOperand).(Op_String)
						if !sok do return 0, cursor, token_error(&dtok, "Internal error: .db operand not resolved")
						n += u32(len(str.value))
					}
					return n, cursor, common.no_error()
				case ".dw":
					return u32(len(v.operands)) * 2, cursor, common.no_error()
				case ".dl":
					return u32(len(v.operands)) * 4, cursor, common.no_error()
				case ".d24":
					return u32(len(v.operands)) * 3, cursor, common.no_error()
				case ".pad":
					if len(v.operands) != 1 do return 0, cursor, token_error(&dtok, "Internal error: .pad without operand")
					pad, ok := v.operands[0].(ResolvedOperand).(Op_Imm)
					if !ok || pad.expr.type != .Integer do return 0, cursor, token_error(&dtok, "Internal error: .pad operand not resolved")
					return u32(pad.expr.val), cursor, common.no_error()
				case ".incbin":
					if len(v.operands) != 1 do return 0, cursor, token_error(&dtok, "Internal error: .incbin without operand")
					str, ok := v.operands[0].(ResolvedOperand).(Op_String)
					if !ok do return 0, cursor, token_error(&dtok, "Internal error: .incbin operand not resolved")
					full, joined := sibling_path(v.directive.filename, str.value)
					defer if joined do delete(full)
					data, rerr := read_provided_file(full)
					if rerr.raised do return 0, cursor, rerr
					n := u32(len(data))
					delete(data)
					return n, cursor, common.no_error()
				case ".include":
					return 0, cursor, token_error(&dtok, "Internal error: unexpanded .include")
				case ".wram", ".rom":
					return 0, cursor, common.no_error()
				case:
					return 0, cursor, token_errorf(
						&dtok,
						"Internal error: unknown directive '%s'",
						v.directive.text,
					)
			}
		case Mnemonic:
			mn := v
			mtok := mn.mnemonic
			if in_wram do return 0, cursor, token_error(&mtok, "Opcodes are not allowed in WRAM")
			form, ferr := select_mnemonic_form(&mn, mn.wide)
			if ferr.raised do return 0, cursor, ferr
			return form.length, cursor, common.no_error()
	}
	return 0, cursor, common.make_error("Internal error: unknown statement type")
}

select_mnemonic_form :: proc(mnem: ^Mnemonic, wide: bool) -> (Form, common.AssemblerError) {
	mtok := mnem.mnemonic
	if mnem.mnemonic.text not_in MNEMONICS do return {}, token_errorf(&mtok, "Undefined mnemonic '%s'", mnem.mnemonic.text)

	forms := MNEMONICS[mnem.mnemonic.text]

	any_arity := false

	for form in forms {
		if form_has_symbol(form) do continue
		if len(form.shapes) != int(mnem.amount) do continue
		any_arity = true
		matched := true
		for i in 0 ..< len(form.shapes) {
			op, ok := mnem.operands[i].(ResolvedOperand)
			if !ok do return {}, token_error(&mtok, "Internal error: selecting with unresolved operands")
			if !operand_matches_shape(form.shapes[i], op) {
				matched = false
				break
			}
		}
		if matched do return form, common.no_error()
	}

	best := Form{}
	found := false

	for form in forms {
		if !form_has_symbol(form) do continue
		if len(form.shapes) != int(mnem.amount) do continue
		any_arity = true
		matched := true
		for i in 0 ..< len(form.shapes) {
			op, ok := mnem.operands[i].(ResolvedOperand)
			if !ok do return {}, token_error(&mtok, "Internal error: selecting with unresolved operands")
			if !operand_matches_shape(form.shapes[i], op) {
				matched = false
				break
			}
		}
		if !matched do continue
		if !found || (wide && form.length > best.length) || (!wide && form.length < best.length) {
			best = form
			found = true
		}
	}

	if found do return best, common.no_error()
	if !any_arity do return {}, token_errorf(&mtok, "No form of mnemonic '%s' takes %d operands", mnem.mnemonic.text, int(mnem.amount))
	return {}, token_errorf(&mtok, "No matching form for mnemonic '%s'", mnem.mnemonic.text)
}

pass1_size_and_relax :: proc(e: ^Emitter, stmts: []Statement) -> common.AssemblerError {
	for i in 0 ..< len(stmts) {
		if mnem, ok := stmts[i].(Mnemonic); ok {
			mnem.wide = true
			stmts[i] = mnem
		}
	}
	if LABELS == nil do LABELS = make(map[string]Label)
	addrs := make([dynamic]u32, len(stmts))
	defer delete(addrs)
	for _ in 0 ..< 256 {
		e.cursor = cpu.ROM_START
		e.wram_cursor = cpu.WRAM_START
		e.in_wram = false
		keys := make([dynamic]string)
		for k in LABELS do append(&keys, k)
		for k in keys do delete_key(&LABELS, k)
		delete(keys)
		changed := false
		for i in 0 ..< len(stmts) {
			cur := e.cursor
			if e.in_wram do cur = e.wram_cursor
			addrs[i] = cur
			if lbl, ok := stmts[i].(LabelDef); ok {
				if derr := define_label(lbl.label.text, cur); derr.raised do return derr
				continue
			}
			if drctv, ok := stmts[i].(Directive); ok {
				if drctv.directive.text == ".wram" {
					e.in_wram = true
					continue
				}
				if drctv.directive.text == ".rom" {
					e.in_wram = false
					continue
				}
				if drctv.directive.text == ".equ" do continue
			}
			length, new_cursor, lerr := statement_length(&stmts[i], cur, e.in_wram)
			if lerr.raised do return lerr
			end_cap := cpu.ROM_END + 1
			if e.in_wram do end_cap = cpu.WRAM_END + 1
			if new_cursor + length > end_cap do return common.make_error("Exceeded region size limit")
			if e.in_wram {
				e.wram_cursor = new_cursor + length
			} else {
				e.cursor = new_cursor + length
			}
		}
		for i in 0 ..< len(stmts) {
			mnem, ok := stmts[i].(Mnemonic)
			if !ok do continue

			fw, err := select_mnemonic_form(&mnem, true)
			if err.raised do return err

			fn: Form
			fn, err = select_mnemonic_form(&mnem, false)
			if err.raised do return err
			if fn.length >= fw.length do continue
			sym_name := ""
			sym_tok := Token{}
			sym_count := 0
			for idx in 0 ..< len(fn.shapes) {
				if fn.shapes[idx] != .Symbol do continue
				sym_count += 1
				op, ook := mnem.operands[idx].(ResolvedOperand).(Op_Imm)
				if !ook || op.expr.type != .Symbol do return common.make_error("Internal error: symbol operand malformed")
				sym_name = op.expr.symbol
				sym_tok = op.expr.tok
			}
			if sym_count != 1 do return common.make_error("Internal error: branch without single symbol")
			target: u32
			if lbl, lok := LABELS[sym_name]; lok {
				target = lbl.addr
			} else {
				return token_errorf(&sym_tok, "Undefined label '%s'", sym_name)
			}
			narrow_end := addrs[i] + fn.length
			rel := i64(target) - i64(narrow_end)
			if rel >= -128 && rel <= 127 {
				if mnem.wide {
					m := mnem
					m.wide = false
					stmts[i] = m
					changed = true
				}
			}
		}
		if !changed do return common.no_error()
	}
	return common.make_error("Internal error: branch relaxation did not converge")
}

encode_mnemonic :: proc(
	e: ^Emitter,
	mnem: Mnemonic,
	form: Form,
	addr: u32,
) -> common.AssemblerError {
	regs: [dynamic]int
	defer delete(regs)
	values: [dynamic]int
	defer delete(values)
	value_toks: [dynamic]Token
	defer delete(value_toks)
	value_from_name := false
	sym_count := 0
	sym_tok := Token{}
	for i in 0 ..< len(form.shapes) {
		op := mnem.operands[i].(ResolvedOperand)
		switch form.shapes[i] {
			case .Reg8, .Reg16:
				reg := op.(Op_Reg)
				append(&regs, int(reg.reg.index))
			case .PairBare:
				pair := op.(Op_Reg_Pair)
				append(&regs, int(pair.hi.index))
				append(&regs, int(pair.lo.index))
			case .Imm8, .Imm16, .Imm24, .Imm32:
				imm := op.(Op_Imm)
				v, verr := expr_value(imm.expr)
				if verr.raised do return verr
				append(&values, int(v))
				append(&value_toks, imm.expr.tok)
				if imm.expr.symbol != "" do value_from_name = true
			case .Symbol:
				imm := op.(Op_Imm)
				if imm.expr.type != .Symbol do return common.make_error("Internal error: symbol operand malformed")
				sym_count += 1
				sym_tok = imm.expr.tok
			case .String:
				return common.make_error("Internal error: string operand in instruction")
			case .RegPtr, .PostInc, .PreInc, .PostDec, .PreDec:
				deref := op.(Op_Deref)
				append(&regs, int(deref.base_lo.index))
			case .ImmPtr:
				deref := op.(Op_Deref)
				v, verr := expr_value(deref.imm_offs)
				if verr.raised do return verr
				append(&values, int(v))
				append(&value_toks, deref.imm_offs.tok)
				if deref.imm_offs.symbol != "" do value_from_name = true
			case .RegPtrImmOffs:
				deref := op.(Op_Deref)
				append(&regs, int(deref.base_lo.index))
				v, verr := expr_value(deref.imm_offs)
				if verr.raised do return verr
				append(&values, int(v))
				append(&value_toks, deref.imm_offs.tok)
				if deref.imm_offs.symbol != "" do value_from_name = true
			case .RegPtrRegOffs:
				deref := op.(Op_Deref)
				append(&regs, int(deref.base_lo.index))
				append(&regs, int(deref.reg_offs.index))
			case .PairPtr:
				deref := op.(Op_Deref)
				append(&regs, int(deref.base_hi.index))
				append(&regs, int(deref.base_lo.index))
			case .PairImmOffs:
				deref := op.(Op_Deref)
				append(&regs, int(deref.base_hi.index))
				append(&regs, int(deref.base_lo.index))
				v, verr := expr_value(deref.imm_offs)
				if verr.raised do return verr
				append(&values, int(v))
				append(&value_toks, deref.imm_offs.tok)
				if deref.imm_offs.symbol != "" do value_from_name = true
			case .PairRegOffs:
				deref := op.(Op_Deref)
				append(&regs, int(deref.base_hi.index))
				append(&regs, int(deref.base_lo.index))
				append(&regs, int(deref.reg_offs.index))
			case .Imm24RegOffs:
				deref := op.(Op_Deref)
				v, verr := expr_value(deref.imm_offs)
				if verr.raised do return verr
				append(&values, int(v))
				append(&value_toks, deref.imm_offs.tok)
				if deref.imm_offs.symbol != "" do value_from_name = true
				append(&regs, int(deref.reg_offs.index))
		}
	}
	for r in regs {
		if r < 0 || r > 7 do return common.make_error("Internal error: register index out of range")
	}
	extra := len(regs) - 2
	if extra < 0 do extra = 0
	packs := (extra + 1) / 2
	trailing := int(form.length) - 2 - packs
	if trailing < 0 do return common.make_error("Internal error: instruction length too short for operands")
	if sym_count > 0 {
		if sym_count > 1 do return common.make_error("Internal error: multiple symbols in instruction")
		if len(values) != 0 do return common.make_error("Internal error: symbol form produced a value")
		if trailing == 0 do return common.make_error("Internal error: symbol form has no trailing bytes")
	} else {
		if len(values) > 1 do return common.make_error("Internal error: multiple value operands")
		if (trailing == 0) != (len(values) == 0) do return common.make_error("Internal error: trailing bytes do not match operands")
	}
	if trailing > 4 do return common.make_error("Internal error: trailing width exceeds 32 bits")

	instr := transmute(shared.Instruction)u16(form.opcode)
	if len(regs) > 0 do instr.reg1 = u8(regs[0])
	if len(regs) > 1 do instr.reg2 = u8(regs[1])
	if err := emitter_emit_u16(e, transmute(u16)instr); err.raised do return err

	pi := 2
	for len(regs) - pi >= 2 {
		if err := emitter_emit_byte(e, byte(regs[pi]) | (byte(regs[pi + 1]) << 3)); err.raised do return err
		pi += 2
	}
	if len(regs) - pi == 1 {
		if err := emitter_emit_byte(e, byte(regs[pi])); err.raised do return err
	}

	if sym_count > 0 {
		kind, kerr := fixup_kind_for(form, trailing, sym_tok)
		if kerr.raised do return kerr
		pos := u32(len(e.output))
		for _ in 0 ..< trailing {
			if err := emitter_emit_byte(e, 0); err.raised do return err
		}
		append(&e.fixups, Fixup{pos = pos, tok = sym_tok, kind = kind, end = addr + form.length})
	} else if len(values) == 1 {
		lo := -(i64(1) << (8 * u64(trailing) - 1))
		hi := (i64(1) << (8 * u64(trailing))) - 1
		if i64(values[0]) < lo || i64(values[0]) > hi {
			if value_from_name {
				mask := (i64(1) << (8 * u64(trailing))) - 1
				values[0] = int(i64(values[0]) & mask)
			} else {
				return token_errorf(
					&value_toks[0],
					"Value %d (0x%X) out of range for %d-bit operand",
					values[0],
					values[0],
					trailing * 8,
				)
			}
		}
		switch trailing {
			case 1:
				if err := emitter_emit_byte(e, byte(values[0])); err.raised do return err
			case 2:
				if err := emitter_emit_u16(e, u16(values[0])); err.raised do return err
			case 3:
				if err := emitter_emit_u24(e, u32(values[0])); err.raised do return err
			case 4:
				if err := emitter_emit_u32(e, u32(values[0])); err.raised do return err
			case:
				return common.make_error("Internal error: unsupported trailing width")
		}
	}

	return common.no_error()
}

apply_fixups :: proc(e: ^Emitter) -> common.AssemblerError {
	for i in 0 ..< len(e.fixups) {
		f := e.fixups[i]
		lbl, lerr := resolve_label(f.tok.text)
		if lerr.raised {
			common.free_error(&lerr)
			return token_errorf(&f.tok, "Undefined label '%s'", f.tok.text)
		}
		target := lbl.addr
		switch f.kind {
			case .Abs8:
				if f.pos >= u32(len(e.output)) do return token_errorf(&f.tok, "Internal error: fixup outside output")
				e.output[f.pos] = u8(target & 0xFF)
			case .Abs16:
				v := u16(target & 0xFFFF)
				if f.pos + 1 >= u32(len(e.output)) do return token_errorf(&f.tok, "Internal error: fixup outside output")
				e.output[f.pos] = u8(v)
				e.output[f.pos + 1] = u8(v >> 8)
			case .Abs24:
				if target > 0xFFFFFF do return token_errorf(&f.tok, "Internal error: label address exceeds 24 bits")
				if f.pos + 2 >= u32(len(e.output)) do return token_errorf(&f.tok, "Internal error: fixup outside output")
				e.output[f.pos] = u8(target)
				e.output[f.pos + 1] = u8(target >> 8)
				e.output[f.pos + 2] = u8(target >> 16)
			case .Abs32:
				if f.pos + 3 >= u32(len(e.output)) do return token_errorf(&f.tok, "Internal error: fixup outside output")
				e.output[f.pos] = u8(target)
				e.output[f.pos + 1] = u8(target >> 8)
				e.output[f.pos + 2] = u8(target >> 16)
				e.output[f.pos + 3] = u8(target >> 24)
			case .Rel8:
				rel := i64(target) - i64(f.end)
				if rel < -128 || rel > 127 do return token_errorf(&f.tok, "Branch out of range for 8-bit offset")
				if f.pos >= u32(len(e.output)) do return token_errorf(&f.tok, "Internal error: fixup outside output")
				e.output[f.pos] = u8(i8(rel))
			case .Rel16:
				rel := i64(target) - i64(f.end)
				if rel < -32768 || rel > 32767 do return token_errorf(&f.tok, "Branch out of range for 16-bit offset")
				if f.pos + 1 >= u32(len(e.output)) do return token_errorf(&f.tok, "Internal error: fixup outside output")
				e.output[f.pos] = u8(u16(i16(rel)))
				e.output[f.pos + 1] = u8(u16(i16(rel)) >> 8)
			case .Invalid:
				return token_errorf(&f.tok, "Internal error: invalid fixup")
		}
	}

	return common.no_error()
}

emitter_init :: proc(e: ^Emitter) {
	e.cursor = cpu.ROM_START
	e.wram_cursor = cpu.WRAM_START
	e.in_wram = false
	e.output = make([dynamic]byte)
	e.fixups = make([dynamic]Fixup)
}

emitter_free :: proc(e: ^Emitter) {
	delete(e.output)
	delete(e.fixups)
}

emitter_has_room :: proc(e: ^Emitter, n: u32) -> bool {
	return n <= cpu.ROM_END + 1 - e.cursor
}

emitter_set_cursor :: proc(e: ^Emitter, val: u32) -> common.AssemblerError {
	if e.in_wram {
		if val < e.wram_cursor do return common.make_error("Cursor cannot move backwards")
		if val < cpu.WRAM_START || val > cpu.WRAM_END + 1 do return common.make_error("Cursor outside WRAM bounds")
		e.wram_cursor = val
		return common.no_error()
	}
	if val < e.cursor do return common.make_error("Cursor cannot move backwards")
	if val < cpu.ROM_START || val > cpu.ROM_END + 1 do return common.make_error("Cursor outside ROM bounds")
	resize(&e.output, int(val - cpu.ROM_START))
	e.cursor = val
	return common.no_error()
}

emitter_advance :: proc(e: ^Emitter, n: u32) -> common.AssemblerError {
	if e.in_wram {
		if n > cpu.WRAM_END + 1 - e.wram_cursor do return common.make_error("Exceeded WRAM size limit")
		e.wram_cursor += n
		return common.no_error()
	}
	if n > cpu.ROM_END + 1 - e.cursor do return common.make_error("Exceeded ROM size limit")
	e.cursor += n
	resize(&e.output, int(e.cursor - cpu.ROM_START))
	return common.no_error()
}

emitter_emit_byte :: proc(e: ^Emitter, val: byte) -> common.AssemblerError {
	if !emitter_has_room(e, 1) do return common.make_error("Exceeded ROM size limit")
	append(&e.output, val)
	e.cursor += 1
	return common.no_error()
}

emitter_emit_u16 :: proc(e: ^Emitter, val: u16) -> common.AssemblerError {
	if !emitter_has_room(e, 2) do return common.make_error("Exceeded ROM size limit")
	append(&e.output, u8(val), u8(val >> 8))
	e.cursor += 2
	return common.no_error()
}

emitter_emit_u24 :: proc(e: ^Emitter, val: u32) -> common.AssemblerError {
	if !emitter_has_room(e, 3) do return common.make_error("Exceeded ROM size limit")
	append(&e.output, u8(val), u8(val >> 8), u8(val >> 16))
	e.cursor += 3
	return common.no_error()
}

emitter_emit_u32 :: proc(e: ^Emitter, val: u32) -> common.AssemblerError {
	if !emitter_has_room(e, 4) do return common.make_error("Exceeded ROM size limit")
	append(&e.output, u8(val), u8(val >> 8), u8(val >> 16), u8(val >> 24))
	e.cursor += 4
	return common.no_error()
}

FileProvider :: proc(path: string) -> ([]byte, bool)

FILE_PROVIDER: FileProvider

FileBlob :: struct {
	text:          []byte,
	toks:          [dynamic]Token,
	filename:      string,
	owns_filename: bool,
}

free_file_blobs :: proc(pool: [dynamic]FileBlob) {
	for b in pool {
		delete(b.toks)
		delete(b.text)
		if b.owns_filename do delete(b.filename)
	}
	delete(pool)
}

read_provided_file :: proc(path: string) -> ([]byte, common.AssemblerError) {
	if FILE_PROVIDER == nil do return nil, common.make_error("File access requires a file provider")
	data, ok := FILE_PROVIDER(path)
	if !ok do return nil, common.make_errorf("Could not read file '%s'", path)
	return data, common.no_error()
}

sibling_path :: proc(origin_file, rel: string) -> (full: string, joined: bool) {
	if filepath.is_abs(rel) do return rel, false
	joined_path, jerr := filepath.join([]string{filepath.dir(origin_file), rel})
	if jerr != .None do return rel, false
	return joined_path, true
}

expand_includes :: proc(
	stmts: ^[dynamic]Statement,
	origin: string,
	depth: int,
	stack: ^[dynamic]string,
	pool: ^[dynamic]FileBlob,
) -> common.AssemblerError {
	if depth > 32 do return common.make_error("Include depth exceeded")
	for i in 0 ..< len(stack^) do if stack^[i] == origin do return common.make_errorf("Cyclical .include of '%s'", origin)

	sub := make([dynamic]string)
	defer delete(sub)
	for i in 0 ..< len(stack^) do append(&sub, stack^[i])
	append(&sub, origin)

	out := make([dynamic]Statement)
	for i in 0 ..< len(stmts^) {
		drctv, is_dir := stmts[i].(Directive)
		if !is_dir || drctv.directive.text != ".include" {
			append(&out, stmts[i])
			continue
		}
		if len(drctv.operands) != 1 {
			delete(out)
			return token_errorf(
				&drctv.directive,
				"Directive '.include' expects a single quoted path",
			)
		}
		raw, is_raw := drctv.operands[0].(RawOperand)
		toks := ([]Token)(raw)
		if !is_raw || len(toks) != 1 || toks[0].type != .StringLiteral {
			delete(out)
			return token_errorf(
				&drctv.directive,
				"Directive '.include' expects a single quoted path",
			)
		}
		rel := toks[0].text
		full, joined := sibling_path(origin, rel)
		data, rerr := read_provided_file(full)
		if rerr.raised {
			if joined do delete(full)
			delete(out)
			return rerr
		}
		blob := FileBlob {
			text          = data,
			filename      = full,
			owns_filename = joined,
		}
		text := string(data)
		toks2, lerr := tokenize(full, text)
		if lerr.raised {
			if joined do delete(full)
			delete(data)
			delete(out)
			return lerr
		}
		blob.toks = toks2
		lines := split_lines(blob.toks[:])
		sub_stmts, perr := parse_into_statements(lines[:])
		delete(lines)
		if perr.raised {
			if joined do delete(full)
			delete(toks2)
			delete(data)
			delete(out)
			return perr
		}
		if e2 := expand_includes(&sub_stmts, full, depth + 1, &sub, pool); e2.raised {
			if joined do delete(full)
			free_statements(sub_stmts)
			delete(toks2)
			delete(data)
			delete(out)
			return e2
		}
		append(pool, blob)
		append(&out, ..sub_stmts[:])
		delete(sub_stmts)
	}
	old := stmts^
	stmts^ = out
	delete(old)
	return common.no_error()
}

substitute_expression :: proc(expr: ^Expression) {
	if expr.type != .Symbol do return
	c, cerr := resolve_constant(expr.symbol)
	if cerr.raised {
		common.free_error(&cerr)
		return
	}
	val: i64 = c.is_signed ? i64(c.signed) : i64(c.unsigned)
	expr^ = Expression {
		val       = val,
		symbol    = expr.symbol,
		is_signed = c.is_signed,
		type      = .Integer,
		tok       = expr.tok,
	}
}

substitute_operand_slot :: proc(slot: ^OperandSlot) {
	tmp := slot^
	res, ok := tmp.(ResolvedOperand)
	if !ok do return
	if imm, is_imm := res.(Op_Imm); is_imm {
		m := imm
		substitute_expression(&m.expr)
		slot^ = ResolvedOperand(m)
		return
	}
	if deref, is_deref := res.(Op_Deref); is_deref {
		d := deref
		substitute_expression(&d.imm_offs)
		slot^ = ResolvedOperand(d)
		return
	}
}

substitute_constants :: proc(stmts: []Statement) {
	for &st in stmts {
		#partial switch &s in st {
			case Directive:
				if s.directive.text == ".equ" do continue
				for i in 0 ..< len(s.operands) {
					substitute_operand_slot(&s.operands[i])
				}
			case Mnemonic:
				for i in 0 ..< int(s.amount) {
					substitute_operand_slot(&s.operands[i])
				}
		}
	}
}

form_has_symbol :: proc(form: Form) -> bool {
	for shape in form.shapes do if shape == .Symbol do return true
	return false
}

expr_value :: proc(expr: Expression) -> (val: i64, err: common.AssemblerError) {
	if expr.type == .Integer do return expr.val, common.no_error()
	v, _, rerr := resolve_symbol(expr.symbol)
	if rerr.raised do return 0, rerr
	return v, common.no_error()
}

fixup_kind_for :: proc(
	form: Form,
	trailing: int,
	tok: Token,
) -> (
	FixupKind,
	common.AssemblerError,
) {
	instr := transmute(shared.Instruction)u16(form.opcode)
	if instr.type != .ControlFlow {
		switch trailing {
			case 1:
				return .Abs8, common.no_error()
			case 2:
				return .Abs16, common.no_error()
			case 3:
				return .Abs24, common.no_error()
			case 4:
				return .Abs32, common.no_error()
		}
		t := tok
		return .Invalid, token_errorf(&t, "Internal error: cannot fix up symbol operand")
	}
	#partial switch shared.FlowOpcodes(instr.opcode) {
		case .Jz,
		     .Jnz,
		     .Jc,
		     .Jnc,
		     .Jmi,
		     .Jpl,
		     .Jv,
		     .Jnv,
		     .Jges,
		     .Jgts,
		     .Jles,
		     .Jlts,
		     .Jgtu,
		     .Jleu,
		     .Djnz:
			if trailing == 1 do return .Rel8, common.no_error()
			if trailing == 2 do return .Rel16, common.no_error()
		case .Jsr_Imm, .Jmp_Imm:
			if trailing == 2 do return .Abs16, common.no_error()
		case .Jsr_L_Imm, .Jmp_L_Imm:
			if trailing == 3 do return .Abs24, common.no_error()
	}
	t := tok
	return .Invalid, token_errorf(&t, "Internal error: cannot fix up symbol operand")
}

emitter_emit_directive :: proc(e: ^Emitter, dir: Directive) -> common.AssemblerError {
	dtok := dir.directive
	switch dir.directive.text {
		case ".org":
			op := dir.operands[0].(ResolvedOperand).(Op_Imm)
			if op.expr.type != .Integer do return token_error(&dtok, "Internal error: .org operand not resolved")
			return emitter_set_cursor(e, u32(op.expr.val))
		case ".db":
			for op in dir.operands {
				imm, ok := op.(ResolvedOperand).(Op_Imm)
				if ok {
					if imm.expr.type == .Symbol {
						pos := u32(len(e.output))
						if err := emitter_emit_byte(e, 0); err.raised do return err
						append(&e.fixups, Fixup{pos = pos, tok = imm.expr.tok, kind = .Abs8})
						continue
					}
					if imm.expr.type != .Integer do return token_error(&dtok, "Internal error: unresolved symbol in .db")
					if err := emitter_emit_byte(e, u8(imm.expr.val)); err.raised do return err
					continue
				}
				str, sok := op.(ResolvedOperand).(Op_String)
				if !sok do return token_error(&dtok, "Internal error: malformed .db operand")
				for i in 0 ..< len(str.value) {
					if err := emitter_emit_byte(e, str.value[i]); err.raised do return err
				}
			}
			return common.no_error()
		case ".dw":
			for op in dir.operands {
				imm := op.(ResolvedOperand).(Op_Imm)
				if imm.expr.type == .Symbol {
					pos := u32(len(e.output))
					if err := emitter_emit_u16(e, 0); err.raised do return err
					append(&e.fixups, Fixup{pos = pos, tok = imm.expr.tok, kind = .Abs16})
					continue
				}
				if imm.expr.type != .Integer do return token_error(&dtok, "Internal error: .dw operand not resolved")
				if err := emitter_emit_u16(e, u16(imm.expr.val)); err.raised do return err
			}
			return common.no_error()
		case ".dl":
			for op in dir.operands {
				imm := op.(ResolvedOperand).(Op_Imm)
				if imm.expr.type == .Symbol {
					pos := u32(len(e.output))
					if err := emitter_emit_u32(e, 0); err.raised do return err
					append(&e.fixups, Fixup{pos = pos, tok = imm.expr.tok, kind = .Abs32})
					continue
				}
				if imm.expr.type != .Integer do return token_error(&dtok, "Internal error: .dl operand not resolved")
				if err := emitter_emit_u32(e, u32(imm.expr.val)); err.raised do return err
			}
			return common.no_error()
		case ".d24":
			for op in dir.operands {
				imm := op.(ResolvedOperand).(Op_Imm)
				if imm.expr.type == .Symbol {
					pos := u32(len(e.output))
					if err := emitter_emit_u24(e, 0); err.raised do return err
					append(&e.fixups, Fixup{pos = pos, tok = imm.expr.tok, kind = .Abs24})
					continue
				}
				if imm.expr.type != .Integer do return token_error(&dtok, "Internal error: .d24 operand not resolved")
				if err := emitter_emit_u24(e, u32(imm.expr.val)); err.raised do return err
			}
			return common.no_error()
		case ".pad":
			op := dir.operands[0].(ResolvedOperand).(Op_Imm)
			if op.expr.type != .Integer do return token_error(&dtok, "Internal error: .pad operand not resolved")
			return emitter_advance(e, u32(op.expr.val))
		case ".equ":
			return common.no_error()
		case ".include":
			return token_error(&dtok, "Internal error: unexpanded .include")
		case ".incbin":
			op := dir.operands[0].(ResolvedOperand).(Op_String)
			full, joined := sibling_path(dir.directive.filename, op.value)
			defer if joined do delete(full)
			data, rerr := read_provided_file(full)
			if rerr.raised do return rerr
			defer delete(data)
			if !emitter_has_room(e, u32(len(data))) do return common.make_error("Exceeded ROM size limit")
			append(&e.output, ..data[:])
			e.cursor += u32(len(data))
			return common.no_error()
		case ".wram", ".rom":
			e.in_wram = dir.directive.text == ".wram"
			return common.no_error()
		case:
			return token_errorf(
				&dtok,
				"Internal error: unknown directive '%s'",
				dir.directive.text,
			)
	}
}

pass2_emit :: proc(e: ^Emitter, stmts: []Statement) -> common.AssemblerError {
	e.cursor = cpu.ROM_START
	e.wram_cursor = cpu.WRAM_START
	e.in_wram = false
	for i in 0 ..< len(stmts) {
		if lbl, ok := stmts[i].(LabelDef); ok {
			rlbl, lerr := resolve_label(lbl.label.text)
			if lerr.raised {
				common.free_error(&lerr)
				return token_errorf(
					&lbl.label,
					"Internal error: label '%s' missing in pass 2",
					lbl.label.text,
				)
			}
			cur := e.cursor
			if e.in_wram do cur = e.wram_cursor
			if rlbl.addr != cur do return token_errorf(&lbl.label, "Internal error: label address drifted in pass 2")
			continue
		}
		if dir, ok := stmts[i].(Directive); ok {
			if derr := emitter_emit_directive(e, dir); derr.raised do return derr
			continue
		}
		if mnem, ok := stmts[i].(Mnemonic); ok {
			form, ferr := select_mnemonic_form(&mnem, mnem.wide)
			if ferr.raised do return ferr
			if eerr := encode_mnemonic(e, mnem, form, e.cursor); eerr.raised do return eerr
			continue
		}
		return common.make_error("Internal error: unknown statement type")
	}
	return apply_fixups(e)
}
