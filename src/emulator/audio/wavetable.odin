package audio

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

WavetableCtrl :: distinct GenericChannelCtrl

WavetableChannel :: struct {
	using ctrl: WavetableCtrl,
	volume:     u8,
	pitch:      u16,
	adsr:       Envelope,
	index:      u8,
}
