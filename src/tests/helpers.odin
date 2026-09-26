package tests

import "../assembler/syntax"

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
