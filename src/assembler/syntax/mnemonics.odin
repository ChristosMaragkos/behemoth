#+feature dynamic-literals
package syntax

import "../../shared"
import "core:fmt"

USE_SUBROUTINE_ALIASES :: #config(MODERN_SUBROUTINE_ALIASES, false)

OperandShape :: enum {
	Reg8,
	Reg16,
	PairBare,
	Imm8,
	Imm16,
	Imm24,
	Imm32,
	Symbol,
	String,
	RegPtr,
	ImmPtr,
	RegPtrImmOffs,
	RegPtrRegOffs,
	PairPtr,
	PairImmOffs,
	PairRegOffs,
	Imm24RegOffs,
	PostInc,
	PreInc,
	PostDec,
	PreDec,
}

Form :: struct {
	shapes: [dynamic]OperandShape,
	opcode: u16,
	length: u32,
}

MNEMONICS: map[string][dynamic]Form

misc_opcode :: #force_inline proc(sz: shared.SizeMode, op: shared.MiscOpcodes) -> u16 {
	return transmute(u16)shared.Instruction{size = sz, type = .Misc, opcode = u8(op)}
}

mem_opcode :: #force_inline proc(sz: shared.SizeMode, op: shared.MemoryOpcodes) -> u16 {
	return transmute(u16)shared.Instruction{size = sz, type = .Memory, opcode = u8(op)}
}

math_opcode :: #force_inline proc(sz: shared.SizeMode, op: shared.MathOpcodes) -> u16 {
	return transmute(u16)shared.Instruction{size = sz, type = .Math, opcode = u8(op)}
}

flow_opcode :: #force_inline proc(sz: shared.SizeMode, op: shared.FlowOpcodes) -> u16 {
	return transmute(u16)shared.Instruction{size = sz, type = .ControlFlow, opcode = u8(op)}
}

alias_of :: #force_inline proc(mnem: string) -> [dynamic]Form {
	if mnem not_in MNEMONICS do fmt.panicf("Cannot define alias of %s, mnemonic was not found in the table", mnem)

	src := MNEMONICS[mnem]
	out := make([dynamic]Form, len(src))
	for f, i in src {
		out[i].opcode = f.opcode
		out[i].length = f.length
		out[i].shapes = make([dynamic]OperandShape, len(f.shapes))
		copy(out[i].shapes[:], f.shapes[:])
	}

	return out
}

operand_matches_shape :: proc(shape: OperandShape, op: ResolvedOperand) -> bool {
	switch shape {
		case .Reg8:
			reg, ok := op.(Op_Reg)
			return ok && reg.reg.size == .Byte
		case .Reg16:
			reg, ok := op.(Op_Reg)
			return ok && reg.reg.size == .Word
		case .PairBare:
			_, ok := op.(Op_Reg_Pair)
			return ok
		case .Imm8, .Imm16, .Imm24, .Imm32:
			imm, ok := op.(Op_Imm)
			return ok && imm.expr.type == .Integer
		case .Symbol:
			imm, ok := op.(Op_Imm)
			return ok && imm.expr.type == .Symbol
		case .String:
			_, ok := op.(Op_String)
			return ok
		case .RegPtr, .PostInc, .PreInc, .PostDec, .PreDec:
			deref, ok := op.(Op_Deref)
			if !ok do return false
			if shape == .RegPtr do return deref.mode == .Reg
			if shape == .PostInc do return deref.mode == .Reg_PostInc
			if shape == .PreInc do return deref.mode == .Reg_PreInc
			if shape == .PostDec do return deref.mode == .Reg_PostDec
			return deref.mode == .Reg_PreDec
		case .ImmPtr:
			deref, ok := op.(Op_Deref)
			return ok && deref.mode == .Imm
		case .RegPtrImmOffs:
			deref, ok := op.(Op_Deref)
			return ok && deref.mode == .Reg_ImmOffset
		case .RegPtrRegOffs:
			deref, ok := op.(Op_Deref)
			return ok && deref.mode == .Reg_RegOffset
		case .PairPtr:
			deref, ok := op.(Op_Deref)
			return ok && deref.mode == .Reg_Pair
		case .PairImmOffs:
			deref, ok := op.(Op_Deref)
			return ok && deref.mode == .Reg_Pair_ImmOffset
		case .PairRegOffs:
			deref, ok := op.(Op_Deref)
			return ok && deref.mode == .Reg_Pair_RegOffset
		case .Imm24RegOffs:
			deref, ok := op.(Op_Deref)
			return ok && deref.mode == .Imm_Long_RegOffset
	}
	return false
}

init_mnemonics :: proc() {
	MNEMONICS = make(map[string][dynamic]Form)

	define_misc_ops()
	define_mem_ops()
	define_math_ops()
	define_flow_ops()

	when USE_SUBROUTINE_ALIASES {
		MNEMONICS["call"] = alias_of("jsr")
		MNEMONICS["call.l"] = alias_of("jsr.l")
		MNEMONICS["ret"] = alias_of("rts")
		MNEMONICS["ret.l"] = alias_of("rts.l")
		MNEMONICS["iret"] = alias_of("rti")
		MNEMONICS["fret"] = alias_of("rtf")
	}
}

free_mnemonics :: proc() {
	if MNEMONICS == nil do return
	for _, forms in MNEMONICS {
		for f in forms do delete(f.shapes)
		delete(forms)
	}
	err := delete(MNEMONICS)
	if err != .None do fmt.printfln("Unable to free mnemonic table")
	MNEMONICS = nil
}

@(private = "file")
define_misc_ops :: #force_inline proc() {
	// nop
	MNEMONICS["nop"] = {{shapes = {}, opcode = misc_opcode(.Word, .Nop), length = 2}}

	// wfi
	MNEMONICS["wfi"] = {{shapes = {}, opcode = misc_opcode(.Word, .Wfi), length = 2}}

	// mov reg reg
	MNEMONICS["mov"] = {
		{shapes = {.Reg8, .Reg8}, opcode = misc_opcode(.Byte, .Mov), length = 2},
		{shapes = {.Reg16, .Reg16}, opcode = misc_opcode(.Word, .Mov), length = 2},
	}

	// sxt reg
	MNEMONICS["sxt"] = {{shapes = {.Reg8}, opcode = misc_opcode(.Byte, .Sxt), length = 2}}

	// zxt reg
	MNEMONICS["zxt"] = {{shapes = {.Reg8}, opcode = misc_opcode(.Byte, .Zxt), length = 2}}

	// xchg reg reg
	MNEMONICS["xchg"] = {
		{shapes = {.Reg8, .Reg8}, opcode = misc_opcode(.Byte, .Xchg), length = 2},
		{shapes = {.Reg16, .Reg16}, opcode = misc_opcode(.Word, .Xchg), length = 2},
	}

	// swp reg
	MNEMONICS["swp"] = {{shapes = {.Reg16}, opcode = misc_opcode(.Word, .Swp), length = 2}}

	// mfhi reg
	MNEMONICS["mfhi"] = {
		{shapes = {.Reg8}, opcode = misc_opcode(.Byte, .Mfhi), length = 2},
		{shapes = {.Reg16}, opcode = misc_opcode(.Word, .Mfhi), length = 2},
	}

	// mthi reg
	MNEMONICS["mthi"] = {
		{shapes = {.Reg8}, opcode = misc_opcode(.Byte, .Mthi), length = 2},
		{shapes = {.Reg16}, opcode = misc_opcode(.Word, .Mthi), length = 2},
	}

	// mfpp reg
	MNEMONICS["mfpp"] = {{shapes = {.Reg8}, opcode = misc_opcode(.Byte, .Mfpp), length = 2}}

	// mtpp reg
	MNEMONICS["mtpp"] = {{shapes = {.Reg8}, opcode = misc_opcode(.Byte, .Mtpp), length = 2}}

	// mfdp reg
	MNEMONICS["mfdp"] = {{shapes = {.Reg8}, opcode = misc_opcode(.Byte, .Mfdp), length = 2}}

	// mtdp reg
	MNEMONICS["mtdp"] = {{shapes = {.Reg8}, opcode = misc_opcode(.Byte, .Mtdp), length = 2}}

	MNEMONICS["swi"] = {
		// swi imm
		{shapes = {.Imm8}, opcode = misc_opcode(.Byte, .Swi_Imm), length = 3},
		// swi reg
		{shapes = {.Reg8}, opcode = misc_opcode(.Byte, .Swi_Reg), length = 2},
	}

	// sec
	MNEMONICS["sec"] = {{shapes = {}, opcode = misc_opcode(.Word, .Sec), length = 2}}

	// clc
	MNEMONICS["clc"] = {{shapes = {}, opcode = misc_opcode(.Word, .Clc), length = 2}}

	// sez
	MNEMONICS["sez"] = {{shapes = {}, opcode = misc_opcode(.Word, .Sez), length = 2}}

	// clz
	MNEMONICS["clz"] = {{shapes = {}, opcode = misc_opcode(.Word, .Clz), length = 2}}

	// sen
	MNEMONICS["sen"] = {{shapes = {}, opcode = misc_opcode(.Word, .Sen), length = 2}}

	// cln
	MNEMONICS["cln"] = {{shapes = {}, opcode = misc_opcode(.Word, .Cln), length = 2}}

	// sev
	MNEMONICS["sev"] = {{shapes = {}, opcode = misc_opcode(.Word, .Sev), length = 2}}

	// clv
	MNEMONICS["clv"] = {{shapes = {}, opcode = misc_opcode(.Word, .Clv), length = 2}}

	// sei
	MNEMONICS["sei"] = {{shapes = {}, opcode = misc_opcode(.Word, .Sei), length = 2}}

	// cli
	MNEMONICS["cli"] = {{shapes = {}, opcode = misc_opcode(.Word, .Cli), length = 2}}

	// mffr reg
	MNEMONICS["mffr"] = {
		{shapes = {.Reg8}, opcode = misc_opcode(.Byte, .Mffr), length = 2},
		{shapes = {.Reg16}, opcode = misc_opcode(.Word, .Mffr), length = 2},
	}

	// mtfr reg
	MNEMONICS["mtfr"] = {
		{shapes = {.Reg8}, opcode = misc_opcode(.Byte, .Mtfr), length = 2},
		{shapes = {.Reg16}, opcode = misc_opcode(.Word, .Mtfr), length = 2},
	}
}

@(private = "file")
define_mem_ops :: #force_inline proc() {
	MNEMONICS["ld"] = {
		// ld reg imm
		{shapes = {.Reg8, .Imm8}, opcode = mem_opcode(.Byte, .Ld_Reg_Imm), length = 3},
		{shapes = {.Reg16, .Imm16}, opcode = mem_opcode(.Word, .Ld_Reg_Imm), length = 4},

		// ld reg, label
		{shapes = {.Reg8, .Symbol}, opcode = mem_opcode(.Byte, .Ld_Reg_Imm), length = 3},
		{shapes = {.Reg16, .Symbol}, opcode = mem_opcode(.Word, .Ld_Reg_Imm), length = 4},

		// ld reg, [reg]
		{shapes = {.Reg8, .RegPtr}, opcode = mem_opcode(.Byte, .Ld_Reg_RegPtr), length = 2},
		{shapes = {.Reg16, .RegPtr}, opcode = mem_opcode(.Word, .Ld_Reg_RegPtr), length = 2},

		// ld reg, [imm]
		{shapes = {.Reg8, .ImmPtr}, opcode = mem_opcode(.Byte, .Ld_Reg_ImmPtr), length = 4},
		{shapes = {.Reg16, .ImmPtr}, opcode = mem_opcode(.Word, .Ld_Reg_ImmPtr), length = 4},

		// ld reg, [reg + imm]
		{
			shapes = {.Reg8, .RegPtrImmOffs},
			opcode = mem_opcode(.Byte, .Ld_Reg_ImmOffs),
			length = 4,
		},
		{
			shapes = {.Reg16, .RegPtrImmOffs},
			opcode = mem_opcode(.Word, .Ld_Reg_ImmOffs),
			length = 4,
		},

		// ld reg, [reg + reg]
		{
			shapes = {.Reg8, .RegPtrRegOffs},
			opcode = mem_opcode(.Byte, .Ld_Reg_RegOffs),
			length = 3,
		},
		{
			shapes = {.Reg16, .RegPtrRegOffs},
			opcode = mem_opcode(.Word, .Ld_Reg_RegOffs),
			length = 3,
		},

		// ld reg, [reg+]
		{
			shapes = {.Reg8, .PostInc},
			opcode = mem_opcode(.Byte, .Ld_Reg_RegPtr_PostInc),
			length = 2,
		},
		{
			shapes = {.Reg16, .PostInc},
			opcode = mem_opcode(.Word, .Ld_Reg_RegPtr_PostInc),
			length = 2,
		},

		// ld reg, [+reg]
		{shapes = {.Reg8, .PreInc}, opcode = mem_opcode(.Byte, .Ld_Reg_RegPtr_PreInc), length = 2},
		{
			shapes = {.Reg16, .PreInc},
			opcode = mem_opcode(.Word, .Ld_Reg_RegPtr_PreInc),
			length = 2,
		},
		// ld reg, [reg-]
		{
			shapes = {.Reg8, .PostDec},
			opcode = mem_opcode(.Byte, .Ld_Reg_RegPtr_PostDec),
			length = 2,
		},
		{
			shapes = {.Reg16, .PostDec},
			opcode = mem_opcode(.Word, .Ld_Reg_RegPtr_PostDec),
			length = 2,
		},

		// ld reg, [-reg]
		{shapes = {.Reg8, .PreDec}, opcode = mem_opcode(.Byte, .Ld_Reg_RegPtr_PreDec), length = 2},
		{
			shapes = {.Reg16, .PreDec},
			opcode = mem_opcode(.Word, .Ld_Reg_RegPtr_PreDec),
			length = 2,
		},
	}

	MNEMONICS["st"] = {
		// st reg, [reg]
		{shapes = {.Reg8, .RegPtr}, opcode = mem_opcode(.Byte, .St_Reg_RegPtr), length = 2},
		{shapes = {.Reg16, .RegPtr}, opcode = mem_opcode(.Word, .St_Reg_RegPtr), length = 2},

		// st reg, [imm]
		{shapes = {.Reg8, .ImmPtr}, opcode = mem_opcode(.Byte, .St_Reg_ImmPtr), length = 4},
		{shapes = {.Reg16, .ImmPtr}, opcode = mem_opcode(.Word, .St_Reg_ImmPtr), length = 4},

		// st reg, [reg + imm]
		{
			shapes = {.Reg8, .RegPtrImmOffs},
			opcode = mem_opcode(.Byte, .St_Reg_ImmOffs),
			length = 4,
		},
		{
			shapes = {.Reg16, .RegPtrImmOffs},
			opcode = mem_opcode(.Word, .St_Reg_ImmOffs),
			length = 4,
		},

		// st reg, [reg + reg]
		{
			shapes = {.Reg8, .RegPtrRegOffs},
			opcode = mem_opcode(.Byte, .St_Reg_RegOffs),
			length = 3,
		},
		{
			shapes = {.Reg16, .RegPtrRegOffs},
			opcode = mem_opcode(.Word, .St_Reg_RegOffs),
			length = 3,
		},

		// st reg, [reg+]
		{
			shapes = {.Reg8, .PostInc},
			opcode = mem_opcode(.Byte, .St_Reg_RegPtr_PostInc),
			length = 2,
		},
		{
			shapes = {.Reg16, .PostInc},
			opcode = mem_opcode(.Word, .St_Reg_RegPtr_PostInc),
			length = 2,
		},

		// st reg, [+reg]
		{shapes = {.Reg8, .PreInc}, opcode = mem_opcode(.Byte, .St_Reg_RegPtr_PreInc), length = 2},
		{
			shapes = {.Reg16, .PreInc},
			opcode = mem_opcode(.Word, .St_Reg_RegPtr_PreInc),
			length = 2,
		},
		// st reg, [reg-]
		{
			shapes = {.Reg8, .PostDec},
			opcode = mem_opcode(.Byte, .St_Reg_RegPtr_PostDec),
			length = 2,
		},
		{
			shapes = {.Reg16, .PostDec},
			opcode = mem_opcode(.Word, .St_Reg_RegPtr_PostDec),
			length = 2,
		},

		// st reg, [-reg]
		{shapes = {.Reg8, .PreDec}, opcode = mem_opcode(.Byte, .St_Reg_RegPtr_PreDec), length = 2},
		{
			shapes = {.Reg16, .PreDec},
			opcode = mem_opcode(.Word, .St_Reg_RegPtr_PreDec),
			length = 2,
		},
	}

	MNEMONICS["push"] = {{shapes = {.Reg16}, opcode = mem_opcode(.Word, .Push), length = 2}}
	MNEMONICS["pop"] = {{shapes = {.Reg16}, opcode = mem_opcode(.Word, .Pop), length = 2}}
	MNEMONICS["shove"] = {{shapes = {.Imm16}, opcode = mem_opcode(.Word, .Shove), length = 4}}

	MNEMONICS["ld.l"] = {
		// ld.l reg, [imm24]
		{shapes = {.Reg8, .ImmPtr}, opcode = mem_opcode(.Byte, .Ld_L_Ptr24), length = 5},
		{shapes = {.Reg16, .ImmPtr}, opcode = mem_opcode(.Word, .Ld_L_Ptr24), length = 5},

		// ld.l reg, [imm24 + reg]
		{
			shapes = {.Reg8, .Imm24RegOffs},
			opcode = mem_opcode(.Byte, .Ld_L_Ptr24_RegOffs),
			length = 5,
		},
		{
			shapes = {.Reg16, .Imm24RegOffs},
			opcode = mem_opcode(.Word, .Ld_L_Ptr24_RegOffs),
			length = 5,
		},

		// ld.l reg, [reg8:reg16]
		{shapes = {.Reg8, .PairPtr}, opcode = mem_opcode(.Byte, .Ld_L_RegPair), length = 3},
		{shapes = {.Reg16, .PairPtr}, opcode = mem_opcode(.Word, .Ld_L_RegPair), length = 3},

		// ld.l reg, [reg8:reg16 + imm]
		{
			shapes = {.Reg8, .PairImmOffs},
			opcode = mem_opcode(.Byte, .Ld_L_RegPair_ImmOffs),
			length = 5,
		},
		{
			shapes = {.Reg16, .PairImmOffs},
			opcode = mem_opcode(.Word, .Ld_L_RegPair_ImmOffs),
			length = 5,
		},

		// ld.l reg, [reg8:reg16 + reg]
		{
			shapes = {.Reg8, .PairRegOffs},
			opcode = mem_opcode(.Byte, .Ld_L_RegPair_RegOffs),
			length = 3,
		},
		{
			shapes = {.Reg16, .PairRegOffs},
			opcode = mem_opcode(.Word, .Ld_L_RegPair_RegOffs),
			length = 3,
		},
	}

	MNEMONICS["st.l"] = {
		// st.l reg, [imm24]
		{shapes = {.Reg8, .ImmPtr}, opcode = mem_opcode(.Byte, .St_L_Ptr24), length = 5},
		{shapes = {.Reg16, .ImmPtr}, opcode = mem_opcode(.Word, .St_L_Ptr24), length = 5},

		// st.l reg, [imm24 + reg]
		{
			shapes = {.Reg8, .Imm24RegOffs},
			opcode = mem_opcode(.Byte, .St_L_Ptr24_RegOffs),
			length = 5,
		},
		{
			shapes = {.Reg16, .Imm24RegOffs},
			opcode = mem_opcode(.Word, .St_L_Ptr24_RegOffs),
			length = 5,
		},

		// st.l reg, [reg8:reg16]
		{shapes = {.Reg8, .PairPtr}, opcode = mem_opcode(.Byte, .St_L_RegPair), length = 3},
		{shapes = {.Reg16, .PairPtr}, opcode = mem_opcode(.Word, .St_L_RegPair), length = 3},

		// st.l reg, [reg8:reg16 + imm]
		{
			shapes = {.Reg8, .PairImmOffs},
			opcode = mem_opcode(.Byte, .St_L_RegPair_ImmOffs),
			length = 5,
		},
		{
			shapes = {.Reg16, .PairImmOffs},
			opcode = mem_opcode(.Word, .St_L_RegPair_ImmOffs),
			length = 5,
		},

		// st.l reg, [reg8:reg16 + reg]
		{
			shapes = {.Reg8, .PairRegOffs},
			opcode = mem_opcode(.Byte, .St_L_RegPair_RegOffs),
			length = 3,
		},
		{
			shapes = {.Reg16, .PairRegOffs},
			opcode = mem_opcode(.Word, .St_L_RegPair_RegOffs),
			length = 3,
		},
	}

	// blkcp [reg8:reg16], [reg8:reg16], reg16
	MNEMONICS["blkcp"] = {
		{shapes = {.PairPtr, .PairPtr, .Reg16}, opcode = mem_opcode(.Word, .Blkcp), length = 4},
	}

	// blkmv [reg8:reg16], [reg8:reg16], reg16
	MNEMONICS["blkmv"] = {
		{shapes = {.PairPtr, .PairPtr, .Reg16}, opcode = mem_opcode(.Word, .Blkmv), length = 4},
	}
}

@(private = "file")
define_math_ops :: #force_inline proc() {
	// add reg, reg
	MNEMONICS["add"] = {
		{shapes = {.Reg8, .Reg8}, opcode = math_opcode(.Byte, .Add_Reg_Reg), length = 2},
		{shapes = {.Reg16, .Reg16}, opcode = math_opcode(.Word, .Add_Reg_Reg), length = 2},
		{shapes = {.Reg8, .Imm8}, opcode = math_opcode(.Byte, .Add_Reg_Imm), length = 3},
		{shapes = {.Reg16, .Imm16}, opcode = math_opcode(.Word, .Add_Reg_Imm), length = 4},
		{shapes = {.Reg8, .RegPtr}, opcode = math_opcode(.Byte, .Add_Reg_RegPtr), length = 2},
		{shapes = {.Reg16, .RegPtr}, opcode = math_opcode(.Word, .Add_Reg_RegPtr), length = 2},
		{shapes = {.Reg8, .ImmPtr}, opcode = math_opcode(.Byte, .Add_Reg_ImmPtr), length = 4},
		{shapes = {.Reg16, .ImmPtr}, opcode = math_opcode(.Word, .Add_Reg_ImmPtr), length = 4},
		{
			shapes = {.Reg8, .RegPtrImmOffs},
			opcode = math_opcode(.Byte, .Add_Reg_RegPtr_ImmOffs),
			length = 4,
		},
		{
			shapes = {.Reg16, .RegPtrImmOffs},
			opcode = math_opcode(.Word, .Add_Reg_RegPtr_ImmOffs),
			length = 4,
		},
		{
			shapes = {.Reg8, .RegPtrRegOffs},
			opcode = math_opcode(.Byte, .Add_Reg_RegPtr_RegOffs),
			length = 3,
		},
		{
			shapes = {.Reg16, .RegPtrRegOffs},
			opcode = math_opcode(.Word, .Add_Reg_RegPtr_RegOffs),
			length = 3,
		},
	}

	// sub reg, reg
	MNEMONICS["sub"] = {
		{shapes = {.Reg8, .Reg8}, opcode = math_opcode(.Byte, .Sub_Reg_Reg), length = 2},
		{shapes = {.Reg16, .Reg16}, opcode = math_opcode(.Word, .Sub_Reg_Reg), length = 2},
		{shapes = {.Reg8, .Imm8}, opcode = math_opcode(.Byte, .Sub_Reg_Imm), length = 3},
		{shapes = {.Reg16, .Imm16}, opcode = math_opcode(.Word, .Sub_Reg_Imm), length = 4},
		{shapes = {.Reg8, .RegPtr}, opcode = math_opcode(.Byte, .Sub_Reg_RegPtr), length = 2},
		{shapes = {.Reg16, .RegPtr}, opcode = math_opcode(.Word, .Sub_Reg_RegPtr), length = 2},
		{shapes = {.Reg8, .ImmPtr}, opcode = math_opcode(.Byte, .Sub_Reg_ImmPtr), length = 4},
		{shapes = {.Reg16, .ImmPtr}, opcode = math_opcode(.Word, .Sub_Reg_ImmPtr), length = 4},
		{
			shapes = {.Reg8, .RegPtrImmOffs},
			opcode = math_opcode(.Byte, .Sub_Reg_RegPtr_ImmOffs),
			length = 4,
		},
		{
			shapes = {.Reg16, .RegPtrImmOffs},
			opcode = math_opcode(.Word, .Sub_Reg_RegPtr_ImmOffs),
			length = 4,
		},
		{
			shapes = {.Reg8, .RegPtrRegOffs},
			opcode = math_opcode(.Byte, .Sub_Reg_RegPtr_RegOffs),
			length = 3,
		},
		{
			shapes = {.Reg16, .RegPtrRegOffs},
			opcode = math_opcode(.Word, .Sub_Reg_RegPtr_RegOffs),
			length = 3,
		},
	}

	// mulu reg, reg
	MNEMONICS["mulu"] = {
		{shapes = {.Reg8, .Reg8}, opcode = math_opcode(.Byte, .Mulu_Reg_Reg), length = 2},
		{shapes = {.Reg16, .Reg16}, opcode = math_opcode(.Word, .Mulu_Reg_Reg), length = 2},
		{shapes = {.Reg8, .Imm8}, opcode = math_opcode(.Byte, .Mulu_Reg_Imm), length = 3},
		{shapes = {.Reg16, .Imm16}, opcode = math_opcode(.Word, .Mulu_Reg_Imm), length = 4},
		{shapes = {.Reg8, .RegPtr}, opcode = math_opcode(.Byte, .Mulu_Reg_RegPtr), length = 2},
		{shapes = {.Reg16, .RegPtr}, opcode = math_opcode(.Word, .Mulu_Reg_RegPtr), length = 2},
		{shapes = {.Reg8, .ImmPtr}, opcode = math_opcode(.Byte, .Mulu_Reg_ImmPtr), length = 4},
		{shapes = {.Reg16, .ImmPtr}, opcode = math_opcode(.Word, .Mulu_Reg_ImmPtr), length = 4},
		{
			shapes = {.Reg8, .RegPtrImmOffs},
			opcode = math_opcode(.Byte, .Mulu_Reg_RegPtr_ImmOffs),
			length = 4,
		},
		{
			shapes = {.Reg16, .RegPtrImmOffs},
			opcode = math_opcode(.Word, .Mulu_Reg_RegPtr_ImmOffs),
			length = 4,
		},
		{
			shapes = {.Reg8, .RegPtrRegOffs},
			opcode = math_opcode(.Byte, .Mulu_Reg_RegPtr_RegOffs),
			length = 3,
		},
		{
			shapes = {.Reg16, .RegPtrRegOffs},
			opcode = math_opcode(.Word, .Mulu_Reg_RegPtr_RegOffs),
			length = 3,
		},
	}

	// divu reg, reg
	MNEMONICS["divu"] = {
		{shapes = {.Reg8, .Reg8}, opcode = math_opcode(.Byte, .Divu_Reg_Reg), length = 2},
		{shapes = {.Reg16, .Reg16}, opcode = math_opcode(.Word, .Divu_Reg_Reg), length = 2},
		{shapes = {.Reg8, .Imm8}, opcode = math_opcode(.Byte, .Divu_Reg_Imm), length = 3},
		{shapes = {.Reg16, .Imm16}, opcode = math_opcode(.Word, .Divu_Reg_Imm), length = 4},
		{shapes = {.Reg8, .RegPtr}, opcode = math_opcode(.Byte, .Divu_Reg_RegPtr), length = 2},
		{shapes = {.Reg16, .RegPtr}, opcode = math_opcode(.Word, .Divu_Reg_RegPtr), length = 2},
		{shapes = {.Reg8, .ImmPtr}, opcode = math_opcode(.Byte, .Divu_Reg_ImmPtr), length = 4},
		{shapes = {.Reg16, .ImmPtr}, opcode = math_opcode(.Word, .Divu_Reg_ImmPtr), length = 4},
		{
			shapes = {.Reg8, .RegPtrImmOffs},
			opcode = math_opcode(.Byte, .Divu_Reg_RegPtr_ImmOffs),
			length = 4,
		},
		{
			shapes = {.Reg16, .RegPtrImmOffs},
			opcode = math_opcode(.Word, .Divu_Reg_RegPtr_ImmOffs),
			length = 4,
		},
		{
			shapes = {.Reg8, .RegPtrRegOffs},
			opcode = math_opcode(.Byte, .Divu_Reg_RegPtr_RegOffs),
			length = 3,
		},
		{
			shapes = {.Reg16, .RegPtrRegOffs},
			opcode = math_opcode(.Word, .Divu_Reg_RegPtr_RegOffs),
			length = 3,
		},
	}

	// muls reg, reg
	MNEMONICS["muls"] = {
		{shapes = {.Reg8, .Reg8}, opcode = math_opcode(.Byte, .Muls_Reg_Reg), length = 2},
		{shapes = {.Reg16, .Reg16}, opcode = math_opcode(.Word, .Muls_Reg_Reg), length = 2},
		{shapes = {.Reg8, .Imm8}, opcode = math_opcode(.Byte, .Muls_Reg_Imm), length = 3},
		{shapes = {.Reg16, .Imm16}, opcode = math_opcode(.Word, .Muls_Reg_Imm), length = 4},
		{shapes = {.Reg8, .RegPtr}, opcode = math_opcode(.Byte, .Muls_Reg_RegPtr), length = 2},
		{shapes = {.Reg16, .RegPtr}, opcode = math_opcode(.Word, .Muls_Reg_RegPtr), length = 2},
		{shapes = {.Reg8, .ImmPtr}, opcode = math_opcode(.Byte, .Muls_Reg_ImmPtr), length = 4},
		{shapes = {.Reg16, .ImmPtr}, opcode = math_opcode(.Word, .Muls_Reg_ImmPtr), length = 4},
		{
			shapes = {.Reg8, .RegPtrImmOffs},
			opcode = math_opcode(.Byte, .Muls_Reg_RegPtr_ImmOffs),
			length = 4,
		},
		{
			shapes = {.Reg16, .RegPtrImmOffs},
			opcode = math_opcode(.Word, .Muls_Reg_RegPtr_ImmOffs),
			length = 4,
		},
		{
			shapes = {.Reg8, .RegPtrRegOffs},
			opcode = math_opcode(.Byte, .Muls_Reg_RegPtr_RegOffs),
			length = 3,
		},
		{
			shapes = {.Reg16, .RegPtrRegOffs},
			opcode = math_opcode(.Word, .Muls_Reg_RegPtr_RegOffs),
			length = 3,
		},
	}

	// divs reg, reg
	MNEMONICS["divs"] = {
		{shapes = {.Reg8, .Reg8}, opcode = math_opcode(.Byte, .Divs_Reg_Reg), length = 2},
		{shapes = {.Reg16, .Reg16}, opcode = math_opcode(.Word, .Divs_Reg_Reg), length = 2},
		{shapes = {.Reg8, .Imm8}, opcode = math_opcode(.Byte, .Divs_Reg_Imm), length = 3},
		{shapes = {.Reg16, .Imm16}, opcode = math_opcode(.Word, .Divs_Reg_Imm), length = 4},
		{shapes = {.Reg8, .RegPtr}, opcode = math_opcode(.Byte, .Divs_Reg_RegPtr), length = 2},
		{shapes = {.Reg16, .RegPtr}, opcode = math_opcode(.Word, .Divs_Reg_RegPtr), length = 2},
		{shapes = {.Reg8, .ImmPtr}, opcode = math_opcode(.Byte, .Divs_Reg_ImmPtr), length = 4},
		{shapes = {.Reg16, .ImmPtr}, opcode = math_opcode(.Word, .Divs_Reg_ImmPtr), length = 4},
		{
			shapes = {.Reg8, .RegPtrImmOffs},
			opcode = math_opcode(.Byte, .Divs_Reg_RegPtr_ImmOffs),
			length = 4,
		},
		{
			shapes = {.Reg16, .RegPtrImmOffs},
			opcode = math_opcode(.Word, .Divs_Reg_RegPtr_ImmOffs),
			length = 4,
		},
		{
			shapes = {.Reg8, .RegPtrRegOffs},
			opcode = math_opcode(.Byte, .Divs_Reg_RegPtr_RegOffs),
			length = 3,
		},
		{
			shapes = {.Reg16, .RegPtrRegOffs},
			opcode = math_opcode(.Word, .Divs_Reg_RegPtr_RegOffs),
			length = 3,
		},
	}

	// adc reg, reg
	MNEMONICS["adc"] = {
		{shapes = {.Reg8, .Reg8}, opcode = math_opcode(.Byte, .Adc_Reg_Reg), length = 2},
		{shapes = {.Reg16, .Reg16}, opcode = math_opcode(.Word, .Adc_Reg_Reg), length = 2},
		{shapes = {.Reg8, .Imm8}, opcode = math_opcode(.Byte, .Adc_Reg_Imm), length = 3},
		{shapes = {.Reg16, .Imm16}, opcode = math_opcode(.Word, .Adc_Reg_Imm), length = 4},
		{shapes = {.Reg8, .RegPtr}, opcode = math_opcode(.Byte, .Adc_Reg_RegPtr), length = 2},
		{shapes = {.Reg16, .RegPtr}, opcode = math_opcode(.Word, .Adc_Reg_RegPtr), length = 2},
		{shapes = {.Reg8, .ImmPtr}, opcode = math_opcode(.Byte, .Adc_Reg_ImmPtr), length = 4},
		{shapes = {.Reg16, .ImmPtr}, opcode = math_opcode(.Word, .Adc_Reg_ImmPtr), length = 4},
		{
			shapes = {.Reg8, .RegPtrImmOffs},
			opcode = math_opcode(.Byte, .Adc_Reg_RegPtr_ImmOffs),
			length = 4,
		},
		{
			shapes = {.Reg16, .RegPtrImmOffs},
			opcode = math_opcode(.Word, .Adc_Reg_RegPtr_ImmOffs),
			length = 4,
		},
		{
			shapes = {.Reg8, .RegPtrRegOffs},
			opcode = math_opcode(.Byte, .Adc_Reg_RegPtr_RegOffs),
			length = 3,
		},
		{
			shapes = {.Reg16, .RegPtrRegOffs},
			opcode = math_opcode(.Word, .Adc_Reg_RegPtr_RegOffs),
			length = 3,
		},
	}

	// sbc reg, reg
	MNEMONICS["sbc"] = {
		{shapes = {.Reg8, .Reg8}, opcode = math_opcode(.Byte, .Sbc_Reg_Reg), length = 2},
		{shapes = {.Reg16, .Reg16}, opcode = math_opcode(.Word, .Sbc_Reg_Reg), length = 2},
		{shapes = {.Reg8, .Imm8}, opcode = math_opcode(.Byte, .Sbc_Reg_Imm), length = 3},
		{shapes = {.Reg16, .Imm16}, opcode = math_opcode(.Word, .Sbc_Reg_Imm), length = 4},
		{shapes = {.Reg8, .RegPtr}, opcode = math_opcode(.Byte, .Sbc_Reg_RegPtr), length = 2},
		{shapes = {.Reg16, .RegPtr}, opcode = math_opcode(.Word, .Sbc_Reg_RegPtr), length = 2},
		{shapes = {.Reg8, .ImmPtr}, opcode = math_opcode(.Byte, .Sbc_Reg_ImmPtr), length = 4},
		{shapes = {.Reg16, .ImmPtr}, opcode = math_opcode(.Word, .Sbc_Reg_ImmPtr), length = 4},
		{
			shapes = {.Reg8, .RegPtrImmOffs},
			opcode = math_opcode(.Byte, .Sbc_Reg_RegPtr_ImmOffs),
			length = 4,
		},
		{
			shapes = {.Reg16, .RegPtrImmOffs},
			opcode = math_opcode(.Word, .Sbc_Reg_RegPtr_ImmOffs),
			length = 4,
		},
		{
			shapes = {.Reg8, .RegPtrRegOffs},
			opcode = math_opcode(.Byte, .Sbc_Reg_RegPtr_RegOffs),
			length = 3,
		},
		{
			shapes = {.Reg16, .RegPtrRegOffs},
			opcode = math_opcode(.Word, .Sbc_Reg_RegPtr_RegOffs),
			length = 3,
		},
	}

	// cmp reg, reg
	MNEMONICS["cmp"] = {
		{shapes = {.Reg8, .Reg8}, opcode = math_opcode(.Byte, .Cmp_Reg_Reg), length = 2},
		{shapes = {.Reg16, .Reg16}, opcode = math_opcode(.Word, .Cmp_Reg_Reg), length = 2},
		{shapes = {.Reg8, .Imm8}, opcode = math_opcode(.Byte, .Cmp_Reg_Imm), length = 3},
		{shapes = {.Reg16, .Imm16}, opcode = math_opcode(.Word, .Cmp_Reg_Imm), length = 4},
		{shapes = {.Reg8, .RegPtr}, opcode = math_opcode(.Byte, .Cmp_Reg_RegPtr), length = 2},
		{shapes = {.Reg16, .RegPtr}, opcode = math_opcode(.Word, .Cmp_Reg_RegPtr), length = 2},
		{shapes = {.Reg8, .ImmPtr}, opcode = math_opcode(.Byte, .Cmp_Reg_ImmPtr), length = 4},
		{shapes = {.Reg16, .ImmPtr}, opcode = math_opcode(.Word, .Cmp_Reg_ImmPtr), length = 4},
		{
			shapes = {.Reg8, .RegPtrImmOffs},
			opcode = math_opcode(.Byte, .Cmp_Reg_RegPtr_ImmOffs),
			length = 4,
		},
		{
			shapes = {.Reg16, .RegPtrImmOffs},
			opcode = math_opcode(.Word, .Cmp_Reg_RegPtr_ImmOffs),
			length = 4,
		},
		{
			shapes = {.Reg8, .RegPtrRegOffs},
			opcode = math_opcode(.Byte, .Cmp_Reg_RegPtr_RegOffs),
			length = 3,
		},
		{
			shapes = {.Reg16, .RegPtrRegOffs},
			opcode = math_opcode(.Word, .Cmp_Reg_RegPtr_RegOffs),
			length = 3,
		},
	}

	// inc reg
	MNEMONICS["inc"] = {
		{shapes = {.Reg8}, opcode = math_opcode(.Byte, .Inc), length = 2},
		{shapes = {.Reg16}, opcode = math_opcode(.Word, .Inc), length = 2},
	}

	// dec reg
	MNEMONICS["dec"] = {
		{shapes = {.Reg8}, opcode = math_opcode(.Byte, .Dec), length = 2},
		{shapes = {.Reg16}, opcode = math_opcode(.Word, .Dec), length = 2},
	}

	// neg reg
	MNEMONICS["neg"] = {
		{shapes = {.Reg8}, opcode = math_opcode(.Byte, .Neg), length = 2},
		{shapes = {.Reg16}, opcode = math_opcode(.Word, .Neg), length = 2},
	}

	// and reg, reg
	MNEMONICS["and"] = {
		{shapes = {.Reg8, .Reg8}, opcode = math_opcode(.Byte, .And_Reg_Reg), length = 2},
		{shapes = {.Reg16, .Reg16}, opcode = math_opcode(.Word, .And_Reg_Reg), length = 2},
		{shapes = {.Reg8, .Imm8}, opcode = math_opcode(.Byte, .And_Reg_Imm), length = 3},
		{shapes = {.Reg16, .Imm16}, opcode = math_opcode(.Word, .And_Reg_Imm), length = 4},
		{shapes = {.Reg8, .RegPtr}, opcode = math_opcode(.Byte, .And_Reg_RegPtr), length = 2},
		{shapes = {.Reg16, .RegPtr}, opcode = math_opcode(.Word, .And_Reg_RegPtr), length = 2},
		{shapes = {.Reg8, .ImmPtr}, opcode = math_opcode(.Byte, .And_Reg_ImmPtr), length = 4},
		{shapes = {.Reg16, .ImmPtr}, opcode = math_opcode(.Word, .And_Reg_ImmPtr), length = 4},
		{
			shapes = {.Reg8, .RegPtrImmOffs},
			opcode = math_opcode(.Byte, .And_Reg_RegPtr_ImmOffs),
			length = 4,
		},
		{
			shapes = {.Reg16, .RegPtrImmOffs},
			opcode = math_opcode(.Word, .And_Reg_RegPtr_ImmOffs),
			length = 4,
		},
		{
			shapes = {.Reg8, .RegPtrRegOffs},
			opcode = math_opcode(.Byte, .And_Reg_RegPtr_RegOffs),
			length = 3,
		},
		{
			shapes = {.Reg16, .RegPtrRegOffs},
			opcode = math_opcode(.Word, .And_Reg_RegPtr_RegOffs),
			length = 3,
		},
	}

	// or reg, reg
	MNEMONICS["or"] = {
		{shapes = {.Reg8, .Reg8}, opcode = math_opcode(.Byte, .Or_Reg_Reg), length = 2},
		{shapes = {.Reg16, .Reg16}, opcode = math_opcode(.Word, .Or_Reg_Reg), length = 2},
		{shapes = {.Reg8, .Imm8}, opcode = math_opcode(.Byte, .Or_Reg_Imm), length = 3},
		{shapes = {.Reg16, .Imm16}, opcode = math_opcode(.Word, .Or_Reg_Imm), length = 4},
		{shapes = {.Reg8, .RegPtr}, opcode = math_opcode(.Byte, .Or_Reg_RegPtr), length = 2},
		{shapes = {.Reg16, .RegPtr}, opcode = math_opcode(.Word, .Or_Reg_RegPtr), length = 2},
		{shapes = {.Reg8, .ImmPtr}, opcode = math_opcode(.Byte, .Or_Reg_ImmPtr), length = 4},
		{shapes = {.Reg16, .ImmPtr}, opcode = math_opcode(.Word, .Or_Reg_ImmPtr), length = 4},
		{
			shapes = {.Reg8, .RegPtrImmOffs},
			opcode = math_opcode(.Byte, .Or_Reg_RegPtr_ImmOffs),
			length = 4,
		},
		{
			shapes = {.Reg16, .RegPtrImmOffs},
			opcode = math_opcode(.Word, .Or_Reg_RegPtr_ImmOffs),
			length = 4,
		},
		{
			shapes = {.Reg8, .RegPtrRegOffs},
			opcode = math_opcode(.Byte, .Or_Reg_RegPtr_RegOffs),
			length = 3,
		},
		{
			shapes = {.Reg16, .RegPtrRegOffs},
			opcode = math_opcode(.Word, .Or_Reg_RegPtr_RegOffs),
			length = 3,
		},
	}

	// xor reg, reg
	MNEMONICS["xor"] = {
		{shapes = {.Reg8, .Reg8}, opcode = math_opcode(.Byte, .Xor_Reg_Reg), length = 2},
		{shapes = {.Reg16, .Reg16}, opcode = math_opcode(.Word, .Xor_Reg_Reg), length = 2},
		{shapes = {.Reg8, .Imm8}, opcode = math_opcode(.Byte, .Xor_Reg_Imm), length = 3},
		{shapes = {.Reg16, .Imm16}, opcode = math_opcode(.Word, .Xor_Reg_Imm), length = 4},
		{shapes = {.Reg8, .RegPtr}, opcode = math_opcode(.Byte, .Xor_Reg_RegPtr), length = 2},
		{shapes = {.Reg16, .RegPtr}, opcode = math_opcode(.Word, .Xor_Reg_RegPtr), length = 2},
		{shapes = {.Reg8, .ImmPtr}, opcode = math_opcode(.Byte, .Xor_Reg_ImmPtr), length = 4},
		{shapes = {.Reg16, .ImmPtr}, opcode = math_opcode(.Word, .Xor_Reg_ImmPtr), length = 4},
		{
			shapes = {.Reg8, .RegPtrImmOffs},
			opcode = math_opcode(.Byte, .Xor_Reg_RegPtr_ImmOffs),
			length = 4,
		},
		{
			shapes = {.Reg16, .RegPtrImmOffs},
			opcode = math_opcode(.Word, .Xor_Reg_RegPtr_ImmOffs),
			length = 4,
		},
		{
			shapes = {.Reg8, .RegPtrRegOffs},
			opcode = math_opcode(.Byte, .Xor_Reg_RegPtr_RegOffs),
			length = 3,
		},
		{
			shapes = {.Reg16, .RegPtrRegOffs},
			opcode = math_opcode(.Word, .Xor_Reg_RegPtr_RegOffs),
			length = 3,
		},
	}

	// bt reg, reg
	MNEMONICS["bt"] = {
		{shapes = {.Reg8, .Reg8}, opcode = math_opcode(.Byte, .Bt_Reg_Reg), length = 2},
		{shapes = {.Reg16, .Reg16}, opcode = math_opcode(.Word, .Bt_Reg_Reg), length = 2},
		{shapes = {.Reg8, .Imm8}, opcode = math_opcode(.Byte, .Bt_Reg_Imm), length = 3},
		{shapes = {.Reg16, .Imm16}, opcode = math_opcode(.Word, .Bt_Reg_Imm), length = 4},
		{shapes = {.Reg8, .RegPtr}, opcode = math_opcode(.Byte, .Bt_Reg_RegPtr), length = 2},
		{shapes = {.Reg16, .RegPtr}, opcode = math_opcode(.Word, .Bt_Reg_RegPtr), length = 2},
		{shapes = {.Reg8, .ImmPtr}, opcode = math_opcode(.Byte, .Bt_Reg_ImmPtr), length = 4},
		{shapes = {.Reg16, .ImmPtr}, opcode = math_opcode(.Word, .Bt_Reg_ImmPtr), length = 4},
		{
			shapes = {.Reg8, .RegPtrImmOffs},
			opcode = math_opcode(.Byte, .Bt_Reg_RegPtr_ImmOffs),
			length = 4,
		},
		{
			shapes = {.Reg16, .RegPtrImmOffs},
			opcode = math_opcode(.Word, .Bt_Reg_RegPtr_ImmOffs),
			length = 4,
		},
		{
			shapes = {.Reg8, .RegPtrRegOffs},
			opcode = math_opcode(.Byte, .Bt_Reg_RegPtr_RegOffs),
			length = 3,
		},
		{
			shapes = {.Reg16, .RegPtrRegOffs},
			opcode = math_opcode(.Word, .Bt_Reg_RegPtr_RegOffs),
			length = 3,
		},
	}

	// not reg
	MNEMONICS["not"] = {
		{shapes = {.Reg8}, opcode = math_opcode(.Byte, .Not), length = 2},
		{shapes = {.Reg16}, opcode = math_opcode(.Word, .Not), length = 2},
	}

	// lsl reg, reg
	MNEMONICS["lsl"] = {
		{shapes = {.Reg8, .Reg8}, opcode = math_opcode(.Byte, .Lsl_Reg_Reg), length = 2},
		{shapes = {.Reg16, .Reg16}, opcode = math_opcode(.Word, .Lsl_Reg_Reg), length = 2},
		{shapes = {.Reg8, .Imm8}, opcode = math_opcode(.Byte, .Lsl_Reg_Imm), length = 3},
		{shapes = {.Reg16, .Imm8}, opcode = math_opcode(.Word, .Lsl_Reg_Imm), length = 3},
	}

	// lsr reg, reg
	MNEMONICS["lsr"] = {
		{shapes = {.Reg8, .Reg8}, opcode = math_opcode(.Byte, .Lsr_Reg_Reg), length = 2},
		{shapes = {.Reg16, .Reg16}, opcode = math_opcode(.Word, .Lsr_Reg_Reg), length = 2},
		{shapes = {.Reg8, .Imm8}, opcode = math_opcode(.Byte, .Lsr_Reg_Imm), length = 3},
		{shapes = {.Reg16, .Imm8}, opcode = math_opcode(.Word, .Lsr_Reg_Imm), length = 3},
	}

	// asr reg, reg
	MNEMONICS["asr"] = {
		{shapes = {.Reg8, .Reg8}, opcode = math_opcode(.Byte, .Asr_Reg_Reg), length = 2},
		{shapes = {.Reg16, .Reg16}, opcode = math_opcode(.Word, .Asr_Reg_Reg), length = 2},
		{shapes = {.Reg8, .Imm8}, opcode = math_opcode(.Byte, .Asr_Reg_Imm), length = 3},
		{shapes = {.Reg16, .Imm8}, opcode = math_opcode(.Word, .Asr_Reg_Imm), length = 3},
	}

	// rol reg, reg
	MNEMONICS["rol"] = {
		{shapes = {.Reg8, .Reg8}, opcode = math_opcode(.Byte, .Rol_Reg_Reg), length = 2},
		{shapes = {.Reg16, .Reg16}, opcode = math_opcode(.Word, .Rol_Reg_Reg), length = 2},
		{shapes = {.Reg8, .Imm8}, opcode = math_opcode(.Byte, .Rol_Reg_Imm), length = 3},
		{shapes = {.Reg16, .Imm8}, opcode = math_opcode(.Word, .Rol_Reg_Imm), length = 3},
	}

	// ror reg, reg
	MNEMONICS["ror"] = {
		{shapes = {.Reg8, .Reg8}, opcode = math_opcode(.Byte, .Ror_Reg_Reg), length = 2},
		{shapes = {.Reg16, .Reg16}, opcode = math_opcode(.Word, .Ror_Reg_Reg), length = 2},
		{shapes = {.Reg8, .Imm8}, opcode = math_opcode(.Byte, .Ror_Reg_Imm), length = 3},
		{shapes = {.Reg16, .Imm8}, opcode = math_opcode(.Word, .Ror_Reg_Imm), length = 3},
	}

	// rcl reg, reg
	MNEMONICS["rcl"] = {
		{shapes = {.Reg8, .Reg8}, opcode = math_opcode(.Byte, .Rcl_Reg_Reg), length = 2},
		{shapes = {.Reg16, .Reg16}, opcode = math_opcode(.Word, .Rcl_Reg_Reg), length = 2},
		{shapes = {.Reg8, .Imm8}, opcode = math_opcode(.Byte, .Rcl_Reg_Imm), length = 3},
		{shapes = {.Reg16, .Imm8}, opcode = math_opcode(.Word, .Rcl_Reg_Imm), length = 3},
	}

	// rcr reg, reg
	MNEMONICS["rcr"] = {
		{shapes = {.Reg8, .Reg8}, opcode = math_opcode(.Byte, .Rcr_Reg_Reg), length = 2},
		{shapes = {.Reg16, .Reg16}, opcode = math_opcode(.Word, .Rcr_Reg_Reg), length = 2},
		{shapes = {.Reg8, .Imm8}, opcode = math_opcode(.Byte, .Rcr_Reg_Imm), length = 3},
		{shapes = {.Reg16, .Imm8}, opcode = math_opcode(.Word, .Rcr_Reg_Imm), length = 3},
	}

	// add.l reg16:reg16, reg16:reg16
	MNEMONICS["add.l"] = {
		{shapes = {.PairBare, .PairBare}, opcode = math_opcode(.Word, .Add_L_RegPair), length = 3},
		{shapes = {.PairBare, .Imm32}, opcode = math_opcode(.Word, .Add_L_Imm32), length = 6},
	}

	// sub.l reg16:reg16, reg16:reg16
	MNEMONICS["sub.l"] = {
		{shapes = {.PairBare, .PairBare}, opcode = math_opcode(.Word, .Sub_L_RegPair), length = 3},
		{shapes = {.PairBare, .Imm32}, opcode = math_opcode(.Word, .Sub_L_Imm32), length = 6},
	}

	// cmp.l reg16:reg16, reg16:reg16
	MNEMONICS["cmp.l"] = {
		{shapes = {.PairBare, .PairBare}, opcode = math_opcode(.Word, .Cmp_L_RegPair), length = 3},
		{shapes = {.PairBare, .Imm32}, opcode = math_opcode(.Word, .Cmp_L_Imm32), length = 6},
	}
}

@(private = "file")
define_flow_ops :: #force_inline proc() {
	// jsr imm16
	MNEMONICS["jsr"] = {
		{shapes = {.Imm16}, opcode = flow_opcode(.Word, .Jsr_Imm), length = 4},
		{shapes = {.Symbol}, opcode = flow_opcode(.Word, .Jsr_Imm), length = 4},
		{shapes = {.Reg16}, opcode = flow_opcode(.Word, .Jsr_Reg), length = 2},
	}

	// jmp imm16
	MNEMONICS["jmp"] = {
		{shapes = {.Imm16}, opcode = flow_opcode(.Word, .Jmp_Imm), length = 4},
		{shapes = {.Symbol}, opcode = flow_opcode(.Word, .Jmp_Imm), length = 4},
		{shapes = {.Reg16}, opcode = flow_opcode(.Word, .Jmp_Reg), length = 2},
	}

	// rts
	MNEMONICS["rts"] = {{shapes = {}, opcode = flow_opcode(.Word, .Rts), length = 2}}

	// rti
	MNEMONICS["rti"] = {{shapes = {}, opcode = flow_opcode(.Word, .Rti), length = 2}}

	// rtf
	MNEMONICS["rtf"] = {{shapes = {}, opcode = flow_opcode(.Word, .Rtf), length = 2}}

	// jz simm
	MNEMONICS["jz"] = {
		{shapes = {.Imm8}, opcode = flow_opcode(.Byte, .Jz), length = 3},
		{shapes = {.Symbol}, opcode = flow_opcode(.Byte, .Jz), length = 3},
		{shapes = {.Imm16}, opcode = flow_opcode(.Word, .Jz), length = 4},
		{shapes = {.Symbol}, opcode = flow_opcode(.Word, .Jz), length = 4},
	}

	// jnz simm
	MNEMONICS["jnz"] = {
		{shapes = {.Imm8}, opcode = flow_opcode(.Byte, .Jnz), length = 3},
		{shapes = {.Symbol}, opcode = flow_opcode(.Byte, .Jnz), length = 3},
		{shapes = {.Imm16}, opcode = flow_opcode(.Word, .Jnz), length = 4},
		{shapes = {.Symbol}, opcode = flow_opcode(.Word, .Jnz), length = 4},
	}

	// jc simm
	MNEMONICS["jc"] = {
		{shapes = {.Imm8}, opcode = flow_opcode(.Byte, .Jc), length = 3},
		{shapes = {.Symbol}, opcode = flow_opcode(.Byte, .Jc), length = 3},
		{shapes = {.Imm16}, opcode = flow_opcode(.Word, .Jc), length = 4},
		{shapes = {.Symbol}, opcode = flow_opcode(.Word, .Jc), length = 4},
	}

	// jnc simm
	MNEMONICS["jnc"] = {
		{shapes = {.Imm8}, opcode = flow_opcode(.Byte, .Jnc), length = 3},
		{shapes = {.Symbol}, opcode = flow_opcode(.Byte, .Jnc), length = 3},
		{shapes = {.Imm16}, opcode = flow_opcode(.Word, .Jnc), length = 4},
		{shapes = {.Symbol}, opcode = flow_opcode(.Word, .Jnc), length = 4},
	}

	// jmi simm
	MNEMONICS["jmi"] = {
		{shapes = {.Imm8}, opcode = flow_opcode(.Byte, .Jmi), length = 3},
		{shapes = {.Symbol}, opcode = flow_opcode(.Byte, .Jmi), length = 3},
		{shapes = {.Imm16}, opcode = flow_opcode(.Word, .Jmi), length = 4},
		{shapes = {.Symbol}, opcode = flow_opcode(.Word, .Jmi), length = 4},
	}

	// jpl simm
	MNEMONICS["jpl"] = {
		{shapes = {.Imm8}, opcode = flow_opcode(.Byte, .Jpl), length = 3},
		{shapes = {.Symbol}, opcode = flow_opcode(.Byte, .Jpl), length = 3},
		{shapes = {.Imm16}, opcode = flow_opcode(.Word, .Jpl), length = 4},
		{shapes = {.Symbol}, opcode = flow_opcode(.Word, .Jpl), length = 4},
	}

	// jv simm
	MNEMONICS["jv"] = {
		{shapes = {.Imm8}, opcode = flow_opcode(.Byte, .Jv), length = 3},
		{shapes = {.Symbol}, opcode = flow_opcode(.Byte, .Jv), length = 3},
		{shapes = {.Imm16}, opcode = flow_opcode(.Word, .Jv), length = 4},
		{shapes = {.Symbol}, opcode = flow_opcode(.Word, .Jv), length = 4},
	}

	// jnv simm
	MNEMONICS["jnv"] = {
		{shapes = {.Imm8}, opcode = flow_opcode(.Byte, .Jnv), length = 3},
		{shapes = {.Symbol}, opcode = flow_opcode(.Byte, .Jnv), length = 3},
		{shapes = {.Imm16}, opcode = flow_opcode(.Word, .Jnv), length = 4},
		{shapes = {.Symbol}, opcode = flow_opcode(.Word, .Jnv), length = 4},
	}

	// jges simm
	MNEMONICS["jges"] = {
		{shapes = {.Imm8}, opcode = flow_opcode(.Byte, .Jges), length = 3},
		{shapes = {.Symbol}, opcode = flow_opcode(.Byte, .Jges), length = 3},
		{shapes = {.Imm16}, opcode = flow_opcode(.Word, .Jges), length = 4},
		{shapes = {.Symbol}, opcode = flow_opcode(.Word, .Jges), length = 4},
	}

	// jgts simm
	MNEMONICS["jgts"] = {
		{shapes = {.Imm8}, opcode = flow_opcode(.Byte, .Jgts), length = 3},
		{shapes = {.Symbol}, opcode = flow_opcode(.Byte, .Jgts), length = 3},
		{shapes = {.Imm16}, opcode = flow_opcode(.Word, .Jgts), length = 4},
		{shapes = {.Symbol}, opcode = flow_opcode(.Word, .Jgts), length = 4},
	}

	// jles simm
	MNEMONICS["jles"] = {
		{shapes = {.Imm8}, opcode = flow_opcode(.Byte, .Jles), length = 3},
		{shapes = {.Symbol}, opcode = flow_opcode(.Byte, .Jles), length = 3},
		{shapes = {.Imm16}, opcode = flow_opcode(.Word, .Jles), length = 4},
		{shapes = {.Symbol}, opcode = flow_opcode(.Word, .Jles), length = 4},
	}

	// jlts simm
	MNEMONICS["jlts"] = {
		{shapes = {.Imm8}, opcode = flow_opcode(.Byte, .Jlts), length = 3},
		{shapes = {.Symbol}, opcode = flow_opcode(.Byte, .Jlts), length = 3},
		{shapes = {.Imm16}, opcode = flow_opcode(.Word, .Jlts), length = 4},
		{shapes = {.Symbol}, opcode = flow_opcode(.Word, .Jlts), length = 4},
	}

	// jgtu simm
	MNEMONICS["jgtu"] = {
		{shapes = {.Imm8}, opcode = flow_opcode(.Byte, .Jgtu), length = 3},
		{shapes = {.Symbol}, opcode = flow_opcode(.Byte, .Jgtu), length = 3},
		{shapes = {.Imm16}, opcode = flow_opcode(.Word, .Jgtu), length = 4},
		{shapes = {.Symbol}, opcode = flow_opcode(.Word, .Jgtu), length = 4},
	}

	// jleu simm
	MNEMONICS["jleu"] = {
		{shapes = {.Imm8}, opcode = flow_opcode(.Byte, .Jleu), length = 3},
		{shapes = {.Symbol}, opcode = flow_opcode(.Byte, .Jleu), length = 3},
		{shapes = {.Imm16}, opcode = flow_opcode(.Word, .Jleu), length = 4},
		{shapes = {.Symbol}, opcode = flow_opcode(.Word, .Jleu), length = 4},
	}

	// djnz reg, simm
	MNEMONICS["djnz"] = {
		{shapes = {.Reg8, .Imm8}, opcode = flow_opcode(.Byte, .Djnz), length = 3},
		{shapes = {.Reg8, .Symbol}, opcode = flow_opcode(.Byte, .Djnz), length = 3},
		{shapes = {.Reg16, .Imm16}, opcode = flow_opcode(.Word, .Djnz), length = 4},
		{shapes = {.Reg16, .Symbol}, opcode = flow_opcode(.Word, .Djnz), length = 4},
	}

	// jsr.l imm24
	MNEMONICS["jsr.l"] = {
		{shapes = {.Imm24}, opcode = flow_opcode(.Word, .Jsr_L_Imm), length = 5},
		{shapes = {.Symbol}, opcode = flow_opcode(.Word, .Jsr_L_Imm), length = 5},
		{shapes = {.PairBare}, opcode = flow_opcode(.Word, .Jsr_L_Regpair), length = 2},
	}

	// jmp.l imm24
	MNEMONICS["jmp.l"] = {
		{shapes = {.Imm24}, opcode = flow_opcode(.Word, .Jmp_L_Imm), length = 5},
		{shapes = {.Symbol}, opcode = flow_opcode(.Word, .Jmp_L_Imm), length = 5},
		{shapes = {.PairBare}, opcode = flow_opcode(.Word, .Jmp_L_Regpair), length = 2},
	}

	// rts.l
	MNEMONICS["rts.l"] = {{shapes = {}, opcode = flow_opcode(.Word, .Rts_L), length = 2}}

	MNEMONICS["jltu"] = alias_of("jc")
	MNEMONICS["jgeu"] = alias_of("jnc")
}
