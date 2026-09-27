package syntax

import "../common"
import "../cpu"

Expression :: struct {
	val:       i64,
	symbol:    string,
	is_signed: bool,
	type:      enum u8 {
		Symbol,
		Integer,
	},
}

Op_Reg :: struct {
	reg: cpu.RegInfo,
}

Op_Reg_Pair :: struct {
	hi: cpu.RegInfo,
	lo: cpu.RegInfo,
}

Op_Imm :: struct {
	expr: Expression,
}

DerefMode :: enum {
	Reg,
	Imm,
	Reg_ImmOffset,
	Reg_RegOffset,
	Reg_PreInc,
	Reg_PostInc,
	Reg_PreDec,
	Reg_PostDec,
	Reg_Pair,
	Reg_Pair_ImmOffset,
	Reg_Pair_RegOffset,
	Imm_Long_RegOffset, // [ptr24 + reg16]
}

Op_Deref :: struct {
	mode:     DerefMode,
	base_hi:  cpu.RegInfo,
	base_lo:  cpu.RegInfo,
	reg_offs: cpu.RegInfo,
	imm_offs: Expression,
}

ResolvedOperand :: union {
	Op_Reg,
	Op_Reg_Pair,
	Op_Imm,
	Op_Deref,
}

RawOperand :: distinct []Token

OperandSlot :: union {
	RawOperand,
	ResolvedOperand,
}

LabelDef :: struct {
	label: Token, // contains line and filename info AND the label name for better error reporting
}

Directive :: struct {
	directive: Token,
	operands:  [dynamic]OperandSlot, // integers and strings mostly; dynamic because a directive like .db or .dw might expect more than the max of 3 our opcodes expect
}

Mnemonic :: struct {
	mnemonic: Token,
	operands: [3]OperandSlot, // The instructions with the most operands are blkcp and blkmv (reg8:reg16, reg8:reg16, reg16). Our cap is 3. Storing inline is fine.
	amount:   uint,
}

Statement :: union {
	LabelDef,
	Directive,
	Mnemonic,
}

resolve_operand :: proc(raw: RawOperand) -> (ResolvedOperand, common.AssemblerError) {
	toks := ([]Token)(raw)
	if len(toks) == 0 do return nil, common.make_error("Empty operand")

	// Deref
	if toks[0].type == .BrackLeft {
		if toks[len(toks) - 1].type != .BrackRight {
			return nil, token_error(&toks[0], "Missing closing bracket ']'")
		}
		deref, err := resolve_deref(toks[1:len(toks) - 1])
		if err.raised do return nil, err
		return deref, common.no_error()
	}

	// Reg pair
	if len(toks) == 3 && toks[1].type == .Colon {
		hi, hi_ok := cpu.parse_reg(toks[0].text)
		lo, lo_ok := cpu.parse_reg(toks[2].text)
		if hi_ok && lo_ok {
			return Op_Reg_Pair{hi = hi, lo = lo}, common.no_error()
		}
	}

	// Single reg
	if len(toks) == 1 && toks[0].type == .Identifier {
		if reg, ok := cpu.parse_reg(toks[0].text); ok {
			return Op_Reg{reg = reg}, common.no_error()
		}
	}

	// Anything else is an immediate
	expr, err := resolve_expr(toks)
	if err.raised do return nil, err
	return Op_Imm{expr = expr}, common.no_error()
}

resolve_deref :: proc(toks: []Token) -> (Op_Deref, common.AssemblerError) {
	if len(toks) == 0 {
		return {}, common.make_error("Empty dereference '[]'")
	}

	op: Op_Deref

	// single token [reg16] or [imm]
	if len(toks) == 1 {
		#partial switch toks[0].type {
			case .IntegerLiteral:
				val, err := parse_integer_token(&toks[0])
				if err.raised {
					tok_err := token_error(&toks[0], err.msg)
					common.free_error(&err)
					return {}, tok_err
				}
				op.mode = .Imm
				op.imm_offs = val
				return op, common.no_error()

			case .Identifier:
				reg, ok := cpu.parse_reg(toks[0].text)
				if ok {
					if reg.size != .Word {
						return {}, token_errorf(&toks[0], "Base pointer register '%s' must be 16-bit", toks[0].text)
					}
					op.mode = .Reg
					op.base_lo = reg
					return op, common.no_error()
				}

				// Not a register -> symbol
				expr, expr_err := resolve_expr(toks[0:1])
				if expr_err.raised do return {}, expr_err
				op.mode = .Imm
				op.imm_offs = expr
				return op, common.no_error()

			case:
				return {}, token_errorf(&toks[0], "Invalid token inside dereference: '%s'", toks[0].text)
		}
	}

	// pre/post inc/dec [+b], [-b], [b+], [b-]
	if len(toks) == 2 {
		// pre
		if toks[1].type == .Identifier && (toks[0].type == .Plus || toks[0].type == .Minus) {
			reg, ok := cpu.parse_reg(toks[1].text)
			if !ok {
				tok_err := token_errorf(&toks[1], "Expected register, found '%s'", toks[1].text)
				return {}, tok_err
			}
			if reg.size != .Word {
				return {}, token_errorf(&toks[1], "Pointer register '%s' must be 16-bit", toks[1].text)
			}
			op.mode = (toks[0].type == .Plus) ? .Reg_PreInc : .Reg_PreDec
			op.base_lo = reg
			return op, common.no_error()
		}

		// post
		if toks[0].type == .Identifier && (toks[1].type == .Plus || toks[1].type == .Minus) {
			reg, err := cpu.parse_reg(toks[0].text)
			if !err {
				tok_err := token_errorf(&toks[0], "Expected register, found '%s'", toks[0].text)
				return {}, tok_err
			}
			if reg.size != .Word {
				return {}, token_errorf(&toks[0], "Pointer register '%s' must be 16-bit", toks[0].text)
			}
			op.mode = (toks[1].type == .Plus) ? .Reg_PostInc : .Reg_PostDec
			op.base_lo = reg
			return op, common.no_error()
		}

		return {}, token_errorf(&toks[0], "Invalid 2-token dereference syntax")
	}

	// register pairs [hi:lo] or [hi:lo +/- offset]
	if len(toks) >= 3 && toks[1].type == .Colon {
		hi, hi_ok := cpu.parse_reg(toks[0].text)
		lo, lo_ok := cpu.parse_reg(toks[2].text)
		if !hi_ok || hi.size != .Byte {
			return {}, token_errorf(&toks[0], "High register of pair '%s' must be an 8-bit register", toks[0].text)
		}
		if !lo_ok || lo.size != .Word {
			return {}, token_errorf(&toks[2], "Low register of pair '%s' must be a 16-bit register", toks[2].text)
		}

		op.base_hi = hi
		op.base_lo = lo

		// Bare pair [al:b]
		if len(toks) == 3 {
			op.mode = .Reg_Pair
			return op, common.no_error()
		}

		// Pair with offset [al:b + c] or [al:b +/- 10]
		if len(toks) >= 5 && (toks[3].type == .Plus || toks[3].type == .Minus) {
			offset_toks := toks[4:]

			// Check for reg offset [al:b + c]
			if len(offset_toks) == 1 && offset_toks[0].type == .Identifier {
				reg_off, reg_ok := cpu.parse_reg(offset_toks[0].text)
				if reg_ok {
					if toks[3].type != .Plus {
						return {}, token_errorf(&toks[3], "Register offsets cannot be subtracted (suggestion: use neg %s)", toks[3].text)
					}
					if reg_off.size != .Word {
						return {}, token_errorf(&offset_toks[0], "Offset register '%s' must be 16-bit", offset_toks[0].text)
					}
					op.mode = .Reg_Pair_RegOffset
					op.reg_offs = reg_off
					return op, common.no_error()
				}
			}

			// immediate or symbol offset [al:b + 4] or [al:b - constant]
			expr, expr_err := resolve_expr(toks[3:]) // passes the +/- together with the number
			if expr_err.raised do return {}, expr_err

			op.mode = .Reg_Pair_ImmOffset
			op.imm_offs = expr
			return op, common.no_error()
		}

		return {}, token_error(&toks[1], "Malformed register pair dereference")
	}

	// base + offset [b + 4], [b - 4], [b + c], or [ptr24 + c]
	op_idx := -1
	for i := 1; i < len(toks) - 1; i += 1 {
		if toks[i].type == .Plus || toks[i].type == .Minus {
			op_idx = i
			break
		}
	}

	if op_idx != -1 {
		left_toks := toks[:op_idx]
		right_toks := toks[op_idx + 1:]
		is_minus := toks[op_idx].type == .Minus

		if len(left_toks) == 1 && left_toks[0].type == .Identifier {
			base_reg, ok := cpu.parse_reg(left_toks[0].text)
			if ok {
				if base_reg.size != .Word {
					return {}, token_errorf(&left_toks[0], "Base register '%s' must be 16-bit", left_toks[0].text)
				}
				op.base_lo = base_reg

				// is the right side a register? [b+c]
				if len(right_toks) == 1 && right_toks[0].type == .Identifier {
					off_reg, r_err := cpu.parse_reg(right_toks[0].text)
					if r_err {
						if is_minus {
							return {}, token_error(&toks[op_idx], "Register offsets cannot be subtracted")
						}
						if off_reg.size != .Word {
							return {}, token_errorf(&right_toks[0], "Offset register '%s' must be 16-bit", right_toks[0].text)
						}
						op.mode = .Reg_RegOffset
						op.reg_offs = off_reg
						return op, common.no_error()
					}
				}

				// otherwise right side is an immediate offset [b + 10] or [b - 10]
				expr, expr_err := resolve_expr(toks[op_idx:])
				if expr_err.raised do return {}, expr_err

				op.mode = .Reg_ImmOffset
				op.imm_offs = expr
				return op, common.no_error()
			}
		}

		// Left side is not a register -> must be 24bit immediate base: [ptr24 + reg16]
		if is_minus {
			return {}, token_error(&toks[op_idx], "Cannot subtract from an absolute pointer base")
		}

		left_expr, left_err := resolve_expr(left_toks)
		if left_err.raised do return {}, left_err

		if len(right_toks) != 1 || right_toks[0].type != .Identifier {
			return {}, token_error(&right_toks[0], "Expected 16-bit index register after '+'")
		}

		off_reg, off_ok := cpu.parse_reg(right_toks[0].text)
		if !off_ok || off_reg.size != .Word {
			return {}, token_errorf(&right_toks[0], "Index register '%s' must be a 16-bit register", right_toks[0].text)
		}

		op.mode = .Imm_Long_RegOffset
		op.imm_offs = left_expr
		op.reg_offs = off_reg
		return op, common.no_error()
	}

	return {}, token_errorf(&toks[0], "Malformed dereference expression")
}

resolve_expr :: proc(toks: []Token) -> (Expression, common.AssemblerError) {
	if len(toks) == 0 do return {}, common.make_error("Empty expression")

	is_neg := false
	tok_list := toks

	if tok_list[0].type == .Minus {
		is_neg = true
		tok_list = tok_list[1:]
		if len(tok_list) == 0 {
			return {}, token_error(&toks[0], "Trailing '-' with no operand")
		}
	} else if tok_list[0].type == .Plus {
		tok_list = tok_list[1:]
		if len(tok_list) == 0 {
			return {}, token_error(&toks[0], "Trailing '+' with no operand")
		}
	}

	if len(tok_list) != 1 {
		return {}, token_error(&tok_list[0], "Malformed expression")
	}

	target := tok_list[0]
	#partial switch target.type {
		case .IntegerLiteral:
			return parse_integer_token(&target, is_neg)
		case .Identifier:
			return Expression {
				symbol = target.text,
				is_signed = is_neg,
				type = .Symbol,
			}, common.no_error()
		case:
			return {}, token_errorf(&target, "Expected number or identifier, got '%s'", target.text)
	}
}
