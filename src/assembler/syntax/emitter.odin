package syntax

import "../common"

Emitter :: struct {
	symbols:    map[string]i64,
	rom_offset: u32,
	mem_offset: u32,
}

// count_statement_size :: proc(e: ^Emitter, stmt: Statement) -> (u32, common.AssemblerError) {
// 	switch st in stmt {
// 		case LabelDef:
// 			return 0, common.no_error()
// 		case Directive:
// 			switch st.directive.text {
// 				case ".db":
// 					return len(st.operands), common.no_error()
// 				case ".dw":
// 					return len(st.operands) * 2, common.no_error()
// 				case ".dl":
// 					return u32(len(st.operands) * 4), common.no_error()
// 				case ".org":
//
// 			}
// 		case Mnemonic:
// 	}
// }

validate_directive_operands :: proc(directive: ^Directive) -> common.AssemblerError {
	if len(directive.operands) != 0 {
		_, ok := directive.operands[0].(ResolvedOperand)
		if !ok do return token_errorf(&directive.directive, "Cannot validate non-resolved operands for directive '%s'", directive.directive.text)
	}
	switch directive.directive.text {
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
