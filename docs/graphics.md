# Graphics

The graphics chip (PPU) comes with:

- 128kb of VRAM, holding the tile data and grid maps for all four background layers. Accessible either
  word-by-word for individual reads and writes or via DMA for bulk transfers. Its layout is fully
  programmable: each layer's tile data and grid map live wherever their dedicated MMIO registers point,
  and the programmer is free to allocate the space however they see fit.
- 2kb of OAM (Object Attribute Memory) holding the descriptors of up to 256 sprites. Separate from the
  VRAM address space and written to via DMA transfer.
- 512 bytes of color RAM (CRAM) holding the 256-color palette. Also separate from the VRAM address space. See [[#Color]] below.

## Display

Internally, the PPU renders line-by-line at a resolution of 256x240. Depending on the size configuration of the background layers, this means that
you can have up to double the screen space as a scrollable buffer before you are required to update the grid maps.

## Color

CRAM consists of 16 palettes, each of which consists of 16 colors (15-bit RGB padded to 16 bits: 0_bbbbb_ggggg_rrrrr).
The first 8 palettes are used by the background layers and the last 8 are used by OAM sprites.
Regardless of the value of color 0 in each palette, it is always treated as transparent.

> [!NOTE]
> Later revisions may add color math capabilities per layer and per OAM sprite

## Tile data

Tile maps cannot be streamed from CPU memory and must be uploaded to VRAM via DMA transfer (or individual byte writes if
you are criminally insane). A single tile map can contain up to 1024 8x8 tiles and must be configured to use one color depth for
all of them. Possible color depths include:

- 1bpp: 1 -> color 1 in the selected palette, 0 -> color 0 (ergo transparent). 8 bytes per tile.
- 4bpp: Can use all the colors in the selected palette. 32 bytes per tile.
- 8bpp: Can use *every color in CRAM*. Indexing starts from the selected palette and wraps. 64 bytes per tile.

This means that at most, a full tile map of 8bpp tiles takes up 64kb of VRAM (half of the total space), but you do not need to use all 1024 tiles,
meaning you can create tile maps with fewer than the maximum necessary tiles and overlay them (but be careful using out-of-bounds tile indices if you do this).

## Background layers

VRAM is also home to four background graphics layers (bg1, bg2, bg3, bg4). Their origins must also be configured via MMIO registers (including the addresses and color depths
of the tilemaps they use). Each layer can have its size (in two-byte entries, see [[#Background layer entries]]) configured between these three modes:

- 32x32 -> 2kb total
- 32x64 -> 4kb total
- 64x32 -> 4kb total
- 64x64 -> 8kb total

Each layer can then contain that many total entries. Layers can also be scrolled using MMIO registers, both horizontally and vertically (with wrapping if
any edge of the layer is hit), and each layer supports a 2-bit priority value at the MMIO level as well as a 1-bit flag that bumps priority up per tile.
If not configured, the default priority order is as such, from lowest (drawn first) to highest (drawn last): bg1->bg2->bg3->oam->bg4. For more information, see
[[#Priority]] further down.

### Background layer entries

Each background tile entry consists of two bytes, formatted as such:

- Bits 0-9: Tile index from 0 to 1023
- Bits 10-12: Palette index from 0 to 7
- Bit 13: Flip horizontally if 1
- Bit 14: Flip vertically if 1
- Bit 15: Increase priority *only for this tile* by 1

## OAM

OAM (Object Attribute Memory) is used for anything that moves and has dynamic state. Each OAM entry amounts to 8 bytes, so, at 2kb, you may have up to 256
sprites on the screen at any time. OAM can also have the address and color depth of its tilemap in VRAM configured via MMIO but these options apply to all sprites.
This is the layout of an OAM entry:

- Bytes 0-1: Signed 16-bit X coordinate
- Bytes 2-3: Signed 16-bit Y coordinate. Position (0, 0) represents the top-left corner of the visible display.
- Bytes 4-5:
  - Bits 0-9: Tile index (0-1023 as with backgrounds)
  - Bits 10-12: Palette selector (0-7)
  - Bits 13-14: Priority (0-3)
  - Bit 15: Disable flag. If set to 1, sprite is not drawn.
- Byte 6:
  - Bit 0: Horizontal flip
  - Bit 1: Vertical flip
  - Bits 2-4: Horizontal size in total sprites (0-7). Draws the next `n` tiles towards the right (or left if horizontal flip is on).
  Minimum size is 1, so leave to zero for default (1x1) sprites.
  - Bits 5-7: Vertical size in total sprites (0-7). Draws `n` further rows of the same width as the horizontal selector, growing downward
  (or upward if vertical flip is on). Minimum size is 1, so leave to zero for default.
- Byte 7: Reserved

It should be noted that, for larger sprites, flipping applies to the entire sprite. Vertical flip mirrors each column and horizontal
flipping mirrors each row. Furthermore, rows of tiles for composed sprites must be packed contiguously in VRAM:
a sprite at base tile index `b` fills (`height`) rows of (`width`) tiles each. For example, a 3-wide by 2-tall sprite must be laid out as such:
`... tile 0, 1, 2 (row 0) -> tile 3, 4, 5 (row 1) ...`

Finally, unlike with real hardware, there is no per-scanline sprite limit.

## Priority

All four background layers and each individual OAM sprite can have their
priority index configured as described above. Priority is resolved as such:

In every scanline, for every pixel, the PPU queries all background layers and OAM to find out which graphics tiles intercept that
pixel. The PPU then compares the priority values of each pixel to find out which belongs to the topmost layer (the one with the highest priority value).

Any potential ties are broken like so:

- Between layers (and OAM): `bg1 < bg2 < bg3 < oam < bg4`
- Between OAM sprites: lowest OAM index wins

The selected pixel is then drawn to the screen.
Notice that, because OAM supports only the 4 priority values and background layers support priority values *and an optional +1 toggle*,
you can have a layer that is drawn always on top of everything by assigning it to priority 3 *and* setting its tiles' priority bit to 1.

## Drawing (what the PPU does each frame)

Every frame, the PPU draws the 256x240 display line by line, targeting 60 frames per second. While drawing to the screen,
VRAM, Color RAM and OAM are constantly being read by the video chip to output pixels at a steady rate, so read and write operations
to them produce bus contention, stalling the CPU for about 2 cycles while the I/O operation is queued.
At the end of each line, the horizontal blank (`HBLNK`) interrupt fires (if not masked), signaling that the PPU is done drawing
and allowing free access to VRAM, OAM and CRAM for 200 CPU cycles. After all 240 lines have been drawn, the vertical blank (`VBLNK`) non-maskable interrupt
is triggered, once again allowing free memory access for 25 scan lines' worth of PPU time (which translates to 12800 CPU cycles).
