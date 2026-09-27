package syntax

import "../common"

Line :: distinct []Token

split_lines :: proc(tokens: []Token) -> [dynamic]Line {
	out := make([dynamic]Line)

	start_idx := 0
	for i in 0 ..< len(tokens) {
		current := tokens[i]
		if current.type == .Newline || current.type == .EOF {
			line := Line(tokens[start_idx:i])
			start_idx = i + 1
			if len(line) > 0 do append(&out, line)
		}
	}

	return out
}

parse_into_statements :: proc(lines: []Line) -> ([dynamic]Statement, common.AssemblerError) {
	out := make([dynamic]Statement)
	for i in 0 ..< len(lines) {
		line := lines[i]
		for len(line) > 0 {
			stmt, err := split_statement(&line)
			if err.raised {
				delete(out)
				return {}, err
			}
			append(&out, stmt)
		}
	}

	return out, common.no_error()
}

split_statement :: proc(line: ^Line) -> (Statement, common.AssemblerError) {
	if len(line) >= 2 && line[0].type == .Identifier && line[1].type == .Colon {
		label := LabelDef {
			label = line[0],
		}
		if len(line) == 2 {
			line^ = {}
		} else {
			line^ = line[2:]
		}

		return label, common.no_error()
	} else if line[0].type == .Identifier {
		operands, err := split_raw_operands(([]Token)(line[1:]))
		if err.raised {
			delete(operands)
			return {}, err
		}

		if line[0].text[0] == '.' {
			dir := Directive {
				directive = line[0],
				operands  = operands,
			}
			line^ = {}
			return dir, common.no_error()
		} else {
			if len(operands) > 3 {
				lastop := operands[len(operands) - 1].(RawOperand)
				lasttok := lastop[len(lastop) - 1]
				delete(operands)
				return {}, token_error(&lasttok, "Too many operands found (no mnemonic requires more than 3)")
			}
			mnem := Mnemonic {
				mnemonic = line[0],
				amount   = len(operands),
			}

			for i in 0 ..< len(operands) {
				mnem.operands[i] = operands[i]
			}
			delete(operands)
			line^ = {}
			return mnem, common.no_error()
		}
	}

	return {}, token_errorf(&line[0], "Unexpected token '%s'; expected directive, mnemonic or label", line[0].text)
}

split_raw_operands :: proc(tokens: []Token) -> ([dynamic]OperandSlot, common.AssemblerError) {
	out := make([dynamic]OperandSlot)

	if len(tokens) == 0 {
		return out, common.no_error()
	}

	start := 0
	for i in 0 ..< len(tokens) {
		if tokens[i].type == .Comma {
			if i == start do return out, token_error(&tokens[i], "Unexpected comma")

			append(&out, RawOperand(tokens[start:i]))
			start = i + 1
		}
	}

	if start == len(tokens) {
		last := tokens[len(tokens) - 1]
		return out, token_error(&last, "Trailing comma after operands")
	}

	append(&out, RawOperand(tokens[start:]))
	return out, common.no_error()
}
