package execution

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
