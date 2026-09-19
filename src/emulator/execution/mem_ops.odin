package execution

import "../../shared"
import "../memory"

BLKCP_BLKMV_SIZE :: 4

exec_ld_reg_imm :: proc(size: shared.SizeMode, reg1: u8, cpu: ^Cpu) {
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

exec_ld_reg_regptr :: proc(size: shared.SizeMode, reg1, reg2: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)

	switch size {
		case .Word:
			val := cpu_reg_fetch_word(cpu, reg2, r2.full)
			r1.full = val
		case .Byte:
			val := cpu_reg_fetch_byte(cpu, reg2, r2.full)
			r1.low = val
	}
}

exec_ld_reg_immptr :: proc(size: shared.SizeMode, reg1: u8, cpu: ^Cpu) {
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

exec_ld_reg_immoffs :: proc(size: shared.SizeMode, reg1, reg2: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)
	offs := cpu_pc_fetch_word(cpu)
	addr := u16(i16(r2.full) + i16(offs))

	switch size {
		case .Word:
			val := cpu_reg_fetch_word(cpu, reg2, addr)
			r1.full = val
		case .Byte:
			val := cpu_reg_fetch_byte(cpu, reg2, addr)
			r1.low = val
	}
}

exec_ld_reg_regoffs :: proc(size: shared.SizeMode, reg1, reg2: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)
	offs := cpu_get_reg(cpu, cpu_pc_fetch_byte(cpu) & 0b111).full
	addr := u16(i16(r2.full) + i16(offs))

	switch size {
		case .Word:
			val := cpu_reg_fetch_word(cpu, reg2, addr)
			r1.full = val
		case .Byte:
			val := cpu_reg_fetch_byte(cpu, reg2, addr)
			r1.low = val
	}
}

exec_ld_reg_regptr_postinc :: proc(size: shared.SizeMode, reg1, reg2: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)

	switch size {
		case .Word:
			if reg2 == SP_REG_IDX && sp_math_wraps(r2.full, size_of(u16), false) {
				cpu_trigger_interrupt(cpu, STACK_UDF_VEC_IDX, true)
				return
			}

			val := cpu_reg_fetch_word(cpu, reg2, r2.full)
			r2.full += size_of(u16)
			r1.full = val
		case .Byte:
			if reg2 == SP_REG_IDX && sp_math_wraps(r2.full, size_of(u8), false) {
				cpu_trigger_interrupt(cpu, STACK_UDF_VEC_IDX, true)
				return
			}

			val := cpu_reg_fetch_byte(cpu, reg2, r2.full)
			r2.full += size_of(u8)
			r1.low = val
	}
}

exec_ld_reg_regptr_preinc :: proc(size: shared.SizeMode, reg1, reg2: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)

	switch size {
		case .Word:
			if reg2 == SP_REG_IDX && sp_math_wraps(r2.full, size_of(u16), false) {
				cpu_trigger_interrupt(cpu, STACK_UDF_VEC_IDX, true)
				return
			}

			r2.full += size_of(u16)
			val := cpu_reg_fetch_word(cpu, reg2, r2.full)
			r1.full = val
		case .Byte:
			if reg2 == SP_REG_IDX && sp_math_wraps(r2.full, size_of(u8), false) {
				cpu_trigger_interrupt(cpu, STACK_UDF_VEC_IDX, true)
				return
			}

			r2.full += size_of(u8)
			val := cpu_reg_fetch_byte(cpu, reg2, r2.full)
			r1.low = val
	}
}

exec_ld_reg_regptr_postdec :: proc(size: shared.SizeMode, reg1, reg2: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)

	switch size {
		case .Word:
			if reg2 == SP_REG_IDX && sp_math_wraps(r2.full, size_of(u16), true) {
				cpu_trigger_interrupt(cpu, STACK_OVF_VEC_IDX, true)
				return
			}

			val := cpu_reg_fetch_word(cpu, reg2, r2.full)
			r2.full -= size_of(u16)
			r1.full = val
		case .Byte:
			if reg2 == SP_REG_IDX && sp_math_wraps(r2.full, size_of(u8), true) {
				cpu_trigger_interrupt(cpu, STACK_OVF_VEC_IDX, true)
				return
			}

			val := cpu_reg_fetch_byte(cpu, reg2, r2.full)
			r2.full -= size_of(u8)
			r1.low = val
	}
}

exec_ld_reg_regptr_predec :: proc(size: shared.SizeMode, reg1, reg2: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)

	switch size {
		case .Word:
			if reg2 == SP_REG_IDX && sp_math_wraps(r2.full, size_of(u16), true) {
				cpu_trigger_interrupt(cpu, STACK_OVF_VEC_IDX, true)
				return
			}

			r2.full -= size_of(u16)
			val := cpu_reg_fetch_word(cpu, reg2, r2.full)
			r1.full = val
		case .Byte:
			if reg2 == SP_REG_IDX && sp_math_wraps(r2.full, size_of(u8), true) {
				cpu_trigger_interrupt(cpu, STACK_OVF_VEC_IDX, true)
				return
			}

			r2.full -= size_of(u8)
			val := cpu_reg_fetch_byte(cpu, reg2, r2.full)
			r1.low = val
	}
}

exec_st_reg_regptr :: proc(size: shared.SizeMode, reg1, reg2: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)

	switch size {
		case .Word:
			cpu_reg_store_word(cpu, reg2, r2.full, r1.full)
		case .Byte:
			cpu_reg_store_byte(cpu, reg2, r2.full, r1.low)
	}
}

exec_st_reg_immptr :: proc(size: shared.SizeMode, reg1: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	immptr := cpu_pc_fetch_word(cpu)

	switch size {
		case .Word:
			cpu_dp_store_word(cpu, immptr, r1.full)
		case .Byte:
			cpu_dp_store_byte(cpu, immptr, r1.low)
	}
}

exec_st_reg_immoffs :: proc(size: shared.SizeMode, reg1, reg2: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)
	offs := cpu_pc_fetch_word(cpu)
	addr := u16(i16(r2.full) + i16(offs))

	switch size {
		case .Word:
			cpu_reg_store_word(cpu, reg2, addr, r1.full)
		case .Byte:
			cpu_reg_store_byte(cpu, reg2, addr, r1.low)
	}
}

exec_st_reg_regoffs :: proc(size: shared.SizeMode, reg1, reg2: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)
	offs := cpu_get_reg(cpu, cpu_pc_fetch_byte(cpu) & 0b111).full
	addr := u16(i16(r2.full) + i16(offs))

	switch size {
		case .Word:
			cpu_reg_store_word(cpu, reg2, addr, r1.full)
		case .Byte:
			cpu_reg_store_byte(cpu, reg2, addr, r1.low)
	}
}

exec_st_reg_regptr_postinc :: proc(size: shared.SizeMode, reg1, reg2: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)

	switch size {
		case .Word:
			if reg2 == SP_REG_IDX && sp_math_wraps(r2.full, size_of(u16), false) {
				cpu_trigger_interrupt(cpu, STACK_UDF_VEC_IDX, true)
				return
			}

			cpu_reg_store_word(cpu, reg2, r2.full, r1.full)
			r2.full += size_of(u16)
		case .Byte:
			if reg2 == SP_REG_IDX && sp_math_wraps(r2.full, size_of(u8), false) {
				cpu_trigger_interrupt(cpu, STACK_UDF_VEC_IDX, true)
				return
			}

			cpu_reg_store_byte(cpu, reg2, r2.full, r1.low)
			r2.full += size_of(u8)
	}
}

exec_st_reg_regptr_preinc :: proc(size: shared.SizeMode, reg1, reg2: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)

	switch size {
		case .Word:
			if reg2 == SP_REG_IDX && sp_math_wraps(r2.full, size_of(u16), false) {
				cpu_trigger_interrupt(cpu, STACK_UDF_VEC_IDX, true)
				return
			}

			r2.full += size_of(u16)
			cpu_reg_store_word(cpu, reg2, r2.full, r1.full)
		case .Byte:
			if reg2 == SP_REG_IDX && sp_math_wraps(r2.full, size_of(u8), false) {
				cpu_trigger_interrupt(cpu, STACK_UDF_VEC_IDX, true)
				return
			}

			r2.full += size_of(u8)
			cpu_reg_store_byte(cpu, reg2, r2.full, r1.low)
	}
}

exec_st_reg_regptr_postdec :: proc(size: shared.SizeMode, reg1, reg2: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)

	switch size {
		case .Word:
			if reg2 == SP_REG_IDX && sp_math_wraps(r2.full, size_of(u16), true) {
				cpu_trigger_interrupt(cpu, STACK_OVF_VEC_IDX, true)
				return
			}

			cpu_reg_store_word(cpu, reg2, r2.full, r1.full)
			r2.full -= size_of(u16)
		case .Byte:
			if reg2 == SP_REG_IDX && sp_math_wraps(r2.full, size_of(u8), true) {
				cpu_trigger_interrupt(cpu, STACK_OVF_VEC_IDX, true)
				return
			}

			cpu_reg_store_byte(cpu, reg2, r2.full, r1.low)
			r2.full -= size_of(u8)
	}
}

exec_st_reg_regptr_predec :: proc(size: shared.SizeMode, reg1, reg2: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)

	switch size {
		case .Word:
			if reg2 == SP_REG_IDX && sp_math_wraps(r2.full, size_of(u16), true) {
				cpu_trigger_interrupt(cpu, STACK_OVF_VEC_IDX, true)
				return
			}

			r2.full -= size_of(u16)
			cpu_reg_store_word(cpu, reg2, r2.full, r1.full)
		case .Byte:
			if reg2 == SP_REG_IDX && sp_math_wraps(r2.full, size_of(u8), true) {
				cpu_trigger_interrupt(cpu, STACK_OVF_VEC_IDX, true)
				return
			}

			r2.full -= size_of(u8)
			cpu_reg_store_byte(cpu, reg2, r2.full, r1.low)
	}
}

exec_push :: proc(reg1: u8, cpu: ^Cpu) {
	cpu_push(cpu, shared.RegName(reg1))
}

exec_pop :: proc(reg1: u8, cpu: ^Cpu) {
	cpu_pop(cpu, shared.RegName(reg1))
}

exec_shove :: proc(cpu: ^Cpu) {
	bitmask := transmute(shared.ShoveBitmask)(cpu_pc_fetch_word(cpu))

	if .Mode not_in bitmask {
		for idx in shared.ShoveValues.A ..< shared.ShoveValues.Flags {
			if idx in bitmask do cpu_push(cpu, shared.RegName(idx))
		}
		if .Flags in bitmask do cpu_push(cpu, .Flags)
		if .Hi in bitmask do cpu_push(cpu, .Hi)
		if .DP in bitmask do cpu_push(cpu, .DP)
	} else {
		if .DP in bitmask do cpu_pop(cpu, .DP)
		if .Hi in bitmask do cpu_pop(cpu, .Hi)
		if .Flags in bitmask do cpu_pop(cpu, .Flags)
		for idx: i16 = i16(shared.ShoveValues.G); idx >= i16(shared.ShoveValues.A); idx -= 1 { 	// just what the hell is this monstrosity
			if shared.ShoveValues(idx) in bitmask do cpu_pop(cpu, shared.RegName(idx))
		}
	}
}

exec_ld_l_ptr24 :: proc(size: shared.SizeMode, reg1: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	offs := cpu_pc_fetch_word(cpu)
	page := cpu_pc_fetch_byte(cpu)
	addr := memory.calculate_address(page, offs)

	switch size {
		case .Word:
			val := cpu_read_word(cpu, addr)
			r1.full = val
		case .Byte:
			val := cpu_read_byte(cpu, addr)
			r1.low = val
	}
}

exec_ld_l_ptr24_regoffs :: proc(size: shared.SizeMode, reg1, reg2: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)
	offs := cpu_pc_fetch_word(cpu)
	page := cpu_pc_fetch_byte(cpu)
	addr := u32(i32(memory.calculate_address(page, offs)) + i32(i16(r2.full)))

	switch size {
		case .Word:
			val := cpu_read_word(cpu, addr)
			r1.full = val
		case .Byte:
			val := cpu_read_byte(cpu, addr)
			r1.low = val
	}
}

exec_ld_l_regpair :: proc(size: shared.SizeMode, reg1, reg2: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)
	r3 := cpu_get_reg(cpu, cpu_pc_fetch_byte(cpu) & 0b111)
	addr := memory.calculate_address(r2.low, r3.full)

	switch size {
		case .Word:
			val := cpu_read_word(cpu, addr)
			r1.full = val
		case .Byte:
			val := cpu_read_byte(cpu, addr)
			r1.low = val
	}
}

exec_ld_l_regpair_immoffs :: proc(size: shared.SizeMode, reg1, reg2: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)
	r3 := cpu_get_reg(cpu, cpu_pc_fetch_byte(cpu) & 0b111)
	offs := cpu_pc_fetch_word(cpu)
	addr := u32(i32(memory.calculate_address(r2.low, r3.full)) + i32(i16(offs)))

	switch size {
		case .Word:
			val := cpu_read_word(cpu, addr)
			r1.full = val
		case .Byte:
			val := cpu_read_byte(cpu, addr)
			r1.low = val
	}
}

exec_ld_l_regpair_regoffs :: proc(size: shared.SizeMode, reg1, reg2: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)
	next_byte := cpu_pc_fetch_byte(cpu)
	r3 := cpu_get_reg(cpu, next_byte & 0b111)
	r4 := cpu_get_reg(cpu, (next_byte >> 3) & 0b111)

	addr := u32(i32(memory.calculate_address(r2.low, r3.full)) + i32(i16(r4.full))) // this is getting ridiculous

	switch size {
		case .Word:
			val := cpu_read_word(cpu, addr)
			r1.full = val
		case .Byte:
			val := cpu_read_byte(cpu, addr)
			r1.low = val
	}
}

exec_st_l_ptr24 :: proc(size: shared.SizeMode, reg1: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	offs := cpu_pc_fetch_word(cpu)
	page := cpu_pc_fetch_byte(cpu)
	addr := memory.calculate_address(page, offs)

	switch size {
		case .Word:
			cpu_write_word(cpu, addr, r1.full)
		case .Byte:
			cpu_write_byte(cpu, addr, r1.low)
	}
}

exec_st_l_ptr24_regoffs :: proc(size: shared.SizeMode, reg1, reg2: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)
	offs := cpu_pc_fetch_word(cpu)
	page := cpu_pc_fetch_byte(cpu)
	addr := u32(i32(memory.calculate_address(page, offs)) + i32(i16(r2.full)))

	switch size {
		case .Word:
			cpu_write_word(cpu, addr, r1.full)
		case .Byte:
			cpu_write_byte(cpu, addr, r1.low)
	}
}

exec_st_l_regpair :: proc(size: shared.SizeMode, reg1, reg2: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)
	r3 := cpu_get_reg(cpu, cpu_pc_fetch_byte(cpu) & 0b111)
	addr := memory.calculate_address(r2.low, r3.full)

	switch size {
		case .Word:
			cpu_write_word(cpu, addr, r1.full)
		case .Byte:
			cpu_write_byte(cpu, addr, r1.low)
	}
}

exec_st_l_regpair_immoffs :: proc(size: shared.SizeMode, reg1, reg2: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)
	r3 := cpu_get_reg(cpu, cpu_pc_fetch_byte(cpu) & 0b111)
	offs := cpu_pc_fetch_word(cpu)
	addr := u32(i32(memory.calculate_address(r2.low, r3.full)) + i32(i16(offs)))

	switch size {
		case .Word:
			cpu_write_word(cpu, addr, r1.full)
		case .Byte:
			cpu_write_byte(cpu, addr, r1.low)
	}
}

exec_st_l_regpair_regoffs :: proc(size: shared.SizeMode, reg1, reg2: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)
	next_byte := cpu_pc_fetch_byte(cpu)
	r3 := cpu_get_reg(cpu, next_byte & 0b111)
	r4 := cpu_get_reg(cpu, (next_byte >> 3) & 0b111)

	addr := u32(i32(memory.calculate_address(r2.low, r3.full)) + i32(i16(r4.full)))

	switch size {
		case .Word:
			cpu_write_word(cpu, addr, r1.full)
		case .Byte:
			cpu_write_byte(cpu, addr, r1.low)
	}
}

exec_blkcp :: proc(reg1, reg2: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)

	next_byte := cpu_pc_fetch_byte(cpu)

	r3 := cpu_get_reg(cpu, next_byte & 0b111)
	r4 := cpu_get_reg(cpu, (next_byte >> 3) & 0b111)

	next_byte = cpu_pc_fetch_byte(cpu)
	r5 := cpu_get_reg(cpu, next_byte & 0b111)

	amnt := r5.full
	if amnt == 0 do return

	src_addr := memory.calculate_address(r1.low, r2.full)
	dest_addr := memory.calculate_address(r3.low, r4.full)

	src_byte := cpu_read_byte(cpu, src_addr)
	cpu_write_byte(cpu, dest_addr, src_byte)
	src_addr += 1
	dest_addr += 1

	r1.low = u8(src_addr >> 16)
	r2.full = u16(src_addr)

	r3.low = u8(dest_addr >> 16)
	r4.full = u16(dest_addr)

	r5.full -= 1
	cpu_advance_pc(cpu, -1 * BLKCP_BLKMV_SIZE)
}

exec_blkmv :: proc(reg1, reg2: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)

	next_byte := cpu_pc_fetch_byte(cpu)

	r3 := cpu_get_reg(cpu, next_byte & 0b111)
	r4 := cpu_get_reg(cpu, (next_byte >> 3) & 0b111)

	next_byte = cpu_pc_fetch_byte(cpu)
	r5 := cpu_get_reg(cpu, next_byte & 0b111)

	amnt := r5.full
	if amnt == 0 do return

	src_addr := memory.calculate_address(r1.low, r2.full)
	dest_addr := memory.calculate_address(r3.low, r4.full)

	src_byte := cpu_read_byte(cpu, src_addr + u32(amnt - 1))
	cpu_write_byte(cpu, dest_addr + u32(amnt - 1), src_byte)
	src_addr += 1
	dest_addr += 1

	r1.low = u8(src_addr >> 16)
	r2.full = u16(src_addr)

	r3.low = u8(dest_addr >> 16)
	r4.full = u16(dest_addr)

	r5.full -= 1
	cpu_advance_pc(cpu, -1 * BLKCP_BLKMV_SIZE)
}
