package audio

import c "../common"
import "core:math"
import "core:slice"

WT1CTRL :: 0x23
WT1PITCH :: 0x24
WT1VOL :: 0x26
WT1ADSR :: 0x27
WT1IDX :: 0x29

WT2CTRL :: 0x2a
WT2PITCH :: 0x2b
WT2VOL :: 0x2d
WT2ADSR :: 0x2e
WT2IDX :: 0x30

TABLE_SIZE :: 64

WavetableCtrl :: distinct GenericChannelCtrl

WavetableChannel :: struct {
	using ctrl: WavetableCtrl,
	volume:     u8,
	pitch:      u16,
	adsr:       Envelope,
	index:      u8,
	phase:      f32,
	state:      EnvState,
}

wavetable_generate :: proc(ch: ^WavetableChannel, aram: []byte) -> f32 {
	if ch.disabled do return 0.0

	amp := envelope_step(&ch.state, ch.adsr, ch.gate_on, ch.reset_on_retrigger, &ch.phase)

	ch.phase += f32(ch.pitch) / c.SAMPLE_RATE
	ch.phase -= math.floor(ch.phase)

	table := slice.bytes_from_ptr(&aram[ch.index * TABLE_SIZE], TABLE_SIZE)
	vol := q0_8_expand(ch.volume)

	table_idx := int(ch.phase * TABLE_SIZE)

	sample := (f32(table[table_idx]) / 255.0) * 2.0 - 1.0
	sample *= amp * vol
	return sample
}
