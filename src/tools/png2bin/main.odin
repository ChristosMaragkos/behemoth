package png2bin

import "core:fmt"
import "core:os"
import "core:strings"
import img "vendor:stb/image"

TILE_SIZE :: 8

main :: proc() {
	args := os.args

	if len(args) < 2 || len(args) > 4 {
		fail()
	}

	in_path := args[1]

	if !strings.has_suffix(in_path, ".png") do fail()

	out_path, allocated := strings.replace(in_path, "png", "bin", 1)
	defer if allocated do delete(out_path)

	if len(args) == 4 {
		if args[2] != "-o" do fail()

		out_path = os.args[3]
	}
	if len(os.args) == 3 {
		fail()
	}

	packed, tile_count, ok := pack_to_1bpp(in_path)
	if !ok do os.exit(1)
	defer delete(packed)

	err := os.write_entire_file_from_bytes(out_path, packed)
	if err != nil {
		fmt.eprintfln("Could not write file %s: %s", out_path, err)
		os.exit(1)
	}

	fmt.printfln(
		"Converted %s -> %s: %d tiles (%d bytes)",
		in_path,
		out_path,
		tile_count,
		len(packed),
	)
}

fail :: proc() -> ! {
	fmt.eprintln("Usage: png2bin <input.png> [-o output.bin]")
	os.exit(1)
}

pack_to_1bpp :: proc(path: string) -> (packed: []u8, tile_count: int, ok: bool) {
	w, h, chans: i32

	pixels := img.load(cstring(raw_data(path)), &w, &h, &chans, 4)
	if pixels == nil {
		fmt.eprintfln("Failed to load image '%s': %s", path, img.failure_reason())
		return nil, 0, false
	}
	defer img.image_free(pixels)

	width := int(w)
	height := int(h)

	if width % TILE_SIZE != 0 || height % TILE_SIZE != 0 {
		fmt.eprintfln("Image dimensions (%dx%d) must be multiples of %d", width, height, TILE_SIZE)
		return nil, 0, false
	}

	tiles_x := width / TILE_SIZE
	tiles_y := height / TILE_SIZE
	tile_count = tiles_x * tiles_y

	packed = make([]u8, tile_count * TILE_SIZE)
	cursor := 0

	for ty in 0 ..< tiles_y {
		for tx in 0 ..< tiles_x {
			for row in 0 ..< TILE_SIZE {
				py := ty * TILE_SIZE + row
				row_byte: u8 = 0

				for col in 0 ..< TILE_SIZE {
					px := tx * TILE_SIZE + col
					pixel_idx := py * width + px

					alpha := pixels[pixel_idx * 4 + 3]
					if alpha > 0 {
						row_byte |= (1 << u8(7 - col))
					}
				}

				packed[cursor] = row_byte
				cursor += 1
			}
		}
	}

	return packed, tile_count, true
}
