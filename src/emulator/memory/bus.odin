package memory

DMA_INIT_COST :: 10
SDMASTART :: 0x05_060a
VDMASTART :: 0x05_0544
VMPCTRL :: 0x05_0534
VMPADDR :: 0x05_0535
VMDATAL :: 0x05_0538
VMDATAH :: 0x05_0539

import "core:mem"

is_valid_write :: proc(addr: u32) -> bool {
	switch addr {
		case CART_ROM_START ..= CART_ROM_END:
			return false
		case:
			return true
	}
}

is_valid_read :: proc(addr: u32) -> bool {
	// FIXME: This is a no-op until MMIO is implemented
	return true
}

calculate_address :: proc(page: u8, offset: u16) -> u32 {
	return u32(page << 16) | u32(offset)
}

MemoryBus :: struct {
	ram:        MainRam,
	latch:      u16,
	vram:       rawptr,
	cram:       rawptr,
	oam:        rawptr,
	contention: u32,
}

bus_read_byte :: proc(bus: ^MemoryBus, addr: u32) -> byte {
	if !is_valid_read(addr) do return byte(bus.latch)

	return ram_read_byte(bus.ram[:], addr)
}

bus_read_word :: proc(bus: ^MemoryBus, addr: u32) -> u16 {
	if !is_valid_read(addr) do return bus.latch
	if !is_valid_read(addr + 1) do return bus.latch

	return ram_read_word(bus.ram[:], addr)
}

bus_write_byte :: proc(bus: ^MemoryBus, addr: u32, val: byte) {
	if !is_valid_write(addr) do return

	ram_write_byte(bus.ram[:], addr, val)

	if addr == SDMASTART do bus_system_dma(bus)
	else if addr == VDMASTART do bus_video_dma(bus)
}

bus_write_word :: proc(bus: ^MemoryBus, addr: u32, val: u16) {
	if !is_valid_write(addr) do return
	if !is_valid_write(addr + 1) do return

	ram_write_word(bus.ram[:], addr, val)
	// NOTE: This doesn't check the high byte
	if addr == SDMASTART do bus_system_dma(bus)
	else if addr == VDMASTART do bus_video_dma(bus)
}

@(private = "file")
bus_read_u24 :: proc(bus: ^MemoryBus, addr: u32) -> u32 {
	return u32(bus.ram[addr]) | u32(bus.ram[addr + 1] << 8) | u32(bus.ram[addr + 2] << 16)
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

bus_video_dma :: proc(bus: ^MemoryBus) {
	VDMACTRL :: 0x05_053a
	VDMASRC :: 0x05_053b
	VDMADST :: 0x05_053e
	VDMALEN :: 0x05_0541
	VDMASTAT :: 0x05_0543
	PPUSTATUS :: 0x05_0500

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
	is_blanking := bus_read_byte(bus, PPUSTATUS) & 0b11 == 0
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
