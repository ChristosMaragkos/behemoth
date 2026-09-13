package graphics

SCREEN_WIDTH :: 256
SCREEN_HEIGHT :: 240

Pixel :: struct {
	r, g, b, a: u8,
}

CramColor :: bit_field u16 {
	_: u8 | 1,
	b: u8 | 5,
	g: u8 | 5,
	r: u8 | 5,
}

FrameBuffer :: [SCREEN_WIDTH * SCREEN_HEIGHT]Pixel
