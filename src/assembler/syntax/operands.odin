package syntax

import "../cpu"

Expression :: struct {
	val:    i64,
	symbol: string,
	type:   enum u8 {
		Symbol,
		Integer,
	},
}

Op_Reg :: struct {
	reg: cpu.RegInfo,
}

Op_Reg_Pair :: struct {
	hi: cpu.RegInfo,
	lo: cpu.RegInfo,
}

Op_Imm :: struct {
	expr: Expression,
}

DerefMode :: enum {
	Reg,
	Imm,
	Reg_ImmOffset,
	Reg_RegOffset,
	Reg_PreInc,
	Reg_PostInc,
	Reg_PreDec,
	Reg_PostDec,
	Reg_Pair,
	Reg_Pair_ImmOffset,
	Reg_Pair_RegOffset,
	Imm_Long_RegOffset, // [ptr24 + reg16]
}

Op_Deref :: struct {
	mode:     DerefMode,
	base_hi:  cpu.RegInfo,
	base_lo:  cpu.RegInfo,
	reg_offs: cpu.RegInfo,
	imm_offs: Expression,
}

ResolvedOperand :: union {
	Op_Reg,
	Op_Reg_Pair,
	Op_Imm,
	Op_Deref,
}

RawOperand :: distinct []Token

OperandSlot :: union {
	RawOperand,
	ResolvedOperand,
}

LabelDef :: struct {
	label: Token, // contains line and filename info AND the label name for better error reporting
}

Directive :: struct {
	directive: Token,
	operands:  [dynamic]OperandSlot, // integers and strings mostly; dynamic because a directive like .db or .dw might expect more than the max of 3 our opcodes expect
}

Mnemonic :: struct {
	mnemonic: Token,
	operands: [3]OperandSlot, // The instructions with the most operands are blkcp and blkmv (reg8:reg16, reg8:reg16, reg16). Our cap is 3. Storing inline is fine.
	amount:   uint,
}

Statement :: union {
	LabelDef,
	Directive,
	Mnemonic,
}
