package tests

import asm_common "../assembler/common"
import "../assembler/syntax"
import "core:testing"

@(test)
lexer_identifies_correct_token_types :: proc(t: ^testing.T) {
	EXPECTED_TOKENS := []syntax.Token {
		{filename = "source.asm", line = 0, type = .Identifier, text = ".org"},
		{filename = "source.asm", line = 0, type = .IntegerLiteral, text = "0x060000"},
		{filename = "source.asm", line = 0, type = .Newline, text = "<newline>"},
		{filename = "source.asm", line = 1, type = .Identifier, text = "main"},
		{filename = "source.asm", line = 1, type = .Colon, text = ":"},
		{filename = "source.asm", line = 1, type = .Newline, text = "<newline>"},
		{filename = "source.asm", line = 2, type = .Identifier, text = "ld"},
		{filename = "source.asm", line = 2, type = .Identifier, text = "a"},
		{filename = "source.asm", line = 2, type = .Comma, text = ","},
		{filename = "source.asm", line = 2, type = .IntegerLiteral, text = "0x1234"},
		{filename = "source.asm", line = 2, type = .Newline, text = "<newline>"},
		{filename = "source.asm", line = 3, type = .Identifier, text = "ld"},
		{filename = "source.asm", line = 3, type = .Identifier, text = "b"},
		{filename = "source.asm", line = 3, type = .Comma, text = ","},
		{filename = "source.asm", line = 3, type = .BrackLeft, text = "["},
		{filename = "source.asm", line = 3, type = .Identifier, text = "cl"},
		{filename = "source.asm", line = 3, type = .Colon, text = ":"},
		{filename = "source.asm", line = 3, type = .Identifier, text = "d"},
		{filename = "source.asm", line = 3, type = .Plus, text = "+"},
		{filename = "source.asm", line = 3, type = .IntegerLiteral, text = "10"},
		{filename = "source.asm", line = 3, type = .BrackRight, text = "]"},
		{filename = "source.asm", line = 3, type = .Newline, text = "<newline>"},
		{filename = "source.asm", line = 4, type = .Newline, text = "<newline>"},
		{filename = "source.asm", line = 5, type = .Identifier, text = "shove"},
		{filename = "source.asm", line = 5, type = .IntegerLiteral, text = "0b1111111111111111"},
		{filename = "source.asm", line = 5, type = .EOF, text = "<EOF>"},
	}

	SOURCE :: `.org 0x060000
    main:
        ld a, 0x1234
        ld b, [cl:d + 10]

        shove 0b1111111111111111`

	output, err := syntax.tokenize("source.asm", SOURCE)
	defer asm_common.free_error(&err)
	defer delete(output)
	testing.expectf(t, !err.raised, "Expected no lexer errors, received: '%s'", err.msg)
	testing.expectf(
		t,
		token_outputs_equivalent(output[:], EXPECTED_TOKENS),
		"Token outputs did not match.\nExpected:\n%v\nGot:\n%v",
		EXPECTED_TOKENS,
		output[:],
	)
}

@(test)
parser_discards_leading_newlines_when_splitting_lines :: proc(t: ^testing.T) {
	EXPECTED_LINES := []syntax.Line {
		{
			{type = .Identifier, line = 0, filename = "source.asm", text = "label"},
			{type = .Colon, line = 0, filename = "source.asm", text = ":"},
		},
		{
			{type = .Identifier, line = 4, filename = "source.asm", text = "mov"},
			{type = .Identifier, line = 4, filename = "source.asm", text = "a"},
			{type = .Comma, line = 4, filename = "source.asm", text = ","},
			{type = .Identifier, line = 4, filename = "source.asm", text = "b"},
		},
	}

	SOURCE :: `label:



    mov a, b`
	output, err := syntax.tokenize("source.asm", SOURCE)
	defer asm_common.free_error(&err)
	defer delete(output)

	lines := syntax.split_lines(output[:])
	defer delete(lines)

	testing.expectf(t, !err.raised, "Expected no lexer errors, received: '%s'", err.msg)
	testing.expectf(
		t,
		lines_equivalent(lines[:], EXPECTED_LINES),
		"Token outputs did not match.\nExpected:\n%v\nGot:\n%v",
		EXPECTED_LINES,
		lines[:],
	)
}

@(test)
parser_splits_statements :: proc(t: ^testing.T) {
	SOURCE :: `main:
        ld a, [b]
        .org 0x060000`

	tokens, lex_err := syntax.tokenize("source.asm", SOURCE)
	defer asm_common.free_error(&lex_err)
	defer delete(tokens)
	testing.expect(t, !lex_err.raised, "Lexer error")

	lines := syntax.split_lines(tokens[:])
	defer delete(lines)

	stmts, parse_err := syntax.parse_into_statements(lines[:])
	defer asm_common.free_error(&parse_err)
	defer {
		for s in stmts {
			#partial switch dir in s {
				case syntax.Directive:
					delete(dir.operands)
			}
		}
		delete(stmts)
	}
	testing.expectf(t, !parse_err.raised, "Parser error '%s'", parse_err.msg)

	testing.expect_value(t, len(stmts), 3)

	#partial switch s in stmts[0] {
		case syntax.LabelDef:
			testing.expect_value(t, s.label.text, "main")
			testing.expect_value(t, s.label.line, 0)
		case:
			testing.expectf(t, false, "Statement 0 was not a LabelDef, got %v", stmts[0])
	}

	#partial switch s in stmts[1] {
		case syntax.Mnemonic:
			testing.expect_value(t, s.mnemonic.text, "ld")
			testing.expect_value(t, s.mnemonic.line, 1)
			testing.expect_value(t, s.amount, 2)

			op0 := s.operands[0].(syntax.RawOperand)
			testing.expect_value(t, len(op0), 1)
			testing.expect_value(t, op0[0].text, "a")

			op1 := s.operands[1].(syntax.RawOperand)
			testing.expect_value(t, len(op1), 3)
			testing.expect_value(t, op1[0].type, syntax.TokenType.BrackLeft)
			testing.expect_value(t, op1[1].text, "b")
			testing.expect_value(t, op1[2].type, syntax.TokenType.BrackRight)
		case:
			testing.expectf(t, false, "Statement 1 was not a Mnemonic, got %v", stmts[1])
	}

	#partial switch s in stmts[2] {
		case syntax.Directive:
			testing.expect_value(t, s.directive.text, ".org")
			testing.expect_value(t, s.directive.line, 2)
			testing.expect_value(t, len(s.operands), 1)

			dir_op := s.operands[0].(syntax.RawOperand)
			testing.expect_value(t, len(dir_op), 1)
			testing.expect_value(t, dir_op[0].text, "0x060000")
		case:
			testing.expectf(t, false, "Statement 2 was not a Directive, got %v", stmts[2])
	}
}
