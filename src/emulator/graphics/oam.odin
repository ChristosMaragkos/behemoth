package graphics

OamConfig :: struct {
	using _: bit_field u32 {
		gfx_src: u32 | 17,
	},
	using _: bit_field u8 {
		color_depth: ColorDepth | 2,
	},
}

OamEntry :: struct #packed {
	x, y:     i16,
	using _:  bit_field u16 {
		tile_idx: u16  | 10,
		pal_idx:  u8   | 3,
		prio:     u8   | 2,
		disabled: bool | 1,
	},
	using _:  bit_field u8 {
		flip_h: bool | 1,
		flip_v: bool | 1,
		size_h: u8   | 3,
		size_v: u8   | 3,
	},
	reserved: u8,
}
#assert(size_of(OamEntry) == 8)
