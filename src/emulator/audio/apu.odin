package audio

import "../common"
import "core:math"
import "core:slice"

ApuCtrl :: bit_field u8 {
	disabled: bool | 1,
	reserved: u8   | 7,
}

Apu :: struct {
	ctrl:         ApuCtrl,
	master_vol_l: u8,
	master_vol_r: u8,
	pulse:        PulseChannel,
	saw:          SawChannel,
	triangle:     TriangleChannel,
	noise:        NoiseChannel,
	wave1:        WavetableChannel,
	wave2:        WavetableChannel,
	mmio_view:    []byte,
	aram:         [common.AUDIO_RAM_SIZE]byte,
}

apu_init :: proc(apu: ^Apu, mmio_start_ptr: ^byte) {
	apu.mmio_view = slice.from_ptr(mmio_start_ptr, 0xff)
	apu.master_vol_l = 0xff
	apu.master_vol_r = 0xff
	// TODO: Maybe a small boot routine/BIOS should handle the initial channel setup
	apu.pulse.volume_l = 208
	apu.pulse.volume_r = 208
	apu.saw.volume_l = 192
	apu.saw.volume_r = 192
	apu.triangle.volume_l = 248
	apu.triangle.volume_r = 248
	apu.noise.volume_l = 192
	apu.noise.volume_r = 192
	apu.wave1.volume_l = 208
	apu.wave1.volume_r = 208
	apu.wave2.volume_l = 208
	apu.wave2.volume_r = 208
	apu_encode_to_mmio(apu)
	apu.noise.lfsr = LFSR_INIT
}

apu_encode_to_mmio :: proc(apu: ^Apu) {
	apu.mmio_view[common.APUCTRL] = transmute(u8)apu.ctrl
	apu.mmio_view[common.MASVOL] = apu.master_vol_l
	apu.mmio_view[common.MASVOR] = apu.master_vol_r
	apu.mmio_view[PULVOL] = apu.pulse.volume_l
	apu.mmio_view[PULVOR] = apu.pulse.volume_r
	apu.mmio_view[SAWVOL] = apu.saw.volume_l
	apu.mmio_view[SAWVOR] = apu.saw.volume_r
	apu.mmio_view[TRIVOL] = apu.triangle.volume_l
	apu.mmio_view[TRIVOR] = apu.triangle.volume_r
	apu.mmio_view[NOIVOL] = apu.noise.volume_l
	apu.mmio_view[NOIVOR] = apu.noise.volume_r
	apu.mmio_view[WT1VOL] = apu.wave1.volume_l
	apu.mmio_view[WT1VOR] = apu.wave1.volume_r
	apu.mmio_view[WT2VOL] = apu.wave2.volume_l
	apu.mmio_view[WT2VOR] = apu.wave2.volume_r
}

apu_decode_from_mmio :: proc(apu: ^Apu) {
	apu.ctrl = transmute(ApuCtrl)apu.mmio_view[common.APUCTRL]
	apu.master_vol_l = apu.mmio_view[common.MASVOL]
	apu.master_vol_r = apu.mmio_view[common.MASVOR]

	apu.pulse.ctrl = transmute(PulseCtrl)apu.mmio_view[PULCTRL]
	apu.pulse.pitch = u16(apu.mmio_view[PULPITCH]) | (u16(apu.mmio_view[PULPITCH + 1]) << 8)
	apu.pulse.volume_l = apu.mmio_view[PULVOL]
	apu.pulse.volume_r = apu.mmio_view[PULVOR]
	apu.pulse.adsr.rs = apu.mmio_view[PULADSR]
	apu.pulse.adsr.da = apu.mmio_view[PULADSR + 1]

	apu.saw.ctrl = transmute(SawCtrl)apu.mmio_view[SAWCTRL]
	apu.saw.pitch = u16(apu.mmio_view[SAWPITCH]) | (u16(apu.mmio_view[SAWPITCH + 1]) << 8)
	apu.saw.volume_l = apu.mmio_view[SAWVOL]
	apu.saw.volume_r = apu.mmio_view[SAWVOR]
	apu.saw.adsr.rs = apu.mmio_view[SAWADSR]
	apu.saw.adsr.da = apu.mmio_view[SAWADSR + 1]

	apu.triangle.ctrl = transmute(TriangleCtrl)apu.mmio_view[TRICTRL]
	apu.triangle.pitch = u16(apu.mmio_view[TRIPITCH]) | (u16(apu.mmio_view[TRIPITCH + 1]) << 8)
	apu.triangle.volume_l = apu.mmio_view[TRIVOL]
	apu.triangle.volume_r = apu.mmio_view[TRIVOR]
	apu.triangle.adsr.rs = apu.mmio_view[TRIADSR]
	apu.triangle.adsr.da = apu.mmio_view[TRIADSR + 1]

	apu.noise.ctrl = transmute(NoiseCtrl)apu.mmio_view[NOICTRL]
	apu.noise.rate = u16(apu.mmio_view[NOIRATE]) | (u16(apu.mmio_view[NOIRATE + 1]) << 8)
	apu.noise.volume_l = apu.mmio_view[NOIVOL]
	apu.noise.volume_r = apu.mmio_view[NOIVOR]
	apu.noise.adsr.rs = apu.mmio_view[NOIADSR]
	apu.noise.adsr.da = apu.mmio_view[NOIADSR + 1]

	apu.wave1.ctrl = transmute(WavetableCtrl)apu.mmio_view[WT1CTRL]
	apu.wave1.pitch = u16(apu.mmio_view[WT1PITCH]) | (u16(apu.mmio_view[WT1PITCH + 1]) << 8)
	apu.wave1.volume_l = apu.mmio_view[WT1VOL]
	apu.wave1.volume_r = apu.mmio_view[WT1VOR]
	apu.wave1.adsr.rs = apu.mmio_view[WT1ADSR]
	apu.wave1.adsr.da = apu.mmio_view[WT1ADSR + 1]
	apu.wave1.index = apu.mmio_view[WT1IDX]

	apu.wave2.ctrl = transmute(WavetableCtrl)apu.mmio_view[WT2CTRL]
	apu.wave2.pitch = u16(apu.mmio_view[WT2PITCH]) | (u16(apu.mmio_view[WT2PITCH + 1]) << 8)
	apu.wave2.volume_l = apu.mmio_view[WT2VOL]
	apu.wave2.volume_r = apu.mmio_view[WT2VOR]
	apu.wave2.adsr.rs = apu.mmio_view[WT2ADSR]
	apu.wave2.adsr.da = apu.mmio_view[WT2ADSR + 1]
	apu.wave2.index = apu.mmio_view[WT2IDX]
}

apu_generate_sample :: proc(apu: ^Apu) -> (l: f32, r: f32) {
	apu_decode_from_mmio(apu)
	if apu.ctrl.disabled do return 0.0, 0.0

	pl, pr := pulse_generate(&apu.pulse)
	tl, tr := triangle_generate(&apu.triangle)
	sl, sr := saw_generate(&apu.saw)
	nl, nr := noise_generate(&apu.noise)
	w1l, w1r := wavetable_generate(&apu.wave1, apu.aram[:])
	w2l, w2r := wavetable_generate(&apu.wave2, apu.aram[:])

	avg_l := (pl + tl + sl + nl + w1l + w2l) / 2.0
	vol_l := q0_8_expand(apu.master_vol_l)

	avg_r := (pr + tr + sr + nr + w1r + w2r) / 2.0
	vol_r := q0_8_expand(apu.master_vol_r)

	return math.tanh(avg_l) * vol_l, math.tanh(avg_r) * vol_r
}
