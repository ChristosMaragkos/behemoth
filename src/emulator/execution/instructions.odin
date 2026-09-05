package behemoth

SizeMode :: enum u8 {
	Word = 0,
	Byte = 1,
}

InstructionType :: enum u8 {
	Misc        = 0,
	Memory      = 1,
	Math        = 2,
	ControlFlow = 3,
}

Instruction :: bit_field u16 {
	opcode: u16             | 7,
	type:   InstructionType | 2,
	size:   SizeMode        | 1,
	reg1:   u8              | 3,
	reg2:   u8              | 3,
}

AddressingMode :: enum {
	// Load/Store specific
	Reg_RegPostInc,
	Reg_RegPreInc,
	Reg_RegPostDec,
	Reg_RegPreDec,
	// Regular modes
	Reg_Reg,
	Reg_Imm,
	Reg_RegPtr,
	Reg_ImmPtr,
	Reg_RegPtr_ImmOffs,
	Reg_RegPtr_RegOffs,
	// 32-bit
	Pair32_Pair32,
	Pair32_Imm32,
	// 24-bit
	Reg_ImmPtr24,
	Reg_ImmPtr24_Reg16Offs,
	Reg_Pair24,
	Reg_Pair24_ImmOffs,
	Reg_Pair24_Reg16Offs,
}
