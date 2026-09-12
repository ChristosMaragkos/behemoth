package execution

MathOpcodes :: enum u8 {
	// add
	Add_Reg_Reg,
	Add_Reg_Imm,
	Add_Reg_RegPtr,
	Add_Reg_ImmPtr,
	Add_Reg_RegPtr_ImmOffs,
	Add_Reg_RegPtr_RegOffs,
	// sub
	Sub_Reg_Reg,
	Sub_Reg_Imm,
	Sub_Reg_RegPtr,
	Sub_Reg_ImmPtr,
	Sub_Reg_RegPtr_ImmOffs,
	Sub_Reg_RegPtr_RegOffs,
	// mulu
	Mulu_Reg_Reg,
	Mulu_Reg_Imm,
	Mulu_Reg_RegPtr,
	Mulu_Reg_ImmPtr,
	Mulu_Reg_RegPtr_ImmOffs,
	Mulu_Reg_RegPtr_RegOffs,
	// divu
	Divu_Reg_Reg,
	Divu_Reg_Imm,
	Divu_Reg_RegPtr,
	Divu_Reg_ImmPtr,
	Divu_Reg_RegPtr_ImmOffs,
	Divu_Reg_RegPtr_RegOffs,
	// muls
	Muls_Reg_Reg,
	Muls_Reg_Imm,
	Muls_Reg_RegPtr,
	Muls_Reg_ImmPtr,
	Muls_Reg_RegPtr_ImmOffs,
	Muls_Reg_RegPtr_RegOffs,
	// divs
	Divs_Reg_Reg,
	Divs_Reg_Imm,
	Divs_Reg_RegPtr,
	Divs_Reg_ImmPtr,
	Divs_Reg_RegPtr_ImmOffs,
	Divs_Reg_RegPtr_RegOffs,
	// adc
	Adc_Reg_Reg,
	Adc_Reg_Imm,
	Adc_Reg_RegPtr,
	Adc_Reg_ImmPtr,
	Adc_Reg_RegPtr_ImmOffs,
	Adc_Reg_RegPtr_RegOffs,
	// sbc
	Sbc_Reg_Reg,
	Sbc_Reg_Imm,
	Sbc_Reg_RegPtr,
	Sbc_Reg_ImmPtr,
	Sbc_Reg_RegPtr_ImmOffs,
	Sbc_Reg_RegPtr_RegOffs,
	// cmp
	Cmp_Reg_Reg,
	Cmp_Reg_Imm,
	Cmp_Reg_RegPtr,
	Cmp_Reg_ImmPtr,
	Cmp_Reg_RegPtr_ImmOffs,
	Cmp_Reg_RegPtr_RegOffs,
}

compute_flags_add :: proc(size: SizeMode, accum: u32, op1, op2: u16) -> FlagRegister {
	out: FlagRegister
	if size == .Word {
		truncated := u16(accum)
		if truncated == 0 do out += {.Zero}
		if truncated & 0x8000 != 0 do out += {.Negative}
		if accum > 0xFFFF do out += {.Carry}
		v_test := (op1 ~ truncated) & (op2 ~ truncated)
		if v_test & 0x8000 != 0 do out += {.Overflow}
	} else {
		op1 := u8(op1)
		op2 := u8(op2)
		truncated := u8(accum)
		if truncated == 0 do out += {.Zero}
		if truncated & 0x80 != 0 do out += {.Negative}
		if accum > 0xFF do out += {.Carry}
		v_test := (op1 ~ truncated) & (op2 ~ truncated)
		if v_test & 0x80 != 0 do out += {.Overflow}
	}
	return out
}

exec_add_reg_reg :: proc(size: SizeMode, reg1, reg2: u8, use_carry: bool, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)
	flags_old := cpu_get_flags(cpu)
	carry: u32 = !use_carry ? 0 : (.Carry in (flags_old^) ? 1 : 0)
	flags_new := (flags_old^) & {.IgnoreInterrupts}
	res_full: u32

	switch size {
		case .Word:
			res_full = u32(r1.full) + u32(r2.full) + carry
			res := u16(res_full)
			flags_old^ = flags_new + compute_flags_add(size, res_full, r1.full, r2.full)
			r1.full = res

		case .Byte:
			res_full = u32(r1.low) + u32(r2.low) + carry
			res := u8(res_full)
			flags_old^ = flags_new + compute_flags_add(size, res_full, u16(r1.low), u16(r2.low))
			r1.low = res
	}
	cpu.cycle_delta += 1
}

exec_add_reg_imm :: proc(size: SizeMode, reg1: u8, use_carry: bool, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	flags_old := cpu_get_flags(cpu)
	carry: u32 = !use_carry ? 0 : (.Carry in (flags_old^) ? 1 : 0)
	flags_new := (flags_old^) & {.IgnoreInterrupts}
	res_full: u32

	switch size {
		case .Word:
			op2 := cpu_pc_fetch_word(cpu)
			res_full = u32(r1.full) + u32(op2) + carry
			res := u16(res_full)

			flags_old^ = flags_new + compute_flags_add(size, res_full, r1.full, op2)
			r1.full = res

		case .Byte:
			op2 := cpu_pc_fetch_byte(cpu)
			res_full = u32(r1.low) + u32(op2) + carry
			res := u8(res_full)

			flags_old^ = flags_new + compute_flags_add(size, res_full, u16(r1.low), u16(op2))
			r1.low = res
	}
	cpu.cycle_delta += 1
}

exec_add_reg_regptr :: proc(size: SizeMode, reg1, reg2: u8, use_carry: bool, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)
	flags_old := cpu_get_flags(cpu)
	carry: u32 = !use_carry ? 0 : (.Carry in (flags_old^) ? 1 : 0)
	flags_new := (flags_old^) & {.IgnoreInterrupts}
	res_full: u32

	switch size {
		case .Word:
			op2 := cpu_dp_fetch_word(cpu, r2.full)
			res_full = u32(r1.full) + u32(op2) + carry
			res := u16(res_full)

			flags_old^ = flags_new + compute_flags_add(size, res_full, r1.full, op2)
			r1.full = res

		case .Byte:
			op2 := cpu_dp_fetch_byte(cpu, r2.full)
			res_full = u32(r1.low) + u32(op2) + carry
			res := u8(res_full)

			flags_old^ = flags_new + compute_flags_add(size, res_full, u16(r1.low), u16(op2))
			r1.low = res
	}
	cpu.cycle_delta += 1
}

exec_add_reg_immptr :: proc(size: SizeMode, reg1: u8, use_carry: bool, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	immptr := cpu_pc_fetch_word(cpu)
	flags_old := cpu_get_flags(cpu)
	carry: u32 = !use_carry ? 0 : (.Carry in (flags_old^) ? 1 : 0)
	flags_new := (flags_old^) & {.IgnoreInterrupts}
	res_full: u32

	switch size {
		case .Word:
			op2 := cpu_dp_fetch_word(cpu, immptr)
			res_full = u32(r1.full) + u32(op2) + carry
			res := u16(res_full)

			flags_old^ = flags_new + compute_flags_add(size, res_full, r1.full, op2)
			r1.full = res

		case .Byte:
			op2 := cpu_dp_fetch_byte(cpu, immptr)
			res_full = u32(r1.low) + u32(op2) + carry
			res := u8(res_full)

			flags_old^ = flags_new + compute_flags_add(size, res_full, u16(r1.low), u16(op2))
			r1.low = res
	}
	cpu.cycle_delta += 1
}

exec_add_reg_regptr_immoffs :: proc(size: SizeMode, reg1, reg2: u8, use_carry: bool, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)
	offs := cpu_pc_fetch_word(cpu)
	flags_old := cpu_get_flags(cpu)
	carry: u32 = !use_carry ? 0 : (.Carry in (flags_old^) ? 1 : 0)
	flags_new := (flags_old^) & {.IgnoreInterrupts}
	res_full: u32

	switch size {
		case .Word:
			op2 := cpu_dp_fetch_word(cpu, u16(i16(r2.full) + i16(offs)))
			res_full = u32(r1.full) + u32(op2) + carry
			res := u16(res_full)

			flags_old^ = flags_new + compute_flags_add(size, res_full, r1.full, op2)
			r1.full = res

		case .Byte:
			op2 := cpu_dp_fetch_byte(cpu, u16(i16(r2.full) + i16(offs)))
			res_full = u32(r1.low) + u32(op2) + carry
			res := u8(res_full)

			flags_old^ = flags_new + compute_flags_add(size, res_full, u16(r1.low), u16(op2))
			r1.low = res
	}
	cpu.cycle_delta += 1
}

exec_add_reg_regptr_regoffs :: proc(size: SizeMode, reg1, reg2: u8, use_carry: bool, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)
	r3 := cpu_get_reg(cpu, cpu_pc_fetch_byte(cpu) & 0b111)
	offs := r3.full
	flags_old := cpu_get_flags(cpu)
	carry: u32 = !use_carry ? 0 : (.Carry in (flags_old^) ? 1 : 0)
	flags_new := (flags_old^) & {.IgnoreInterrupts}
	res_full: u32

	switch size {
		case .Word:
			op2 := cpu_dp_fetch_word(cpu, u16(i16(r2.full) + i16(offs)))
			res_full = u32(r1.full) + u32(op2) + carry
			res := u16(res_full)

			flags_old^ = flags_new + compute_flags_add(size, res_full, r1.full, op2)
			r1.full = res

		case .Byte:
			op2 := cpu_dp_fetch_byte(cpu, u16(i16(r2.full) + i16(offs)))
			res_full = u32(r1.low) + u32(op2) + carry
			res := u8(res_full)

			flags_old^ = flags_new + compute_flags_add(size, res_full, u16(r1.low), u16(op2))
			r1.low = res
	}
	cpu.cycle_delta += 1
}

compute_flags_sub :: proc(size: SizeMode, accum: u32, op1, op2: u16) -> FlagRegister {
	out: FlagRegister
	if size == .Word {
		truncated := u16(accum)

		if truncated == 0 do out += {.Zero}
		if truncated & 0x8000 != 0 do out += {.Negative}
		if accum > 0xFFFF do out += {.Carry}
		v_test := (op1 ~ op2) & (op1 ~ truncated)
		if v_test & 0x8000 != 0 do out += {.Overflow}
	} else {
		op1 := u8(op1)
		op2 := u8(op2)
		truncated := u8(accum)

		if truncated == 0 do out += {.Zero}
		if truncated & 0x80 != 0 do out += {.Negative}
		if accum > 0xFF do out += {.Carry}
		v_test := (op1 ~ op2) & (op1 ~ truncated)
		if v_test & 0x80 != 0 do out += {.Overflow}
	}
	return out
}

exec_sub_reg_reg :: proc(size: SizeMode, reg1, reg2: u8, use_borrow, discard: bool, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)
	flags_old := cpu_get_flags(cpu)
	carry: u32 = !use_borrow ? 0 : (.Carry in (flags_old^) ? 1 : 0)
	flags_new := (flags_old^) & {.IgnoreInterrupts}
	res_full: u32

	switch size {
		case .Word:
			res_full = u32(r1.full) - u32(r2.full) - carry
			res := u16(res_full)
			flags_old^ = flags_new + compute_flags_sub(size, res_full, r1.full, r2.full)
			if !discard do r1.full = res

		case .Byte:
			res_full = u32(r1.low) - u32(r2.low) - carry
			res := u8(res_full)
			flags_old^ = flags_new + compute_flags_sub(size, res_full, u16(r1.low), u16(r2.low))
			if !discard do r1.low = res
	}
	cpu.cycle_delta += 1
}

exec_sub_reg_imm :: proc(size: SizeMode, reg1: u8, use_borrow, discard: bool, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	flags_old := cpu_get_flags(cpu)
	carry: u32 = !use_borrow ? 0 : (.Carry in (flags_old^) ? 1 : 0)
	flags_new := (flags_old^) & {.IgnoreInterrupts}
	res_full: u32

	switch size {
		case .Word:
			op2 := cpu_pc_fetch_word(cpu)
			res_full = u32(r1.full) - u32(op2) - carry
			res := u16(res_full)

			flags_old^ = flags_new + compute_flags_sub(size, res_full, r1.full, op2)
			if !discard do r1.full = res

		case .Byte:
			op2 := cpu_pc_fetch_byte(cpu)
			res_full = u32(r1.low) - u32(op2) - carry
			res := u8(res_full)

			flags_old^ = flags_new + compute_flags_sub(size, res_full, u16(r1.low), u16(op2))
			if !discard do r1.low = res
	}
	cpu.cycle_delta += 1
}

exec_sub_reg_regptr :: proc(size: SizeMode, reg1, reg2: u8, use_borrow, discard: bool, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)
	flags_old := cpu_get_flags(cpu)
	carry: u32 = !use_borrow ? 0 : (.Carry in (flags_old^) ? 1 : 0)
	flags_new := (flags_old^) & {.IgnoreInterrupts}
	res_full: u32

	switch size {
		case .Word:
			op2 := cpu_dp_fetch_word(cpu, r2.full)
			res_full = u32(r1.full) - u32(op2) - carry
			res := u16(res_full)

			flags_old^ = flags_new + compute_flags_sub(size, res_full, r1.full, op2)
			if !discard do r1.full = res

		case .Byte:
			op2 := cpu_dp_fetch_byte(cpu, r2.full)
			res_full = u32(r1.low) - u32(op2) - carry
			res := u8(res_full)

			flags_old^ = flags_new + compute_flags_sub(size, res_full, u16(r1.low), u16(op2))
			if !discard do r1.low = res
	}
	cpu.cycle_delta += 1
}

exec_sub_reg_immptr :: proc(size: SizeMode, reg1: u8, use_borrow, discard: bool, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	immptr := cpu_pc_fetch_word(cpu)
	flags_old := cpu_get_flags(cpu)
	carry: u32 = !use_borrow ? 0 : (.Carry in (flags_old^) ? 1 : 0)
	flags_new := (flags_old^) & {.IgnoreInterrupts}
	res_full: u32

	switch size {
		case .Word:
			op2 := cpu_dp_fetch_word(cpu, immptr)
			res_full = u32(r1.full) - u32(op2) - carry
			res := u16(res_full)

			flags_old^ = flags_new + compute_flags_sub(size, res_full, r1.full, op2)
			if !discard do r1.full = res

		case .Byte:
			op2 := cpu_dp_fetch_byte(cpu, immptr)
			res_full = u32(r1.low) - u32(op2) - carry
			res := u8(res_full)

			flags_old^ = flags_new + compute_flags_sub(size, res_full, u16(r1.low), u16(op2))
			if !discard do r1.low = res
	}
	cpu.cycle_delta += 1
}

exec_sub_reg_regptr_immoffs :: proc(
	size: SizeMode,
	reg1, reg2: u8,
	use_borrow, discard: bool,
	cpu: ^Cpu,
) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)
	offs := cpu_pc_fetch_word(cpu)
	flags_old := cpu_get_flags(cpu)
	carry: u32 = !use_borrow ? 0 : (.Carry in (flags_old^) ? 1 : 0)
	flags_new := (flags_old^) & {.IgnoreInterrupts}
	res_full: u32

	switch size {
		case .Word:
			op2 := cpu_dp_fetch_word(cpu, u16(i16(r2.full) + i16(offs)))
			res_full = u32(r1.full) - u32(op2) - carry
			res := u16(res_full)

			flags_old^ = flags_new + compute_flags_sub(size, res_full, r1.full, op2)
			if !discard do r1.full = res

		case .Byte:
			op2 := cpu_dp_fetch_byte(cpu, u16(i16(r2.full) + i16(offs)))
			res_full = u32(r1.low) - u32(op2) - carry
			res := u8(res_full)

			flags_old^ = flags_new + compute_flags_sub(size, res_full, u16(r1.low), u16(op2))
			if !discard do r1.low = res
	}
	cpu.cycle_delta += 1
}

exec_sub_reg_regptr_regoffs :: proc(
	size: SizeMode,
	reg1, reg2: u8,
	use_borrow, discard: bool,
	cpu: ^Cpu,
) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)
	r3 := cpu_get_reg(cpu, cpu_pc_fetch_byte(cpu) & 0b111)
	offs := r3.full
	flags_old := cpu_get_flags(cpu)
	carry: u32 = !use_borrow ? 0 : (.Carry in (flags_old^) ? 1 : 0)
	flags_new := (flags_old^) & {.IgnoreInterrupts}
	res_full: u32

	switch size {
		case .Word:
			op2 := cpu_dp_fetch_word(cpu, u16(i16(r2.full) + i16(offs)))
			res_full = u32(r1.full) - u32(op2) - carry
			res := u16(res_full)

			flags_old^ = flags_new + compute_flags_sub(size, res_full, r1.full, op2)
			if !discard do r1.full = res

		case .Byte:
			op2 := cpu_dp_fetch_byte(cpu, u16(i16(r2.full) + i16(offs)))
			res_full = u32(r1.low) - u32(op2) - carry
			res := u8(res_full)

			flags_old^ = flags_new + compute_flags_sub(size, res_full, u16(r1.low), u16(op2))
			if !discard do r1.low = res
	}
	cpu.cycle_delta += 1
}

compute_flags_mul :: proc(size: SizeMode, result, hi: u16, signed: bool) -> FlagRegister {
	out: FlagRegister

	if size == .Word {
		if result == 0 do out += {.Zero}
		if result & 0x8000 != 0 do out += {.Negative}
		overflow := signed ? hi != (result & 0x8000 != 0 ? 0xFFFF : 0) : hi != 0
		if overflow do out += {.Carry, .Overflow}
	} else {
		result := u8(result)
		hi := u8(hi)
		if result == 0 do out += {.Zero}
		if result & 0x80 != 0 do out += {.Negative}
		overflow := signed ? hi != (result & 0x80 != 0 ? 0xFF : 0) : hi != 0
		if overflow do out += {.Carry, .Overflow}
	}

	return out
}

exec_mulu_reg_reg :: proc(size: SizeMode, reg1, reg2: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)
	flags_old := cpu_get_flags(cpu)
	flags_new := (flags_old^) & {.IgnoreInterrupts}

	switch size {
		case .Word:
			product := u32(r1.full) * u32(r2.full)
			res := u16(product)
			hi := u16(product >> 16)

			cpu.hi.full = hi
			flags_old^ = flags_new + compute_flags_mul(size, res, hi, false)
			r1.full = res

		case .Byte:
			product := u32(r1.low) * u32(r2.low)
			res := u8(product)
			hi := u8(product >> 8)

			cpu.hi.low = hi
			cpu.hi.high = 0
			flags_old^ = flags_new + compute_flags_mul(size, u16(res), u16(hi), false)
			r1.low = res
	}
	cpu.cycle_delta += 6
}

exec_mulu_reg_imm :: proc(size: SizeMode, reg1: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	flags_old := cpu_get_flags(cpu)
	flags_new := (flags_old^) & {.IgnoreInterrupts}

	switch size {
		case .Word:
			op2 := cpu_pc_fetch_word(cpu)
			product := u32(r1.full) * u32(op2)
			res := u16(product)
			hi := u16(product >> 16)

			cpu.hi.full = hi
			flags_old^ = flags_new + compute_flags_mul(size, res, hi, false)
			r1.full = res

		case .Byte:
			op2 := cpu_pc_fetch_byte(cpu)
			product := u32(r1.low) * u32(op2)
			res := u8(product)
			hi := u8(product >> 8)

			cpu.hi.low = hi
			cpu.hi.high = 0
			flags_old^ = flags_new + compute_flags_mul(size, u16(res), u16(hi), false)
			r1.low = res
	}
	cpu.cycle_delta += 6
}

exec_mulu_reg_regptr :: proc(size: SizeMode, reg1, reg2: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)
	flags_old := cpu_get_flags(cpu)
	flags_new := (flags_old^) & {.IgnoreInterrupts}

	switch size {
		case .Word:
			op2 := cpu_dp_fetch_word(cpu, r2.full)
			product := u32(r1.full) * u32(op2)
			res := u16(product)
			hi := u16(product >> 16)

			cpu.hi.full = hi
			flags_old^ = flags_new + compute_flags_mul(size, res, hi, false)
			r1.full = res

		case .Byte:
			op2 := cpu_dp_fetch_byte(cpu, r2.full)
			product := u32(r1.low) * u32(op2)
			res := u8(product)
			hi := u8(product >> 8)

			cpu.hi.low = hi
			cpu.hi.high = 0
			flags_old^ = flags_new + compute_flags_mul(size, u16(res), u16(hi), false)
			r1.low = res
	}
	cpu.cycle_delta += 6
}

exec_mulu_reg_immptr :: proc(size: SizeMode, reg1: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	immptr := cpu_pc_fetch_word(cpu)
	flags_old := cpu_get_flags(cpu)
	flags_new := (flags_old^) & {.IgnoreInterrupts}

	switch size {
		case .Word:
			op2 := cpu_dp_fetch_word(cpu, immptr)
			product := u32(r1.full) * u32(op2)
			res := u16(product)
			hi := u16(product >> 16)

			cpu.hi.full = hi
			flags_old^ = flags_new + compute_flags_mul(size, res, hi, false)
			r1.full = res

		case .Byte:
			op2 := cpu_dp_fetch_byte(cpu, immptr)
			product := u32(r1.low) * u32(op2)
			res := u8(product)
			hi := u8(product >> 8)

			cpu.hi.low = hi
			cpu.hi.high = 0
			flags_old^ = flags_new + compute_flags_mul(size, u16(res), u16(hi), false)
			r1.low = res
	}
	cpu.cycle_delta += 6
}

exec_mulu_reg_regptr_immoffs :: proc(size: SizeMode, reg1, reg2: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)
	offs := cpu_pc_fetch_word(cpu)
	addr := u16(i16(r2.full) + i16(offs))
	flags_old := cpu_get_flags(cpu)
	flags_new := (flags_old^) & {.IgnoreInterrupts}

	switch size {
		case .Word:
			op2 := cpu_dp_fetch_word(cpu, addr)
			product := u32(r1.full) * u32(op2)
			res := u16(product)
			hi := u16(product >> 16)

			cpu.hi.full = hi
			flags_old^ = flags_new + compute_flags_mul(size, res, hi, false)
			r1.full = res

		case .Byte:
			op2 := cpu_dp_fetch_byte(cpu, addr)
			product := u32(r1.low) * u32(op2)
			res := u8(product)
			hi := u8(product >> 8)

			cpu.hi.low = hi
			cpu.hi.high = 0
			flags_old^ = flags_new + compute_flags_mul(size, u16(res), u16(hi), false)
			r1.low = res
	}
	cpu.cycle_delta += 6
}

exec_mulu_reg_regptr_regoffs :: proc(size: SizeMode, reg1, reg2: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)
	r3 := cpu_get_reg(cpu, cpu_pc_fetch_byte(cpu) & 0b111)
	addr := u16(i16(r2.full) + i16(r3.full))
	flags_old := cpu_get_flags(cpu)
	flags_new := (flags_old^) & {.IgnoreInterrupts}

	switch size {
		case .Word:
			op2 := cpu_dp_fetch_word(cpu, addr)
			product := u32(r1.full) * u32(op2)
			res := u16(product)
			hi := u16(product >> 16)

			cpu.hi.full = hi
			flags_old^ = flags_new + compute_flags_mul(size, res, hi, false)
			r1.full = res

		case .Byte:
			op2 := cpu_dp_fetch_byte(cpu, addr)
			product := u32(r1.low) * u32(op2)
			res := u8(product)
			hi := u8(product >> 8)

			cpu.hi.low = hi
			cpu.hi.high = 0
			flags_old^ = flags_new + compute_flags_mul(size, u16(res), u16(hi), false)
			r1.low = res
	}
	cpu.cycle_delta += 6
}

compute_flags_div :: proc(size: SizeMode, result: u16, overflow: bool) -> FlagRegister {
	out: FlagRegister

	if size == .Word {
		if result == 0 do out += {.Zero}
		if result & 0x8000 != 0 do out += {.Negative}
		if overflow do out += {.Overflow}
	} else {
		result := u8(result)
		if result == 0 do out += {.Zero}
		if result & 0x80 != 0 do out += {.Negative}
		if overflow do out += {.Overflow}
	}

	return out
}

exec_divu_reg_reg :: proc(size: SizeMode, reg1, reg2: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)
	flags_old := cpu_get_flags(cpu)
	flags_new := (flags_old^) & {.IgnoreInterrupts}

	switch size {
		case .Word:
			if r2.full == 0 {
				cpu_trigger_interrupt(cpu, DIV0_VEC_IDX, true)
				return
			}
			quotient := u32(r1.full) / u32(r2.full)
			remainder := u32(r1.full) % u32(r2.full)

			cpu.hi.full = u16(remainder)
			flags_old^ = flags_new + compute_flags_div(size, u16(quotient), false)
			r1.full = u16(quotient)

		case .Byte:
			if r2.low == 0 {
				cpu_trigger_interrupt(cpu, DIV0_VEC_IDX, true)
				return
			}
			quotient := u16(r1.low) / u16(r2.low)
			remainder := u16(r1.low) % u16(r2.low)

			cpu.hi.low = u8(remainder)
			cpu.hi.high = 0
			flags_old^ = flags_new + compute_flags_div(size, quotient, false)
			r1.low = u8(quotient)
	}
	cpu.cycle_delta += 8
}

exec_divu_reg_imm :: proc(size: SizeMode, reg1: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	flags_old := cpu_get_flags(cpu)
	flags_new := (flags_old^) & {.IgnoreInterrupts}

	switch size {
		case .Word:
			op2 := cpu_pc_fetch_word(cpu)
			if op2 == 0 {
				cpu_trigger_interrupt(cpu, DIV0_VEC_IDX, true)
				return
			}
			quotient := u32(r1.full) / u32(op2)
			remainder := u32(r1.full) % u32(op2)

			cpu.hi.full = u16(remainder)
			flags_old^ = flags_new + compute_flags_div(size, u16(quotient), false)
			r1.full = u16(quotient)

		case .Byte:
			op2 := cpu_pc_fetch_byte(cpu)
			if op2 == 0 {
				cpu_trigger_interrupt(cpu, DIV0_VEC_IDX, true)
				return
			}
			quotient := u16(r1.low) / u16(op2)
			remainder := u16(r1.low) % u16(op2)

			cpu.hi.low = u8(remainder)
			cpu.hi.high = 0
			flags_old^ = flags_new + compute_flags_div(size, quotient, false)
			r1.low = u8(quotient)
	}
	cpu.cycle_delta += 8
}

exec_divu_reg_regptr :: proc(size: SizeMode, reg1, reg2: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)
	flags_old := cpu_get_flags(cpu)
	flags_new := (flags_old^) & {.IgnoreInterrupts}

	switch size {
		case .Word:
			op2 := cpu_dp_fetch_word(cpu, r2.full)
			if op2 == 0 {
				cpu_trigger_interrupt(cpu, DIV0_VEC_IDX, true)
				return
			}
			quotient := u32(r1.full) / u32(op2)
			remainder := u32(r1.full) % u32(op2)

			cpu.hi.full = u16(remainder)
			flags_old^ = flags_new + compute_flags_div(size, u16(quotient), false)
			r1.full = u16(quotient)

		case .Byte:
			op2 := cpu_dp_fetch_byte(cpu, r2.full)
			if op2 == 0 {
				cpu_trigger_interrupt(cpu, DIV0_VEC_IDX, true)
				return
			}
			quotient := u16(r1.low) / u16(op2)
			remainder := u16(r1.low) % u16(op2)

			cpu.hi.low = u8(remainder)
			cpu.hi.high = 0
			flags_old^ = flags_new + compute_flags_div(size, quotient, false)
			r1.low = u8(quotient)
	}
	cpu.cycle_delta += 8
}

exec_divu_reg_immptr :: proc(size: SizeMode, reg1: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	immptr := cpu_pc_fetch_word(cpu)
	flags_old := cpu_get_flags(cpu)
	flags_new := (flags_old^) & {.IgnoreInterrupts}

	switch size {
		case .Word:
			op2 := cpu_dp_fetch_word(cpu, immptr)
			if op2 == 0 {
				cpu_trigger_interrupt(cpu, DIV0_VEC_IDX, true)
				return
			}
			quotient := u32(r1.full) / u32(op2)
			remainder := u32(r1.full) % u32(op2)

			cpu.hi.full = u16(remainder)
			flags_old^ = flags_new + compute_flags_div(size, u16(quotient), false)
			r1.full = u16(quotient)

		case .Byte:
			op2 := cpu_dp_fetch_byte(cpu, immptr)
			if op2 == 0 {
				cpu_trigger_interrupt(cpu, DIV0_VEC_IDX, true)
				return
			}
			quotient := u16(r1.low) / u16(op2)
			remainder := u16(r1.low) % u16(op2)

			cpu.hi.low = u8(remainder)
			cpu.hi.high = 0
			flags_old^ = flags_new + compute_flags_div(size, quotient, false)
			r1.low = u8(quotient)
	}
	cpu.cycle_delta += 8
}

exec_divu_reg_regptr_immoffs :: proc(size: SizeMode, reg1, reg2: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)
	offs := cpu_pc_fetch_word(cpu)
	addr := u16(i16(r2.full) + i16(offs))
	flags_old := cpu_get_flags(cpu)
	flags_new := (flags_old^) & {.IgnoreInterrupts}

	switch size {
		case .Word:
			op2 := cpu_dp_fetch_word(cpu, addr)
			if op2 == 0 {
				cpu_trigger_interrupt(cpu, DIV0_VEC_IDX, true)
				return
			}
			quotient := u32(r1.full) / u32(op2)
			remainder := u32(r1.full) % u32(op2)

			cpu.hi.full = u16(remainder)
			flags_old^ = flags_new + compute_flags_div(size, u16(quotient), false)
			r1.full = u16(quotient)

		case .Byte:
			op2 := cpu_dp_fetch_byte(cpu, addr)
			if op2 == 0 {
				cpu_trigger_interrupt(cpu, DIV0_VEC_IDX, true)
				return
			}
			quotient := u16(r1.low) / u16(op2)
			remainder := u16(r1.low) % u16(op2)

			cpu.hi.low = u8(remainder)
			cpu.hi.high = 0
			flags_old^ = flags_new + compute_flags_div(size, quotient, false)
			r1.low = u8(quotient)
	}
	cpu.cycle_delta += 8
}

exec_divu_reg_regptr_regoffs :: proc(size: SizeMode, reg1, reg2: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)
	r3 := cpu_get_reg(cpu, cpu_pc_fetch_byte(cpu) & 0b111)
	addr := u16(i16(r2.full) + i16(r3.full))
	flags_old := cpu_get_flags(cpu)
	flags_new := (flags_old^) & {.IgnoreInterrupts}

	switch size {
		case .Word:
			op2 := cpu_dp_fetch_word(cpu, addr)
			if op2 == 0 {
				cpu_trigger_interrupt(cpu, DIV0_VEC_IDX, true)
				return
			}
			quotient := u32(r1.full) / u32(op2)
			remainder := u32(r1.full) % u32(op2)

			cpu.hi.full = u16(remainder)
			flags_old^ = flags_new + compute_flags_div(size, u16(quotient), false)
			r1.full = u16(quotient)

		case .Byte:
			op2 := cpu_dp_fetch_byte(cpu, addr)
			if op2 == 0 {
				cpu_trigger_interrupt(cpu, DIV0_VEC_IDX, true)
				return
			}
			quotient := u16(r1.low) / u16(op2)
			remainder := u16(r1.low) % u16(op2)

			cpu.hi.low = u8(remainder)
			cpu.hi.high = 0
			flags_old^ = flags_new + compute_flags_div(size, quotient, false)
			r1.low = u8(quotient)
	}
	cpu.cycle_delta += 8
}

exec_muls_reg_reg :: proc(size: SizeMode, reg1, reg2: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)
	flags_old := cpu_get_flags(cpu)
	flags_new := (flags_old^) & {.IgnoreInterrupts}

	switch size {
		case .Word:
			product := i32(i16(r1.full)) * i32(i16(r2.full))
			res := u16(product)
			hi := u16(u32(product >> 16))

			cpu.hi.full = hi
			flags_old^ = flags_new + compute_flags_mul(size, res, hi, true)
			r1.full = res

		case .Byte:
			product := i32(i8(r1.low)) * i32(i8(r2.low))
			res := u8(product)
			hi := u8(product >> 8)

			cpu.hi.low = hi
			cpu.hi.high = 0
			flags_old^ = flags_new + compute_flags_mul(size, u16(res), u16(hi), true)
			r1.low = res
	}
	cpu.cycle_delta += 6
}

exec_muls_reg_imm :: proc(size: SizeMode, reg1: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	flags_old := cpu_get_flags(cpu)
	flags_new := (flags_old^) & {.IgnoreInterrupts}

	switch size {
		case .Word:
			op2 := cpu_pc_fetch_word(cpu)
			product := i32(i16(r1.full)) * i32(i16(op2))
			res := u16(product)
			hi := u16(u32(product >> 16))

			cpu.hi.full = hi
			flags_old^ = flags_new + compute_flags_mul(size, res, hi, true)
			r1.full = res

		case .Byte:
			op2 := cpu_pc_fetch_byte(cpu)
			product := i32(i8(r1.low)) * i32(i8(op2))
			res := u8(product)
			hi := u8(product >> 8)

			cpu.hi.low = hi
			cpu.hi.high = 0
			flags_old^ = flags_new + compute_flags_mul(size, u16(res), u16(hi), true)
			r1.low = res
	}
	cpu.cycle_delta += 6
}

exec_muls_reg_regptr :: proc(size: SizeMode, reg1, reg2: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)
	flags_old := cpu_get_flags(cpu)
	flags_new := (flags_old^) & {.IgnoreInterrupts}

	switch size {
		case .Word:
			op2 := cpu_dp_fetch_word(cpu, r2.full)
			product := i32(i16(r1.full)) * i32(i16(op2))
			res := u16(product)
			hi := u16(u32(product >> 16))

			cpu.hi.full = hi
			flags_old^ = flags_new + compute_flags_mul(size, res, hi, true)
			r1.full = res

		case .Byte:
			op2 := cpu_dp_fetch_byte(cpu, r2.full)
			product := i32(i8(r1.low)) * i32(i8(op2))
			res := u8(product)
			hi := u8(product >> 8)

			cpu.hi.low = hi
			cpu.hi.high = 0
			flags_old^ = flags_new + compute_flags_mul(size, u16(res), u16(hi), true)
			r1.low = res
	}
	cpu.cycle_delta += 6
}

exec_muls_reg_immptr :: proc(size: SizeMode, reg1: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	immptr := cpu_pc_fetch_word(cpu)
	flags_old := cpu_get_flags(cpu)
	flags_new := (flags_old^) & {.IgnoreInterrupts}

	switch size {
		case .Word:
			op2 := cpu_dp_fetch_word(cpu, immptr)
			product := i32(i16(r1.full)) * i32(i16(op2))
			res := u16(product)
			hi := u16(u32(product >> 16))

			cpu.hi.full = hi
			flags_old^ = flags_new + compute_flags_mul(size, res, hi, true)
			r1.full = res

		case .Byte:
			op2 := cpu_dp_fetch_byte(cpu, immptr)
			product := i32(i8(r1.low)) * i32(i8(op2))
			res := u8(product)
			hi := u8(product >> 8)

			cpu.hi.low = hi
			cpu.hi.high = 0
			flags_old^ = flags_new + compute_flags_mul(size, u16(res), u16(hi), true)
			r1.low = res
	}
	cpu.cycle_delta += 6
}

exec_muls_reg_regptr_immoffs :: proc(size: SizeMode, reg1, reg2: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)
	offs := cpu_pc_fetch_word(cpu)
	addr := u16(i16(r2.full) + i16(offs))
	flags_old := cpu_get_flags(cpu)
	flags_new := (flags_old^) & {.IgnoreInterrupts}

	switch size {
		case .Word:
			op2 := cpu_dp_fetch_word(cpu, addr)
			product := i32(i16(r1.full)) * i32(i16(op2))
			res := u16(product)
			hi := u16(u32(product >> 16))

			cpu.hi.full = hi
			flags_old^ = flags_new + compute_flags_mul(size, res, hi, true)
			r1.full = res

		case .Byte:
			op2 := cpu_dp_fetch_byte(cpu, addr)
			product := i32(i8(r1.low)) * i32(i8(op2))
			res := u8(product)
			hi := u8(product >> 8)

			cpu.hi.low = hi
			cpu.hi.high = 0
			flags_old^ = flags_new + compute_flags_mul(size, u16(res), u16(hi), true)
			r1.low = res
	}
	cpu.cycle_delta += 6
}

exec_muls_reg_regptr_regoffs :: proc(size: SizeMode, reg1, reg2: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)
	r3 := cpu_get_reg(cpu, cpu_pc_fetch_byte(cpu) & 0b111)
	addr := u16(i16(r2.full) + i16(r3.full))
	flags_old := cpu_get_flags(cpu)
	flags_new := (flags_old^) & {.IgnoreInterrupts}

	switch size {
		case .Word:
			op2 := cpu_dp_fetch_word(cpu, addr)
			product := i32(i16(r1.full)) * i32(i16(op2))
			res := u16(product)
			hi := u16(u32(product >> 16))

			cpu.hi.full = hi
			flags_old^ = flags_new + compute_flags_mul(size, res, hi, true)
			r1.full = res

		case .Byte:
			op2 := cpu_dp_fetch_byte(cpu, addr)
			product := i32(i8(r1.low)) * i32(i8(op2))
			res := u8(product)
			hi := u8(product >> 8)

			cpu.hi.low = hi
			cpu.hi.high = 0
			flags_old^ = flags_new + compute_flags_mul(size, u16(res), u16(hi), true)
			r1.low = res
	}
	cpu.cycle_delta += 6
}

exec_divs_reg_reg :: proc(size: SizeMode, reg1, reg2: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)
	flags_old := cpu_get_flags(cpu)
	flags_new := (flags_old^) & {.IgnoreInterrupts}

	switch size {
		case .Word:
			if r2.full == 0 {
				cpu_trigger_interrupt(cpu, DIV0_VEC_IDX, true)
				return
			}
			a := i32(i16(r1.full))
			b := i32(i16(r2.full))
			overflow := a == -32768 && b == -1
			quotient := a / b
			remainder := a % b

			cpu.hi.full = u16(remainder)
			flags_old^ = flags_new + compute_flags_div(size, u16(quotient), overflow)
			r1.full = u16(quotient)

		case .Byte:
			if r2.low == 0 {
				cpu_trigger_interrupt(cpu, DIV0_VEC_IDX, true)
				return
			}
			a := i32(i8(r1.low))
			b := i32(i8(r2.low))
			overflow := a == -128 && b == -1
			quotient := a / b
			remainder := a % b

			cpu.hi.low = u8(remainder)
			cpu.hi.high = 0
			flags_old^ = flags_new + compute_flags_div(size, u16(quotient), overflow)
			r1.low = u8(quotient)
	}
	cpu.cycle_delta += 8
}

exec_divs_reg_imm :: proc(size: SizeMode, reg1: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	flags_old := cpu_get_flags(cpu)
	flags_new := (flags_old^) & {.IgnoreInterrupts}

	switch size {
		case .Word:
			op2 := cpu_pc_fetch_word(cpu)
			if op2 == 0 {
				cpu_trigger_interrupt(cpu, DIV0_VEC_IDX, true)
				return
			}
			a := i32(i16(r1.full))
			b := i32(i16(op2))
			overflow := a == -32768 && b == -1
			quotient := a / b
			remainder := a % b

			cpu.hi.full = u16(remainder)
			flags_old^ = flags_new + compute_flags_div(size, u16(quotient), overflow)
			r1.full = u16(quotient)

		case .Byte:
			op2 := cpu_pc_fetch_byte(cpu)
			if op2 == 0 {
				cpu_trigger_interrupt(cpu, DIV0_VEC_IDX, true)
				return
			}
			a := i32(i8(r1.low))
			b := i32(i8(op2))
			overflow := a == -128 && b == -1
			quotient := a / b
			remainder := a % b

			cpu.hi.low = u8(remainder)
			cpu.hi.high = 0
			flags_old^ = flags_new + compute_flags_div(size, u16(quotient), overflow)
			r1.low = u8(quotient)
	}
	cpu.cycle_delta += 8
}

exec_divs_reg_regptr :: proc(size: SizeMode, reg1, reg2: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)
	flags_old := cpu_get_flags(cpu)
	flags_new := (flags_old^) & {.IgnoreInterrupts}

	switch size {
		case .Word:
			op2 := cpu_dp_fetch_word(cpu, r2.full)
			if op2 == 0 {
				cpu_trigger_interrupt(cpu, DIV0_VEC_IDX, true)
				return
			}
			a := i32(i16(r1.full))
			b := i32(i16(op2))
			overflow := a == -32768 && b == -1
			quotient := a / b
			remainder := a % b

			cpu.hi.full = u16(remainder)
			flags_old^ = flags_new + compute_flags_div(size, u16(quotient), overflow)
			r1.full = u16(quotient)

		case .Byte:
			op2 := cpu_dp_fetch_byte(cpu, r2.full)
			if op2 == 0 {
				cpu_trigger_interrupt(cpu, DIV0_VEC_IDX, true)
				return
			}
			a := i32(i8(r1.low))
			b := i32(i8(op2))
			overflow := a == -128 && b == -1
			quotient := a / b
			remainder := a % b

			cpu.hi.low = u8(remainder)
			cpu.hi.high = 0
			flags_old^ = flags_new + compute_flags_div(size, u16(quotient), overflow)
			r1.low = u8(quotient)
	}
	cpu.cycle_delta += 8
}

exec_divs_reg_immptr :: proc(size: SizeMode, reg1: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	immptr := cpu_pc_fetch_word(cpu)
	flags_old := cpu_get_flags(cpu)
	flags_new := (flags_old^) & {.IgnoreInterrupts}

	switch size {
		case .Word:
			op2 := cpu_dp_fetch_word(cpu, immptr)
			if op2 == 0 {
				cpu_trigger_interrupt(cpu, DIV0_VEC_IDX, true)
				return
			}
			a := i32(i16(r1.full))
			b := i32(i16(op2))
			overflow := a == -32768 && b == -1
			quotient := a / b
			remainder := a % b

			cpu.hi.full = u16(remainder)
			flags_old^ = flags_new + compute_flags_div(size, u16(quotient), overflow)
			r1.full = u16(quotient)

		case .Byte:
			op2 := cpu_dp_fetch_byte(cpu, immptr)
			if op2 == 0 {
				cpu_trigger_interrupt(cpu, DIV0_VEC_IDX, true)
				return
			}
			a := i32(i8(r1.low))
			b := i32(i8(op2))
			overflow := a == -128 && b == -1
			quotient := a / b
			remainder := a % b

			cpu.hi.low = u8(remainder)
			cpu.hi.high = 0
			flags_old^ = flags_new + compute_flags_div(size, u16(quotient), overflow)
			r1.low = u8(quotient)
	}
	cpu.cycle_delta += 8
}

exec_divs_reg_regptr_immoffs :: proc(size: SizeMode, reg1, reg2: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)
	offs := cpu_pc_fetch_word(cpu)
	addr := u16(i16(r2.full) + i16(offs))
	flags_old := cpu_get_flags(cpu)
	flags_new := (flags_old^) & {.IgnoreInterrupts}

	switch size {
		case .Word:
			op2 := cpu_dp_fetch_word(cpu, addr)
			if op2 == 0 {
				cpu_trigger_interrupt(cpu, DIV0_VEC_IDX, true)
				return
			}
			a := i32(i16(r1.full))
			b := i32(i16(op2))
			overflow := a == -32768 && b == -1
			quotient := a / b
			remainder := a % b

			cpu.hi.full = u16(remainder)
			flags_old^ = flags_new + compute_flags_div(size, u16(quotient), overflow)
			r1.full = u16(quotient)

		case .Byte:
			op2 := cpu_dp_fetch_byte(cpu, addr)
			if op2 == 0 {
				cpu_trigger_interrupt(cpu, DIV0_VEC_IDX, true)
				return
			}
			a := i32(i8(r1.low))
			b := i32(i8(op2))
			overflow := a == -128 && b == -1
			quotient := a / b
			remainder := a % b

			cpu.hi.low = u8(remainder)
			cpu.hi.high = 0
			flags_old^ = flags_new + compute_flags_div(size, u16(quotient), overflow)
			r1.low = u8(quotient)
	}
	cpu.cycle_delta += 8
}

exec_divs_reg_regptr_regoffs :: proc(size: SizeMode, reg1, reg2: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)
	r3 := cpu_get_reg(cpu, cpu_pc_fetch_byte(cpu) & 0b111)
	addr := u16(i16(r2.full) + i16(r3.full))
	flags_old := cpu_get_flags(cpu)
	flags_new := (flags_old^) & {.IgnoreInterrupts}

	switch size {
		case .Word:
			op2 := cpu_dp_fetch_word(cpu, addr)
			if op2 == 0 {
				cpu_trigger_interrupt(cpu, DIV0_VEC_IDX, true)
				return
			}
			a := i32(i16(r1.full))
			b := i32(i16(op2))
			overflow := a == -32768 && b == -1
			quotient := a / b
			remainder := a % b

			cpu.hi.full = u16(remainder)
			flags_old^ = flags_new + compute_flags_div(size, u16(quotient), overflow)
			r1.full = u16(quotient)

		case .Byte:
			op2 := cpu_dp_fetch_byte(cpu, addr)
			if op2 == 0 {
				cpu_trigger_interrupt(cpu, DIV0_VEC_IDX, true)
				return
			}
			a := i32(i8(r1.low))
			b := i32(i8(op2))
			overflow := a == -128 && b == -1
			quotient := a / b
			remainder := a % b

			cpu.hi.low = u8(remainder)
			cpu.hi.high = 0
			flags_old^ = flags_new + compute_flags_div(size, u16(quotient), overflow)
			r1.low = u8(quotient)
	}
	cpu.cycle_delta += 8
}
