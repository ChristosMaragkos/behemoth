package audio

import c "../common"
import "core:math"

SAWCTRL :: 0x14
SAWPITCH :: 0x15
SAWVOL :: 0x17
SAWVOR :: 0x18
SAWADSR :: 0x19

SawCtrl :: distinct GenericChannelCtrl

SawChannel :: struct {
	using ctrl: SawCtrl,
	volume_l:   u8,
	volume_r:   u8,
	pitch:      u16,
	adsr:       Envelope,
	phase:      f32,
	state:      EnvState,
}

saw_generate :: proc(ch: ^SawChannel) -> (l: f32, r: f32) {
	if ch.disabled do return 0.0, 0.0

	amp := envelope_step(&ch.state, ch.adsr, ch.gate_on, ch.reset_on_retrigger, &ch.phase)

	ch.phase += q12_4_expand(ch.pitch) / c.SAMPLE_RATE
	ch.phase -= math.floor(ch.phase)

	vol_l := q0_8_expand(ch.volume_l)
	vol_r := q0_8_expand(ch.volume_r)

	l = 2.0 * ch.phase - 1.0
	r = l
	l *= amp * vol_l
	r *= amp * vol_r
	return l, r
}
