package audio

import c "../common"
import "core:math"
import "core:slice"

WT1CTRL :: 0x29
WT1PITCH :: 0x2a
WT1VOL :: 0x2c
WT1VOR :: 0x2d
WT1ADSR :: 0x2e
WT1IDX :: 0x30

WT2CTRL :: 0x31
WT2PITCH :: 0x32
WT2VOL :: 0x34
WT2VOR :: 0x35
WT2ADSR :: 0x36
WT2IDX :: 0x38

TABLE_SIZE :: 64

WavetableCtrl :: distinct GenericChannelCtrl

WavetableChannel :: struct {
	using ctrl: WavetableCtrl,
	volume_l:   u8,
	volume_r:   u8,
	pitch:      u16,
	adsr:       Envelope,
	index:      u8,
	phase:      f32,
	state:      EnvState,
}

wavetable_generate :: proc(ch: ^WavetableChannel, aram: []byte) -> (l: f32, r: f32) {
	if ch.disabled do return 0.0, 0.0

	amp := envelope_step(&ch.state, ch.adsr, ch.gate_on, ch.reset_on_retrigger, &ch.phase)

	ch.phase += q12_4_expand(ch.pitch) / c.SAMPLE_RATE
	ch.phase -= math.floor(ch.phase)

	table := slice.bytes_from_ptr(&aram[int(ch.index) * TABLE_SIZE], TABLE_SIZE)
	vol_l := q0_8_expand(ch.volume_l)
	vol_r := q0_8_expand(ch.volume_r)

	table_idx := clamp(int(ch.phase * TABLE_SIZE), 0, TABLE_SIZE - 1)

	l = f32(i8(table[table_idx])) / 128.0
	r = l
	l *= amp * vol_l
	r *= amp * vol_r
	return l, r
}
