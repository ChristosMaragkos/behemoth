package execution

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
