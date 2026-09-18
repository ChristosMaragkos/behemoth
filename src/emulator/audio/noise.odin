package audio

NOICTRL :: 0x1d
NOIRATE :: 0x1e
NOIVOL :: 0x20
NOIADSR :: 0x21

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
	using ctrl: NoiseCtrl,
	volume:     u8,
	rate:       u16,
	adsr:       Envelope,
}
