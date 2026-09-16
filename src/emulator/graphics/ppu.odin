package graphics

// Horizontal blank duration in PPU cycles (CPU runs at 2x the speed)
HBLANK_DURATION :: 100
PPU_MMIO_OFFSET :: 0x0500

import "../common"
import "core:slice"

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
	backdrop:     u8,
	current_col:  u8,
	current_line: u16,
	hblank_count: u8,
	mmio_view:    []byte,
	bg1_conf:     BgConfig,
	bg2_conf:     BgConfig,
	bg3_conf:     BgConfig,
	bg4_conf:     BgConfig,
	oam_conf:     OamConfig,
	vmp:          common.VideoMemoryPort,
	vram:         VideoRam,
	cram:         ColorRam,
	oam:          SpriteRam,
	frame_buffer: FrameBuffer,
}

// Extract writeable PPU registers from MMIO
ppu_decode_from_mmio :: proc(ppu: ^Ppu) {
	ppu.ctrl = transmute(PpuCtrl)read_u8(ppu.mmio_view, 0x02)
	ppu.backdrop = read_u8(ppu.mmio_view, 0x03)

	ppu.bg1_conf.h_offs = i16(read_u16(ppu.mmio_view, 0x04))
	ppu.bg1_conf.v_offs = i16(read_u16(ppu.mmio_view, 0x06))
	ppu.bg2_conf.h_offs = i16(read_u16(ppu.mmio_view, 0x08))
	ppu.bg2_conf.v_offs = i16(read_u16(ppu.mmio_view, 0x0a))
	ppu.bg3_conf.h_offs = i16(read_u16(ppu.mmio_view, 0x0c))
	ppu.bg3_conf.v_offs = i16(read_u16(ppu.mmio_view, 0x0e))
	ppu.bg4_conf.h_offs = i16(read_u16(ppu.mmio_view, 0x10))
	ppu.bg4_conf.v_offs = i16(read_u16(ppu.mmio_view, 0x12))

	ppu.bg1_conf.entry_src = read_u24(ppu.mmio_view, 0x14) & 0x1ffff
	ppu.bg2_conf.entry_src = read_u24(ppu.mmio_view, 0x17) & 0x1ffff
	ppu.bg3_conf.entry_src = read_u24(ppu.mmio_view, 0x1a) & 0x1ffff
	ppu.bg4_conf.entry_src = read_u24(ppu.mmio_view, 0x1d) & 0x1ffff

	ppu.bg1_conf.gfx_src = read_u24(ppu.mmio_view, 0x20) & 0x1ffff
	ppu.bg2_conf.gfx_src = read_u24(ppu.mmio_view, 0x23) & 0x1ffff
	ppu.bg3_conf.gfx_src = read_u24(ppu.mmio_view, 0x26) & 0x1ffff
	ppu.bg4_conf.gfx_src = read_u24(ppu.mmio_view, 0x29) & 0x1ffff

	ppu.bg1_conf.ctrl = transmute(BgCtrl)read_u8(ppu.mmio_view, 0x2c)
	ppu.bg2_conf.ctrl = transmute(BgCtrl)read_u8(ppu.mmio_view, 0x2d)
	ppu.bg3_conf.ctrl = transmute(BgCtrl)read_u8(ppu.mmio_view, 0x2e)
	ppu.bg4_conf.ctrl = transmute(BgCtrl)read_u8(ppu.mmio_view, 0x2f)

	ppu.oam_conf.gfx_src = read_u24(ppu.mmio_view, 0x30) & 0x1ffff
	ppu.oam_conf.color_depth = ColorDepth(read_u8(ppu.mmio_view, 0x33))

	ppu.vmp.control = common.VmpControl(read_u8(ppu.mmio_view, 0x34))
	ppu.vmp.addr = read_u24(ppu.mmio_view, 0x35)
	ppu.vmp.data_l = read_u8(ppu.mmio_view, 0x38)
	ppu.vmp.data_h = read_u8(ppu.mmio_view, 0x39)
}

@(private = "file")
read_u8 :: proc(view: []byte, addr: u8) -> u8 {
	return view[addr]
}

@(private = "file")
read_u16 :: proc(view: []byte, addr: u8) -> u16 {
	return u16(view[addr]) | u16(view[addr + 1] << 8)
}

@(private = "file")
read_u24 :: proc(view: []byte, addr: u8) -> u32 {
	return u32(view[addr]) | u32(view[addr + 1] << 8) | u32(view[addr + 2] << 16)
}

ppu_encode_to_mmio :: proc(ppu: ^Ppu) {
	ppu.mmio_view[0x00] = transmute(u8)ppu.status
	ppu.mmio_view[0x01] = u8(clamp(ppu.current_line, 0, 239))
}

ppu_step :: proc(ppu: ^Ppu) {
	if .ForceBlanking in ppu.ctrl {
		ppu.status -= {.InHblank, .InVblank}
		ppu.current_col = 0
		ppu.current_line = 0
		return
	}
	if .InVblank not_in ppu.status && .InHblank not_in ppu.status {
		candidates: [5]PixelCandidate
		for i in PixelSource.Bg1 ..= PixelSource.Bg4 {
			candidates[i] = get_pixel_candidate(
				ppu,
				int(ppu.current_col),
				int(ppu.current_line),
				i,
			)
		}

		// sort in descending order so the larger priorities end up first
		slice.reverse_sort_by(candidates[:], candidate_less_than)
		chosen_color := ppu.backdrop
		for i in 0 ..< 5 {
			if candidates[i].color_index % 16 == 0 do continue

			chosen_color = candidates[i].color_index
			break
		}

		color := ppu.cram[chosen_color]
		r, g, b := scale_to_rgb(color)

		pixel_idx := uint(ppu.current_line) * SCREEN_WIDTH + uint(ppu.current_col)
		ppu.frame_buffer[pixel_idx].r = r
		ppu.frame_buffer[pixel_idx].g = g
		ppu.frame_buffer[pixel_idx].b = b
		ppu.frame_buffer[pixel_idx].a = chosen_color % 16 == 0 ? 0 : 0xff
	}

	if .InHblank not_in ppu.status {
		ppu.current_col += 1
		if ppu.current_col != 0 do return

		ppu.current_line += 1
		if ppu.current_line < 240 {
			ppu.status += {.InHblank}
			ppu.hblank_count = HBLANK_DURATION
		}
		if ppu.current_line == 240 {
			ppu.status += {.InVblank}
		} else if ppu.current_line == 265 {
			ppu.status -= {.InVblank}
			ppu.current_line = 0
		}
	} else {
		ppu.hblank_count -= 1
		if ppu.hblank_count == 0 {
			ppu.status -= {.InHblank}
		}
	}
}

ppu_get_tile_slice :: proc(ppu: ^Ppu, gfx_src: u32, tile_idx: u32, tile_size: u32) -> []byte {
	return slice.bytes_from_ptr(&ppu.vram[gfx_src + tile_size * tile_idx], int(tile_size))
}

get_layer_mask_and_cadence :: proc(size: LayerSize) -> (mask_x, mask_y: int, layer_width: int) {
	switch size {
		case ._32x32:
			return 255, 255, 32
		case ._32x64:
			return 255, 511, 32
		case ._64x32:
			return 511, 255, 64
		case ._64x64:
			return 511, 511, 64
	}
	return 255, 255, 32
}

// This is also the exact same order in which ties are broken,
// so the algorithm can use u32(candidate.source)
PixelSource :: enum u16 {
	Bg1,
	Bg2,
	Bg3,
	Oam,
	Bg4,
}

PixelCandidate :: struct {
	color_index: u8,
	prio:        u8,
	source:      PixelSource,
}

candidate_less_than :: proc(c1, c2: PixelCandidate) -> bool {
	return c1.prio < c2.prio || (c1.prio == c2.prio && c1.source < c2.source)
}

get_pixel_candidate :: proc(
	ppu: ^Ppu,
	scr_x, scr_y: int,
	source_in: PixelSource,
) -> (
	candidate: PixelCandidate,
) {
	candidate.source = source_in
	if source_in != .Oam {
		conf: BgConfig
		#partial switch source_in {
			case .Bg1:
				conf = ppu.bg1_conf
				candidate.prio = conf.prio
			case .Bg2:
				conf = ppu.bg2_conf
				candidate.prio = conf.prio
			case .Bg3:
				conf = ppu.bg3_conf
				candidate.prio = conf.prio
			case .Bg4:
				conf = ppu.bg4_conf
				candidate.prio = conf.prio
		}

		if conf.disabled {
			// set it to a known-transparent color index so it will be ignored further
			// down the pipeline
			candidate.color_index = 0
			return
		}

		mask_x, mask_y, cadence := get_layer_mask_and_cadence(conf.size)
		// transform screen x, y into layer x, y:
		layer_x := (scr_x - int(conf.h_offs)) & mask_x
		layer_y := (scr_y - int(conf.v_offs)) & mask_y
		tile_x, tile_y, offs_x, offs_y := layer_x / 8, layer_y / 8, layer_x % 8, layer_y % 8

		idx := int(conf.entry_src) + (2 * (cadence * tile_y + tile_x))
		low, high := u16(ppu.vram[idx]), u16(ppu.vram[idx + 1])
		entry := transmute(BgEntry)((high << 8) | low)

		candidate.prio = conf.prio + u8(entry.inc_prio)
		candidate.color_index = 16 * entry.pal_idx

		if entry.flip_h do offs_x = 7 - offs_x
		if entry.flip_v do offs_y = 7 - offs_y

		tile_size := get_tile_size(conf.color_depth)
		tile := ppu_get_tile_slice(ppu, conf.gfx_src, u32(entry.tile_idx), tile_size)

		candidate.color_index += get_tile_pixel_color(conf.color_depth, tile[:], offs_x, offs_y)
	} else {
		scr_x, scr_y := i16(u16(scr_x)), i16(u16(scr_y))
		latest_prio: i8 = -1
		candidate.color_index = 0
		depth := ppu.oam_conf.color_depth
		gfx_src := ppu.oam_conf.gfx_src
		tile_size := get_tile_size(depth)
		for &sprite in ppu.oam {
			TILE_WIDTH, TILE_HEIGHT :: 8, 8
			if sprite.disabled do continue

			tiles_h := int(sprite.size_h + 1)
			tiles_v := int(sprite.size_v + 1)

			rel_x := int(scr_x) - int(sprite.x)
			rel_y := int(scr_y) - int(sprite.y)

			if !(rel_x >= 0 &&
				   rel_y >= 0 &&
				   rel_x < tiles_h * TILE_WIDTH &&
				   rel_y < tiles_v * TILE_HEIGHT) { continue }
			// if pixel does not fall within sprite AABB just skip
			signed_prio := i8(sprite.prio)
			if signed_prio <= latest_prio && candidate.color_index % 16 != 0 do continue
			// if entry has lower priority than the latest valid candidate, and the candidate's latest color was not transparent, skip
			// equal prio also fails because ties are broken by picking the lowest OAM index

			// for entries composed of more than one tile,
			// get which tile we are at and the offset within that tile
			col0, row0 := rel_x / 8, rel_y / 8
			ofx0, ofy0 := rel_x % 8, rel_y % 8

			col, ofx := col0, ofx0
			row, ofy := row0, ofy0

			// flipping applies to composite sprites in their entirety,
			// mirroring rows and columns, so we must reverse the order:
			// for example, column 0, offset 0 of a 2x2 tile must become
			// column 1, offset 7. Same for rows.
			if sprite.flip_h do col, ofx = tiles_h - 1 - col0, 7 - ofx0
			if sprite.flip_v do row, ofy = tiles_v - 1 - row0, 7 - ofy0

			tile_idx := u32(int(sprite.tile_idx) + row * tiles_h + col)
			tile := ppu_get_tile_slice(ppu, gfx_src, tile_idx, tile_size)
			candidate.color_index =
				((sprite.pal_idx + 8) * 16) + get_tile_pixel_color(depth, tile[:], ofx, ofy)
			candidate.prio = sprite.prio
			latest_prio = i8(sprite.prio)
		}
	}
	return
}

get_tile_pixel_color :: proc(depth: ColorDepth, tile: []byte, offs_x, offs_y: int) -> (value: u8) {
	switch depth {
		case ._1bpp:
			value = (tile[offs_y] >> uint(7 - offs_x)) & 0b1
		case ._2bpp:
			row := offs_y * 2

			column_byte := offs_x / 4
			column_offset := offs_x % 4

			value = ((tile[row + column_byte]) >> uint(6 - (2 * column_offset))) & 0b11
		case ._4bpp:
			is_left_pixel := offs_x % 2 == 0

			value = tile[offs_y * 4 + offs_x / 2]
			if is_left_pixel do value >>= 4
			else do value &= 0xf
		case ._8bpp:
			value = tile[offs_y * 8 + offs_x]
	}
	return
}

get_tile_size :: #force_inline proc(depth: ColorDepth) -> u32 {
	return 8 << depth
}

scale_to_rgb :: proc(clr: CramColor) -> (r, g, b: u8) {
	r = clr.r * 255 / 31
	g = clr.g * 255 / 31
	b = clr.b * 255 / 31
	return
}
