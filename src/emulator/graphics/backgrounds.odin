package graphics

LayerSize :: enum u8 {
	_32x32,
	_32x64,
	_64x32,
	_64x64,
}

BgCtrl :: bit_field u8 {
	disabled:    bool       | 1,
	color_depth: ColorDepth | 2,
	size:        LayerSize  | 2,
	prio:        u8         | 2,
	reserved:    u8         | 1,
}

BgConfig :: struct {
	h_offs:  i16,
	v_offs:  i16,
	using _: bit_field u32 {
		entry_src: u32 | 17,
	},
	using _: bit_field u32 {
		gfx_src: u32 | 17,
	},
	using _: BgCtrl,
}

BgEntry :: bit_field u16 {
	tile_idx: u16  | 10,
	pal_idx:  u8   | 3,
	flip_h:   bool | 1,
	flip_v:   bool | 1,
	inc_prio: bool | 1,
}
