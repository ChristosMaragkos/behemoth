package tests

import "../assembler/syntax"
import "core:testing"


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
