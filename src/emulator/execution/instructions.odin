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

MiscOpcodes :: enum u8 {
	Nop,
	Wfi,
	Mov,
	Cbw,
	Zxt,
	Xchg,
	Swp,
	Mfhi,
	Mthi,
	Mfpp,
	Mtpp,
	Mfdp,
	Mtdp,
	Swi_Imm,
	Swi_Reg,
}

exec_nop :: proc(cpu: ^Cpu) {
	cpu.cycle_delta += 1
}

exec_wfi :: proc(cpu: ^Cpu) {
	if !cpu.halted {
		cpu.halted = true
		return
	}

	// FIXME: This will cause save file loss if we *ever* somehow get here, so fix ASAP.
	// The emulator will need to handle exceptions like these gracefully.
	panic("Instruction 'wfi' was executed while the CPU was halted. How did we get here?")
}

exec_mov :: proc(size: SizeMode, reg1, reg2: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)

	switch size {
		case .Word:
			r1.full = r2.full
		case .Byte:
			r1.low = r2.low
	}
}

exec_cbw :: proc(reg1: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r1.full = u16(i16(i8(r1.low)))
}

exec_zxt :: proc(reg1: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r1.full = u16(r1.low)
}

exec_xchg :: proc(size: SizeMode, reg1, reg2: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)

	switch size {
		case .Word:
			r1.full, r2.full = r2.full, r1.full
		case .Byte:
			r1.low, r2.low = r2.low, r1.low
	}
}

exec_swp :: proc(reg1: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)

	r1.low, r1.high = r1.high, r1.low
}

exec_mfhi :: proc(size: SizeMode, reg1: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)

	switch size {
		case .Word:
			r1.full = cpu.hi.full
		case .Byte:
			r1.low = cpu.hi.low
	}
}

exec_mthi :: proc(size: SizeMode, reg1: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)

	switch size {
		case .Word:
			cpu.hi.full = r1.full
		case .Byte:
			cpu.hi.low = r1.low
	}
}

exec_mfpp :: proc(reg1: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r1.low = cpu.pp
}

exec_mtpp :: proc(reg1: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	cpu.pp = r1.low
}

exec_mfdp :: proc(reg1: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r1.low = cpu.dp
}

exec_mtdp :: proc(reg1: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	cpu.dp = r1.low
}

exec_swi_imm :: proc(cpu: ^Cpu) {
	imm8 := cpu_pc_fetch_byte(cpu)

	idx := (imm8 & 0b1111111) + 128
	cpu_trigger_interrupt(cpu, idx, false)
}

exec_swi_reg :: proc(reg1: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)

	idx := (r1.low & 0b1111111) + 128
	cpu_trigger_interrupt(cpu, idx, false)
}

MemoryOpcodes :: enum u8 {
	Ld_Reg_Imm,
	Ld_Reg_RegPtr,
	Ld_Reg_ImmPtr,
}

exec_ld_reg_imm :: proc(size: SizeMode, reg1: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)

	switch size {
		case .Word:
			val := cpu_pc_fetch_word(cpu)
			r1.full = val
		case .Byte:
			val := cpu_pc_fetch_byte(cpu)
			r1.low = val
	}
}

exec_ld_reg_regptr :: proc(size: SizeMode, reg1, reg2: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)

	switch size {
		case .Word:
			val := cpu_dp_fetch_word(cpu, r2.full)
			r1.full = val
		case .Byte:
			val := cpu_dp_fetch_byte(cpu, r2.full)
			r1.low = val
	}
}

exec_ld_reg_immptr :: proc(size: SizeMode, reg1: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	immptr := cpu_pc_fetch_word(cpu)

	switch size {
		case .Word:
			val := cpu_dp_fetch_word(cpu, immptr)
			r1.full = val
		case .Byte:
			val := cpu_dp_fetch_byte(cpu, immptr)
			r1.low = val
	}
}
