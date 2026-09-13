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
				case .Sec:
					exec_sec(cpu)
				case .Clc:
					exec_clc(cpu)
				case .Sez:
					exec_sez(cpu)
				case .Clz:
					exec_clz(cpu)
				case .Sen:
					exec_sen(cpu)
				case .Cln:
					exec_cln(cpu)
				case .Sev:
					exec_sev(cpu)
				case .Clv:
					exec_clv(cpu)
				case .Mffr:
					exec_mffr(instr.size, instr.reg1, cpu)
				case .Mtfr:
					exec_mtfr(instr.size, instr.reg1, cpu)
				case .Sei:
					exec_sei(cpu)
				case .Cli:
					exec_cli(cpu)
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
				case .Muls_Reg_Reg:
					exec_muls_reg_reg(instr.size, instr.reg1, instr.reg2, cpu)
				case .Muls_Reg_Imm:
					exec_muls_reg_imm(instr.size, instr.reg1, cpu)
				case .Muls_Reg_RegPtr:
					exec_muls_reg_regptr(instr.size, instr.reg1, instr.reg2, cpu)
				case .Muls_Reg_ImmPtr:
					exec_muls_reg_immptr(instr.size, instr.reg1, cpu)
				case .Muls_Reg_RegPtr_ImmOffs:
					exec_muls_reg_regptr_immoffs(instr.size, instr.reg1, instr.reg2, cpu)
				case .Muls_Reg_RegPtr_RegOffs:
					exec_muls_reg_regptr_regoffs(instr.size, instr.reg1, instr.reg2, cpu)
				case .Divs_Reg_Reg:
					exec_divs_reg_reg(instr.size, instr.reg1, instr.reg2, cpu)
				case .Divs_Reg_Imm:
					exec_divs_reg_imm(instr.size, instr.reg1, cpu)
				case .Divs_Reg_RegPtr:
					exec_divs_reg_regptr(instr.size, instr.reg1, instr.reg2, cpu)
				case .Divs_Reg_ImmPtr:
					exec_divs_reg_immptr(instr.size, instr.reg1, cpu)
				case .Divs_Reg_RegPtr_ImmOffs:
					exec_divs_reg_regptr_immoffs(instr.size, instr.reg1, instr.reg2, cpu)
				case .Divs_Reg_RegPtr_RegOffs:
					exec_divs_reg_regptr_regoffs(instr.size, instr.reg1, instr.reg2, cpu)
				case .Adc_Reg_Reg:
					exec_add_reg_reg(instr.size, instr.reg1, instr.reg2, true, cpu)
				case .Adc_Reg_Imm:
					exec_add_reg_imm(instr.size, instr.reg1, true, cpu)
				case .Adc_Reg_RegPtr:
					exec_add_reg_regptr(instr.size, instr.reg1, instr.reg2, true, cpu)
				case .Adc_Reg_ImmPtr:
					exec_add_reg_immptr(instr.size, instr.reg1, true, cpu)
				case .Adc_Reg_RegPtr_ImmOffs:
					exec_add_reg_regptr_immoffs(instr.size, instr.reg1, instr.reg2, true, cpu)
				case .Adc_Reg_RegPtr_RegOffs:
					exec_add_reg_regptr_regoffs(instr.size, instr.reg1, instr.reg2, true, cpu)
				case .Sbc_Reg_Reg:
					exec_sub_reg_reg(instr.size, instr.reg1, instr.reg2, true, false, cpu)
				case .Sbc_Reg_Imm:
					exec_sub_reg_imm(instr.size, instr.reg1, true, false, cpu)
				case .Sbc_Reg_RegPtr:
					exec_sub_reg_regptr(instr.size, instr.reg1, instr.reg2, true, false, cpu)
				case .Sbc_Reg_ImmPtr:
					exec_sub_reg_immptr(instr.size, instr.reg1, true, false, cpu)
				case .Sbc_Reg_RegPtr_ImmOffs:
					exec_sub_reg_regptr_immoffs(
						instr.size,
						instr.reg1,
						instr.reg2,
						true,
						false,
						cpu,
					)
				case .Sbc_Reg_RegPtr_RegOffs:
					exec_sub_reg_regptr_regoffs(
						instr.size,
						instr.reg1,
						instr.reg2,
						true,
						false,
						cpu,
					)
				case .Cmp_Reg_Reg:
					exec_sub_reg_reg(instr.size, instr.reg1, instr.reg2, false, true, cpu)
				case .Cmp_Reg_Imm:
					exec_sub_reg_imm(instr.size, instr.reg1, false, true, cpu)
				case .Cmp_Reg_RegPtr:
					exec_sub_reg_regptr(instr.size, instr.reg1, instr.reg2, false, true, cpu)
				case .Cmp_Reg_ImmPtr:
					exec_sub_reg_immptr(instr.size, instr.reg1, false, true, cpu)
				case .Cmp_Reg_RegPtr_ImmOffs:
					exec_sub_reg_regptr_immoffs(
						instr.size,
						instr.reg1,
						instr.reg2,
						false,
						true,
						cpu,
					)
				case .Cmp_Reg_RegPtr_RegOffs:
					exec_sub_reg_regptr_regoffs(
						instr.size,
						instr.reg1,
						instr.reg2,
						false,
						true,
						cpu,
					)
				case .Inc:
					exec_inc(instr.size, instr.reg1, cpu)
				case .Dec:
					exec_dec(instr.size, instr.reg1, cpu)
				case .Neg:
					exec_neg(instr.size, instr.reg1, cpu)
				case .And_Reg_Reg:
					exec_and_reg_reg(instr.size, instr.reg1, instr.reg2, false, cpu)
				case .And_Reg_Imm:
					exec_and_reg_imm(instr.size, instr.reg1, false, cpu)
				case .And_Reg_RegPtr:
					exec_and_reg_regptr(instr.size, instr.reg1, instr.reg2, false, cpu)
				case .And_Reg_ImmPtr:
					exec_and_reg_immptr(instr.size, instr.reg1, false, cpu)
				case .And_Reg_RegPtr_ImmOffs:
					exec_and_reg_regptr_immoffs(instr.size, instr.reg1, instr.reg2, false, cpu)
				case .And_Reg_RegPtr_RegOffs:
					exec_and_reg_regptr_regoffs(instr.size, instr.reg1, instr.reg2, false, cpu)
				case .Or_Reg_Reg:
					exec_or_reg_reg(instr.size, instr.reg1, instr.reg2, cpu)
				case .Or_Reg_Imm:
					exec_or_reg_imm(instr.size, instr.reg1, cpu)
				case .Or_Reg_RegPtr:
					exec_or_reg_regptr(instr.size, instr.reg1, instr.reg2, cpu)
				case .Or_Reg_ImmPtr:
					exec_or_reg_immptr(instr.size, instr.reg1, cpu)
				case .Or_Reg_RegPtr_ImmOffs:
					exec_or_reg_regptr_immoffs(instr.size, instr.reg1, instr.reg2, cpu)
				case .Or_Reg_RegPtr_RegOffs:
					exec_or_reg_regptr_regoffs(instr.size, instr.reg1, instr.reg2, cpu)
				case .Xor_Reg_Reg:
					exec_xor_reg_reg(instr.size, instr.reg1, instr.reg2, cpu)
				case .Xor_Reg_Imm:
					exec_xor_reg_imm(instr.size, instr.reg1, cpu)
				case .Xor_Reg_RegPtr:
					exec_xor_reg_regptr(instr.size, instr.reg1, instr.reg2, cpu)
				case .Xor_Reg_ImmPtr:
					exec_xor_reg_immptr(instr.size, instr.reg1, cpu)
				case .Xor_Reg_RegPtr_ImmOffs:
					exec_xor_reg_regptr_immoffs(instr.size, instr.reg1, instr.reg2, cpu)
				case .Xor_Reg_RegPtr_RegOffs:
					exec_xor_reg_regptr_regoffs(instr.size, instr.reg1, instr.reg2, cpu)
				case .Bt_Reg_Reg:
					exec_and_reg_reg(instr.size, instr.reg1, instr.reg2, true, cpu)
				case .Bt_Reg_Imm:
					exec_and_reg_imm(instr.size, instr.reg1, true, cpu)
				case .Bt_Reg_RegPtr:
					exec_and_reg_regptr(instr.size, instr.reg1, instr.reg2, true, cpu)
				case .Bt_Reg_ImmPtr:
					exec_and_reg_immptr(instr.size, instr.reg1, true, cpu)
				case .Bt_Reg_RegPtr_ImmOffs:
					exec_and_reg_regptr_immoffs(instr.size, instr.reg1, instr.reg2, true, cpu)
				case .Bt_Reg_RegPtr_RegOffs:
					exec_and_reg_regptr_regoffs(instr.size, instr.reg1, instr.reg2, true, cpu)
				case .Not:
					exec_not(instr.size, instr.reg1, cpu)
				case .Lsl_Reg_Reg:
					exec_lsl_reg_reg(instr.size, instr.reg1, instr.reg2, cpu)
				case .Lsl_Reg_Imm:
					exec_lsl_reg_imm(instr.size, instr.reg1, cpu)
				case .Lsr_Reg_Reg:
					exec_lsr_reg_reg(instr.size, instr.reg1, instr.reg2, cpu)
				case .Lsr_Reg_Imm:
					exec_lsr_reg_imm(instr.size, instr.reg1, cpu)
				case .Asr_Reg_Reg:
					exec_asr_reg_reg(instr.size, instr.reg1, instr.reg2, cpu)
				case .Asr_Reg_Imm:
					exec_asr_reg_imm(instr.size, instr.reg1, cpu)
				case .Rol_Reg_Reg:
					exec_rol_reg_reg(instr.size, instr.reg1, instr.reg2, cpu)
				case .Rol_Reg_Imm:
					exec_rol_reg_imm(instr.size, instr.reg1, cpu)
				case .Ror_Reg_Reg:
					exec_ror_reg_reg(instr.size, instr.reg1, instr.reg2, cpu)
				case .Ror_Reg_Imm:
					exec_ror_reg_imm(instr.size, instr.reg1, cpu)
				case .Rcl_Reg_Reg:
					exec_rcl_reg_reg(instr.size, instr.reg1, instr.reg2, cpu)
				case .Rcl_Reg_Imm:
					exec_rcl_reg_imm(instr.size, instr.reg1, cpu)
				case .Rcr_Reg_Reg:
					exec_rcr_reg_reg(instr.size, instr.reg1, instr.reg2, cpu)
				case .Rcr_Reg_Imm:
					exec_rcr_reg_imm(instr.size, instr.reg1, cpu)
				case .Add_L_RegPair:
					exec_add_l_regpair(instr.reg1, instr.reg2, cpu)
				case .Add_L_Imm32:
					exec_add_l_imm32(instr.reg1, instr.reg2, cpu)
				case .Sub_L_RegPair:
					exec_sub_l_regpair(instr.reg1, instr.reg2, false, cpu)
				case .Sub_L_Imm32:
					exec_sub_l_imm32(instr.reg1, instr.reg2, false, cpu)
				case .Cmp_L_RegPair:
					exec_sub_l_regpair(instr.reg1, instr.reg2, true, cpu)
				case .Cmp_L_Imm32:
					exec_sub_l_imm32(instr.reg1, instr.reg2, true, cpu)
			}
		case .ControlFlow:
			switch FlowOps(instr.opcode) {
				case .Jsr_Imm:
					exec_jsr_imm(cpu)
				case .Jsr_Reg:
					exec_jsr_reg(instr.reg1, cpu)
				case .Jmp_Imm:
					exec_jmp_imm(cpu)
				case .Jmp_Reg:
					exec_jmp_reg(instr.reg1, cpu)
				case .Rts:
					exec_rts(cpu)
				case .Rti:
					exec_rti(cpu)
				case .Rtf:
					exec_rtf(cpu)
				case .Jz:
					exec_jz(instr.size, cpu)
				case .Jnz:
					exec_jnz(instr.size, cpu)
				case .Jc:
					exec_jc(instr.size, cpu)
				case .Jnc:
					exec_jnc(instr.size, cpu)
				case .Jmi:
					exec_jmi(instr.size, cpu)
				case .Jpl:
					exec_jpl(instr.size, cpu)
				case .Jv:
					exec_jv(instr.size, cpu)
				case .Jnv:
					exec_jnv(instr.size, cpu)
				case .Jges:
					exec_jges(instr.size, cpu)
				case .Jgts:
					exec_jgts(instr.size, cpu)
				case .Jles:
					exec_jles(instr.size, cpu)
				case .Jlts:
					exec_jlts(instr.size, cpu)
				case .Jgtu:
					exec_jgtu(instr.size, cpu)
				case .Jleu:
					exec_jleu(instr.size, cpu)
				case .Djnz:
					exec_djnz(instr.size, instr.reg1, cpu)
				case .Jsr_L_Imm:
					exec_jsr_l_imm(cpu)
				case .Jsr_L_Regpair:
					exec_jsr_l_regpair(instr.reg1, instr.reg2, cpu)
				case .Jmp_L_Imm:
					exec_jmp_l_imm(cpu)
				case .Jmp_L_Regpair:
					exec_jmp_l_regpair(instr.reg1, instr.reg2, cpu)
				case .Rts_L:
					exec_rts_l(cpu)
			}
	}
}
