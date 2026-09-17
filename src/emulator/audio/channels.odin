package audio

PulseCtrl :: bit_field u8 {
	disabled:           bool | 1,
	gate_on:            bool | 1,
	reset_on_retrigger: bool | 1,
	duty_cycle:         u8   | 3,
	reserved:           u8   | 2,
}

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

// This is not the exact ordering used in the spec but it'll be packed tighter in memory
PulseChannel :: struct {
	using _: PulseCtrl,
	volume:  u8,
	pitch:   u16,
	adsr:    Envelope,
}

@(private = "file")
GenericChannelCtrl :: bit_field u8 {
	disabled:           bool | 1,
	gate_on:            bool | 1,
	reset_on_retrigger: bool | 1,
	reserved:           u8   | 5,
}

SawCtrl :: distinct GenericChannelCtrl

SawChannel :: struct {
	using _: SawCtrl,
	volume:  u8,
	pitch:   u16,
	adsr:    Envelope,
}

TriangleCtrl :: distinct GenericChannelCtrl

TriangleChannel :: struct {
	using _: TriangleCtrl,
	volume:  u8,
	pitch:   u16,
	adsr:    Envelope,
}

NoiseCtrl :: bit_field u8 {
	disabled:           bool | 1,
	gate_on:            bool | 1,
	reset_on_retrigger: bool | 1,
	mode:               enum u8 {
		Long,
		Short,
	}     | 1,
}

NoiseChannel :: struct {
	using _: NoiseCtrl,
	volume:  u8,
	rate:    u16,
	adsr:    Envelope,
}

WavetableCtrl :: distinct GenericChannelCtrl

WavetableChannel :: struct {
	using _: WavetableCtrl,
	volume:  u8,
	pitch:   u16,
	adsr:    Envelope,
	index:   u8,
}
