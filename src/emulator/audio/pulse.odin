package audio

import c "../common"
import "core:math"

PULCTRL :: 0x0c
PULPITCH :: 0x0d
PULVOL :: 0x0f
PULADSR :: 0x10

PulseCtrl :: bit_field u8 {
	disabled:           bool | 1,
	gate_on:            bool | 1,
	reset_on_retrigger: bool | 1,
	duty_cycle:         u8   | 3,
	reserved:           u8   | 2,
}

PulseChannel :: struct {
	using ctrl: PulseCtrl,
	volume:     u8,
	pitch:      u16,
	adsr:       Envelope,
	phase:      f32,
	state:      EnvState,
}

pulse_generate :: proc(ch: ^PulseChannel) -> f32 {
	if ch.disabled do return 0.0

	amp := envelope_step(&ch.state, ch.adsr, ch.gate_on, ch.reset_on_retrigger, &ch.phase)

	ch.phase += f32(ch.pitch) / c.SAMPLE_RATE
	ch.phase -= math.floor(ch.phase)

	duty_cycle := duty_cycle_values[ch.duty_cycle]
	vol := q0_8_expand(ch.volume)

	sample: f32 = ch.phase < duty_cycle ? 1.0 : -1.0
	sample *= amp * vol
	return sample
}

@(rodata)
@(private = "file")
// Precalculated duty cycle values to avoid converting q0.3 fixed point to float every sample
duty_cycle_values := [8]f32{0.0, 0.125, 0.25, 0.375, 0.5, 0.625, 0.75, 0.875}
