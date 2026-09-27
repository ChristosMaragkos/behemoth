package syntax

import "../common"
import "core:strconv"

SYMBOLS: map[string]i64

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

fits_width :: proc(#any_int val: i64, width: u8) -> bool {
	if width == 0 {
		return false
	}

	if width >= 64 {
		return true
	}

	min_val := -(i64(1) << (width - 1)) // e.g. -128 for 8-bit
	max_val := (i64(1) << width) - 1 // e.g.  255 for 8-bit

	if val < min_val || val > max_val do return false

	return true
}
