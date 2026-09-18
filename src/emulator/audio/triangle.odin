package audio

import "core:math"

TRICTRL :: 0x17
TRIPITCH :: 0x18
TRIVOL :: 0x1a
TRIADSR :: 0x1b

TriangleCtrl :: distinct GenericChannelCtrl

TriangleChannel :: struct {
	using ctrl: TriangleCtrl,
	volume:     u8,
	pitch:      u16,
	adsr:       Envelope,
	phase:      f32,
	state:      EnvState,
}

triangle_generate :: proc(ch: ^TriangleChannel) -> f32 {
	if ch.disabled do return 0.0

	amp := envelope_step(&ch.state, ch.adsr, ch.gate_on, ch.reset_on_retrigger, &ch.phase)

	ch.phase += f32(ch.pitch) / SAMPLE_RATE
	ch.phase -= math.floor(ch.phase)

	vol := q0_8_expand(ch.volume)

	sample: f32 = 1.0 - (4.0 * math.abs(ch.phase - 0.5))
	sample *= amp * vol
	return sample
}
