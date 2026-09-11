package execution

import "../memory"

BLKCP_BLKMV_SIZE :: 4

MemoryOpcodes :: enum u8 {
	Ld_Reg_Imm,
	Ld_Reg_RegPtr,
	Ld_Reg_ImmPtr,
	Ld_Reg_ImmOffs,
	Ld_Reg_RegOffs,
	Ld_Reg_RegPtr_PostInc,
	Ld_Reg_RegPtr_PreInc,
	Ld_Reg_RegPtr_PostDec,
	Ld_Reg_RegPtr_PreDec,
	St_Reg_RegPtr,
	St_Reg_ImmPtr,
	St_Reg_ImmOffs,
	St_Reg_RegOffs,
	St_Reg_RegPtr_PostInc,
	St_Reg_RegPtr_PreInc,
	St_Reg_RegPtr_PostDec,
	St_Reg_RegPtr_PreDec,
	Push,
	Pop,
	Shove,
	Ld_L_Ptr24,
	Ld_L_Ptr24_RegOffs,
	Ld_L_RegPair,
	Ld_L_RegPair_ImmOffs,
	Ld_L_RegPair_RegOffs,
	St_L_Ptr24,
	St_L_Ptr24_RegOffs,
	St_L_RegPair,
	St_L_RegPair_ImmOffs,
	St_L_RegPair_RegOffs,
	Blkcp,
	Blkmv,
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

exec_ld_reg_immoffs :: proc(size: SizeMode, reg1, reg2: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)
	offs := cpu_pc_fetch_word(cpu)
	addr := u16(i16(r2.full) + i16(offs))

	switch size {
		case .Word:
			val := cpu_dp_fetch_word(cpu, addr)
			r1.full = val
		case .Byte:
			val := cpu_dp_fetch_byte(cpu, addr)
			r1.low = val
	}
}

exec_ld_reg_regoffs :: proc(size: SizeMode, reg1, reg2: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)
	offs := cpu_get_reg(cpu, cpu_pc_fetch_byte(cpu) & 0b111).full
	addr := u16(i16(r2.full) + i16(offs))

	switch size {
		case .Word:
			val := cpu_dp_fetch_word(cpu, addr)
			r1.full = val
		case .Byte:
			val := cpu_dp_fetch_byte(cpu, addr)
			r1.low = val
	}
}

exec_ld_reg_regptr_postinc :: proc(size: SizeMode, reg1, reg2: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)

	switch size {
		case .Word:
			val := cpu_dp_fetch_word(cpu, r2.full)
			r2.full += size_of(u16)
			r1.full = val
		case .Byte:
			val := cpu_dp_fetch_byte(cpu, r2.full)
			r2.full += size_of(u8)
			r1.low = val
	}
}

exec_ld_reg_regptr_preinc :: proc(size: SizeMode, reg1, reg2: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)

	switch size {
		case .Word:
			r2.full += size_of(u16)
			val := cpu_dp_fetch_word(cpu, r2.full)
			r1.full = val
		case .Byte:
			r2.full += size_of(u8)
			val := cpu_dp_fetch_byte(cpu, r2.full)
			r1.low = val
	}
}

exec_ld_reg_regptr_postdec :: proc(size: SizeMode, reg1, reg2: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)

	switch size {
		case .Word:
			val := cpu_dp_fetch_word(cpu, r2.full)
			r2.full += size_of(u16)
			r1.full = val
		case .Byte:
			val := cpu_dp_fetch_byte(cpu, r2.full)
			r2.full += size_of(u8)
			r1.low = val
	}
}

exec_ld_reg_regptr_predec :: proc(size: SizeMode, reg1, reg2: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)

	switch size {
		case .Word:
			r2.full -= size_of(u16)
			val := cpu_dp_fetch_word(cpu, r2.full)
			r1.full = val
		case .Byte:
			r2.full -= size_of(u8)
			val := cpu_dp_fetch_byte(cpu, r2.full)
			r1.low = val
	}
}

exec_st_reg_regptr :: proc(size: SizeMode, reg1, reg2: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)

	switch size {
		case .Word:
			cpu_dp_store_word(cpu, r2.full, r1.full)
		case .Byte:
			cpu_dp_store_byte(cpu, r2.full, r1.low)
	}
}

exec_st_reg_immptr :: proc(size: SizeMode, reg1: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	immptr := cpu_pc_fetch_word(cpu)

	switch size {
		case .Word:
			cpu_dp_store_word(cpu, immptr, r1.full)
		case .Byte:
			cpu_dp_store_byte(cpu, immptr, r1.low)
	}
}

exec_st_reg_immoffs :: proc(size: SizeMode, reg1, reg2: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)
	offs := cpu_pc_fetch_word(cpu)
	addr := u16(i16(r2.full) + i16(offs))

	switch size {
		case .Word:
			cpu_dp_store_word(cpu, addr, r1.full)
		case .Byte:
			cpu_dp_store_byte(cpu, addr, r1.low)
	}
}

exec_st_reg_regoffs :: proc(size: SizeMode, reg1, reg2: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)
	offs := cpu_get_reg(cpu, cpu_pc_fetch_byte(cpu) & 0b111).full
	addr := u16(i16(r2.full) + i16(offs))

	switch size {
		case .Word:
			cpu_dp_store_word(cpu, addr, r1.full)
		case .Byte:
			cpu_dp_store_byte(cpu, addr, r1.low)
	}
}

exec_st_reg_regptr_postinc :: proc(size: SizeMode, reg1, reg2: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)

	switch size {
		case .Word:
			cpu_dp_store_word(cpu, r2.full, r1.full)
			r2.full += size_of(u16)
		case .Byte:
			cpu_dp_store_byte(cpu, r2.full, r1.low)
			r2.full += size_of(u8)
	}
}

exec_st_reg_regptr_preinc :: proc(size: SizeMode, reg1, reg2: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)

	switch size {
		case .Word:
			r2.full += size_of(u16)
			cpu_dp_store_word(cpu, r2.full, r1.full)
		case .Byte:
			r2.full += size_of(u8)
			cpu_dp_store_byte(cpu, r2.full, r1.low)
	}
}

exec_st_reg_regptr_postdec :: proc(size: SizeMode, reg1, reg2: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)

	switch size {
		case .Word:
			cpu_dp_store_word(cpu, r2.full, r1.full)
			r2.full -= size_of(u16)
		case .Byte:
			cpu_dp_store_byte(cpu, r2.full, r1.low)
			r2.full -= size_of(u8)
	}
}

exec_st_reg_regptr_predec :: proc(size: SizeMode, reg1, reg2: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)

	switch size {
		case .Word:
			r2.full -= size_of(u16)
			cpu_dp_store_word(cpu, r2.full, r1.full)
		case .Byte:
			r2.full -= size_of(u8)
			cpu_dp_store_byte(cpu, r2.full, r1.low)
	}
}

exec_push :: proc(reg1: u8, cpu: ^Cpu) {
	cpu_push(cpu, RegName(reg1))
}

exec_pop :: proc(reg1: u8, cpu: ^Cpu) {
	cpu_pop(cpu, RegName(reg1))
}

ShoveValues :: enum u8 {
	A,
	B,
	C,
	D,
	E,
	F,
	Flags,
	Hi,
	DP,
	Mode = 15,
}

ShoveBitmask :: bit_set[ShoveValues;u16]

exec_shove :: proc(cpu: ^Cpu) {
	bitmask := transmute(ShoveBitmask)(cpu_pc_fetch_word(cpu))

	if .Mode in bitmask {
		for idx in ShoveValues.A ..< ShoveValues.Flags {
			if idx in bitmask do cpu_push(cpu, RegName(idx))
		}
		if .Flags in bitmask do cpu_push(cpu, .Flags)
		if .Hi in bitmask do cpu_push(cpu, .Hi)
		if .DP in bitmask do cpu_push(cpu, .DP)
	} else {
		if .DP in bitmask do cpu_pop(cpu, .DP)
		if .Hi in bitmask do cpu_pop(cpu, .Hi)
		if .Flags in bitmask do cpu_pop(cpu, .Flags)
		for idx: i16 = i16(ShoveValues.F); idx >= i16(ShoveValues.A); idx -= 1 { 	// just what the hell is this monstrosity
			if ShoveValues(idx) in bitmask do cpu_pop(cpu, RegName(idx))
		}
	}
}

exec_ld_l_ptr24 :: proc(size: SizeMode, reg1: u8, cpu: ^Cpu) {
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

exec_ld_l_ptr24_regoffs :: proc(size: SizeMode, reg1, reg2: u8, cpu: ^Cpu) {
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

exec_ld_l_regpair :: proc(size: SizeMode, reg1, reg2: u8, cpu: ^Cpu) {
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

exec_ld_l_regpair_immoffs :: proc(size: SizeMode, reg1, reg2: u8, cpu: ^Cpu) {
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

exec_ld_l_regpair_regoffs :: proc(size: SizeMode, reg1, reg2: u8, cpu: ^Cpu) {
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

exec_st_l_ptr24 :: proc(size: SizeMode, reg1: u8, cpu: ^Cpu) {
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

exec_st_l_ptr24_regoffs :: proc(size: SizeMode, reg1, reg2: u8, cpu: ^Cpu) {
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

exec_st_l_regpair :: proc(size: SizeMode, reg1, reg2: u8, cpu: ^Cpu) {
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

exec_st_l_regpair_immoffs :: proc(size: SizeMode, reg1, reg2: u8, cpu: ^Cpu) {
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

exec_st_l_regpair_regoffs :: proc(size: SizeMode, reg1, reg2: u8, cpu: ^Cpu) {
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
