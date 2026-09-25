package cpu

import "../../shared"
import "../common"

RegInfo :: struct {
	index: u8,
	size:  shared.SizeMode,
}

parse_reg :: proc(s: string) -> (RegInfo, common.AssemblerError) {
	switch s {
		case "a":
			return {0, .Word}, common.no_error()
		case "b":
			return {1, .Word}, common.no_error()
		case "c":
			return {2, .Word}, common.no_error()
		case "d":
			return {3, .Word}, common.no_error()
		case "e":
			return {4, .Word}, common.no_error()
		case "f":
			return {5, .Word}, common.no_error()
		case "g":
			return {6, .Word}, common.no_error()
		case "al":
			return {0, .Byte}, common.no_error()
		case "bl":
			return {1, .Byte}, common.no_error()
		case "cl":
			return {2, .Byte}, common.no_error()
		case "dl":
			return {3, .Byte}, common.no_error()
		case "el":
			return {4, .Byte}, common.no_error()
		case "fl":
			return {5, .Byte}, common.no_error()
		case "gl":
			return {6, .Byte}, common.no_error()
		case "sp":
			return {7, .Word}, common.no_error()
	}

	return {}, common.make_errorf("Cannot resolve register '%s'", s)
}
