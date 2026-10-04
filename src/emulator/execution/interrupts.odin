package execution

import "../memory"
import "core:fmt"

MaskableInterrupt :: enum u16 {
	Hblnk,
}

IrqLine :: bit_set[MaskableInterrupt;u16]

cpu_raise_irq :: proc(cpu: ^Cpu, irq: MaskableInterrupt) {
	cpu.irq_line += {irq}
}

cpu_drop_irq :: proc(cpu: ^Cpu, irq: MaskableInterrupt) {
	cpu.irq_line -= {irq}
}

cpu_irq_is_raised :: proc(cpu: ^Cpu, irq: MaskableInterrupt) -> bool {
	return irq in cpu.irq_line
}

cpu_service_irq :: proc(cpu: ^Cpu) {
	if .IgnoreInterrupts in cpu.flags do return

	for irq in MaskableInterrupt {
		if irq in cpu.irq_line {
			idx := get_irq_vector_idx(irq)
			cpu_trigger_interrupt(cpu, idx, false)
			cpu.irq_line -= {irq}
			return
		}
	}
}

cpu_trigger_interrupt :: proc(cpu: ^Cpu, interrupt_index: u8, fault: bool) {
	cpu.halted = false
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

	cpu.flags += {.IgnoreInterrupts}
	cpu.pc = pc_new
	cpu.pp = pp_new
}

@(private = "file")
get_irq_vector_idx :: proc(irq: MaskableInterrupt) -> u8 {
	switch irq {
		case .Hblnk:
			return HBLNK_VEC_IDX
		case:
			fmt.panicf("Fatal error: received non-existent IRQ '%d'", irq)
	}
}
