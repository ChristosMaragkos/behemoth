package graphics

VRAM_SIZE :: 2 * 64 * 1024 // 128kb
CRAM_SIZE :: 2 * 256
OAM_SIZE :: 2 * 1024

VideoRam :: [VRAM_SIZE]byte
ColorRam :: [CRAM_SIZE]byte
SpriteRam :: [OAM_SIZE]byte

ColorDepth :: enum u8 {
	_1bpp,
	_4bpp,
	_8bpp,
	Reserved,
}

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
		addr: u32 | 17,
	},
	data_l:  u8,
	data_h:  u8,
}
