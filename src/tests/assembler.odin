package tests

import asm_common "../assembler/common"
import "../assembler/syntax"
import "core:strings"
import "core:sync"
import "core:testing"

@(test)
lexer_identifies_correct_token_types :: proc(t: ^testing.T) {
	EXPECTED_TOKENS := []syntax.Token {
		{filename = "source.asm", line = 1, type = .Identifier, text = ".org"},
		{filename = "source.asm", line = 1, type = .IntegerLiteral, text = "0x060000"},
		{filename = "source.asm", line = 1, type = .Newline, text = "<newline>"},
		{filename = "source.asm", line = 2, type = .Identifier, text = "main"},
		{filename = "source.asm", line = 2, type = .Colon, text = ":"},
		{filename = "source.asm", line = 2, type = .Newline, text = "<newline>"},
		{filename = "source.asm", line = 3, type = .Identifier, text = "ld"},
		{filename = "source.asm", line = 3, type = .Identifier, text = "a"},
		{filename = "source.asm", line = 3, type = .Comma, text = ","},
		{filename = "source.asm", line = 3, type = .IntegerLiteral, text = "0x1234"},
		{filename = "source.asm", line = 3, type = .Newline, text = "<newline>"},
		{filename = "source.asm", line = 4, type = .Identifier, text = "ld"},
		{filename = "source.asm", line = 4, type = .Identifier, text = "b"},
		{filename = "source.asm", line = 4, type = .Comma, text = ","},
		{filename = "source.asm", line = 4, type = .BrackLeft, text = "["},
		{filename = "source.asm", line = 4, type = .Identifier, text = "cl"},
		{filename = "source.asm", line = 4, type = .Colon, text = ":"},
		{filename = "source.asm", line = 4, type = .Identifier, text = "d"},
		{filename = "source.asm", line = 4, type = .Plus, text = "+"},
		{filename = "source.asm", line = 4, type = .IntegerLiteral, text = "10"},
		{filename = "source.asm", line = 4, type = .BrackRight, text = "]"},
		{filename = "source.asm", line = 4, type = .Newline, text = "<newline>"},
		{filename = "source.asm", line = 5, type = .Newline, text = "<newline>"},
		{filename = "source.asm", line = 6, type = .Identifier, text = "shove"},
		{filename = "source.asm", line = 6, type = .IntegerLiteral, text = "0b1111111111111111"},
		{filename = "source.asm", line = 6, type = .EOF, text = "<EOF>"},
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
			{type = .Identifier, line = 1, filename = "source.asm", text = "label"},
			{type = .Colon, line = 1, filename = "source.asm", text = ":"},
		},
		{
			{type = .Identifier, line = 5, filename = "source.asm", text = "mov"},
			{type = .Identifier, line = 5, filename = "source.asm", text = "a"},
			{type = .Comma, line = 5, filename = "source.asm", text = ","},
			{type = .Identifier, line = 5, filename = "source.asm", text = "b"},
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
			testing.expect_value(t, s.label.line, 1)
		case:
			testing.expectf(t, false, "Statement 0 was not a LabelDef, got %v", stmts[0])
	}

	#partial switch s in stmts[1] {
		case syntax.Mnemonic:
			testing.expect_value(t, s.mnemonic.text, "ld")
			testing.expect_value(t, s.mnemonic.line, 2)
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
			testing.expect_value(t, s.directive.line, 3)
			testing.expect_value(t, len(s.operands), 1)

			dir_op := s.operands[0].(syntax.RawOperand)
			testing.expect_value(t, len(dir_op), 1)
			testing.expect_value(t, dir_op[0].text, "0x060000")
		case:
			testing.expectf(t, false, "Statement 2 was not a Directive, got %v", stmts[2])
	}
}

@(test)
valid_deref_operands_succeed :: proc(t: ^testing.T) {
	SOURCE :: `data:
    .dw 0xDEAD
main:
    ld a, [sp]
    add a, [1000]
    ld al, [b+]
    ld a, [data]
    ld c, [-b]
    add a, [cl:b + 2]
    ld d, [cl:b + a]
    ld d, [c + b]
    ld d, [a + 1]
    ld.l a, [0x060000 + e]`

	tokens, lex_err := syntax.tokenize("source.asm", SOURCE)
	defer asm_common.free_error(&lex_err)
	defer delete(tokens)
	testing.expectf(t, !lex_err.raised, "Lexer error: %s", lex_err.msg)

	lines := syntax.split_lines(tokens[:])
	defer delete(lines)

	stmts, parse_err := syntax.parse_into_statements(lines[:])
	defer {
		for stmt in stmts {
			#partial switch s in stmt {
				case syntax.Directive:
					delete(s.operands)
			}
		}
		delete(stmts)
		asm_common.free_error(&parse_err)
	}
	testing.expectf(t, !parse_err.raised, "Parser error: %s", parse_err.msg)

	// Resolve all raw operands in mnemonics
	for &stmt in stmts {
		#partial switch &m in stmt {
			case syntax.Mnemonic:
				for i in 0 ..< m.amount {
					raw := m.operands[i].(syntax.RawOperand)
					resolved, r_err := syntax.resolve_operand(raw)
					defer asm_common.free_error(&r_err)
					testing.expectf(
						t,
						!r_err.raised,
						"Failed resolving operand %d in '%s': %s",
						i,
						m.mnemonic.text,
						r_err.msg,
					)
					m.operands[i] = resolved
				}
		}
	}

	// Spot-check specific dereference modes
	//  ld a, [sp] -> stmt index 3 (after data label, .dw, main label)
	check_mnemonic_deref_mode(t, stmts[3], 1, .Reg)

	// add a, [1000]
	check_mnemonic_deref_mode(t, stmts[4], 1, .Imm)

	// ld al, [b+]
	check_mnemonic_deref_mode(t, stmts[5], 1, .Reg_PostInc)

	// ld a, [data]
	check_mnemonic_deref_mode(t, stmts[6], 1, .Imm)

	// ld c, [-b]
	check_mnemonic_deref_mode(t, stmts[7], 1, .Reg_PreDec)

	// add a, [cl:b + 2]
	check_mnemonic_deref_mode(t, stmts[8], 1, .Reg_Pair_ImmOffset)

	// ld d, [cl:b + a]
	check_mnemonic_deref_mode(t, stmts[9], 1, .Reg_Pair_RegOffset)

	// ld d, [c + b]
	check_mnemonic_deref_mode(t, stmts[10], 1, .Reg_RegOffset)

	// ld d, [a + 1]
	check_mnemonic_deref_mode(t, stmts[11], 1, .Reg_ImmOffset)

	// ld.l a, [0x060000 + e]
	check_mnemonic_deref_mode(t, stmts[12], 1, .Imm_Long_RegOffset)
}

@(test)
invalid_deref_operands_error :: proc(t: ^testing.T) {
	FAILING_CASES := []string {
		"ld a, [c - b]", // Register subtraction is invalid
		"ld b, [cl:dl]", // Low register of pair must be 16-bit
		"ld a, [al]", // Base pointer must be 16-bit
		"ld a, [+al]", // Pre-inc register must be 16-bit
		"ld a, [0x060000 - e]", // Absolute pointer subtraction
		"ld a, []", // Empty dereference
	}

	for src in FAILING_CASES {
		tokens, lex_err := syntax.tokenize("source.asm", src)
		testing.expect(t, !lex_err.raised)

		lines := syntax.split_lines(tokens[:])
		stmts, parse_err := syntax.parse_into_statements(lines[:])
		testing.expect(t, !parse_err.raised)

		m := stmts[0].(syntax.Mnemonic)
		raw := m.operands[1].(syntax.RawOperand)
		_, err := syntax.resolve_operand(raw)

		testing.expectf(
			t,
			err.raised,
			"Expected resolution to fail for input '%s', but it succeeded",
			src,
		)

		asm_common.free_error(&err)
		delete(stmts)
		delete(lines)
		delete(tokens)
	}
}

@(test)
immediates_symbols_strings_succeed :: proc(t: ^testing.T) {
	SOURCE :: `
data:
    .db "Hello, world!", 0
    .dw 0x1234, -42, SOME_SYMBOL
main:
    ld a, 42
    ld b, -100
    ld c, 0b1010_0101
    ld d, label_target
`
	tokens, lex_err := syntax.tokenize("source.asm", SOURCE)
	defer asm_common.free_error(&lex_err)
	defer delete(tokens)
	testing.expectf(t, !lex_err.raised, "Lexer error: %s", lex_err.msg)

	lines := syntax.split_lines(tokens[:])
	defer delete(lines)

	stmts, parse_err := syntax.parse_into_statements(lines[:])
	defer {
		for s in stmts {
			#partial switch d in s {
				case syntax.Directive:
					delete(d.operands)
			}
		}
		delete(stmts)
		asm_common.free_error(&parse_err)
	}
	testing.expectf(t, !parse_err.raised, "Parser error: %s", parse_err.msg)

	// Resolve operands without worrying about symbols
	for &stmt in stmts {
		#partial switch &s in stmt {
			case syntax.Directive:
				for i in 0 ..< len(s.operands) {
					raw := s.operands[i].(syntax.RawOperand)
					resolved, r_err := syntax.resolve_operand(raw)
					if r_err.raised {
						testing.expectf(
							t,
							false,
							"Failed resolving directive operand %d: %s",
							i,
							r_err.msg,
						)
						asm_common.free_error(&r_err)
						continue
					}
					s.operands[i] = resolved
				}
			case syntax.Mnemonic:
				for i in 0 ..< s.amount {
					raw := s.operands[i].(syntax.RawOperand)
					resolved, r_err := syntax.resolve_operand(raw)
					if r_err.raised {
						testing.expectf(
							t,
							false,
							"Failed resolving mnemonic operand %d: %s",
							i,
							r_err.msg,
						)
						asm_common.free_error(&r_err)
						continue
					}
					s.operands[i] = resolved
				}
		}
	}

	// .db "Hello, world!", 0
	db_dir := stmts[1].(syntax.Directive)
	testing.expect_value(t, len(db_dir.operands), 2)
	str_op, str_ok := db_dir.operands[0].(syntax.ResolvedOperand).(syntax.Op_String)
	testing.expect(t, str_ok, "Expected Op_String for first .db operand")
	testing.expect_value(t, str_op.value, "Hello, world!")

	zero_op, zero_ok := db_dir.operands[1].(syntax.ResolvedOperand).(syntax.Op_Imm)
	testing.expect(t, zero_ok, "Expected Op_Imm for second .db operand")
	testing.expect_value(t, zero_op.expr.val, 0)

	// .dw 0x1234, -42, SOME_SYMBOL
	dw_dir := stmts[2].(syntax.Directive)
	testing.expect_value(t, len(dw_dir.operands), 3)

	imm0 := dw_dir.operands[0].(syntax.ResolvedOperand).(syntax.Op_Imm)
	testing.expect_value(t, imm0.expr.val, 0x1234)

	imm1 := dw_dir.operands[1].(syntax.ResolvedOperand).(syntax.Op_Imm)
	testing.expect_value(t, imm1.expr.val, -42)
	testing.expect(t, imm1.expr.is_signed, "Expected -42 to be marked signed")

	sym_op := dw_dir.operands[2].(syntax.ResolvedOperand).(syntax.Op_Imm)
	testing.expect_value(t, sym_op.expr.type, syntax.ExpressionType.Symbol)
	testing.expect_value(t, sym_op.expr.symbol, "SOME_SYMBOL")

	// ld a, 42
	m_ld_a := stmts[4].(syntax.Mnemonic)
	imm_42 := m_ld_a.operands[1].(syntax.ResolvedOperand).(syntax.Op_Imm)
	testing.expect_value(t, imm_42.expr.val, 42)

	// ld b, -100
	m_ld_b := stmts[5].(syntax.Mnemonic)
	imm_neg100 := m_ld_b.operands[1].(syntax.ResolvedOperand).(syntax.Op_Imm)
	testing.expect_value(t, imm_neg100.expr.val, -100)
	testing.expect(t, imm_neg100.expr.is_signed, "Expected -100 to be signed")

	// ld c, 0b1010_0101
	m_ld_c := stmts[6].(syntax.Mnemonic)
	imm_bin := m_ld_c.operands[1].(syntax.ResolvedOperand).(syntax.Op_Imm)
	testing.expect_value(t, imm_bin.expr.val, 165)

	// ld d, label_target
	m_ld_d := stmts[7].(syntax.Mnemonic)
	sym_target := m_ld_d.operands[1].(syntax.ResolvedOperand).(syntax.Op_Imm)
	testing.expect_value(t, sym_target.expr.symbol, "label_target")
}

@(test)
directive_operands_validate :: proc(t: ^testing.T) {
	VALID_SOURCE :: `
    .org 0x060000
    .db 0xFF, -128, 0, "test"
    .dw 0xFFFF, -32768, 1234
`
	tokens, _ := syntax.tokenize("source.asm", VALID_SOURCE)
	defer delete(tokens)
	lines := syntax.split_lines(tokens[:])
	defer delete(lines)
	stmts, _ := syntax.parse_into_statements(lines[:])
	defer {
		for s in stmts {
			#partial switch d in s {
				case syntax.Directive:
					delete(d.operands)
			}
		}
		delete(stmts)
	}

	for &stmt in stmts {
		#partial switch &dir in stmt {
			case syntax.Directive:
				for i in 0 ..< len(dir.operands) {
					raw := dir.operands[i].(syntax.RawOperand)
					resolved, _ := syntax.resolve_operand(raw)
					dir.operands[i] = resolved
				}
				val_err := syntax.validate_directive_operands(&dir)
				defer asm_common.free_error(&val_err)
				testing.expectf(
					t,
					!val_err.raised,
					"Directive validation failed for '%s': %s",
					dir.directive.text,
					val_err.msg,
				)
		}
	}
}

@(test)
invalid_directives_fail :: proc(t: ^testing.T) {
	INVALID_DIRECTIVES := []string {
		".db 256", // Exceeds 8 bits
		".db -129", // Below 8-bit signed range
		".dw 65536", // Exceeds 16 bits
		".dw -32769", // Below 16-bit signed range
		".org 0x1000000", // Exceeds 24 bits
		".org", // Missing operand
		".org 1, 2", // Too many operands
	}

	for src in INVALID_DIRECTIVES {
		tokens, _ := syntax.tokenize("source.asm", src)
		lines := syntax.split_lines(tokens[:])
		stmts, _ := syntax.parse_into_statements(lines[:])

		dir := stmts[0].(syntax.Directive)
		for i in 0 ..< len(dir.operands) {
			raw := dir.operands[i].(syntax.RawOperand)
			resolved, _ := syntax.resolve_operand(raw)
			dir.operands[i] = resolved
		}

		err := syntax.validate_directive_operands(&dir)
		testing.expectf(
			t,
			err.raised,
			"Expected validation to fail for '%s', but it succeeded",
			src,
		)

		asm_common.free_error(&err)
		delete(dir.operands)
		delete(stmts)
		delete(lines)
		delete(tokens)
	}
}

@(test)
region_labels_and_pad :: proc(t: ^testing.T) {
	SOURCE :: `.org 0x060000
start:
.db 1
.wram
wvar:
.pad 16
wend:
.org 0x20
worg:
.rom
after:
`
	sync.lock(&TEST_MUTEX)
	defer sync.unlock(&TEST_MUTEX)
	syntax.init_labels()
	defer syntax.free_labels()
	syntax.init_constants()
	defer syntax.free_constants()
	tokens, stmts, ok := prepare_stmts(t, SOURCE)
	if !ok do return
	defer syntax.free_statements(stmts)
	defer delete(tokens)
	e := syntax.Emitter{}
	syntax.emitter_init(&e)
	defer syntax.emitter_free(&e)
	if perr := syntax.pass1_size_and_relax(&e, stmts[:]); perr.raised {
		testing.expectf(t, false, "pass1 failed: %s", perr.msg)
		asm_common.free_error(&perr)
		return
	}
	check_label(t, "start", 0x060000)
	check_label(t, "wvar", 0x000000)
	check_label(t, "wend", 0x000010)
	check_label(t, "worg", 0x000020)
	check_label(t, "after", 0x060001)
}

@(test)
wram_mnemonic_rejected :: proc(t: ^testing.T) {
	SOURCE :: `.wram
nop
`
	sync.lock(&TEST_MUTEX)
	defer sync.unlock(&TEST_MUTEX)
	syntax.init_labels()
	defer syntax.free_labels()
	syntax.init_constants()
	defer syntax.free_constants()
	tokens, stmts, ok := prepare_stmts(t, SOURCE)
	if !ok do return
	defer syntax.free_statements(stmts)
	defer delete(tokens)
	e := syntax.Emitter{}
	syntax.emitter_init(&e)
	defer syntax.emitter_free(&e)
	if perr := syntax.pass1_size_and_relax(&e, stmts[:]); !perr.raised {
		testing.expect(t, false, "expected pass1 to reject mnemonic in WRAM")
		return
	} else {
		testing.expect(t, strings.contains(perr.msg, "WRAM"), "expected WRAM error")
		asm_common.free_error(&perr)
	}
}

@(test)
wram_data_rejected :: proc(t: ^testing.T) {
	SOURCE :: `.wram
.db 1
`
	sync.lock(&TEST_MUTEX)
	defer sync.unlock(&TEST_MUTEX)
	syntax.init_labels()
	defer syntax.free_labels()
	syntax.init_constants()
	defer syntax.free_constants()
	tokens, stmts, ok := prepare_stmts(t, SOURCE)
	if !ok do return
	defer syntax.free_statements(stmts)
	defer delete(tokens)
	e := syntax.Emitter{}
	syntax.emitter_init(&e)
	defer syntax.emitter_free(&e)
	if perr := syntax.pass1_size_and_relax(&e, stmts[:]); !perr.raised {
		testing.expect(t, false, "expected pass1 to reject .db in WRAM")
		return
	} else {
		testing.expect(t, strings.contains(perr.msg, "WRAM"), "expected WRAM error")
		asm_common.free_error(&perr)
	}
}

@(test)
dl_d24_emit_bytes :: proc(t: ^testing.T) {
	SOURCE :: `.org 0x060000
.dl 0x01020304
.d24 0x010203
`
	sync.lock(&TEST_MUTEX)
	defer sync.unlock(&TEST_MUTEX)
	syntax.init_labels()
	defer syntax.free_labels()
	syntax.init_constants()
	defer syntax.free_constants()
	tokens, stmts, ok := prepare_stmts(t, SOURCE)
	if !ok do return
	defer syntax.free_statements(stmts)
	defer delete(tokens)
	e := syntax.Emitter{}
	syntax.emitter_init(&e)
	defer syntax.emitter_free(&e)
	if perr := syntax.pass1_size_and_relax(&e, stmts[:]); perr.raised {
		testing.expectf(t, false, "pass1 failed: %s", perr.msg)
		asm_common.free_error(&perr)
		return
	}
	if aerr := syntax.pass2_emit(&e, stmts[:]); aerr.raised {
		testing.expectf(t, false, "pass2 failed: %s", aerr.msg)
		asm_common.free_error(&aerr)
		return
	}
	want := [7]byte{0x04, 0x03, 0x02, 0x01, 0x03, 0x02, 0x01}
	testing.expect(t, len(e.output) == len(want), "output length mismatch")
	if len(e.output) == len(want) {
		for i in 0 ..< len(want) do testing.expectf(t, e.output[i] == want[i], "byte %d mismatch", i)
	}
}

@(test)
pad_zero_fills :: proc(t: ^testing.T) {
	SOURCE :: `.org 0x060000
.pad 4
.db 9
`
	sync.lock(&TEST_MUTEX)
	defer sync.unlock(&TEST_MUTEX)
	syntax.init_labels()
	defer syntax.free_labels()
	syntax.init_constants()
	defer syntax.free_constants()
	tokens, stmts, ok := prepare_stmts(t, SOURCE)
	if !ok do return
	defer syntax.free_statements(stmts)
	defer delete(tokens)
	e := syntax.Emitter{}
	syntax.emitter_init(&e)
	defer syntax.emitter_free(&e)
	if perr := syntax.pass1_size_and_relax(&e, stmts[:]); perr.raised {
		testing.expectf(t, false, "pass1 failed: %s", perr.msg)
		asm_common.free_error(&perr)
		return
	}
	if aerr := syntax.pass2_emit(&e, stmts[:]); aerr.raised {
		testing.expectf(t, false, "pass2 failed: %s", aerr.msg)
		asm_common.free_error(&aerr)
		return
	}
	want := [5]byte{0x00, 0x00, 0x00, 0x00, 0x09}
	testing.expect(t, len(e.output) == len(want), "output length mismatch")
	if len(e.output) == len(want) {
		for i in 0 ..< len(want) do testing.expectf(t, e.output[i] == want[i], "byte %d mismatch", i)
	}
}

@(test)
org_bounds_rejected :: proc(t: ^testing.T) {
	sync.lock(&TEST_MUTEX)
	defer sync.unlock(&TEST_MUTEX)
	syntax.init_labels()
	defer syntax.free_labels()
	syntax.init_constants()
	defer syntax.free_constants()
	tokens, stmts, ok := prepare_stmts(t, ".org 0x060000\n.org 0xC60001\n")
	if !ok do return
	defer syntax.free_statements(stmts)
	defer delete(tokens)
	e := syntax.Emitter{}
	syntax.emitter_init(&e)
	defer syntax.emitter_free(&e)
	if perr := syntax.pass1_size_and_relax(&e, stmts[:]); !perr.raised {
		testing.expect(t, false, "expected pass1 to reject out-of-ROM .org")
		return
	} else {
		testing.expect(t, strings.contains(perr.msg, "bounds"), "expected bounds error")
		asm_common.free_error(&perr)
	}
}

@(test)
wram_org_bounds_rejected :: proc(t: ^testing.T) {
	sync.lock(&TEST_MUTEX)
	defer sync.unlock(&TEST_MUTEX)
	syntax.init_labels()
	defer syntax.free_labels()
	syntax.init_constants()
	defer syntax.free_constants()
	tokens, stmts, ok := prepare_stmts(t, ".wram\n.org 0x060000\n")
	if !ok do return
	defer syntax.free_statements(stmts)
	defer delete(tokens)
	e := syntax.Emitter{}
	syntax.emitter_init(&e)
	defer syntax.emitter_free(&e)
	if perr := syntax.pass1_size_and_relax(&e, stmts[:]); !perr.raised {
		testing.expect(t, false, "expected pass1 to reject ROM address in WRAM")
		return
	} else {
		testing.expect(t, strings.contains(perr.msg, "bounds"), "expected bounds error")
		asm_common.free_error(&perr)
	}
}

@(test)
equ_constant_emitted :: proc(t: ^testing.T) {
	SOURCE :: `.equ VAL, 0x42
.db VAL
`
	sync.lock(&TEST_MUTEX)
	defer sync.unlock(&TEST_MUTEX)
	syntax.init_labels()
	defer syntax.free_labels()
	syntax.init_constants()
	defer syntax.free_constants()
	tokens, stmts, ok := prepare_stmts(t, SOURCE)
	if !ok do return
	defer syntax.free_statements(stmts)
	defer delete(tokens)
	e := syntax.Emitter{}
	syntax.emitter_init(&e)
	defer syntax.emitter_free(&e)
	if perr := syntax.pass1_size_and_relax(&e, stmts[:]); perr.raised {
		testing.expectf(t, false, "pass1 failed: %s", perr.msg)
		asm_common.free_error(&perr)
		return
	}
	if aerr := syntax.pass2_emit(&e, stmts[:]); aerr.raised {
		testing.expectf(t, false, "pass2 failed: %s", aerr.msg)
		asm_common.free_error(&aerr)
		return
	}
	want := [1]byte{0x42}
	testing.expect(t, len(e.output) == len(want), "output length mismatch")
	if len(e.output) == len(want) {
		for i in 0 ..< len(want) do testing.expectf(t, e.output[i] == want[i], "byte %d mismatch", i)
	}
}
