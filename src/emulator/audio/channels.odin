package audio

Envelope :: struct #raw_union {
	using _: bit_field u16le {
		r: u8 | 4,
		s: u8 | 4,
		d: u8 | 4,
		a: u8 | 4,
	},
	using _: struct {
		rs: u8,
		da: u8,
	},
}

@(private)
GenericChannelCtrl :: bit_field u8 {
	disabled:           bool | 1,
	gate_on:            bool | 1,
	reset_on_retrigger: bool | 1,
	reserved:           u8   | 5,
}

q0_8_expand :: #force_inline proc(q: u8) -> f32 {
	return f32(q) / 256.0
}
