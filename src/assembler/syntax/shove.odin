package syntax

import "../common"

desugar_shove_list :: proc(stmts: []Statement) -> common.AssemblerError {
	for &statement in stmts {
		#partial switch &st in statement {
			case Mnemonic:
				if st.mnemonic.text != "shove" do continue
				if st.amount < 1 do continue
				mode_tok: Token
				pop := false
				{
					op, ok := st.operands[0].(ResolvedOperand)
					if !ok do continue
					mode_imm, is_imm := op.(Op_Imm)
					if !is_imm || mode_imm.expr.type != .Symbol do continue
					if mode_imm.expr.symbol != "push" && mode_imm.expr.symbol != "pop" do continue
					pop = mode_imm.expr.symbol == "pop"
					mode_tok = mode_imm.expr.tok
				}
				if st.amount < 2 {
					return token_error(
						&mode_tok,
						"shove register list requires at least one register (e.g. `shove push, a`)",
					)
				}

				mask: u16
				for i in 1 ..< int(st.amount) {
					rop, ok := st.operands[i].(ResolvedOperand)
					if !ok do continue
					bit: u16
					#partial switch v in rop {
						case Op_Reg:
							if v.reg.size != .Word {
								mtok := st.mnemonic
								return token_error(
									&mtok,
									"shove cannot be used with 8-bit general-purpose registers",
								)
							}
							if v.reg.index > 6 {
								mtok := st.mnemonic
								return token_error(&mtok, "cannot shove register 'sp'")
							}
							bit = u16(1) << v.reg.index
						case Op_Imm:
							tok := v.expr.tok
							if v.expr.type != .Symbol {
								return token_error(
									&tok,
									"numeric operands are not allowed in shove register lists",
								)
							}
							named_bit, recognized := shove_named_register_bit(v.expr.symbol)
							if !recognized {
								return token_errorf(
									&tok,
									"unknown register '%s' in shove list (expected a-g, flags, hi or dp)",
									v.expr.symbol,
								)
							}
							if named_bit == 0 {
								return token_error(&tok, "cannot shove register 'pp'")
							}
							bit = named_bit
						case:
							mtok := st.mnemonic
							return token_error(
								&mtok,
								"invalid operand in shove register list (expected a register name)",
							)
					}
					if mask & bit != 0 {
						mtok := st.mnemonic
						return token_error(&mtok, "duplicate register in shove list")
					}
					mask |= bit
				}
				if pop do mask |= 1 << 15

				st.operands[0] = ResolvedOperand(
					Op_Imm {
						expr = Expression {
							val = i64(mask),
							symbol = "",
							is_signed = false,
							type = .Integer,
							tok = mode_tok,
						},
					},
				)
				st.amount = 1
		}
	}
	return common.no_error()
}

@(private = "file")
shove_named_register_bit :: proc(name: string) -> (bit: u16, recognized: bool) {
	switch name {
		case "flags":
			return 1 << 7, true
		case "hi":
			return 1 << 8, true
		case "dp":
			return 1 << 9, true
		case "pp":
			return 0, true
	}
	return 0, false
}
