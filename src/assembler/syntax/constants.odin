package syntax

import "../common"
import "core:strconv"

parse_integer_token :: proc(
	tok: ^Token,
	negative := false,
) -> (
	Expression,
	common.AssemblerError,
) {
	if tok.type != .IntegerLiteral do return {}, token_errorf(tok, "Expected integer literal, got '%s'", tok.text)

	val, ok := strconv.parse_u64_maybe_prefixed(tok.text)
	if !ok do return {}, token_errorf(tok, "Malformed integer literal '%s'", tok.text)

	sval := i64(val)
	if negative do sval = -sval

	return Expression{val = sval, is_signed = negative, type = .Integer}, common.no_error()
}
