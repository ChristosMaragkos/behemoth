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

	return Expression {
		val = sval,
		is_signed = negative,
		type = .Integer,
		tok = tok^,
	}, common.no_error()
}

fits_width :: proc(#any_int val: i64, width: u8) -> bool {
	if width == 0 {
		return false
	}

	if width >= 64 {
		return true
	}

	min_val := -(i64(1) << (width - 1))
	max_val := (i64(1) << width) - 1

	if val < min_val || val > max_val do return false

	return true
}

resolve_symbol :: proc(name: string) -> (val: i64, is_label: bool, err: common.AssemblerError) {
	if c, ok := CONSTANTS[name]; ok {
		if c.is_signed do return i64(c.signed), false, common.no_error()
		return i64(c.unsigned), false, common.no_error()
	}
	if l, ok := LABELS[name]; ok do return i64(l.addr), true, common.no_error()
	return 0, false, common.make_errorf("Unknown symbol '%s'", name)
}
