package execution

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
	Sec,
	Clc,
	Sez,
	Clz,
	Sen,
	Cln,
	Sev,
	Clv,
	Sei,
	Cli,
	Mffr,
	Mtfr,
}

exec_nop :: proc(cpu: ^Cpu) {
	// According to all known laws of aviation,
	// there is no way a bee should be able to fly.
}

exec_wfi :: proc(cpu: ^Cpu) {
	if !cpu.halted {
		cpu.halted = true
		return
	}
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

exec_sec :: proc(cpu: ^Cpu) {
	cpu.flags += {.Carry}
}

exec_clc :: proc(cpu: ^Cpu) {
	cpu.flags -= {.Carry}
}

exec_sez :: proc(cpu: ^Cpu) {
	cpu.flags += {.Zero}
}

exec_clz :: proc(cpu: ^Cpu) {
	cpu.flags -= {.Zero}
}

exec_sen :: proc(cpu: ^Cpu) {
	cpu.flags += {.Negative}
}

exec_cln :: proc(cpu: ^Cpu) {
	cpu.flags -= {.Negative}
}

exec_sev :: proc(cpu: ^Cpu) {
	cpu.flags += {.Overflow}
}

exec_clv :: proc(cpu: ^Cpu) {
	cpu.flags -= {.Overflow}
}

exec_sei :: proc(cpu: ^Cpu) {
	cpu.flags += {.IgnoreInterrupts}
}

exec_cli :: proc(cpu: ^Cpu) {
	cpu.flags -= {.IgnoreInterrupts}
}

exec_mffr :: proc(size: SizeMode, reg1: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)

	if size == .Word do r1.full = transmute(u16)cpu.flags
	else do r1.low = u8(transmute(u16)cpu.flags)
}

exec_mtfr :: proc(size: SizeMode, reg1: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)

	if size == .Word {
		cpu.flags = transmute(FlagRegister)r1.full
	} else {
		flags_new := transmute(u16)cpu.flags
		flags_new &= 0xFF00
		flags_new |= u16(r1.low)
		cpu.flags = transmute(FlagRegister)flags_new
	}
}
