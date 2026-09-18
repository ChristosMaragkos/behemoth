package audio

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
}
