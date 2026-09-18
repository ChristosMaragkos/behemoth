package audio

import c "../common"
import "core:math"

SAWCTRL :: 0x12
SAWPITCH :: 0x13
SAWVOL :: 0x15
SAWADSR :: 0x16

SawCtrl :: distinct GenericChannelCtrl

SawChannel :: struct {
	using ctrl: SawCtrl,
	volume:     u8,
	pitch:      u16,
	adsr:       Envelope,
	phase:      f32,
	state:      EnvState,
}

saw_generate :: proc(ch: ^SawChannel) -> f32 {
	if ch.disabled do return 0.0

	amp := envelope_step(&ch.state, ch.adsr, ch.gate_on, ch.reset_on_retrigger, &ch.phase)

	ch.phase += f32(ch.pitch) / c.SAMPLE_RATE
	ch.phase -= math.floor(ch.phase)

	vol := q0_8_expand(ch.volume)

	sample: f32 = 2.0 * ch.phase - 1.0
	sample *= amp * vol
	return sample
}
