package memory

import "core:mem"
DMA_INIT_COST :: 10

SDMASTART :: 0x05_060a
VDMASTART :: 0x05_0544

VMPCTRL :: 0x05_0534
VMPADDR :: 0x05_0535
VMDATAL :: 0x05_0538
VMDATAH :: 0x05_0539

PPUSTATUS :: 0x05_0500

import "../common"

@(private = "file")
bus_read_u24 :: proc(bus: ^MemoryBus, addr: u32) -> u32 {
	return u32(bus.ram[addr]) | u32(bus.ram[addr + 1] << 8) | u32(bus.ram[addr + 2] << 16)
}

@(private = "file")
bus_write_u24 :: proc(bus: ^MemoryBus, addr: u32, val: u32) {
	bus_write_word(bus, addr, u16(val))
	bus_write_byte(bus, addr + 2, u8(val >> 16))
}

bus_system_dma :: proc(bus: ^MemoryBus) {
	SDMACTL :: 0x05_0600
	SDMASRC :: 0x05_0601
	SDMADST :: 0x05_0604
	SDMALEN :: 0x05_0607
	SDMASTAT :: 0x05_0609

	src := bus_read_u24(bus, SDMASRC)
	dst := bus_read_u24(bus, SDMADST)

	size := int((bus_read_byte(bus, SDMACTL) & 0b1) + 1)
	len := int(bus_read_word(bus, SDMALEN))
	amnt := u32(size * len)

	src_final := src + amnt
	dst_final := dst + amnt

	// will let this deliberately copy junk from out-of-bounds transfers
	// to simulate bus garbage
	if (dst_final >> 16) > 0x03 || (src >> 16) < 0x06 {
		bus_write_byte(bus, SDMASTAT, 0x01)
		return
	}
	mem.copy(&bus.ram[dst], &bus.ram[src], size * len)
	bus.contention = DMA_INIT_COST + amnt
}

bus_audio_dma :: proc(bus: ^MemoryBus) {
	ADMACTL :: 0x05_0700
	ADMASRC :: 0x05_0701
	ADMADST :: 0x05_0704
	ADMALEN :: 0x05_0707
	ADMASTAT :: 0x05_0709

	ARAM_SIZE :: 16 * 1024

	src := bus_read_u24(bus, ADMASRC)
	dst := bus_read_word(bus, ADMADST)

	size := int((bus_read_byte(bus, ADMACTL) & 0b1) + 1)
	len := int(bus_read_word(bus, ADMALEN))
	amnt := u32(size * len)

	dst_final := u32(dst) + amnt

	if dst_final >= ARAM_SIZE {
		bus_write_byte(bus, ADMASTAT, 0x01)
		return
	}

	mem.copy(&bus.ram[dst], &bus.ram[src], size * len)
	bus.contention = DMA_INIT_COST + amnt
}

bus_video_dma :: proc(bus: ^MemoryBus) {
	VDMACTRL :: 0x05_053a
	VDMASRC :: 0x05_053b
	VDMADST :: 0x05_053e
	VDMALEN :: 0x05_0541
	VDMASTAT :: 0x05_0543

	VdmaCtrl :: bit_field u8 {
		vram_dest: enum u8 {
			Vram,
			Cram,
			Oam,
			Reserved,
		} | 2,
		direction: enum u8 {
			RamToVram,
			VramToRam,
		} | 1,
		width:     enum u8 {
			Bytes,
			Words,
		} | 1,
	}

	ram_addr := int(bus_read_u24(bus, VDMASRC))
	ctrl := transmute(VdmaCtrl)bus_read_byte(bus, VDMACTRL)
	mask: int
	size := int(uint(ctrl.width) + 1)
	len := int(bus_read_word(bus, VDMALEN))
	amnt := int(size * len)
	video_ptr: rawptr

	switch ctrl.vram_dest {
		case .Vram:
			mask = 0x1ffff
			video_ptr = bus.vram
		case .Cram:
			video_ptr = bus.cram
			mask = 0x1ff
		case .Oam:
		case .Reserved:
			video_ptr = bus.oam
			mask = 0x7ff
	}
	video_addr := int(bus_read_u24(bus, VDMADST)) & mask
	video_ptr = mem.ptr_offset(cast(^byte)video_ptr, video_addr)
	ram_ptr := &bus.ram[ram_addr]

	cycle_cost: int = 1
	is_blanking := bus_read_byte(bus, PPUSTATUS) & 0b11 != 0
	if !is_blanking do cycle_cost += 2

	switch ctrl.direction {
		case .RamToVram:
			if (video_addr + amnt) > mask {
				bus_write_byte(bus, VDMASTAT, 1)
				return
			}
			mem.copy(video_ptr, ram_ptr, amnt)
		case .VramToRam:
			if (ram_addr + amnt) >> 16 > 0x03 {
				bus_write_byte(bus, VDMASTAT, 1)
				return
			}
			mem.copy(ram_ptr, video_ptr, amnt)
	}

	bus.contention = u32(DMA_INIT_COST + cycle_cost * amnt)
}

bus_try_vmp_read :: proc(bus: ^MemoryBus) {
	ctrl := transmute(common.VmpControl)bus_read_byte(bus, VMPCTRL)
	if ctrl.direction != .VramToRam do return

	addr := bus_read_u24(bus, VMPADDR)
	dest := ctrl.destination

	width := ctrl.width
	ptr: ^u16

	switch dest {
		case .Vram:
			if addr > 0x1ffff do return

			ptr = (^u16)(bus.vram)
		case .Cram:
			if addr > 0x1ff do return

			ptr = (^u16)(bus.cram)
		case .Oam:
		case .Reserved:
			if addr > 0x7ff do return

			ptr = (^u16)(bus.oam)
	}

	ptr = mem.ptr_offset(ptr, addr)
	value := ptr^

	switch width {
		case .Byte:
			bus_write_byte(bus, VMDATAL, u8(value))
		case .Word:
			bus_write_word(bus, VMDATAL, value)
	}
	addr += 1 + u32(width)
	bus_write_u24(bus, VMPADDR, addr)

	is_blanking := bus_read_byte(bus, PPUSTATUS) & 0b11 != 0
	if !is_blanking do bus.contention = 2
}

bus_try_vmp_write :: proc(bus: ^MemoryBus) {
	ctrl := transmute(common.VmpControl)bus_read_byte(bus, VMPCTRL)
	if ctrl.direction != .RamToVram do return

	addr := bus_read_u24(bus, VMPADDR)
	dest := ctrl.destination

	ptr: ^u8

	width := ctrl.width
	offset := u32(width)
	switch dest {
		case .Vram:
			if addr > 0x1ffff - offset do return

			ptr = (^u8)(bus.vram)
		case .Cram:
			if addr > 0x1ff - offset do return

			ptr = (^u8)(bus.cram)
		case .Oam:
		case .Reserved:
			if addr > 0x7ff - offset do return

			ptr = (^u8)(bus.oam)
	}

	ptr = mem.ptr_offset(ptr, addr)
	value := bus_read_word(bus, VMDATAL)

	switch width {
		case .Byte:
			ptr^ = u8(value)
		case .Word:
			ptr_word := (^u16)(ptr)
			ptr_word^ = value
	}
	addr += 1 + offset
	bus_write_u24(bus, VMPADDR, addr)

	is_blanking := bus_read_byte(bus, PPUSTATUS) & 0b11 != 0
	if !is_blanking do bus.contention = 2
}
