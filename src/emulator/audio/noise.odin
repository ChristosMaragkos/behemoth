package audio

NOICTRL :: 0x1d
NOIRATE :: 0x1e
NOIVOL :: 0x20
NOIADSR :: 0x21

LFSR_INIT :: 0x7654

LfsrMode :: enum u8 {
	Long,
	Short,
}

NoiseCtrl :: bit_field u8 {
	disabled:           bool     | 1,
	gate_on:            bool     | 1,
	reset_on_retrigger: bool     | 1,
	mode:               LfsrMode | 1,
}

NoiseChannel :: struct {
	using ctrl:      NoiseCtrl,
	volume:          u8,
	rate:            u16,
	adsr:            Envelope,
	state:           EnvState,
	lfsr:            u16,
	advance_counter: u16,
}

noise_generate :: proc(ch: ^NoiseChannel) -> f32 {
	if ch.disabled do return 0.0

	if ch.gate_on && !ch.state.prev_gate {
		if ch.reset_on_retrigger {
			ch.lfsr = LFSR_INIT
			ch.advance_counter = 0
		}
	}

	phase: f32
	// Noise does not use phase so we just pass a stack dummy
	amp := envelope_step(&ch.state, ch.adsr, ch.gate_on, ch.reset_on_retrigger, &phase)

	ch.advance_counter += 1
	if ch.advance_counter >= ch.rate {
		ch.advance_counter = 0
		advance_lfsr(&ch.lfsr, ch.mode)
	}

	vol := q0_8_expand(ch.volume)

	sample: f32 = ch.lfsr & 1 == 1 ? 1.0 : -1.0
	sample *= amp * vol
	return sample
}

@(private = "file")
advance_lfsr :: #force_inline proc(lfsr: ^u16, mode: LfsrMode) {
	feedback: u16
	bit0: u16 = lfsr^ & 1
	shift_amnt: u16 = 6 - 5 * (1 - u16(mode))
	tap: u16 = (lfsr^ >> shift_amnt) & 1
	feedback = bit0 ~ tap
	lfsr^ = (lfsr^ >> 1) | (feedback << 14)
}
