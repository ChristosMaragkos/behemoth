package syntax

import "../common"
import "core:fmt"

TokenType :: enum {
	Identifier,
	IntegerLiteral,
	StringLiteral,
	BrackLeft,
	BrackRight,
	Plus,
	Minus,
	Colon,
	Comma,
	Newline,
	EOF,
}

Token :: struct {
	type:     TokenType,
	text:     string,
	filename: string,
	line:     uint,
}

token_error :: proc(t: ^Token, msg: string) -> common.AssemblerError {
	return common.make_errorf("%s:%d: %s", t.filename, t.line, msg)
}

token_errorf :: proc(t: ^Token, msg: string, args: ..any) -> common.AssemblerError {
	formatted := fmt.aprintf(msg, ..args)
	defer delete(formatted)
	return common.make_errorf("%s:%d: %s", t.filename, t.line, formatted)
}

Tokenizer :: struct {
	source:   string,
	filename: string,
	pos:      uint,
	line:     uint,
}

tokenizer_peek :: proc {
	tokenizer_peek_single,
	tokenizer_peek_multiple,
}

tokenizer_peek_single :: proc(t: ^Tokenizer) -> byte {
	if t.pos >= len(t.source) do return 0
	#no_bounds_check { return t.source[t.pos] }
}

tokenizer_peek_multiple :: proc(t: ^Tokenizer, amount: uint) -> string {
	if t.pos + amount > len(t.source) do return ""
	#no_bounds_check { return t.source[t.pos:t.pos + amount] }
}

tokenizer_advance_single :: proc(t: ^Tokenizer) {
	current := tokenizer_peek(t)
	if current == 0 do return

	t.pos += 1
	if current == '\n' do t.line += 1
}

tokenizer_advance_multiple :: proc(t: ^Tokenizer, amount: uint) {
	for i in 0 ..< amount do tokenizer_advance_single(t)
}

tokenizer_advance :: proc {
	tokenizer_advance_single,
	tokenizer_advance_multiple,
}

tokenizer_skip_to_newline :: proc(t: ^Tokenizer) {
	for tokenizer_peek(t) != '\n' && tokenizer_peek(t) != 0 {
		tokenizer_advance(t)
	}
}

emit_const_text_token :: proc(t: ^Tokenizer, type: TokenType, text: string) -> Token {
	return Token{type = type, text = text, filename = t.filename, line = t.line}
}

// The contract here is that the tokenizer rests on a double quote when entering
emit_string :: proc(t: ^Tokenizer) -> (Token, common.AssemblerError) {
	tokenizer_advance_single(t) // step over opening quote
	opening := t.pos
	closing: uint

	out := Token {
		type     = .StringLiteral,
		filename = t.filename,
		line     = t.line,
	}

	for {
		current := tokenizer_peek(t)
		if current == '\n' || current == 0 {
			return {}, token_error(&out, "Unterminated string literal")
		} else if current == '"' {
			closing = t.pos
			out.text = t.source[opening:closing]
			tokenizer_advance(t)
			return out, common.no_error()
		} else {
			tokenizer_advance(t)
		}
	}
}

is_identifier_char :: proc(ch: byte) -> bool {
	return is_identifier_start(ch) || (ch >= '0' && ch <= '9')
}

is_identifier_start :: proc(ch: byte) -> bool {
	return(
		(ch >= 'a' && ch <= 'z') ||
		(ch >= 'A' && ch <= 'Z') ||
		ch == '_' ||
		ch == '@' ||
		ch == '.' \
	)
}

is_decimal_digit :: proc(ch: byte) -> bool {
	return (ch >= '0' && ch <= '9') || ch == '_'
}

is_hex_digit :: proc(ch: byte) -> bool {
	return(
		is_decimal_digit(ch) ||
		(ch >= 'a' && ch <= 'f') ||
		(ch >= 'A' && ch <= 'F') ||
		ch == '_' \
	)
}

is_hex_prefix :: proc(prefix: string) -> bool {
	return prefix == "0x" || prefix == "0X"
}

is_bin_prefix :: proc(prefix: string) -> bool {
	return prefix == "0b" || prefix == "0B"
}

is_octal_prefix :: proc(prefix: string) -> bool {
	return prefix == "0o" || prefix == "0O"
}

emit_integer :: proc(t: ^Tokenizer) -> Token {
	start := t.pos
	prefix := tokenizer_peek(t, 2)

	if is_hex_prefix(prefix) {
		tokenizer_advance(t, 2)
		for is_hex_digit(tokenizer_peek(t)) {
			tokenizer_advance(t)
		}
	} else if is_bin_prefix(prefix) {
		tokenizer_advance(t, 2)
		for {
			current := tokenizer_peek(t)
			if current != '0' && current != '1' && current != '_' do break
			tokenizer_advance(t)
		}
	} else if is_octal_prefix(prefix) {
		for {
			current := tokenizer_peek(t)
			if !(current >= '0' && current <= '7' && current != '_') do break
			tokenizer_advance(t)
		}
	} else {
		for is_decimal_digit(tokenizer_peek(t)) {
			tokenizer_advance(t)
		}
	}

	return Token {
		type = .IntegerLiteral,
		filename = t.filename,
		line = t.line,
		text = t.source[start:t.pos],
	}
}

emit_identifier :: proc(t: ^Tokenizer) -> Token {
	start := t.pos
	for is_identifier_char(tokenizer_peek(t)) {
		tokenizer_advance_single(t)
	}
	return Token {
		type = .Identifier,
		filename = t.filename,
		line = t.line,
		text = t.source[start:t.pos],
	}
}

tokenizer_next_token :: proc(t: ^Tokenizer) -> (Token, common.AssemblerError) {
	for {
		current := tokenizer_peek(t)

		if current == ';' {
			tokenizer_skip_to_newline(t)
			continue
		} else if current == ' ' || current == '\t' || current == '\r' {
			tokenizer_advance(t)
			continue
		}

		out: Token
		switch current {
			case '\n':
				out = emit_const_text_token(t, .Newline, "<newline>")
				tokenizer_advance(t)
			case 0:
				out = emit_const_text_token(t, .EOF, "<EOF>")
				tokenizer_advance(t)
			case '[':
				out = emit_const_text_token(t, .BrackLeft, "[")
				tokenizer_advance(t)
			case ']':
				out = emit_const_text_token(t, .BrackRight, "]")
				tokenizer_advance(t)
			case ',':
				out = emit_const_text_token(t, .Comma, ",")
				tokenizer_advance(t)
			case '+':
				out = emit_const_text_token(t, .Plus, "+")
				tokenizer_advance(t)
			case '-':
				out = emit_const_text_token(t, .Minus, "-")
				tokenizer_advance(t)
			case ':':
				out = emit_const_text_token(t, .Colon, ":")
				tokenizer_advance(t)
			case '"':
				err: common.AssemblerError
				out, err = emit_string(t)
				if err.raised do return {}, err
			case '0' ..= '9':
				out = emit_integer(t)
			case:
				if is_identifier_start(current) {
					out = emit_identifier(t)
				} else {
					return {}, common.make_errorf("%s:%d: Unexpected character '%c'", t.filename, t.line, current)
				}
		}

		return out, common.no_error()
	}
}

tokenize :: proc(filename, source: string) -> ([dynamic]Token, common.AssemblerError) {
	out := make([dynamic]Token)

	t := Tokenizer {
		source   = source,
		filename = filename,
		pos      = 0,
		line     = 0,
	}

	for {
		next, err := tokenizer_next_token(&t)
		if err.raised do return out, err

		append(&out, next)
		if next.type == .EOF do break
	}

	return out, common.no_error()
}
