package execution

cpu_fetch_instruction :: proc(cpu: ^Cpu) -> Instruction {
	cpu.pc_delta = 0
	return Instruction(cpu_pc_fetch_word(cpu))
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
				case .Ld_L_Ptr24:
					exec_ld_l_ptr24(instr.size, instr.reg1, cpu)
				case .Ld_L_Ptr24_RegOffs:
					exec_ld_l_ptr24_regoffs(instr.size, instr.reg1, instr.reg2, cpu)
				case .Ld_L_RegPair:
					exec_ld_l_regpair(instr.size, instr.reg1, instr.reg2, cpu)
				case .Ld_L_RegPair_ImmOffs:
					exec_ld_l_regpair_immoffs(instr.size, instr.reg1, instr.reg2, cpu)
				case .Ld_L_RegPair_RegOffs:
					exec_ld_l_regpair_regoffs(instr.size, instr.reg1, instr.reg2, cpu)
				case .St_L_Ptr24:
					exec_st_l_ptr24(instr.size, instr.reg1, cpu)
				case .St_L_Ptr24_RegOffs:
					exec_st_l_ptr24_regoffs(instr.size, instr.reg1, instr.reg2, cpu)
				case .St_L_RegPair:
					exec_st_l_regpair(instr.size, instr.reg1, instr.reg2, cpu)
				case .St_L_RegPair_ImmOffs:
					exec_st_l_regpair_immoffs(instr.size, instr.reg1, instr.reg2, cpu)
				case .St_L_RegPair_RegOffs:
					exec_st_l_regpair_regoffs(instr.size, instr.reg1, instr.reg2, cpu)
				case .Blkcp:
					exec_blkcp(instr.reg1, instr.reg2, cpu)
				case .Blkmv:
					exec_blkmv(instr.reg1, instr.reg2, cpu)
				case:
					cpu_trigger_interrupt(cpu, INVALID_OPCODE_VEC_IDX, true)
			}
		case .Math:
			switch MathOpcodes(instr.opcode) {
				case .Add_Reg_Reg:
					exec_add_reg_reg(instr.size, instr.reg1, instr.reg2, false, cpu)
				case .Add_Reg_Imm:
					exec_add_reg_imm(instr.size, instr.reg1, false, cpu)
				case .Add_Reg_RegPtr:
					exec_add_reg_regptr(instr.size, instr.reg1, instr.reg2, false, cpu)
				case .Add_Reg_ImmPtr:
					exec_add_reg_immptr(instr.size, instr.reg1, false, cpu)
				case .Add_Reg_RegPtr_ImmOffs:
					exec_add_reg_regptr_immoffs(instr.size, instr.reg1, instr.reg2, false, cpu)
				case .Add_Reg_RegPtr_RegOffs:
					exec_add_reg_regptr_regoffs(instr.size, instr.reg1, instr.reg2, false, cpu)
				case .Sub_Reg_Reg:
					exec_sub_reg_reg(instr.size, instr.reg1, instr.reg2, false, false, cpu)
				case .Sub_Reg_Imm:
					exec_sub_reg_imm(instr.size, instr.reg1, false, false, cpu)
				case .Sub_Reg_RegPtr:
					exec_sub_reg_regptr(instr.size, instr.reg1, instr.reg2, false, false, cpu)
				case .Sub_Reg_ImmPtr:
					exec_sub_reg_immptr(instr.size, instr.reg1, false, false, cpu)
				case .Sub_Reg_RegPtr_ImmOffs:
					exec_sub_reg_regptr_immoffs(
						instr.size,
						instr.reg1,
						instr.reg2,
						false,
						false,
						cpu,
					)
				case .Sub_Reg_RegPtr_RegOffs:
					exec_sub_reg_regptr_regoffs(
						instr.size,
						instr.reg1,
						instr.reg2,
						false,
						false,
						cpu,
					)
				case .Mulu_Reg_Reg:
					exec_mulu_reg_reg(instr.size, instr.reg1, instr.reg2, cpu)
				case .Mulu_Reg_Imm:
					exec_mulu_reg_imm(instr.size, instr.reg1, cpu)
				case .Mulu_Reg_RegPtr:
					exec_mulu_reg_regptr(instr.size, instr.reg1, instr.reg2, cpu)
				case .Mulu_Reg_ImmPtr:
					exec_mulu_reg_immptr(instr.size, instr.reg1, cpu)
				case .Mulu_Reg_RegPtr_ImmOffs:
					exec_mulu_reg_regptr_immoffs(instr.size, instr.reg1, instr.reg2, cpu)
				case .Mulu_Reg_RegPtr_RegOffs:
					exec_mulu_reg_regptr_regoffs(instr.size, instr.reg1, instr.reg2, cpu)
				case .Divu_Reg_Reg:
					exec_divu_reg_reg(instr.size, instr.reg1, instr.reg2, cpu)
				case .Divu_Reg_Imm:
					exec_divu_reg_imm(instr.size, instr.reg1, cpu)
				case .Divu_Reg_RegPtr:
					exec_divu_reg_regptr(instr.size, instr.reg1, instr.reg2, cpu)
				case .Divu_Reg_ImmPtr:
					exec_divu_reg_immptr(instr.size, instr.reg1, cpu)
				case .Divu_Reg_RegPtr_ImmOffs:
					exec_divu_reg_regptr_immoffs(instr.size, instr.reg1, instr.reg2, cpu)
				case .Divu_Reg_RegPtr_RegOffs:
					exec_divu_reg_regptr_regoffs(instr.size, instr.reg1, instr.reg2, cpu)
			}
		case .ControlFlow:
	}
}
