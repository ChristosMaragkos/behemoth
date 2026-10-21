package png2bin

import "core:fmt"
import "core:os"
import "core:strconv"
import "core:strings"
import img "vendor:stb/image"

TILE_SIZE :: 8

Bpp :: enum {
	Bpp1 = 1,
	Bpp2 = 2,
	Bpp4 = 4,
	Bpp8 = 8,
}

bytes_per_tile :: proc(bpp: Bpp) -> int {
	switch bpp {
		case .Bpp1:
			return 8
		case .Bpp2:
			return 16
		case .Bpp4:
			return 32
		case .Bpp8:
			return 64
	}
	return 8
}

max_colors_for_bpp :: proc(bpp: Bpp) -> int {
	switch bpp {
		case .Bpp1:
			return 2
		case .Bpp2:
			return 4
		case .Bpp4:
			return 16
		case .Bpp8:
			return 256
	}
	return 2
}

rgba_to_rgb555 :: proc(r, g, b: u8) -> u16 {
	r5 := u16(r >> 3) & 0x1F
	g5 := u16(g >> 3) & 0x1F
	b5 := u16(b >> 3) & 0x1F
	return (b5 << 10) | (g5 << 5) | r5
}

main :: proc() {
	args := os.args[1:]
	if len(args) < 1 do fail()

	in_path := ""
	out_tiles := ""
	out_pal := ""
	in_pal := ""
	bpp := Bpp.Bpp4

	i := 0
	for i < len(args) {
		arg := args[i]
		switch arg {
			case "--bpp":
				i += 1
				if i >= len(args) do fail()
				val, ok := strconv.parse_int(args[i])
				if !ok do fail()
				switch val {
					case 1:
						bpp = .Bpp1
					case 2:
						bpp = .Bpp2
					case 4:
						bpp = .Bpp4
					case 8:
						bpp = .Bpp8
					case:
						fmt.eprintfln("Unsupported BPP: %d (choose 1, 2, 4, or 8)", val)
						os.exit(1)
				}
			case "-o":
				i += 1
				if i >= len(args) do fail()
				out_tiles = args[i]
			case "--in-pal":
				i += 1
				if i >= len(args) do fail()
				in_pal = args[i]
			case "--out-pal":
				i += 1
				if i >= len(args) do fail()
				out_pal = args[i]
			case:
				if strings.has_prefix(arg, "-") do fail()
				if in_path == "" {
					in_path = arg
				} else {
					fail()
				}
		}
		i += 1
	}

	if in_path == "" || !strings.has_suffix(in_path, ".png") do fail()

	if out_tiles == "" && out_pal == "" {
		fmt.eprintln(
			"Error: Must specify at least one output target (-o <tiles.bin> or --out-pal <out.pal>)",
		)
		fail()
	}

	palette_table: [dynamic]u16
	defer delete(palette_table)
	has_external_pal := false

	if in_pal != "" {
		pal_data, pal_err := os.read_entire_file(in_pal, context.allocator)
		if pal_err != nil {
			fmt.eprintfln("Failed to read palette file '%s': %s", in_pal, pal_err)
			os.exit(1)
		}
		defer delete(pal_data)

		if len(pal_data) % 2 != 0 {
			fmt.eprintfln("Corrupted palette '%s': size must be multiple of 2 bytes", in_pal)
			os.exit(1)
		}

		entries := len(pal_data) / 2
		for p in 0 ..< entries {
			val := u16(pal_data[p * 2]) | (u16(pal_data[p * 2 + 1]) << 8)
			append(&palette_table, val)
		}
		has_external_pal = true
	} else {
		append(&palette_table, 0x0000)
	}

	if out_tiles == "" && out_pal != "" {
		if !extract_palette_only(in_path, bpp, &palette_table) do os.exit(1)
		if !write_palette_file(out_pal, palette_table[:], bpp) do os.exit(1)

		fmt.printfln(
			"Ripped palette %s -> %s: %d colors (capped for %d bpp)",
			in_path,
			out_pal,
			len(palette_table),
			int(bpp),
		)
		return
	}

	packed, tile_count, ok := convert_png(in_path, bpp, &palette_table, has_external_pal)
	if !ok do os.exit(1)
	defer delete(packed)

	write_err := os.write_entire_file_from_bytes(out_tiles, packed)
	if write_err != nil {
		fmt.eprintfln("Could not write file %s: %s", out_tiles, write_err)
		os.exit(1)
	}

	if out_pal != "" && !has_external_pal {
		if !write_palette_file(out_pal, palette_table[:], bpp) do os.exit(1)
	}

	fmt.printfln(
		"Converted %s -> %s: %d tiles, %d bpp (%d bytes, %d colors in palette)",
		in_path,
		out_tiles,
		tile_count,
		int(bpp),
		len(packed),
		len(palette_table),
	)
}

fail :: proc() -> ! {
	fmt.eprintln(
		"Usage: png2bin <input.png> [--bpp 1|2|4|8] [-o tiles.bin] [--in-pal in.pal] [--out-pal out.pal]",
	)
	os.exit(1)
}

write_palette_file :: proc(path: string, palette: []u16, bpp: Bpp) -> bool {
	total_entries := 16
	if bpp == .Bpp8 do total_entries = 256

	pal_bytes := make([]u8, total_entries * 2)
	defer delete(pal_bytes)

	for c, idx in palette {
		if idx >= total_entries do break
		pal_bytes[idx * 2] = u8(c & 0xFF)
		pal_bytes[idx * 2 + 1] = u8(c >> 8)
	}

	err := os.write_entire_file_from_bytes(path, pal_bytes)
	if err != nil {
		fmt.eprintfln("Could not write palette file %s: %s", path, err)
		return false
	}
	return true
}

extract_palette_only :: proc(path: string, bpp: Bpp, palette: ^[dynamic]u16) -> bool {
	w, h, chans: i32
	pixels := img.load(cstring(raw_data(path)), &w, &h, &chans, 4)
	if pixels == nil {
		fmt.eprintfln("Failed to load image '%s': %s", path, img.failure_reason())
		return false
	}
	defer img.image_free(pixels)

	max_cols := max_colors_for_bpp(bpp)
	total_pixels := int(w * h)

	for p in 0 ..< total_pixels {
		idx := p * 4
		r := pixels[idx + 0]
		g := pixels[idx + 1]
		b := pixels[idx + 2]
		a := pixels[idx + 3]

		if a < 128 do continue

		c555 := rgba_to_rgb555(r, g, b)
		exists := false

		// dont merge any color with color 0 (kept to 0x0000 so true black gets merged otherwise)
		for existing_idx in 1 ..< len(palette) {
			if palette[existing_idx] == c555 {
				exists = true
				break
			}
		}

		if !exists {
			if len(palette) >= max_cols {
				fmt.eprintfln(
					"Image contains more than %d unique colors for %d bpp",
					max_cols,
					int(bpp),
				)
				return false
			}
			append(palette, c555)
		}
	}

	return true
}

convert_png :: proc(
	path: string,
	bpp: Bpp,
	palette: ^[dynamic]u16,
	fixed_palette: bool,
) -> (
	packed: []u8,
	tile_count: int,
	ok: bool,
) {
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

	bytes_per_t := bytes_per_tile(bpp)
	packed = make([]u8, tile_count * bytes_per_t)
	cursor := 0

	max_colors := max_colors_for_bpp(bpp)

	for ty in 0 ..< tiles_y {
		for tx in 0 ..< tiles_x {
			for row in 0 ..< TILE_SIZE {
				py := ty * TILE_SIZE + row
				row_indices: [8]u8

				for col in 0 ..< TILE_SIZE {
					px := tx * TILE_SIZE + col
					idx := (py * width + px) * 4

					r := pixels[idx + 0]
					g := pixels[idx + 1]
					b := pixels[idx + 2]
					a := pixels[idx + 3]

					if a < 128 {
						row_indices[col] = 0
						continue
					}

					c555 := rgba_to_rgb555(r, g, b)
					c_idx := -1

					start_idx := fixed_palette ? 0 : 1
					for existing_idx in start_idx ..< len(palette) {
						if !fixed_palette && existing_idx == 0 do continue
						if palette[existing_idx] == c555 {
							c_idx = existing_idx
							break
						}
					}

					if c_idx == -1 {
						if fixed_palette {
							fmt.eprintfln(
								"Color (R:%d, G:%d, B:%d) at (%d, %d) not found in palette",
								r,
								g,
								b,
								px,
								py,
							)
							delete(packed)
							return nil, 0, false
						}

						if len(palette) >= max_colors {
							fmt.eprintfln(
								"Image exceeds maximum %d colors allowed for %d bpp",
								max_colors,
								int(bpp),
							)
							delete(packed)
							return nil, 0, false
						}

						append(palette, c555)
						c_idx = len(palette) - 1
					}

					row_indices[col] = u8(c_idx)
				}

				switch bpp {
					case .Bpp1:
						row_byte: u8 = 0
						for c in 0 ..< 8 {
							if row_indices[c] > 0 do row_byte |= (1 << u8(7 - c))
						}
						packed[cursor] = row_byte
						cursor += 1

					case .Bpp2:
						packed[cursor] =
							(row_indices[0] << 6) |
							(row_indices[1] << 4) |
							(row_indices[2] << 2) |
							row_indices[3]
						packed[cursor + 1] =
							(row_indices[4] << 6) |
							(row_indices[5] << 4) |
							(row_indices[6] << 2) |
							row_indices[7]
						cursor += 2

					case .Bpp4:
						for c in 0 ..< 4 {
							packed[cursor + c] =
								(row_indices[c * 2] << 4) | (row_indices[c * 2 + 1] & 0x0F)
						}
						cursor += 4

					case .Bpp8:
						for c in 0 ..< 8 {
							packed[cursor + c] = row_indices[c]
						}
						cursor += 8
				}
			}
		}
	}

	return packed, tile_count, true
}
