package execution

import "../memory"

FlowOps :: enum u8 {
	Jsr_Imm,
	Jsr_Reg,
	Jmp_Imm,
	Jmp_Reg,
	Rts,
	Rti,
	Rtf,
	Jz,
	Jnz,
	Jc,
	Jnc,
	Jmi,
	Jpl,
	Jv,
	Jnv,
	Jges,
	Jgts,
	Jles,
	Jlts,
	Jgtu,
	Jleu,
	Djnz,
	Jsr_L_Imm,
	Jsr_L_Regpair,
	Jmp_L_Imm,
	Jmp_L_Regpair,
	Rts_L,
}

exec_jsr_imm :: proc(cpu: ^Cpu) {
	imm := cpu_pc_fetch_word(cpu)
	cpu_push(cpu, .PC)
	cpu.pc = imm
	cpu.cycle_delta += 1
}

exec_jsr_reg :: proc(reg1: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	cpu_push(cpu, .PC)
	cpu.pc = r1.full
	cpu.cycle_delta += 1
}

exec_jmp_imm :: proc(cpu: ^Cpu) {
	imm := cpu_pc_fetch_word(cpu)
	cpu.pc = imm
	cpu.cycle_delta += 1
}

exec_jmp_reg :: proc(reg1: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	cpu.pc = r1.full
	cpu.cycle_delta += 1
}

exec_rts :: proc(cpu: ^Cpu) {
	cpu_pop(cpu, .PC)
}

exec_rti :: proc(cpu: ^Cpu) {
	cpu_pop(cpu, .PC)
	cpu_pop(cpu, .PP)
	cpu_pop(cpu, .Flags)
}

exec_rtf :: proc(cpu: ^Cpu) {
	base_addr := memory.calculate_address(memory.IVT_PAGE, 0x0300)
	cpu.flags = transmute(FlagRegister)cpu_read_word(cpu, base_addr)
	cpu.pp = cpu_read_byte(cpu, base_addr + 2)
	cpu.pc = cpu_read_word(cpu, base_addr + 3)
}

@(private = "file")
exec_relative_branch :: proc(size: SizeMode, condition: bool, cpu: ^Cpu) {
	offs: i16
	cpu.cycle_delta += 1

	if size == .Word {
		offs = i16(cpu_pc_fetch_word(cpu))
	} else {
		offs = i16(i8(cpu_pc_fetch_byte(cpu)))
	}

	if condition {
		cpu_advance_pc(cpu, offs)
		cpu.cycle_delta += 1
	}
}

exec_jz :: #force_inline proc(size: SizeMode, cpu: ^Cpu) {
	exec_relative_branch(size, .Zero in cpu.flags, cpu)
}

exec_jnz :: #force_inline proc(size: SizeMode, cpu: ^Cpu) {
	exec_relative_branch(size, .Zero not_in cpu.flags, cpu)
}

exec_jc :: #force_inline proc(size: SizeMode, cpu: ^Cpu) {
	exec_relative_branch(size, .Carry in cpu.flags, cpu)
}

exec_jnc :: #force_inline proc(size: SizeMode, cpu: ^Cpu) {
	exec_relative_branch(size, .Carry not_in cpu.flags, cpu)
}

exec_jmi :: #force_inline proc(size: SizeMode, cpu: ^Cpu) {
	exec_relative_branch(size, .Negative in cpu.flags, cpu)
}

exec_jpl :: #force_inline proc(size: SizeMode, cpu: ^Cpu) {
	exec_relative_branch(size, .Negative not_in cpu.flags, cpu)
}

exec_jv :: #force_inline proc(size: SizeMode, cpu: ^Cpu) {
	exec_relative_branch(size, .Overflow in cpu.flags, cpu)
}

exec_jnv :: #force_inline proc(size: SizeMode, cpu: ^Cpu) {
	exec_relative_branch(size, .Overflow not_in cpu.flags, cpu)
}

exec_jges :: #force_inline proc(size: SizeMode, cpu: ^Cpu) {
	cond := .Overflow in cpu.flags == .Negative in cpu.flags
	exec_relative_branch(size, cond, cpu)
}

exec_jgts :: #force_inline proc(size: SizeMode, cpu: ^Cpu) {
	cond := .Zero not_in cpu.flags && (.Overflow in cpu.flags == .Negative in cpu.flags)
	exec_relative_branch(size, cond, cpu)
}

exec_jles :: #force_inline proc(size: SizeMode, cpu: ^Cpu) {
	cond := .Zero in cpu.flags || (.Overflow in cpu.flags != .Negative in cpu.flags)
	exec_relative_branch(size, cond, cpu)
}

exec_jlts :: #force_inline proc(size: SizeMode, cpu: ^Cpu) {
	cond := .Overflow in cpu.flags != .Negative in cpu.flags
	exec_relative_branch(size, cond, cpu)
}

exec_jgtu :: #force_inline proc(size: SizeMode, cpu: ^Cpu) {
	cond := FlagRegister({.Carry, .Zero}) & cpu.flags == {}
	exec_relative_branch(size, cond, cpu)
}

exec_jleu :: #force_inline proc(size: SizeMode, cpu: ^Cpu) {
	cond := .Carry in cpu.flags || .Zero in cpu.flags
	exec_relative_branch(size, cond, cpu)
}

exec_djnz :: #force_inline proc(size: SizeMode, reg1: u8, cpu: ^Cpu) {
	exec_dec(size, reg1, cpu)
	exec_jnz(size, cpu)
}

exec_jsr_l_imm :: proc(cpu: ^Cpu) {
	offset := cpu_pc_fetch_word(cpu)
	page := cpu_pc_fetch_byte(cpu) // little-endian

	cpu_push(cpu, .PP)
	cpu_push(cpu, .PC)
	cpu.pp = page
	cpu.pc = offset

	cpu.cycle_delta += 2
}

exec_jsr_l_regpair :: proc(reg1, reg2: u8, cpu: ^Cpu) {
	page := cpu_get_reg(cpu, reg1).low
	offset := cpu_get_reg(cpu, reg2).full

	cpu_push(cpu, .PP)
	cpu_push(cpu, .PC)
	cpu.pp = page
	cpu.pc = offset

	cpu.cycle_delta += 2
}

exec_jmp_l_imm :: proc(cpu: ^Cpu) {
	offset := cpu_pc_fetch_word(cpu)
	page := cpu_pc_fetch_byte(cpu) // little-endian

	cpu.pp = page
	cpu.pc = offset

	cpu.cycle_delta += 2
}

exec_jmp_l_regpair :: proc(reg1, reg2: u8, cpu: ^Cpu) {
	page := cpu_get_reg(cpu, reg1).low
	offset := cpu_get_reg(cpu, reg2).full

	cpu.pp = page
	cpu.pc = offset

	cpu.cycle_delta += 2
}

exec_rts_l :: proc(cpu: ^Cpu) {
	cpu_pop(cpu, .PC)
	cpu_pop(cpu, .PP)
}
