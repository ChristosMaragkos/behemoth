package execution

import "../memory"

cpu_fetch_instruction :: proc(cpu: ^Cpu) -> Instruction {
	addr := memory.calculate_address(cpu.pp, cpu.pc)
	cpu.pc_delta = 0
	cpu_advance_pc(cpu, size_of(u16))
	return Instruction(cpu_read_word(cpu, addr))
}

cpu_decode_execute :: proc(cpu: ^Cpu, instr: Instruction) {
	if cpu.halted do return

	cpu.cycle_delta += 1

	switch instr.type {
		case .Misc:
			switch MiscOpcodes(instr.opcode) {
				case .Nop:
					exec_nop(cpu)
				case .Wfi:
					exec_wfi(cpu)
				case .Mov:
					exec_mov(instr.size, instr.reg1, instr.reg2, cpu)
				case .Cbw:
					exec_cbw(instr.reg1, cpu)
				case .Zxt:
					exec_zxt(instr.reg1, cpu)
				case .Xchg:
					exec_xchg(instr.size, instr.reg1, instr.reg2, cpu)
				case .Swp:
					exec_swp(instr.reg1, cpu)
				case .Mfhi:
					exec_mfhi(instr.size, instr.reg1, cpu)
				case .Mthi:
					exec_mthi(instr.size, instr.reg1, cpu)
				case .Mfpp:
					exec_mfpp(instr.reg1, cpu)
				case .Mtpp:
					exec_mtpp(instr.reg1, cpu)
				case .Mfdp:
					exec_mfdp(instr.reg1, cpu)
				case .Mtdp:
					exec_mtdp(instr.reg1, cpu)
				case .Swi_Imm:
					exec_swi_imm(cpu)
				case .Swi_Reg:
					exec_swi_reg(instr.reg1, cpu)
				case:
					cpu_trigger_interrupt(cpu, INVALID_OPCODE_VEC_IDX, true)
			}
		case .Memory:
			switch MemoryOpcodes(instr.opcode) {
				case .Ld_Reg_Imm:
					exec_ld_reg_imm(instr.size, instr.reg1, cpu)
				case .Ld_Reg_RegPtr:
					exec_ld_reg_regptr(instr.size, instr.reg1, instr.reg2, cpu)
				case .Ld_Reg_ImmPtr:
					exec_ld_reg_immptr(instr.size, instr.reg1, cpu)
				case .Ld_Reg_ImmOffs:
					exec_ld_reg_immoffs(instr.size, instr.reg1, instr.reg2, cpu)
				case .Ld_Reg_RegOffs:
					exec_ld_reg_regoffs(instr.size, instr.reg1, instr.reg2, cpu)
				case .Ld_Reg_RegPtr_PostInc:
					exec_ld_reg_regptr_postinc(instr.size, instr.reg1, instr.reg2, cpu)
				case .Ld_Reg_RegPtr_PreInc:
					exec_ld_reg_regptr_preinc(instr.size, instr.reg1, instr.reg2, cpu)
				case .Ld_Reg_RegPtr_PostDec:
					exec_ld_reg_regptr_postdec(instr.size, instr.reg1, instr.reg2, cpu)
				case .Ld_Reg_RegPtr_PreDec:
					exec_ld_reg_regptr_predec(instr.size, instr.reg1, instr.reg2, cpu)
				case .St_Reg_RegPtr:
					exec_st_reg_regptr(instr.size, instr.reg1, instr.reg2, cpu)
				case .St_Reg_ImmPtr:
					exec_st_reg_immptr(instr.size, instr.reg1, cpu)
				case .St_Reg_ImmOffs:
					exec_st_reg_immoffs(instr.size, instr.reg1, instr.reg2, cpu)
				case .St_Reg_RegOffs:
					exec_st_reg_regoffs(instr.size, instr.reg1, instr.reg2, cpu)
				case .St_Reg_RegPtr_PostInc:
					exec_st_reg_regptr_postinc(instr.size, instr.reg1, instr.reg2, cpu)
				case .St_Reg_RegPtr_PreInc:
					exec_st_reg_regptr_preinc(instr.size, instr.reg1, instr.reg2, cpu)
				case .St_Reg_RegPtr_PostDec:
					exec_st_reg_regptr_postdec(instr.size, instr.reg1, instr.reg2, cpu)
				case .St_Reg_RegPtr_PreDec:
					exec_st_reg_regptr_predec(instr.size, instr.reg1, instr.reg2, cpu)
				case .Push:
					exec_push(instr.reg1, cpu)
				case .Pop:
					exec_pop(instr.reg1, cpu)
				case .Shove:
					exec_shove(cpu)
			}
		case .Math:
		case .ControlFlow:
	}
}
