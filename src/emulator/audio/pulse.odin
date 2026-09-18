package audio

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

