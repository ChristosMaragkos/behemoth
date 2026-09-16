package graphics

VRAM_SIZE :: 2 * 64 * 1024 // 128kb
CRAM_SIZE_BYTES :: 2 * 256
CRAM_SIZE_WORDS :: 256
OAM_SIZE :: 2 * 1024

VideoRam :: [VRAM_SIZE]byte
ColorRam :: [CRAM_SIZE_WORDS]CramColor
SpriteRam :: [OAM_SIZE / size_of(OamEntry)]OamEntry

ColorDepth :: enum u8 {
	_1bpp,
	_2bpp,
	_4bpp,
	_8bpp,
}
