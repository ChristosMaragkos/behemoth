package audio

TRICTRL :: 0x17
TRIPITCH :: 0x18
TRIVOL :: 0x1a
TRIADSR :: 0x1b

TriangleCtrl :: distinct GenericChannelCtrl

TriangleChannel :: struct {
	using ctrl: TriangleCtrl,
	volume:     u8,
	pitch:      u16,
	adsr:       Envelope,
}
