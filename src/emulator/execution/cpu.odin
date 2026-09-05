package behemoth

SP_REG_IDX :: 6
FLAGS_REG_IDX :: 7

SP_INIT_VAL :: 0xFFFE

Register :: struct #raw_union {
	full:    u16,
	using _: struct #packed {
		low, high: u8,
	},
}

CpuFlags :: enum u16 {
	Carry,
	Zero,
	Negative,
	Overflow,
	IgnoreInterrupts,
}

FlagRegister :: bit_set[CpuFlags;u16]

Cpu :: struct {
	pc:   u16,
	regs: [8]Register,
	hi:   Register,
	pp:   u8,
	dp:   u8,
}

cpu_init :: proc(cpu: ^Cpu) {
	cpu.regs[SP_REG_IDX].full = SP_INIT_VAL
	cpu.regs[FLAGS_REG_IDX].full = 0
}

cpu_get_flags :: #force_inline proc(cpu: ^Cpu) -> ^FlagRegister {
	return transmute(^FlagRegister)&cpu.regs[FLAGS_REG_IDX].full
}

cpu_get_reg :: #force_inline proc(cpu: ^Cpu, reg_idx: u8) -> ^Register {
	#no_bounds_check {
		return &cpu.regs[reg_idx]
	}
}
