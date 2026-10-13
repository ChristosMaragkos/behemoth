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
WT1END :: 0x31

WT2CTRL :: 0x32
WT2PITCH :: 0x33
WT2VOL :: 0x35
WT2VOR :: 0x36
WT2ADSR :: 0x37
WT2IDX :: 0x39
WT2END :: 0x3a

TABLE_SIZE :: 64

WavetableCtrl :: bit_field u8 {
	disabled:           bool | 1,
	gate_on:            bool | 1,
	reset_on_retrigger: bool | 1,
	auto_advance:       bool | 1,
	mode:               enum u8 {
		Loop,
		One_Shot,
	}     | 1,
	reserved:           u8   | 3,
}

WavetableChannel :: struct {
	using ctrl:     WavetableCtrl,
	volume_l:       u8,
	volume_r:       u8,
	pitch:          u16,
	adsr:           Envelope,
	index_start:    u8,
	index_end:      u8,
	index_current:  u8,
	oneshot_done:   bool,
	gate_mmio_prev: bool,
	phase:          f32,
	state:          EnvState,
}

wavetable_sync_span :: proc(ch: ^WavetableChannel, base, end: u8) {
	if base != ch.index_start || end != ch.index_end {
		ch.index_start = base
		ch.index_end = end
		ch.index_current = base
		ch.oneshot_done = false
	}
}

@(private = "file")
wavetable_advance :: proc(ch: ^WavetableChannel) {
	if !ch.auto_advance {
		if ch.mode == .One_Shot {
			wavetable_finish_oneshot(ch)
		}
		return
	}
	end := max(ch.index_start, ch.index_end)
	if ch.index_current < end {
		ch.index_current += 1
		return
	}
	if ch.mode == .Loop {
		ch.index_current = ch.index_start
	} else {
		wavetable_finish_oneshot(ch)
	}
}

@(private = "file")
wavetable_finish_oneshot :: proc(ch: ^WavetableChannel) {
	ch.oneshot_done = true
	ch.gate_on = false
	ch.gate_mmio_prev = false
}

wavetable_generate :: proc(ch: ^WavetableChannel, aram: []byte) -> (l: f32, r: f32) {
	if ch.disabled do return 0.0, 0.0

	if ch.gate_on && !ch.gate_mmio_prev {
		ch.oneshot_done = false
		if ch.reset_on_retrigger {
			ch.phase = 0
			ch.index_current = ch.index_start
		}
	}
	ch.gate_mmio_prev = ch.gate_on

	effective_gate := ch.gate_on && !ch.oneshot_done
	amp := envelope_step(&ch.state, ch.adsr, effective_gate, ch.reset_on_retrigger, &ch.phase)

	ch.phase += q12_4_expand(ch.pitch) / c.SAMPLE_RATE
	if ch.phase >= 1.0 {
		ch.phase -= math.floor(ch.phase)
		wavetable_advance(ch)
	}

	table_idx_base := ch.index_start if !ch.auto_advance else ch.index_current
	table := slice.bytes_from_ptr(&aram[int(table_idx_base) * TABLE_SIZE], TABLE_SIZE)
	vol_l := q0_8_expand(ch.volume_l)
	vol_r := q0_8_expand(ch.volume_r)

	table_idx := clamp(int(ch.phase * TABLE_SIZE), 0, TABLE_SIZE - 1)

	l = f32(i8(table[table_idx])) / 128.0
	r = l
	l *= amp * vol_l
	r *= amp * vol_r

	if ch.state.state == .Idle {
		ch.index_current = ch.index_start
		ch.phase = 0
		ch.oneshot_done = false
	}
	return l, r
}
