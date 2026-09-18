package audio

import "../common"
import "core:math"
import "core:slice"

ApuCtrl :: bit_field u8 {
	disabled: bool | 1,
	reserved: u8   | 7,
}

Apu :: struct {
	ctrl:       ApuCtrl,
	global_vol: u8,
	pulse:      PulseChannel,
	saw:        SawChannel,
	triangle:   TriangleChannel,
	noise:      NoiseChannel,
	wave1:      WavetableChannel,
	wave2:      WavetableChannel,
	mmio_view:  []byte,
	aram:       [common.AUDIO_RAM_SIZE]byte,
}

apu_init :: proc(apu: ^Apu, mmio_start_ptr: ^byte) {
	apu.mmio_view = slice.from_ptr(mmio_start_ptr, 0xff)
	apu.global_vol = 0xff
	// TODO: Maybe a small boot routine/BIOS should handle the initial channel setup
	apu.pulse.volume = 208
	apu.saw.volume = 192
	apu.triangle.volume = 248
	apu.noise.volume = 192
	apu.wave1.volume = 208
	apu.wave2.volume = 208
	apu_encode_to_mmio(apu)
	apu.noise.lfsr = LFSR_INIT
}

apu_encode_to_mmio :: proc(apu: ^Apu) {
	apu.mmio_view[PULVOL] = apu.pulse.volume
	apu.mmio_view[SAWVOL] = apu.saw.volume
	apu.mmio_view[TRIVOL] = apu.triangle.volume
	apu.mmio_view[NOIVOL] = apu.noise.volume
	apu.mmio_view[WT1VOL] = apu.wave1.volume
	apu.mmio_view[WT2VOL] = apu.wave2.volume
}

apu_decode_from_mmio :: proc(apu: ^Apu) {
	apu.ctrl = transmute(ApuCtrl)apu.mmio_view[common.APUCTRL]
	apu.global_vol = apu.mmio_view[common.GLBLVOL]

	apu.pulse.ctrl = transmute(PulseCtrl)apu.mmio_view[PULCTRL]
	apu.pulse.pitch = u16(apu.mmio_view[PULPITCH]) | (u16(apu.mmio_view[PULPITCH + 1]) << 8)
	apu.pulse.volume = apu.mmio_view[PULVOL]
	apu.pulse.adsr.rs = apu.mmio_view[PULADSR]
	apu.pulse.adsr.da = apu.mmio_view[PULADSR + 1]

	apu.saw.ctrl = transmute(SawCtrl)apu.mmio_view[SAWCTRL]
	apu.saw.pitch = u16(apu.mmio_view[SAWPITCH]) | (u16(apu.mmio_view[SAWPITCH + 1]) << 8)
	apu.saw.volume = apu.mmio_view[SAWVOL]
	apu.saw.adsr.rs = apu.mmio_view[SAWADSR]
	apu.saw.adsr.da = apu.mmio_view[SAWADSR + 1]

	apu.triangle.ctrl = transmute(TriangleCtrl)apu.mmio_view[TRICTRL]
	apu.triangle.pitch = u16(apu.mmio_view[TRIPITCH]) | (u16(apu.mmio_view[TRIPITCH + 1]) << 8)
	apu.triangle.volume = apu.mmio_view[TRIVOL]
	apu.triangle.adsr.rs = apu.mmio_view[TRIADSR]
	apu.triangle.adsr.da = apu.mmio_view[TRIADSR + 1]

	apu.noise.ctrl = transmute(NoiseCtrl)apu.mmio_view[NOICTRL]
	apu.noise.rate = u16(apu.mmio_view[NOIRATE]) | (u16(apu.mmio_view[NOIRATE + 1]) << 8)
	apu.noise.volume = apu.mmio_view[NOIVOL]
	apu.noise.adsr.rs = apu.mmio_view[NOIADSR]
	apu.noise.adsr.da = apu.mmio_view[NOIADSR + 1]

	apu.wave1.ctrl = transmute(WavetableCtrl)apu.mmio_view[WT1CTRL]
	apu.wave1.pitch = u16(apu.mmio_view[WT1PITCH]) | (u16(apu.mmio_view[WT1PITCH + 1]) << 8)
	apu.wave1.volume = apu.mmio_view[WT1VOL]
	apu.wave1.adsr.rs = apu.mmio_view[WT1ADSR]
	apu.wave1.adsr.da = apu.mmio_view[WT1ADSR + 1]

	apu.wave2.ctrl = transmute(WavetableCtrl)apu.mmio_view[WT2CTRL]
	apu.wave2.pitch = u16(apu.mmio_view[WT2PITCH]) | (u16(apu.mmio_view[WT2PITCH + 1]) << 8)
	apu.wave2.volume = apu.mmio_view[WT2VOL]
	apu.wave2.adsr.rs = apu.mmio_view[WT2ADSR]
	apu.wave2.adsr.da = apu.mmio_view[WT2ADSR + 1]
}

apu_generate_sample :: proc(apu: ^Apu) -> f32 {
	apu_decode_from_mmio(apu)
	if apu.ctrl.disabled do return 0.0

	pulse := pulse_generate(&apu.pulse)
	triangle := triangle_generate(&apu.triangle)
	saw := saw_generate(&apu.saw)
	noise := noise_generate(&apu.noise)
	wave1 := wavetable_generate(&apu.wave1, apu.aram[:])
	wave2 := wavetable_generate(&apu.wave2, apu.aram[:])

	avg := (pulse + triangle + saw + noise + wave1 + wave2) / 3.3
	vol := q0_8_expand(apu.global_vol)

	return math.tanh(avg) * vol
}
