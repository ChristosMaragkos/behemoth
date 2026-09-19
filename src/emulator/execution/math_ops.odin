package execution

import "../../shared"

compute_flags_add_l :: proc(accum: u64, op1, op2: u32) -> FlagRegister {
	out: FlagRegister
	truncated := u32(accum)
	if truncated == 0 do out += {.Zero}
	if truncated & 0x80000000 != 0 do out += {.Negative}
	if accum > 0xFFFFFFFF do out += {.Carry}
	v_test := (op1 ~ truncated) & (op2 ~ truncated)
	if v_test & 0x80000000 != 0 do out += {.Overflow}
	return out
}

compute_flags_sub_l :: proc(accum: u64, op1, op2: u32) -> FlagRegister {
	out: FlagRegister
	truncated := u32(accum)
	if truncated == 0 do out += {.Zero}
	if truncated & 0x80000000 != 0 do out += {.Negative}
	if accum > 0xFFFFFFFF do out += {.Carry}
	v_test := (op1 ~ op2) & (op1 ~ truncated)
	if v_test & 0x80000000 != 0 do out += {.Overflow}
	return out
}

compute_flags_add :: proc(size: shared.SizeMode, accum: u32, op1, op2: u16) -> FlagRegister {
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

exec_add_reg_reg :: proc(size: shared.SizeMode, reg1, reg2: u8, use_carry: bool, cpu: ^Cpu) {
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

			if reg1 == SP_REG_IDX && res_full > 0xFFFF {
				cpu_trigger_interrupt(cpu, STACK_UDF_VEC_IDX, true)
				return
			}

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

exec_add_reg_imm :: proc(size: shared.SizeMode, reg1: u8, use_carry: bool, cpu: ^Cpu) {
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

			if reg1 == SP_REG_IDX && res_full > 0xFFFF {
				cpu_trigger_interrupt(cpu, STACK_UDF_VEC_IDX, true)
				return
			}

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

exec_add_reg_regptr :: proc(size: shared.SizeMode, reg1, reg2: u8, use_carry: bool, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)
	flags_old := cpu_get_flags(cpu)
	carry: u32 = !use_carry ? 0 : (.Carry in (flags_old^) ? 1 : 0)
	flags_new := (flags_old^) & {.IgnoreInterrupts}
	res_full: u32

	switch size {
		case .Word:
			op2 := cpu_reg_fetch_word(cpu, reg2, r2.full)
			res_full = u32(r1.full) + u32(op2) + carry
			res := u16(res_full)

			if reg1 == SP_REG_IDX && res_full > 0xFFFF {
				cpu_trigger_interrupt(cpu, STACK_UDF_VEC_IDX, true)
				return
			}

			flags_old^ = flags_new + compute_flags_add(size, res_full, r1.full, op2)
			r1.full = res

		case .Byte:
			op2 := cpu_reg_fetch_byte(cpu, reg2, r2.full)
			res_full = u32(r1.low) + u32(op2) + carry
			res := u8(res_full)

			flags_old^ = flags_new + compute_flags_add(size, res_full, u16(r1.low), u16(op2))
			r1.low = res
	}
	cpu.cycle_delta += 1
}

exec_add_reg_immptr :: proc(size: shared.SizeMode, reg1: u8, use_carry: bool, cpu: ^Cpu) {
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

			if reg1 == SP_REG_IDX && res_full > 0xFFFF {
				cpu_trigger_interrupt(cpu, STACK_UDF_VEC_IDX, true)
				return
			}

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

exec_add_reg_regptr_immoffs :: proc(
	size: shared.SizeMode,
	reg1, reg2: u8,
	use_carry: bool,
	cpu: ^Cpu,
) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)
	offs := cpu_pc_fetch_word(cpu)
	flags_old := cpu_get_flags(cpu)
	carry: u32 = !use_carry ? 0 : (.Carry in (flags_old^) ? 1 : 0)
	flags_new := (flags_old^) & {.IgnoreInterrupts}
	res_full: u32

	switch size {
		case .Word:
			op2 := cpu_reg_fetch_word(cpu, reg2, u16(i16(r2.full) + i16(offs)))
			res_full = u32(r1.full) + u32(op2) + carry
			res := u16(res_full)

			if reg1 == SP_REG_IDX && res_full > 0xFFFF {
				cpu_trigger_interrupt(cpu, STACK_UDF_VEC_IDX, true)
				return
			}

			flags_old^ = flags_new + compute_flags_add(size, res_full, r1.full, op2)
			r1.full = res

		case .Byte:
			op2 := cpu_reg_fetch_byte(cpu, reg2, u16(i16(r2.full) + i16(offs)))
			res_full = u32(r1.low) + u32(op2) + carry
			res := u8(res_full)

			flags_old^ = flags_new + compute_flags_add(size, res_full, u16(r1.low), u16(op2))
			r1.low = res
	}
	cpu.cycle_delta += 1
}

exec_add_reg_regptr_regoffs :: proc(
	size: shared.SizeMode,
	reg1, reg2: u8,
	use_carry: bool,
	cpu: ^Cpu,
) {
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
			op2 := cpu_reg_fetch_word(cpu, reg2, u16(i16(r2.full) + i16(offs)))
			res_full = u32(r1.full) + u32(op2) + carry
			res := u16(res_full)

			if reg1 == SP_REG_IDX && res_full > 0xFFFF {
				cpu_trigger_interrupt(cpu, STACK_UDF_VEC_IDX, true)
				return
			}

			flags_old^ = flags_new + compute_flags_add(size, res_full, r1.full, op2)
			r1.full = res

		case .Byte:
			op2 := cpu_reg_fetch_byte(cpu, reg2, u16(i16(r2.full) + i16(offs)))
			res_full = u32(r1.low) + u32(op2) + carry
			res := u8(res_full)

			flags_old^ = flags_new + compute_flags_add(size, res_full, u16(r1.low), u16(op2))
			r1.low = res
	}
	cpu.cycle_delta += 1
}

compute_flags_sub :: proc(size: shared.SizeMode, accum: u32, op1, op2: u16) -> FlagRegister {
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

exec_sub_reg_reg :: proc(
	size: shared.SizeMode,
	reg1, reg2: u8,
	use_borrow, discard: bool,
	cpu: ^Cpu,
) {
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

			if !discard && reg1 == SP_REG_IDX && res_full > 0xFFFF {
				cpu_trigger_interrupt(cpu, STACK_OVF_VEC_IDX, true)
				return
			}

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

exec_sub_reg_imm :: proc(size: shared.SizeMode, reg1: u8, use_borrow, discard: bool, cpu: ^Cpu) {
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

			if !discard && reg1 == SP_REG_IDX && res_full > 0xFFFF {
				cpu_trigger_interrupt(cpu, STACK_OVF_VEC_IDX, true)
				return
			}

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

exec_sub_reg_regptr :: proc(
	size: shared.SizeMode,
	reg1, reg2: u8,
	use_borrow, discard: bool,
	cpu: ^Cpu,
) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)
	flags_old := cpu_get_flags(cpu)
	carry: u32 = !use_borrow ? 0 : (.Carry in (flags_old^) ? 1 : 0)
	flags_new := (flags_old^) & {.IgnoreInterrupts}
	res_full: u32

	switch size {
		case .Word:
			op2 := cpu_reg_fetch_word(cpu, reg2, r2.full)
			res_full = u32(r1.full) - u32(op2) - carry
			res := u16(res_full)

			if !discard && reg1 == SP_REG_IDX && res_full > 0xFFFF {
				cpu_trigger_interrupt(cpu, STACK_OVF_VEC_IDX, true)
				return
			}

			flags_old^ = flags_new + compute_flags_sub(size, res_full, r1.full, op2)
			if !discard do r1.full = res

		case .Byte:
			op2 := cpu_reg_fetch_byte(cpu, reg2, r2.full)
			res_full = u32(r1.low) - u32(op2) - carry
			res := u8(res_full)

			flags_old^ = flags_new + compute_flags_sub(size, res_full, u16(r1.low), u16(op2))
			if !discard do r1.low = res
	}
	cpu.cycle_delta += 1
}

exec_sub_reg_immptr :: proc(
	size: shared.SizeMode,
	reg1: u8,
	use_borrow, discard: bool,
	cpu: ^Cpu,
) {
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

			if !discard && reg1 == SP_REG_IDX && res_full > 0xFFFF {
				cpu_trigger_interrupt(cpu, STACK_OVF_VEC_IDX, true)
				return
			}

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
	size: shared.SizeMode,
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
			op2 := cpu_reg_fetch_word(cpu, reg2, u16(i16(r2.full) + i16(offs)))
			res_full = u32(r1.full) - u32(op2) - carry
			res := u16(res_full)

			if !discard && reg1 == SP_REG_IDX && res_full > 0xFFFF {
				cpu_trigger_interrupt(cpu, STACK_OVF_VEC_IDX, true)
				return
			}

			flags_old^ = flags_new + compute_flags_sub(size, res_full, r1.full, op2)
			if !discard do r1.full = res

		case .Byte:
			op2 := cpu_reg_fetch_byte(cpu, reg2, u16(i16(r2.full) + i16(offs)))
			res_full = u32(r1.low) - u32(op2) - carry
			res := u8(res_full)

			flags_old^ = flags_new + compute_flags_sub(size, res_full, u16(r1.low), u16(op2))
			if !discard do r1.low = res
	}
	cpu.cycle_delta += 1
}

exec_sub_reg_regptr_regoffs :: proc(
	size: shared.SizeMode,
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
			op2 := cpu_reg_fetch_word(cpu, reg2, u16(i16(r2.full) + i16(offs)))
			res_full = u32(r1.full) - u32(op2) - carry
			res := u16(res_full)

			if !discard && reg1 == SP_REG_IDX && res_full > 0xFFFF {
				cpu_trigger_interrupt(cpu, STACK_OVF_VEC_IDX, true)
				return
			}

			flags_old^ = flags_new + compute_flags_sub(size, res_full, r1.full, op2)
			if !discard do r1.full = res

		case .Byte:
			op2 := cpu_reg_fetch_byte(cpu, reg2, u16(i16(r2.full) + i16(offs)))
			res_full = u32(r1.low) - u32(op2) - carry
			res := u8(res_full)

			flags_old^ = flags_new + compute_flags_sub(size, res_full, u16(r1.low), u16(op2))
			if !discard do r1.low = res
	}
	cpu.cycle_delta += 1
}

compute_flags_mul :: proc(size: shared.SizeMode, result, hi: u16, signed: bool) -> FlagRegister {
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

exec_mulu_reg_reg :: proc(size: shared.SizeMode, reg1, reg2: u8, cpu: ^Cpu) {
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

exec_mulu_reg_imm :: proc(size: shared.SizeMode, reg1: u8, cpu: ^Cpu) {
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

exec_mulu_reg_regptr :: proc(size: shared.SizeMode, reg1, reg2: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)
	flags_old := cpu_get_flags(cpu)
	flags_new := (flags_old^) & {.IgnoreInterrupts}

	switch size {
		case .Word:
			op2 := cpu_reg_fetch_word(cpu, reg2, r2.full)
			product := u32(r1.full) * u32(op2)
			res := u16(product)
			hi := u16(product >> 16)

			cpu.hi.full = hi
			flags_old^ = flags_new + compute_flags_mul(size, res, hi, false)
			r1.full = res

		case .Byte:
			op2 := cpu_reg_fetch_byte(cpu, reg2, r2.full)
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

exec_mulu_reg_immptr :: proc(size: shared.SizeMode, reg1: u8, cpu: ^Cpu) {
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

exec_mulu_reg_regptr_immoffs :: proc(size: shared.SizeMode, reg1, reg2: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)
	offs := cpu_pc_fetch_word(cpu)
	addr := u16(i16(r2.full) + i16(offs))
	flags_old := cpu_get_flags(cpu)
	flags_new := (flags_old^) & {.IgnoreInterrupts}

	switch size {
		case .Word:
			op2 := cpu_reg_fetch_word(cpu, reg2, addr)
			product := u32(r1.full) * u32(op2)
			res := u16(product)
			hi := u16(product >> 16)

			cpu.hi.full = hi
			flags_old^ = flags_new + compute_flags_mul(size, res, hi, false)
			r1.full = res

		case .Byte:
			op2 := cpu_reg_fetch_byte(cpu, reg2, addr)
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

exec_mulu_reg_regptr_regoffs :: proc(size: shared.SizeMode, reg1, reg2: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)
	r3 := cpu_get_reg(cpu, cpu_pc_fetch_byte(cpu) & 0b111)
	addr := u16(i16(r2.full) + i16(r3.full))
	flags_old := cpu_get_flags(cpu)
	flags_new := (flags_old^) & {.IgnoreInterrupts}

	switch size {
		case .Word:
			op2 := cpu_reg_fetch_word(cpu, reg2, addr)
			product := u32(r1.full) * u32(op2)
			res := u16(product)
			hi := u16(product >> 16)

			cpu.hi.full = hi
			flags_old^ = flags_new + compute_flags_mul(size, res, hi, false)
			r1.full = res

		case .Byte:
			op2 := cpu_reg_fetch_byte(cpu, reg2, addr)
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

compute_flags_div :: proc(size: shared.SizeMode, result: u16, overflow: bool) -> FlagRegister {
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

compute_flags_logic :: proc(size: shared.SizeMode, result: u16) -> FlagRegister {
	out: FlagRegister

	if size == .Word {
		if result == 0 do out += {.Zero}
		if result & 0x8000 != 0 do out += {.Negative}
	} else {
		result := u8(result)
		if result == 0 do out += {.Zero}
		if result & 0x80 != 0 do out += {.Negative}
	}

	return out
}

compute_flags_shift :: proc(
	size: shared.SizeMode,
	result: u16,
	carry, overflow: bool,
) -> FlagRegister {
	out: FlagRegister

	if carry do out += {.Carry}
	if overflow do out += {.Overflow}

	if size == .Word {
		if result == 0 do out += {.Zero}
		if result & 0x8000 != 0 do out += {.Negative}
	} else {
		result := u8(result)
		if result == 0 do out += {.Zero}
		if result & 0x80 != 0 do out += {.Negative}
	}

	return out
}

compute_flags_neg :: proc(
	size: shared.SizeMode,
	res_full: u32,
	val, truncated: u16,
) -> FlagRegister {
	out: FlagRegister

	if size == .Word {
		if truncated == 0 do out += {.Zero}
		if truncated & 0x8000 != 0 do out += {.Negative}
		if res_full > 0xFFFF do out += {.Carry}
		v_test := (0 ~ val) & (0 ~ truncated)
		if v_test & 0x8000 != 0 do out += {.Overflow}
	} else {
		val := u8(val)
		truncated := u8(truncated)
		if truncated == 0 do out += {.Zero}
		if truncated & 0x80 != 0 do out += {.Negative}
		if res_full > 0xFF do out += {.Carry}
		v_test := (0 ~ val) & (0 ~ truncated)
		if v_test & 0x80 != 0 do out += {.Overflow}
	}

	return out
}

exec_divu_reg_reg :: proc(size: shared.SizeMode, reg1, reg2: u8, cpu: ^Cpu) {
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

exec_divu_reg_imm :: proc(size: shared.SizeMode, reg1: u8, cpu: ^Cpu) {
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

exec_divu_reg_regptr :: proc(size: shared.SizeMode, reg1, reg2: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)
	flags_old := cpu_get_flags(cpu)
	flags_new := (flags_old^) & {.IgnoreInterrupts}

	switch size {
		case .Word:
			op2 := cpu_reg_fetch_word(cpu, reg2, r2.full)
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
			op2 := cpu_reg_fetch_byte(cpu, reg2, r2.full)
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

exec_divu_reg_immptr :: proc(size: shared.SizeMode, reg1: u8, cpu: ^Cpu) {
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

exec_divu_reg_regptr_immoffs :: proc(size: shared.SizeMode, reg1, reg2: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)
	offs := cpu_pc_fetch_word(cpu)
	addr := u16(i16(r2.full) + i16(offs))
	flags_old := cpu_get_flags(cpu)
	flags_new := (flags_old^) & {.IgnoreInterrupts}

	switch size {
		case .Word:
			op2 := cpu_reg_fetch_word(cpu, reg2, addr)
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
			op2 := cpu_reg_fetch_byte(cpu, reg2, addr)
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

exec_divu_reg_regptr_regoffs :: proc(size: shared.SizeMode, reg1, reg2: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)
	r3 := cpu_get_reg(cpu, cpu_pc_fetch_byte(cpu) & 0b111)
	addr := u16(i16(r2.full) + i16(r3.full))
	flags_old := cpu_get_flags(cpu)
	flags_new := (flags_old^) & {.IgnoreInterrupts}

	switch size {
		case .Word:
			op2 := cpu_reg_fetch_word(cpu, reg2, addr)
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
			op2 := cpu_reg_fetch_byte(cpu, reg2, addr)
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

exec_muls_reg_reg :: proc(size: shared.SizeMode, reg1, reg2: u8, cpu: ^Cpu) {
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

exec_muls_reg_imm :: proc(size: shared.SizeMode, reg1: u8, cpu: ^Cpu) {
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

exec_muls_reg_regptr :: proc(size: shared.SizeMode, reg1, reg2: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)
	flags_old := cpu_get_flags(cpu)
	flags_new := (flags_old^) & {.IgnoreInterrupts}

	switch size {
		case .Word:
			op2 := cpu_reg_fetch_word(cpu, reg2, r2.full)
			product := i32(i16(r1.full)) * i32(i16(op2))
			res := u16(product)
			hi := u16(u32(product >> 16))

			cpu.hi.full = hi
			flags_old^ = flags_new + compute_flags_mul(size, res, hi, true)
			r1.full = res

		case .Byte:
			op2 := cpu_reg_fetch_byte(cpu, reg2, r2.full)
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

exec_muls_reg_immptr :: proc(size: shared.SizeMode, reg1: u8, cpu: ^Cpu) {
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

exec_muls_reg_regptr_immoffs :: proc(size: shared.SizeMode, reg1, reg2: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)
	offs := cpu_pc_fetch_word(cpu)
	addr := u16(i16(r2.full) + i16(offs))
	flags_old := cpu_get_flags(cpu)
	flags_new := (flags_old^) & {.IgnoreInterrupts}

	switch size {
		case .Word:
			op2 := cpu_reg_fetch_word(cpu, reg2, addr)
			product := i32(i16(r1.full)) * i32(i16(op2))
			res := u16(product)
			hi := u16(u32(product >> 16))

			cpu.hi.full = hi
			flags_old^ = flags_new + compute_flags_mul(size, res, hi, true)
			r1.full = res

		case .Byte:
			op2 := cpu_reg_fetch_byte(cpu, reg2, addr)
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

exec_muls_reg_regptr_regoffs :: proc(size: shared.SizeMode, reg1, reg2: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)
	r3 := cpu_get_reg(cpu, cpu_pc_fetch_byte(cpu) & 0b111)
	addr := u16(i16(r2.full) + i16(r3.full))
	flags_old := cpu_get_flags(cpu)
	flags_new := (flags_old^) & {.IgnoreInterrupts}

	switch size {
		case .Word:
			op2 := cpu_reg_fetch_word(cpu, reg2, addr)
			product := i32(i16(r1.full)) * i32(i16(op2))
			res := u16(product)
			hi := u16(u32(product >> 16))

			cpu.hi.full = hi
			flags_old^ = flags_new + compute_flags_mul(size, res, hi, true)
			r1.full = res

		case .Byte:
			op2 := cpu_reg_fetch_byte(cpu, reg2, addr)
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

exec_divs_reg_reg :: proc(size: shared.SizeMode, reg1, reg2: u8, cpu: ^Cpu) {
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

exec_divs_reg_imm :: proc(size: shared.SizeMode, reg1: u8, cpu: ^Cpu) {
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

exec_divs_reg_regptr :: proc(size: shared.SizeMode, reg1, reg2: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)
	flags_old := cpu_get_flags(cpu)
	flags_new := (flags_old^) & {.IgnoreInterrupts}

	switch size {
		case .Word:
			op2 := cpu_reg_fetch_word(cpu, reg2, r2.full)
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
			op2 := cpu_reg_fetch_byte(cpu, reg2, r2.full)
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

exec_divs_reg_immptr :: proc(size: shared.SizeMode, reg1: u8, cpu: ^Cpu) {
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

exec_divs_reg_regptr_immoffs :: proc(size: shared.SizeMode, reg1, reg2: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)
	offs := cpu_pc_fetch_word(cpu)
	addr := u16(i16(r2.full) + i16(offs))
	flags_old := cpu_get_flags(cpu)
	flags_new := (flags_old^) & {.IgnoreInterrupts}

	switch size {
		case .Word:
			op2 := cpu_reg_fetch_word(cpu, reg2, addr)
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
			op2 := cpu_reg_fetch_byte(cpu, reg2, addr)
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

exec_divs_reg_regptr_regoffs :: proc(size: shared.SizeMode, reg1, reg2: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)
	r3 := cpu_get_reg(cpu, cpu_pc_fetch_byte(cpu) & 0b111)
	addr := u16(i16(r2.full) + i16(r3.full))
	flags_old := cpu_get_flags(cpu)
	flags_new := (flags_old^) & {.IgnoreInterrupts}

	switch size {
		case .Word:
			op2 := cpu_reg_fetch_word(cpu, reg2, addr)
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
			op2 := cpu_reg_fetch_byte(cpu, reg2, addr)
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

exec_inc :: proc(size: shared.SizeMode, reg1: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	flags_old := cpu_get_flags(cpu)
	flags_new := (flags_old^) & {.Carry, .IgnoreInterrupts}

	switch size {
		case .Word:
			result := r1.full + 1

			if reg1 == SP_REG_IDX && result < r1.full {
				cpu_trigger_interrupt(cpu, STACK_UDF_VEC_IDX, true)
				return
			}

			if result == 0 do flags_new += {.Zero}
			if result & 0x8000 != 0 do flags_new += {.Negative}
			v_test := (r1.full ~ result) & (1 ~ result)
			if v_test & 0x8000 != 0 do flags_new += {.Overflow}

			r1.full = result
		case .Byte:
			result := r1.low + 1

			if result == 0 do flags_new += {.Zero}
			if result & 0x80 != 0 do flags_new += {.Negative}
			v_test := (r1.low ~ result) & (1 ~ result)
			if v_test & 0x80 != 0 do flags_new += {.Overflow}

			r1.low = result
	}

	flags_old^ = flags_new
	cpu.cycle_delta += 1
}

exec_dec :: proc(size: shared.SizeMode, reg1: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	flags_old := cpu_get_flags(cpu)
	flags_new := (flags_old^) & {.Carry, .IgnoreInterrupts}

	switch size {
		case .Word:
			result := r1.full - 1

			if reg1 == SP_REG_IDX && result > r1.full {
				cpu_trigger_interrupt(cpu, STACK_OVF_VEC_IDX, true)
				return
			}

			if result == 0 do flags_new += {.Zero}
			if result & 0x8000 != 0 do flags_new += {.Negative}
			v_test := (r1.full ~ 1) & (r1.full ~ result)
			if v_test & 0x8000 != 0 do flags_new += {.Overflow}

			r1.full = result
		case .Byte:
			result := r1.low - 1

			if result == 0 do flags_new += {.Zero}
			if result & 0x80 != 0 do flags_new += {.Negative}
			v_test := (r1.low ~ 1) & (r1.low ~ result)
			if v_test & 0x80 != 0 do flags_new += {.Overflow}

			r1.low = result
	}

	flags_old^ = flags_new
	cpu.cycle_delta += 1
}

shift_lsl :: proc(
	size: shared.SizeMode,
	val, amount: u16,
	carry_in: bool,
) -> (
	result: u16,
	carry_out: bool,
) {
	switch size {
		case .Word:
			if amount == 0 do return val, carry_in
			if amount >= 16 {
				result = 0
				carry_out = amount == 16 && (val & 1 != 0)
			} else {
				result = val << amount
				carry_out = (val >> (16 - amount)) & 1 != 0
			}
		case .Byte:
			if amount == 0 do return val & 0xFF, carry_in
			if amount >= 8 {
				result = 0
				carry_out = amount == 8 && (val & 1 != 0)
			} else {
				result = (val & 0xFF) << amount
				carry_out = (val >> (8 - amount)) & 1 != 0
			}
	}
	return result, carry_out
}

shift_lsr :: proc(
	size: shared.SizeMode,
	val, amount: u16,
	carry_in: bool,
) -> (
	result: u16,
	carry_out: bool,
) {
	switch size {
		case .Word:
			if amount == 0 do return val, carry_in
			if amount >= 16 {
				result = 0
				carry_out = amount == 16 && (val >> 15 & 1 != 0)
			} else {
				result = val >> amount
				carry_out = (val >> (amount - 1)) & 1 != 0
			}
		case .Byte:
			if amount == 0 do return val & 0xFF, carry_in
			if amount >= 8 {
				result = 0
				carry_out = amount == 8 && (val >> 7 & 1 != 0)
			} else {
				result = (val & 0xFF) >> amount
				carry_out = (val >> (amount - 1)) & 1 != 0
			}
	}
	return result, carry_out
}

shift_asr :: proc(
	size: shared.SizeMode,
	val, amount: u16,
	carry_in: bool,
) -> (
	result: u16,
	carry_out: bool,
) {
	switch size {
		case .Word:
			if amount == 0 do return val, carry_in
			if amount >= 16 {
				result = val & 0x8000 != 0 ? 0xFFFF : 0
				carry_out = result == 0xFFFF
			} else {
				result = u16(i16(val) >> amount)
				carry_out = (val >> (amount - 1)) & 1 != 0
			}
		case .Byte:
			if amount == 0 do return val & 0xFF, carry_in
			if amount >= 8 {
				result = val & 0x80 != 0 ? 0xFF : 0
				carry_out = result == 0xFF
			} else {
				result = u16(u8(i8(u8(val)) >> amount))
				carry_out = (val >> (amount - 1)) & 1 != 0
			}
	}
	return result, carry_out
}

rotate_rol :: proc(
	size: shared.SizeMode,
	val, amount: u16,
	carry_in: bool,
) -> (
	result: u16,
	carry_out: bool,
) {
	switch size {
		case .Word:
			distance := amount % 16
			if distance == 0 do return val, carry_in
			result = (val << distance) | (val >> (16 - distance))
			carry_out = (val >> (16 - distance)) & 1 != 0
		case .Byte:
			distance := amount % 8
			if distance == 0 do return val & 0xFF, carry_in
			v := val & 0xFF
			result = u16((v << distance) | (v >> (8 - distance)))
			carry_out = (v >> (8 - distance)) & 1 != 0
	}
	return result, carry_out
}

rotate_ror :: proc(
	size: shared.SizeMode,
	val, amount: u16,
	carry_in: bool,
) -> (
	result: u16,
	carry_out: bool,
) {
	switch size {
		case .Word:
			distance := amount % 16
			if distance == 0 do return val, carry_in
			result = (val >> distance) | (val << (16 - distance))
			carry_out = (val >> (distance - 1)) & 1 != 0
		case .Byte:
			distance := amount % 8
			if distance == 0 do return val & 0xFF, carry_in
			v := val & 0xFF
			result = u16((v >> distance) | (v << (8 - distance)))
			carry_out = (v >> (distance - 1)) & 1 != 0
	}
	return result, carry_out
}

rotate_rcl :: proc(
	size: shared.SizeMode,
	val, amount: u16,
	carry_in: bool,
) -> (
	result: u16,
	carry_out: bool,
) {
	switch size {
		case .Word:
			distance := amount % 17
			word_in := u64(carry_in ? 1 : 0) << 16 | u64(val)
			rotated := ((word_in << distance) | (word_in >> (17 - distance))) & 0x1FFFF
			result = u16(rotated)
			carry_out = rotated >> 16 != 0
		case .Byte:
			distance := amount % 9
			v := val & 0xFF
			word_in := u64(carry_in ? 1 : 0) << 8 | u64(v)
			rotated := ((word_in << distance) | (word_in >> (9 - distance))) & 0x1FF
			result = u16(u8(rotated))
			carry_out = rotated >> 8 != 0
	}
	return result, carry_out
}

rotate_rcr :: proc(
	size: shared.SizeMode,
	val, amount: u16,
	carry_in: bool,
) -> (
	result: u16,
	carry_out: bool,
) {
	switch size {
		case .Word:
			distance := amount % 17
			word_in := u64(carry_in ? 1 : 0) << 16 | u64(val)
			rotated := ((word_in >> distance) | (word_in << (17 - distance))) & 0x1FFFF
			result = u16(rotated)
			carry_out = rotated >> 16 != 0
		case .Byte:
			distance := amount % 9
			v := val & 0xFF
			word_in := u64(carry_in ? 1 : 0) << 8 | u64(v)
			rotated := ((word_in >> distance) | (word_in << (9 - distance))) & 0x1FF
			result = u16(u8(rotated))
			carry_out = rotated >> 8 != 0
	}
	return result, carry_out
}

exec_neg :: proc(size: shared.SizeMode, reg1: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	flags_old := cpu_get_flags(cpu)
	flags_new := (flags_old^) & {.IgnoreInterrupts}

	switch size {
		case .Word:
			res_full := 0 - u32(r1.full)
			res := u16(res_full)
			flags_old^ = flags_new + compute_flags_neg(size, res_full, r1.full, res)
			r1.full = res
		case .Byte:
			res_full := 0 - u32(r1.low)
			res := u8(res_full)
			flags_old^ = flags_new + compute_flags_neg(size, res_full, u16(r1.low), u16(res))
			r1.low = res
	}
	cpu.cycle_delta += 1
}

exec_and_reg_reg :: proc(size: shared.SizeMode, reg1, reg2: u8, discard: bool, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)
	flags_old := cpu_get_flags(cpu)
	flags_new := (flags_old^) & {.IgnoreInterrupts}

	switch size {
		case .Word:
			result := r1.full & r2.full
			flags_old^ = flags_new + compute_flags_logic(size, result)
			if !discard do r1.full = result
		case .Byte:
			result := r1.low & r2.low
			flags_old^ = flags_new + compute_flags_logic(size, u16(result))
			if !discard do r1.low = result
	}
	cpu.cycle_delta += 1
}

exec_and_reg_imm :: proc(size: shared.SizeMode, reg1: u8, discard: bool, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	flags_old := cpu_get_flags(cpu)
	flags_new := (flags_old^) & {.IgnoreInterrupts}

	switch size {
		case .Word:
			op2 := cpu_pc_fetch_word(cpu)
			result := r1.full & op2
			flags_old^ = flags_new + compute_flags_logic(size, result)
			if !discard do r1.full = result
		case .Byte:
			op2 := cpu_pc_fetch_byte(cpu)
			result := r1.low & op2
			flags_old^ = flags_new + compute_flags_logic(size, u16(result))
			if !discard do r1.low = result
	}
	cpu.cycle_delta += 1
}

exec_and_reg_regptr :: proc(size: shared.SizeMode, reg1, reg2: u8, discard: bool, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)
	flags_old := cpu_get_flags(cpu)
	flags_new := (flags_old^) & {.IgnoreInterrupts}

	switch size {
		case .Word:
			op2 := cpu_reg_fetch_word(cpu, reg2, r2.full)
			result := r1.full & op2
			flags_old^ = flags_new + compute_flags_logic(size, result)
			if !discard do r1.full = result
		case .Byte:
			op2 := cpu_reg_fetch_byte(cpu, reg2, r2.full)
			result := r1.low & op2
			flags_old^ = flags_new + compute_flags_logic(size, u16(result))
			if !discard do r1.low = result
	}
	cpu.cycle_delta += 1
}

exec_and_reg_immptr :: proc(size: shared.SizeMode, reg1: u8, discard: bool, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	immptr := cpu_pc_fetch_word(cpu)
	flags_old := cpu_get_flags(cpu)
	flags_new := (flags_old^) & {.IgnoreInterrupts}

	switch size {
		case .Word:
			op2 := cpu_dp_fetch_word(cpu, immptr)
			result := r1.full & op2
			flags_old^ = flags_new + compute_flags_logic(size, result)
			if !discard do r1.full = result
		case .Byte:
			op2 := cpu_dp_fetch_byte(cpu, immptr)
			result := r1.low & op2
			flags_old^ = flags_new + compute_flags_logic(size, u16(result))
			if !discard do r1.low = result
	}
	cpu.cycle_delta += 1
}

exec_and_reg_regptr_immoffs :: proc(
	size: shared.SizeMode,
	reg1, reg2: u8,
	discard: bool,
	cpu: ^Cpu,
) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)
	offs := cpu_pc_fetch_word(cpu)
	flags_old := cpu_get_flags(cpu)
	flags_new := (flags_old^) & {.IgnoreInterrupts}

	switch size {
		case .Word:
			op2 := cpu_reg_fetch_word(cpu, reg2, u16(i16(r2.full) + i16(offs)))
			result := r1.full & op2
			flags_old^ = flags_new + compute_flags_logic(size, result)
			if !discard do r1.full = result
		case .Byte:
			op2 := cpu_reg_fetch_byte(cpu, reg2, u16(i16(r2.full) + i16(offs)))
			result := r1.low & op2
			flags_old^ = flags_new + compute_flags_logic(size, u16(result))
			if !discard do r1.low = result
	}
	cpu.cycle_delta += 1
}

exec_and_reg_regptr_regoffs :: proc(
	size: shared.SizeMode,
	reg1, reg2: u8,
	discard: bool,
	cpu: ^Cpu,
) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)
	r3 := cpu_get_reg(cpu, cpu_pc_fetch_byte(cpu) & 0b111)
	offs := r3.full
	flags_old := cpu_get_flags(cpu)
	flags_new := (flags_old^) & {.IgnoreInterrupts}

	switch size {
		case .Word:
			op2 := cpu_reg_fetch_word(cpu, reg2, u16(i16(r2.full) + i16(offs)))
			result := r1.full & op2
			flags_old^ = flags_new + compute_flags_logic(size, result)
			if !discard do r1.full = result
		case .Byte:
			op2 := cpu_reg_fetch_byte(cpu, reg2, u16(i16(r2.full) + i16(offs)))
			result := r1.low & op2
			flags_old^ = flags_new + compute_flags_logic(size, u16(result))
			if !discard do r1.low = result
	}
	cpu.cycle_delta += 1
}

exec_or_reg_reg :: proc(size: shared.SizeMode, reg1, reg2: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)
	flags_old := cpu_get_flags(cpu)
	flags_new := (flags_old^) & {.IgnoreInterrupts}

	switch size {
		case .Word:
			result := r1.full | r2.full
			flags_old^ = flags_new + compute_flags_logic(size, result)
			r1.full = result
		case .Byte:
			result := r1.low | r2.low
			flags_old^ = flags_new + compute_flags_logic(size, u16(result))
			r1.low = result
	}
	cpu.cycle_delta += 1
}

exec_or_reg_imm :: proc(size: shared.SizeMode, reg1: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	flags_old := cpu_get_flags(cpu)
	flags_new := (flags_old^) & {.IgnoreInterrupts}

	switch size {
		case .Word:
			op2 := cpu_pc_fetch_word(cpu)
			result := r1.full | op2
			flags_old^ = flags_new + compute_flags_logic(size, result)
			r1.full = result
		case .Byte:
			op2 := cpu_pc_fetch_byte(cpu)
			result := r1.low | op2
			flags_old^ = flags_new + compute_flags_logic(size, u16(result))
			r1.low = result
	}
	cpu.cycle_delta += 1
}

exec_or_reg_regptr :: proc(size: shared.SizeMode, reg1, reg2: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)
	flags_old := cpu_get_flags(cpu)
	flags_new := (flags_old^) & {.IgnoreInterrupts}

	switch size {
		case .Word:
			op2 := cpu_reg_fetch_word(cpu, reg2, r2.full)
			result := r1.full | op2
			flags_old^ = flags_new + compute_flags_logic(size, result)
			r1.full = result
		case .Byte:
			op2 := cpu_reg_fetch_byte(cpu, reg2, r2.full)
			result := r1.low | op2
			flags_old^ = flags_new + compute_flags_logic(size, u16(result))
			r1.low = result
	}
	cpu.cycle_delta += 1
}

exec_or_reg_immptr :: proc(size: shared.SizeMode, reg1: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	immptr := cpu_pc_fetch_word(cpu)
	flags_old := cpu_get_flags(cpu)
	flags_new := (flags_old^) & {.IgnoreInterrupts}

	switch size {
		case .Word:
			op2 := cpu_dp_fetch_word(cpu, immptr)
			result := r1.full | op2
			flags_old^ = flags_new + compute_flags_logic(size, result)
			r1.full = result
		case .Byte:
			op2 := cpu_dp_fetch_byte(cpu, immptr)
			result := r1.low | op2
			flags_old^ = flags_new + compute_flags_logic(size, u16(result))
			r1.low = result
	}
	cpu.cycle_delta += 1
}

exec_or_reg_regptr_immoffs :: proc(size: shared.SizeMode, reg1, reg2: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)
	offs := cpu_pc_fetch_word(cpu)
	flags_old := cpu_get_flags(cpu)
	flags_new := (flags_old^) & {.IgnoreInterrupts}

	switch size {
		case .Word:
			op2 := cpu_reg_fetch_word(cpu, reg2, u16(i16(r2.full) + i16(offs)))
			result := r1.full | op2
			flags_old^ = flags_new + compute_flags_logic(size, result)
			r1.full = result
		case .Byte:
			op2 := cpu_reg_fetch_byte(cpu, reg2, u16(i16(r2.full) + i16(offs)))
			result := r1.low | op2
			flags_old^ = flags_new + compute_flags_logic(size, u16(result))
			r1.low = result
	}
	cpu.cycle_delta += 1
}

exec_or_reg_regptr_regoffs :: proc(size: shared.SizeMode, reg1, reg2: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)
	r3 := cpu_get_reg(cpu, cpu_pc_fetch_byte(cpu) & 0b111)
	offs := r3.full
	flags_old := cpu_get_flags(cpu)
	flags_new := (flags_old^) & {.IgnoreInterrupts}

	switch size {
		case .Word:
			op2 := cpu_reg_fetch_word(cpu, reg2, u16(i16(r2.full) + i16(offs)))
			result := r1.full | op2
			flags_old^ = flags_new + compute_flags_logic(size, result)
			r1.full = result
		case .Byte:
			op2 := cpu_reg_fetch_byte(cpu, reg2, u16(i16(r2.full) + i16(offs)))
			result := r1.low | op2
			flags_old^ = flags_new + compute_flags_logic(size, u16(result))
			r1.low = result
	}
	cpu.cycle_delta += 1
}

exec_xor_reg_reg :: proc(size: shared.SizeMode, reg1, reg2: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)
	flags_old := cpu_get_flags(cpu)
	flags_new := (flags_old^) & {.IgnoreInterrupts}

	switch size {
		case .Word:
			result := r1.full ~ r2.full
			flags_old^ = flags_new + compute_flags_logic(size, result)
			r1.full = result
		case .Byte:
			result := r1.low ~ r2.low
			flags_old^ = flags_new + compute_flags_logic(size, u16(result))
			r1.low = result
	}
	cpu.cycle_delta += 1
}

exec_xor_reg_imm :: proc(size: shared.SizeMode, reg1: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	flags_old := cpu_get_flags(cpu)
	flags_new := (flags_old^) & {.IgnoreInterrupts}

	switch size {
		case .Word:
			op2 := cpu_pc_fetch_word(cpu)
			result := r1.full ~ op2
			flags_old^ = flags_new + compute_flags_logic(size, result)
			r1.full = result
		case .Byte:
			op2 := cpu_pc_fetch_byte(cpu)
			result := r1.low ~ op2
			flags_old^ = flags_new + compute_flags_logic(size, u16(result))
			r1.low = result
	}
	cpu.cycle_delta += 1
}

exec_xor_reg_regptr :: proc(size: shared.SizeMode, reg1, reg2: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)
	flags_old := cpu_get_flags(cpu)
	flags_new := (flags_old^) & {.IgnoreInterrupts}

	switch size {
		case .Word:
			op2 := cpu_reg_fetch_word(cpu, reg2, r2.full)
			result := r1.full ~ op2
			flags_old^ = flags_new + compute_flags_logic(size, result)
			r1.full = result
		case .Byte:
			op2 := cpu_reg_fetch_byte(cpu, reg2, r2.full)
			result := r1.low ~ op2
			flags_old^ = flags_new + compute_flags_logic(size, u16(result))
			r1.low = result
	}
	cpu.cycle_delta += 1
}

exec_xor_reg_immptr :: proc(size: shared.SizeMode, reg1: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	immptr := cpu_pc_fetch_word(cpu)
	flags_old := cpu_get_flags(cpu)
	flags_new := (flags_old^) & {.IgnoreInterrupts}

	switch size {
		case .Word:
			op2 := cpu_dp_fetch_word(cpu, immptr)
			result := r1.full ~ op2
			flags_old^ = flags_new + compute_flags_logic(size, result)
			r1.full = result
		case .Byte:
			op2 := cpu_dp_fetch_byte(cpu, immptr)
			result := r1.low ~ op2
			flags_old^ = flags_new + compute_flags_logic(size, u16(result))
			r1.low = result
	}
	cpu.cycle_delta += 1
}

exec_xor_reg_regptr_immoffs :: proc(size: shared.SizeMode, reg1, reg2: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)
	offs := cpu_pc_fetch_word(cpu)
	flags_old := cpu_get_flags(cpu)
	flags_new := (flags_old^) & {.IgnoreInterrupts}

	switch size {
		case .Word:
			op2 := cpu_reg_fetch_word(cpu, reg2, u16(i16(r2.full) + i16(offs)))
			result := r1.full ~ op2
			flags_old^ = flags_new + compute_flags_logic(size, result)
			r1.full = result
		case .Byte:
			op2 := cpu_reg_fetch_byte(cpu, reg2, u16(i16(r2.full) + i16(offs)))
			result := r1.low ~ op2
			flags_old^ = flags_new + compute_flags_logic(size, u16(result))
			r1.low = result
	}
	cpu.cycle_delta += 1
}

exec_xor_reg_regptr_regoffs :: proc(size: shared.SizeMode, reg1, reg2: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)
	r3 := cpu_get_reg(cpu, cpu_pc_fetch_byte(cpu) & 0b111)
	offs := r3.full
	flags_old := cpu_get_flags(cpu)
	flags_new := (flags_old^) & {.IgnoreInterrupts}

	switch size {
		case .Word:
			op2 := cpu_reg_fetch_word(cpu, reg2, u16(i16(r2.full) + i16(offs)))
			result := r1.full ~ op2
			flags_old^ = flags_new + compute_flags_logic(size, result)
			r1.full = result
		case .Byte:
			op2 := cpu_reg_fetch_byte(cpu, reg2, u16(i16(r2.full) + i16(offs)))
			result := r1.low ~ op2
			flags_old^ = flags_new + compute_flags_logic(size, u16(result))
			r1.low = result
	}
	cpu.cycle_delta += 1
}

exec_not :: proc(size: shared.SizeMode, reg1: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	flags_old := cpu_get_flags(cpu)
	flags_new := (flags_old^) & {.Carry, .Overflow, .IgnoreInterrupts}

	switch size {
		case .Word:
			result := ~r1.full
			flags_old^ = flags_new + compute_flags_logic(size, result)
			r1.full = result
		case .Byte:
			result := ~r1.low
			flags_old^ = flags_new + compute_flags_logic(size, u16(result))
			r1.low = result
	}
	cpu.cycle_delta += 1
}

exec_lsl_reg_reg :: proc(size: shared.SizeMode, reg1, reg2: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)
	flags_old := cpu_get_flags(cpu)
	flags_new := (flags_old^) & {.IgnoreInterrupts}
	amount := size == .Word ? r2.full : u16(r2.low)
	carry_in := .Carry in (flags_old^)

	switch size {
		case .Word:
			result, carry := shift_lsl(size, r1.full, amount, carry_in)
			sign_changed := (r1.full ~ result) & 0x8000 != 0
			flags_old^ = flags_new + compute_flags_shift(size, result, carry, sign_changed)
			r1.full = result
		case .Byte:
			result, carry := shift_lsl(size, u16(r1.low), amount, carry_in)
			sign_changed := (u16(r1.low) ~ result) & 0x80 != 0
			flags_old^ = flags_new + compute_flags_shift(size, result, carry, sign_changed)
			r1.low = u8(result)
	}
	cpu.cycle_delta += 1
}

exec_lsl_reg_imm :: proc(size: shared.SizeMode, reg1: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	flags_old := cpu_get_flags(cpu)
	flags_new := (flags_old^) & {.IgnoreInterrupts}
	amount := u16(cpu_pc_fetch_byte(cpu))
	carry_in := .Carry in (flags_old^)

	switch size {
		case .Word:
			result, carry := shift_lsl(size, r1.full, amount, carry_in)
			sign_changed := (r1.full ~ result) & 0x8000 != 0
			flags_old^ = flags_new + compute_flags_shift(size, result, carry, sign_changed)
			r1.full = result
		case .Byte:
			result, carry := shift_lsl(size, u16(r1.low), amount, carry_in)
			sign_changed := (u16(r1.low) ~ result) & 0x80 != 0
			flags_old^ = flags_new + compute_flags_shift(size, result, carry, sign_changed)
			r1.low = u8(result)
	}
	cpu.cycle_delta += 1
}

exec_lsr_reg_reg :: proc(size: shared.SizeMode, reg1, reg2: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)
	flags_old := cpu_get_flags(cpu)
	flags_new := (flags_old^) & {.IgnoreInterrupts}
	amount := size == .Word ? r2.full : u16(r2.low)
	carry_in := .Carry in (flags_old^)

	switch size {
		case .Word:
			result, carry := shift_lsr(size, r1.full, amount, carry_in)
			flags_old^ = flags_new + compute_flags_shift(size, result, carry, false)
			r1.full = result
		case .Byte:
			result, carry := shift_lsr(size, u16(r1.low), amount, carry_in)
			flags_old^ = flags_new + compute_flags_shift(size, result, carry, false)
			r1.low = u8(result)
	}
	cpu.cycle_delta += 1
}

exec_lsr_reg_imm :: proc(size: shared.SizeMode, reg1: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	flags_old := cpu_get_flags(cpu)
	flags_new := (flags_old^) & {.IgnoreInterrupts}
	amount := u16(cpu_pc_fetch_byte(cpu))
	carry_in := .Carry in (flags_old^)

	switch size {
		case .Word:
			result, carry := shift_lsr(size, r1.full, amount, carry_in)
			flags_old^ = flags_new + compute_flags_shift(size, result, carry, false)
			r1.full = result
		case .Byte:
			result, carry := shift_lsr(size, u16(r1.low), amount, carry_in)
			flags_old^ = flags_new + compute_flags_shift(size, result, carry, false)
			r1.low = u8(result)
	}
	cpu.cycle_delta += 1
}

exec_asr_reg_reg :: proc(size: shared.SizeMode, reg1, reg2: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)
	flags_old := cpu_get_flags(cpu)
	flags_new := (flags_old^) & {.IgnoreInterrupts}
	amount := size == .Word ? r2.full : u16(r2.low)
	carry_in := .Carry in (flags_old^)

	switch size {
		case .Word:
			result, carry := shift_asr(size, r1.full, amount, carry_in)
			flags_old^ = flags_new + compute_flags_shift(size, result, carry, false)
			r1.full = result
		case .Byte:
			result, carry := shift_asr(size, u16(r1.low), amount, carry_in)
			flags_old^ = flags_new + compute_flags_shift(size, result, carry, false)
			r1.low = u8(result)
	}
	cpu.cycle_delta += 1
}

exec_asr_reg_imm :: proc(size: shared.SizeMode, reg1: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	flags_old := cpu_get_flags(cpu)
	flags_new := (flags_old^) & {.IgnoreInterrupts}
	amount := u16(cpu_pc_fetch_byte(cpu))
	carry_in := .Carry in (flags_old^)

	switch size {
		case .Word:
			result, carry := shift_asr(size, r1.full, amount, carry_in)
			flags_old^ = flags_new + compute_flags_shift(size, result, carry, false)
			r1.full = result
		case .Byte:
			result, carry := shift_asr(size, u16(r1.low), amount, carry_in)
			flags_old^ = flags_new + compute_flags_shift(size, result, carry, false)
			r1.low = u8(result)
	}
	cpu.cycle_delta += 1
}

exec_rol_reg_reg :: proc(size: shared.SizeMode, reg1, reg2: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)
	flags_old := cpu_get_flags(cpu)
	flags_new := (flags_old^) & {.IgnoreInterrupts}
	amount := size == .Word ? r2.full : u16(r2.low)
	carry_in := .Carry in (flags_old^)

	switch size {
		case .Word:
			result, carry := rotate_rol(size, r1.full, amount, carry_in)
			flags_old^ = flags_new + compute_flags_shift(size, result, carry, false)
			r1.full = result
		case .Byte:
			result, carry := rotate_rol(size, u16(r1.low), amount, carry_in)
			flags_old^ = flags_new + compute_flags_shift(size, result, carry, false)
			r1.low = u8(result)
	}
	cpu.cycle_delta += 1
}

exec_rol_reg_imm :: proc(size: shared.SizeMode, reg1: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	flags_old := cpu_get_flags(cpu)
	flags_new := (flags_old^) & {.IgnoreInterrupts}
	amount := u16(cpu_pc_fetch_byte(cpu))
	carry_in := .Carry in (flags_old^)

	switch size {
		case .Word:
			result, carry := rotate_rol(size, r1.full, amount, carry_in)
			flags_old^ = flags_new + compute_flags_shift(size, result, carry, false)
			r1.full = result
		case .Byte:
			result, carry := rotate_rol(size, u16(r1.low), amount, carry_in)
			flags_old^ = flags_new + compute_flags_shift(size, result, carry, false)
			r1.low = u8(result)
	}
	cpu.cycle_delta += 1
}

exec_ror_reg_reg :: proc(size: shared.SizeMode, reg1, reg2: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)
	flags_old := cpu_get_flags(cpu)
	flags_new := (flags_old^) & {.IgnoreInterrupts}
	amount := size == .Word ? r2.full : u16(r2.low)
	carry_in := .Carry in (flags_old^)

	switch size {
		case .Word:
			result, carry := rotate_ror(size, r1.full, amount, carry_in)
			flags_old^ = flags_new + compute_flags_shift(size, result, carry, false)
			r1.full = result
		case .Byte:
			result, carry := rotate_ror(size, u16(r1.low), amount, carry_in)
			flags_old^ = flags_new + compute_flags_shift(size, result, carry, false)
			r1.low = u8(result)
	}
	cpu.cycle_delta += 1
}

exec_ror_reg_imm :: proc(size: shared.SizeMode, reg1: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	flags_old := cpu_get_flags(cpu)
	flags_new := (flags_old^) & {.IgnoreInterrupts}
	amount := u16(cpu_pc_fetch_byte(cpu))
	carry_in := .Carry in (flags_old^)

	switch size {
		case .Word:
			result, carry := rotate_ror(size, r1.full, amount, carry_in)
			flags_old^ = flags_new + compute_flags_shift(size, result, carry, false)
			r1.full = result
		case .Byte:
			result, carry := rotate_ror(size, u16(r1.low), amount, carry_in)
			flags_old^ = flags_new + compute_flags_shift(size, result, carry, false)
			r1.low = u8(result)
	}
	cpu.cycle_delta += 1
}

exec_rcl_reg_reg :: proc(size: shared.SizeMode, reg1, reg2: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)
	flags_old := cpu_get_flags(cpu)
	flags_new := (flags_old^) & {.IgnoreInterrupts}
	amount := size == .Word ? r2.full : u16(r2.low)
	carry_in := .Carry in (flags_old^)

	switch size {
		case .Word:
			result, carry := rotate_rcl(size, r1.full, amount, carry_in)
			flags_old^ = flags_new + compute_flags_shift(size, result, carry, false)
			r1.full = result
		case .Byte:
			result, carry := rotate_rcl(size, u16(r1.low), amount, carry_in)
			flags_old^ = flags_new + compute_flags_shift(size, result, carry, false)
			r1.low = u8(result)
	}
	cpu.cycle_delta += 1
}

exec_rcl_reg_imm :: proc(size: shared.SizeMode, reg1: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	flags_old := cpu_get_flags(cpu)
	flags_new := (flags_old^) & {.IgnoreInterrupts}
	amount := u16(cpu_pc_fetch_byte(cpu))
	carry_in := .Carry in (flags_old^)

	switch size {
		case .Word:
			result, carry := rotate_rcl(size, r1.full, amount, carry_in)
			flags_old^ = flags_new + compute_flags_shift(size, result, carry, false)
			r1.full = result
		case .Byte:
			result, carry := rotate_rcl(size, u16(r1.low), amount, carry_in)
			flags_old^ = flags_new + compute_flags_shift(size, result, carry, false)
			r1.low = u8(result)
	}
	cpu.cycle_delta += 1
}

exec_rcr_reg_reg :: proc(size: shared.SizeMode, reg1, reg2: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)
	flags_old := cpu_get_flags(cpu)
	flags_new := (flags_old^) & {.IgnoreInterrupts}
	amount := size == .Word ? r2.full : u16(r2.low)
	carry_in := .Carry in (flags_old^)

	switch size {
		case .Word:
			result, carry := rotate_rcr(size, r1.full, amount, carry_in)
			flags_old^ = flags_new + compute_flags_shift(size, result, carry, false)
			r1.full = result
		case .Byte:
			result, carry := rotate_rcr(size, u16(r1.low), amount, carry_in)
			flags_old^ = flags_new + compute_flags_shift(size, result, carry, false)
			r1.low = u8(result)
	}
	cpu.cycle_delta += 1
}

exec_rcr_reg_imm :: proc(size: shared.SizeMode, reg1: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	flags_old := cpu_get_flags(cpu)
	flags_new := (flags_old^) & {.IgnoreInterrupts}
	amount := u16(cpu_pc_fetch_byte(cpu))
	carry_in := .Carry in (flags_old^)

	switch size {
		case .Word:
			result, carry := rotate_rcr(size, r1.full, amount, carry_in)
			flags_old^ = flags_new + compute_flags_shift(size, result, carry, false)
			r1.full = result
		case .Byte:
			result, carry := rotate_rcr(size, u16(r1.low), amount, carry_in)
			flags_old^ = flags_new + compute_flags_shift(size, result, carry, false)
			r1.low = u8(result)
	}
	cpu.cycle_delta += 1
}

exec_add_l_regpair :: proc(reg1, reg2: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)
	pack := cpu_pc_fetch_byte(cpu)
	r3 := cpu_get_reg(cpu, pack & 0b111)
	r4 := cpu_get_reg(cpu, (pack >> 3) & 0b111)
	flags_old := cpu_get_flags(cpu)
	flags_new := (flags_old^) & {.IgnoreInterrupts}

	op1 := u32(r1.full) << 16 | u32(r2.full)
	op2 := u32(r3.full) << 16 | u32(r4.full)
	res_full := u64(op1) + u64(op2)
	res := u32(res_full)

	flags_old^ = flags_new + compute_flags_add_l(res_full, op1, op2)
	r1.full = u16(res >> 16)
	r2.full = u16(res)

	cpu.cycle_delta += 2
}

exec_add_l_imm32 :: proc(reg1, reg2: u8, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)

	op2 := u32(cpu_pc_fetch_word(cpu)) | u32(cpu_pc_fetch_word(cpu)) << 16
	flags_old := cpu_get_flags(cpu)
	flags_new := (flags_old^) & {.IgnoreInterrupts}

	op1 := u32(r1.full) << 16 | u32(r2.full)
	res_full := u64(op1) + u64(op2)
	res := u32(res_full)

	flags_old^ = flags_new + compute_flags_add_l(res_full, op1, op2)
	r1.full = u16(res >> 16)
	r2.full = u16(res)

	cpu.cycle_delta += 2
}

exec_sub_l_regpair :: proc(reg1, reg2: u8, discard: bool, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)
	pack := cpu_pc_fetch_byte(cpu)
	r3 := cpu_get_reg(cpu, pack & 0b111)
	r4 := cpu_get_reg(cpu, (pack >> 3) & 0b111)
	flags_old := cpu_get_flags(cpu)
	flags_new := (flags_old^) & {.IgnoreInterrupts}

	op1 := u32(r1.full) << 16 | u32(r2.full)
	op2 := u32(r3.full) << 16 | u32(r4.full)
	res_full := u64(op1) - u64(op2)
	res := u32(res_full)

	flags_old^ = flags_new + compute_flags_sub_l(res_full, op1, op2)
	if !discard {
		r1.full = u16(res >> 16)
		r2.full = u16(res)
	}

	cpu.cycle_delta += 2
}

exec_sub_l_imm32 :: proc(reg1, reg2: u8, discard: bool, cpu: ^Cpu) {
	r1 := cpu_get_reg(cpu, reg1)
	r2 := cpu_get_reg(cpu, reg2)

	op2 := u32(cpu_pc_fetch_word(cpu)) | u32(cpu_pc_fetch_word(cpu)) << 16
	flags_old := cpu_get_flags(cpu)
	flags_new := (flags_old^) & {.IgnoreInterrupts}

	op1 := u32(r1.full) << 16 | u32(r2.full)
	res_full := u64(op1) - u64(op2)
	res := u32(res_full)

	flags_old^ = flags_new + compute_flags_sub_l(res_full, op1, op2)
	if !discard {
		r1.full = u16(res >> 16)
		r2.full = u16(res)
	}

	cpu.cycle_delta += 2
}
