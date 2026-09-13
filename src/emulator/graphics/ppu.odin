package graphics

PpuStatus :: bit_set[enum u8 {
	InVblank,
	InHblank,
};u8]

PpuCtrl :: bit_set[enum u8 {
	ForceBlanking,
	DisableVblank,
	DisableHblank,
};u8]

Ppu :: struct {
	status:       PpuStatus,
	ctrl:         PpuCtrl,
	current_line: u8,
	current_col:  u8,
	bg1_conf:     BgConfig,
	bg2_conf:     BgConfig,
	bg3_conf:     BgConfig,
	bg4_conf:     BgConfig,
	oam_conf:     OamConfig,
	vmp:          VideoMemoryPort,
	vram:         VideoRam,
	cram:         ColorRam,
	oam:          SpriteRam,
	frame_buffer: FrameBuffer,
}
