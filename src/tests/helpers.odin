package tests

import asm_common "../assembler/common"
import "../assembler/syntax"
import "core:sync"
import "core:testing"

TEST_MUTEX: sync.Mutex


token_outputs_equivalent :: proc(seq1, seq2: []syntax.Token) -> bool {
	if len(seq1) != len(seq2) do return false

	for i := 0; i < len(seq1); i += 1 {
		if !tokens_are_equivalent(&seq1[i], &seq2[i]) do return false
	}

	return true
}

lines_equivalent :: proc(l1, l2: []syntax.Line) -> bool {
	if len(l1) != len(l2) do return false

	for i in 0 ..< len(l1) {
		if !token_outputs_equivalent(([]syntax.Token)(l1[i]), ([]syntax.Token)(l2[i])) {
			return false
		}
	}

	return true
}

tokens_are_equivalent :: proc(t1, t2: ^syntax.Token) -> bool {
	return(
		t1.filename == t2.filename &&
		t1.text == t2.text &&
		t1.line == t2.line &&
		t1.type == t2.type \
	)
}

check_mnemonic_deref_mode :: proc(
	t: ^testing.T,
	stmt: syntax.Statement,
	op_idx: int,
	expected_mode: syntax.DerefMode,
) {
	m, ok := stmt.(syntax.Mnemonic)
	testing.expectf(t, ok, "Expected mnemonic statement")
	if !ok do return

	res_op, res_ok := m.operands[op_idx].(syntax.ResolvedOperand)
	testing.expectf(t, res_ok, "Expected resolved operand at slot %d", op_idx)
	if !res_ok do return

	deref, deref_ok := res_op.(syntax.Op_Deref)
	testing.expectf(t, deref_ok, "Expected Op_Deref at slot %d of '%s'", op_idx, m.mnemonic.text)
	if !deref_ok do return

	testing.expectf(
		t,
		deref.mode == expected_mode,
		"Expected mode %v for operand %d in '%s', got %v",
		expected_mode,
		op_idx,
		m.mnemonic.text,
		deref.mode,
	)
}

prepare_stmts :: proc(
	t: ^testing.T,
	source: string,
) -> (
	[dynamic]syntax.Token,
	[dynamic]syntax.Statement,
	bool,
) {
	tokens, lerr := syntax.tokenize("test.asm", source)
	if lerr.raised {
		testing.expectf(t, false, "lex failed: %s", lerr.msg)
		asm_common.free_error(&lerr)
		return nil, nil, false
	}
	lines := syntax.split_lines(tokens[:])
	stmts, perr := syntax.parse_into_statements(lines[:])
	delete(lines)
	if perr.raised {
		testing.expectf(t, false, "parse failed: %s", perr.msg)
		asm_common.free_error(&perr)
		delete(tokens)
		return nil, nil, false
	}
	if terr := syntax.resolve_temp_labels(stmts[:]); terr.raised {
		testing.expectf(t, false, "temp labels failed: %s", terr.msg)
		asm_common.free_error(&terr)
		syntax.free_statements(stmts)
		delete(tokens)
		return nil, nil, false
	}
	if rerr := syntax.replace_operands(stmts[:]); rerr.raised {
		testing.expectf(t, false, "replace failed: %s", rerr.msg)
		asm_common.free_error(&rerr)
		syntax.free_statements(stmts)
		delete(tokens)
		return nil, nil, false
	}
	if eqerr := syntax.emitter_pass_0(stmts[:]); eqerr.raised {
		testing.expectf(t, false, "pass_0 failed: %s", eqerr.msg)
		asm_common.free_error(&eqerr)
		syntax.free_statements(stmts)
		delete(tokens)
		return nil, nil, false
	}
	syntax.substitute_constants(stmts[:])
	for i in 0 ..< len(stmts) {
		d, is_dir := stmts[i].(syntax.Directive)
		if !is_dir do continue
		if verr := syntax.validate_directive_operands(&d); verr.raised {
			testing.expectf(t, false, "validate failed: %s", verr.msg)
			asm_common.free_error(&verr)
			syntax.free_statements(stmts)
			delete(tokens)
			return nil, nil, false
		}
	}
	return tokens, stmts, true
}

check_label :: proc(t: ^testing.T, name: string, want: u32) {
	lbl, lerr := syntax.resolve_label(name)
	asm_common.free_error(&lerr)
	if lerr.raised {
		testing.expectf(t, false, "label '%s' missing", name)
		return
	}
	testing.expectf(t, lbl.addr == want, "label '%s' address %v, want %v", name, lbl.addr, want)
}
