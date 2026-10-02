package audio

import c "../common"
import "core:math"

TRICTRL :: 0x1b
TRIPITCH :: 0x1c
TRIVOL :: 0x1e
TRIVOR :: 0x1f
TRIADSR :: 0x20

TriangleCtrl :: distinct GenericChannelCtrl

TriangleChannel :: struct {
	using ctrl: TriangleCtrl,
	volume_l:   u8,
	volume_r:   u8,
	pitch:      u16,
	adsr:       Envelope,
	phase:      f32,
	state:      EnvState,
}

triangle_generate :: proc(ch: ^TriangleChannel) -> (l: f32, r: f32) {
	if ch.disabled do return 0.0, 0.0

	amp := envelope_step(&ch.state, ch.adsr, ch.gate_on, ch.reset_on_retrigger, &ch.phase)

	ch.phase += q12_4_expand(ch.pitch) / c.SAMPLE_RATE
	ch.phase -= math.floor(ch.phase)

	vol_l := q0_8_expand(ch.volume_l)
	vol_r := q0_8_expand(ch.volume_r)

	l = 1.0 - (4.0 * math.abs(ch.phase - 0.5))
	r = l
	l *= amp * vol_l
	r *= amp * vol_r
	return l, r
}
