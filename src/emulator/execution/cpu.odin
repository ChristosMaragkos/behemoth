package execution

import "../memory"

SP_REG_IDX :: 6
FLAGS_REG_IDX :: 7

SP_INIT_VAL :: 0xFFFE
SP_PAGE :: 0x04

STACK_OVF_VEC_IDX :: 0x03
STACK_UDF_VEC_IDX :: 0x04
INVALID_OPCODE_VEC_IDX :: 0x05

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

RegisterNames :: enum u8 {
	A,
	B,
	C,
	D,
	E,
	F,
	SP,
	Flags,
	Hi,
	PP,
	DP,
	PC,
}

FlagRegister :: bit_set[CpuFlags;u16]

Cpu :: struct {
	pc:          u16,
	regs:        [8]Register,
	hi:          Register,
	pp:          u8,
	dp:          u8,
	bus:         ^memory.MemoryBus,
	cycle_delta: u32,
	pc_delta:    i16,
	halted:      bool,
}

cpu_init :: proc(cpu: ^Cpu, bus: ^memory.MemoryBus) {
	for &reg in cpu.regs {
		reg.full = 0
	}
	cpu.regs[SP_REG_IDX].full = SP_INIT_VAL
	cpu.hi.full = 0
	cpu.pp = 0
	cpu.dp = 0
	cpu.bus = bus
}

cpu_get_flags :: #force_inline proc(cpu: ^Cpu) -> ^FlagRegister {
	return transmute(^FlagRegister)&cpu.regs[FLAGS_REG_IDX].full
}

cpu_get_reg :: #force_inline proc(cpu: ^Cpu, reg_idx: u8) -> ^Register {
	#no_bounds_check {
		return &cpu.regs[reg_idx]
	}
}

cpu_fetch :: proc(cpu: ^Cpu) -> Instruction {
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
			}
		case .Math:
		case .ControlFlow:
	}
}

cpu_pc_fetch_word :: proc(cpu: ^Cpu) -> u16 {
	addr := memory.calculate_address(cpu.pp, cpu.pc)
	cpu_advance_pc(cpu, size_of(u16))
	return cpu_read_word(cpu, addr)
}

cpu_pc_fetch_byte :: proc(cpu: ^Cpu) -> byte {
	addr := memory.calculate_address(cpu.pp, cpu.pc)
	cpu_advance_pc(cpu, size_of(u8))
	return cpu_read_byte(cpu, addr)
}

cpu_dp_fetch_word :: proc(cpu: ^Cpu, offs: u16) -> u16 {
	addr := memory.calculate_address(cpu.dp, offs)
	return cpu_read_word(cpu, addr)
}

cpu_dp_fetch_byte :: proc(cpu: ^Cpu, offs: u16) -> byte {
	addr := memory.calculate_address(cpu.dp, offs)
	return cpu_read_byte(cpu, addr)
}

cpu_advance_pc :: proc(cpu: ^Cpu, amnt: i16) {
	pc_new := i16(cpu.pc) + amnt
	if amnt < 0 {
		if transmute(u16)pc_new > cpu.pc do cpu.pp -= 1
	} else {
		if transmute(u16)pc_new < cpu.pc do cpu.pp += 1
	}

	cpu.pc_delta += amnt
	cpu.pc = transmute(u16)pc_new
}

cpu_read_word :: #force_inline proc(cpu: ^Cpu, addr: u32) -> u16 {
	cpu.cycle_delta += 1
	return memory.bus_read_word(cpu.bus, addr)
}

cpu_read_byte :: #force_inline proc(cpu: ^Cpu, addr: u32) -> u8 {
	cpu.cycle_delta += 1
	return memory.bus_read_byte(cpu.bus, addr)
}

cpu_write_word :: #force_inline proc(cpu: ^Cpu, addr: u32, val: u16) {
	cpu.cycle_delta += 1
	memory.bus_write_word(cpu.bus, addr, val)
}

cpu_write_byte :: #force_inline proc(cpu: ^Cpu, addr: u32, val: u8) {
	cpu.cycle_delta += 1
	memory.bus_write_byte(cpu.bus, addr, val)
}

cpu_push :: proc(cpu: ^Cpu, reg: RegisterNames) {
	sp := cpu_get_reg(cpu, SP_REG_IDX)
	addr := memory.calculate_address(SP_PAGE, sp.full)
	val: u16

	if sp.full - 2 > sp.full {
		cpu_trigger_interrupt(cpu, STACK_OVF_VEC_IDX, true)
		return
	}

	switch reg {
		case .A ..< .Hi:
			val = cpu_get_reg(cpu, u8(reg)).full
		case .Hi:
			val = cpu.hi.full
		case .PP:
			val = u16(cpu.pp)
		case .DP:
			val = u16(cpu.dp)
		case .PC:
			val = cpu.pc
	}

	cpu_write_word(cpu, addr, val)
	sp.full -= size_of(u16)
}

cpu_pop :: proc(cpu: ^Cpu, reg: RegisterNames) {
	sp := cpu_get_reg(cpu, SP_REG_IDX)

	if sp.full + 2 < sp.full {
		cpu_trigger_interrupt(cpu, STACK_UDF_VEC_IDX, true)
		return
	}

	addr := memory.calculate_address(SP_PAGE, sp.full)
	val := cpu_read_word(cpu, addr)

	switch reg {
		case .A ..< .Hi:
			cpu_get_reg(cpu, u8(reg)).full = val
		case .Hi:
			cpu.hi.full = val
		case .PP:
			cpu.pp = u8(val)
		case .DP:
			cpu.dp = u8(val)
		case .PC:
			cpu.pc = val
	}

	sp.full += size_of(u16)
}

cpu_trigger_interrupt :: proc(cpu: ^Cpu, interrupt_index: u8, fault: bool) {
	if !fault {
		cpu_push(cpu, .Flags)
		cpu_push(cpu, .PP)
		cpu_push(cpu, .PC)
	} else {
		store_addr := memory.calculate_address(memory.IVT_PAGE, 0x0300)
		cpu_write_word(cpu, store_addr, cpu_get_reg(cpu, FLAGS_REG_IDX).full)
		cpu_write_word(cpu, store_addr + 2, u16(i16(cpu.pc) - cpu.pc_delta)) // save the pre-instruction PC
		cpu_write_byte(cpu, store_addr + 4, cpu.pp)
	}

	addr := memory.calculate_address(memory.IVT_PAGE, u16(3 * interrupt_index))

	pc_new := cpu_read_word(cpu, addr)
	pp_new := cpu_read_byte(cpu, addr + size_of(u16))

	cpu.pc = pc_new
	cpu.pp = pp_new
	// FIXME: Remove this once interrupts are implemented
	panic("Interrupts are not implemented yet")
}
