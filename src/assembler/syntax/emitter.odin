package syntax

import "../common"

Emitter :: struct {
	rom_offset: u32,
	mem_offset: u32,
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

// count_statement_size :: proc(e: ^Emitter, stmt: Statement) -> (u32, common.AssemblerError) {
// 	switch st in stmt {
// 		case LabelDef:
// 			return 0, common.no_error()
// 		case Directive:
// 			switch st.directive.text {
// 				case ".db":
// 					length: u32 = 0
// 					for op in st.operands {
// 						str, ok_str := op.(ResolvedOperand).(Op_String)
// 						if ok_str {
// 							length += u32(len(str.value))
// 							continue
// 						}
// //
// 						imm, ok_imm := op.(ResolvedOperand).(Op_Imm)
// 						if ok_imm do length += 1
// 					}
// 					return length, common.no_error()
// 				case ".dw":
// 					return u32(len(st.operands)) * 2, common.no_error()
// 				case ".dl":
// 					return u32(len(st.operands) * 4), common.no_error()
// 				case ".org":
// 					return u32(len(st.operands) * 4), common.no_error()
// 			}
// 		case Mnemonic:
//
// 	}
//
// 	unreachable()
// }

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
					// TODO: Implement. This should probably be done after pass 1 so we can properly validate
					// constant sizes and labels (we'd need to handle branch relaxation beforehand as well)
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
						// TODO: Same as .org
						return token_error(
							&directive.directive,
							"Using the .dw directive with a label or constant is not implemented yet",
						)
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
						// TODO: Same as .org, but labels can never be 16-bit, will have to validate constant width too
						return token_error(
							&directive.directive,
							"Using the .db directive with a label or constant is not implemented yet",
						)
					case .Integer:
						fits := fits_width(imm.expr.val, 8)
						if !fits do return token_errorf(&directive.directive, "Value '%d' out of 8-bit range required by .db directive", imm.expr.val)
				}
			}
		case ".include":
		case ".incbin":
			return token_errorf(&directive.directive, "File including is not implemented yet")
		// if len(directive.operands) != 1 do return token_errorf(&directive.directive, "Expected string literal for %s directive", directive.directive.text)
		// str, ok := directive.operands[0].(ResolvedOperand).(Op_String)
		// if !ok do return token_errorf(&directive.directive, "Expected string literal for %s directive", directive.directive.text)
		//
		// if str.value == "" do return token_errorf(&directive.directive, "Directive %s requires a non-empty string operand", directive.directive.text)
		case ".wram":
		case ".rom":
			return token_errorf(
				&directive.directive,
				"Directives .wram and .rom are not implemented yet",
			)
		// if len(directive.operands) != 0 do return token_error(&directive.directive, "Region directives do not take operands")
		case:
			return token_errorf(
				&directive.directive,
				"Unknown directive '%s'",
				directive.directive.text,
			)
	}

	return common.no_error()
}
