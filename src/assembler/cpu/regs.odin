package cpu

import "../../shared"

RegInfo :: struct {
	index: u8,
	size:  shared.SizeMode,
}

parse_reg :: proc(s: string) -> (RegInfo, bool) {
	switch s {
		case "a":
			return {0, .Word}, true
		case "b":
			return {1, .Word}, true
		case "c":
			return {2, .Word}, true
		case "d":
			return {3, .Word}, true
		case "e":
			return {4, .Word}, true
		case "f":
			return {5, .Word}, true
		case "g":
			return {6, .Word}, true
		case "al":
			return {0, .Byte}, true
		case "bl":
			return {1, .Byte}, true
		case "cl":
			return {2, .Byte}, true
		case "dl":
			return {3, .Byte}, true
		case "el":
			return {4, .Byte}, true
		case "fl":
			return {5, .Byte}, true
		case "gl":
			return {6, .Byte}, true
		case "sp":
			return {7, .Word}, true
	}

	return {}, false
}
