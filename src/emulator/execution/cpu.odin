package execution

import "../memory"

SP_REG_IDX :: 7

SP_INIT_VAL :: 0xFFFE
SP_PAGE :: 0x04

VBLNK_VEC_IDX :: 0x00
HBLNK_VEC_IDX :: 0x01
DIV0_VEC_IDX :: 0x02
STACK_OVF_VEC_IDX :: 0x03
STACK_UDF_VEC_IDX :: 0x04
INVALID_OPCODE_VEC_IDX :: 0x05

// This will NEVER be run in a big-endian computer,
// but best to play it safe.
when ODIN_ENDIAN == .Little {
	Register :: struct #raw_union {
		full:    u16,
		using _: struct #packed {
			low, high: u8,
		},
	}
} else {
	Register :: struct #raw_union {
		full:    u16,
		using _: struct #packed {
			high, low: u8,
		},
	}
}

CpuFlags :: enum u16 {
	Carry,
	Zero,
	Negative,
	Overflow,
	IgnoreInterrupts,
}

RegName :: enum u8 {
	A,
	B,
	C,
	D,
	E,
	F,
	G,
	SP,
	Flags,
	Hi,
	PP,
	DP,
	PC,
}

FlagRegister :: bit_set[CpuFlags;u16]

Cpu :: struct {
	regs:        [8]Register,
	flags:       FlagRegister,
	pc:          u16,
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
	cpu.pp = 6
	cpu.dp = 0
	cpu.bus = bus
}

cpu_get_flags :: #force_inline proc(cpu: ^Cpu) -> ^FlagRegister {
	return &cpu.flags
}

cpu_get_reg :: #force_inline proc(cpu: ^Cpu, reg_idx: u8) -> ^Register {
	#no_bounds_check {
		return &cpu.regs[reg_idx]
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

cpu_dp_store_word :: proc(cpu: ^Cpu, offs, val: u16) {
	addr := memory.calculate_address(cpu.dp, offs)
	cpu_write_word(cpu, addr, val)
}

cpu_dp_store_byte :: proc(cpu: ^Cpu, offs: u16, val: u8) {
	addr := memory.calculate_address(cpu.dp, offs)
	cpu_write_byte(cpu, addr, val)
}

cpu_reg_page :: #force_inline proc(cpu: ^Cpu, reg_idx: u8) -> u8 {
	page := cpu.dp
	if reg_idx == SP_REG_IDX do page = SP_PAGE
	return page
}

cpu_reg_fetch_word :: proc(cpu: ^Cpu, reg_idx: u8, offs: u16) -> u16 {
	addr := memory.calculate_address(cpu_reg_page(cpu, reg_idx), offs)
	return cpu_read_word(cpu, addr)
}

cpu_reg_fetch_byte :: proc(cpu: ^Cpu, reg_idx: u8, offs: u16) -> byte {
	addr := memory.calculate_address(cpu_reg_page(cpu, reg_idx), offs)
	return cpu_read_byte(cpu, addr)
}

cpu_reg_store_word :: proc(cpu: ^Cpu, reg_idx: u8, offs, val: u16) {
	addr := memory.calculate_address(cpu_reg_page(cpu, reg_idx), offs)
	cpu_write_word(cpu, addr, val)
}

cpu_reg_store_byte :: proc(cpu: ^Cpu, reg_idx: u8, offs: u16, val: u8) {
	addr := memory.calculate_address(cpu_reg_page(cpu, reg_idx), offs)
	cpu_write_byte(cpu, addr, val)
}

sp_math_wraps :: #force_inline proc(sp: u16, delta: int, subtract: bool) -> bool {
	if subtract do return int(sp) < delta
	return int(sp) > 0xFFFF - delta
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

cpu_push :: proc(cpu: ^Cpu, reg: RegName) {
	sp := cpu_get_reg(cpu, SP_REG_IDX)
	addr := memory.calculate_address(SP_PAGE, sp.full)
	val: u16

	if sp.full - 2 > sp.full {
		cpu_trigger_interrupt(cpu, STACK_OVF_VEC_IDX, true)
		return
	}

	switch reg {
		case .A ..< .Flags:
			val = cpu_get_reg(cpu, u8(reg)).full
		case .Flags:
			val = transmute(u16)cpu.flags
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

cpu_pop :: proc(cpu: ^Cpu, reg: RegName) {
	sp := cpu_get_reg(cpu, SP_REG_IDX)

	if sp.full + 2 < sp.full {
		cpu_trigger_interrupt(cpu, STACK_UDF_VEC_IDX, true)
		return
	}

	addr := memory.calculate_address(SP_PAGE, sp.full)
	val := cpu_read_word(cpu, addr)

	switch reg {
		case .A ..< .Flags:
			cpu_get_reg(cpu, u8(reg)).full = val
		case .Flags:
			cpu.flags = transmute(FlagRegister)val
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
		cpu_write_word(cpu, store_addr, transmute(u16)cpu.flags)
		cpu_write_byte(cpu, store_addr + 2, cpu.pp)
		cpu_write_word(cpu, store_addr + 3, u16(i16(cpu.pc) - cpu.pc_delta)) // save the pre-instruction PC
	}

	addr := memory.calculate_address(memory.IVT_PAGE, u16(3 * interrupt_index))

	pc_new := cpu_read_word(cpu, addr)
	pp_new := cpu_read_byte(cpu, addr + size_of(u16))

	cpu.pc = pc_new
	cpu.pp = pp_new
}
