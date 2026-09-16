package common

VmpControl :: bit_field u8 {
	width:       enum u8 {
		Byte,
		Word,
	} | 1,
	direction:   enum u8 {
		VramToRam,
		RamToVram,
	} | 1,
	destination: enum u8 {
		Vram,
		Cram,
		Oam,
		Reserved,
	} | 2,
}

VideoMemoryPort :: struct {
	control: VmpControl,
	using _: bit_field u32 {
		addr: u32 | 24,
	},
	data_l:  u8,
	data_h:  u8,
}
