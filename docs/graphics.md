
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
you are criminally insane). A single tile map can contain up to 1024 8x8 tiles, and layers/OAM must be configured
to use one color depth for all of their entries. Possible color depths include:

- 1bpp: 1 -> color 1 in the selected palette, 0 -> color 0 (ergo transparent). 8 bytes per tile.
- 2bpp: Can use colors 0-3 of the selected palette. Packs 4 pixels per byte for 16 bytes per tile.
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
  - Bits 2-4: Horizontal size in total sprites (1-8). Draws the next `n` tiles towards the right (or left if horizontal flip is on).
  Minimum size is 1, so leave to zero for default (1x1) sprites.
  - Bits 5-7: Vertical size in total sprites (1-8). Draws `n` further rows of the same width as the horizontal selector, growing downward
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
is triggered, once again allowing free memory access for 25 scan lines' worth of PPU time (which translates to 17800 CPU cycles).

# MMIO & Graphics

The MMIO region for graphics begins at `$05:0500` and houses various control registers and the video memory port.
DMA controllers are documented in [dma.md](./dma.md).

## General PPU state handling

| Address | Name | Description | Read/Write? | Size (bytes) |
| :-------------: | :-------------: | --------------- | :-------------: | :-------------: |
| `$05:0500` | PPUSTATUS | PPU status flags bitmask (see below) | R | 1 |
| `$05:0501` | CRNTLN | Current scanline being drawn by the PPU. Is updated after horizontal blanking. | R | 1 |
| `$05:0502` | PPUCTRL | PPU control bitmask (see below) | RW | 1 |
| `$05:0503` | BACKDROP | CRAM index of the backdrop color, drawn where nothing else has an opaque pixel | RW | 1 |

- PPUSTATUS:
  - Bit 0: `VBLANK`. Set to 1 while the PPU is in vertical blank. Cleared when rendering resumes.
  - Bit 1: `HBLANK`. Set to 1 while the PPU is in a horizontal blank. Cleared when active scan resumes on that line.
  - Bits 2-7: Reserved

- PPUCTRL:
  - Bit 0: Force blanking. Set to 1 to disable PPU rendering entirely and get free access to VRAM/OAM/CRAM on the main bus.
  - Bit 1: Disables interrupt on v-blank if set to 1
  - Bit 2: Disables interrupt on h-blank if set to 1
  - Bits 3-7: Reserved

- BACKDROP:
  - Plain index into CRAM (0-255), the color every scanline falls back to when no background layer or OAM sprite paints an opaque pixel there. Unlike palette color 0, this value is *not* treated as transparent.

## Background layers

| Address | Name | Description | Read/Write? | Size (bytes) |
| :-------------: | :-------------: | --------------- | :-------------: | :-------------: |
| `$05:0504` | BG1HOFS | 16-bit signed horizontal offset for background layer 1 | RW | 2 |
| `$05:0506` | BG1VOFS | 16-bit signed vertical offset for background layer 1 | RW | 2 |
| `$05:0508` | BG2HOFS | 16-bit signed horizontal offset for background layer 2 | RW | 2 |
| `$05:050a` | BG2VOFS | 16-bit signed vertical offset for background layer 2 | RW | 2 |
| `$05:050c` | BG3HOFS | 16-bit signed horizontal offset for background layer 3 | RW | 2 |
| `$05:050e` | BG3VOFS | 16-bit signed vertical offset for background layer 3 | RW | 2 |
| `$05:0510` | BG4HOFS | 16-bit signed horizontal offset for background layer 4 | RW | 2 |
| `$05:0512` | BG4VOFS | 16-bit signed vertical offset for background layer 4 | RW | 2 |
| `$05:0514` | BG1SRC | 17-bit source address for background 1 entry data | RW | 3 |
| `$05:0517` | BG2SRC | 17-bit source address for background 2 entry data | RW | 3 |
| `$05:051a` | BG3SRC | 17-bit source address for background 3 entry data | RW | 3 |
| `$05:051d` | BG4SRC | 17-bit source address for background 4 entry data | RW | 3 |
| `$05:0520` | BG1GFXSRC | 17-bit source address for background 1 graphics data | RW | 3 |
| `$05:0523` | BG2GFXSRC | 17-bit source address for background 2 graphics data | RW | 3 |
| `$05:0526` | BG3GFXSRC | 17-bit source address for background 3 graphics data | RW | 3 |
| `$05:0529` | BG4GFXSRC | 17-bit source address for background 4 graphics data | RW | 3 |
| `$05:0530` | BG1CTRL | Background 1 control bitfield (see below) | RW | 1 |
| `$05:0531` | BG2CTRL | Background 2 control bitfield (see below) | RW | 1 |
| `$05:0532` | BG3CTRL | Background 3 control bitfield (see below) | RW | 1 |
| `$05:0533` | BG4CTRL | Background 4 control bitfield (see below) | RW | 1 |

- `BG`*`CTRL` (`BG1CTRL`..`BG4CTRL`), identical layout for each layer:
  - Bit 0: Disable. Set to 1 to skip drawing this layer; if 0 the layer is drawn.
  - Bits 1-2: Color depth (see [[#Tile data]]): 0 -> 1bpp, 1 -> 2bpp, 2 -> 4bpp, 3 -> 8bpp.
  - Bits 3-4: Layer size (see [[#Background layers]]): 0 -> 32x32, 1 -> 32x64, 2 -> 64x32, 3 -> 64x64.
  - Bits 5-6: Priority (0-3), resolved against other layers/OAM as described in [[#Priority]].
  - Bit 7: Reserved.

## OAM

| Address | Name | Description | Read/Write? | Size (bytes) |
| :-------------: | :-------------: | --------------- | :-------------: | :-------------: |
| `$05:052c` | OAMGFXSRC | 17-bit source address for OAM graphics data | RW | 3 |
| `$05:052f` | OAMCTRL | OAM control bitfield (see below) | RW | 1 |

- `OAMCTRL`:
  - Bits 0-1: Color depth for all sprites (see [[#Tile data]]): 0 -> 1bpp, 1 -> 2bpp, 2 -> 4bpp, 3 -> 8bpp.
  - Bits 2-7: Reserved.

## Off-bus data access

These registers allow you to read and write data from and to VRAM, CRAM or OAM without a DMA transfer.
Note that using the video memory port outside of a blanking period (v-blank or h-blank) will result in bus contention. The data is guaranteed
to have arrived to or from its destination by the time the CPU is executing its next instruction.
Reads and writes from and to invalid addresses are simply dropped.

| Address | Name | Description | Read/Write? | Size (bytes) |
| :-------------: | :-------------: | --------------- | :-------------: | :-------------: |
| `$05:0534` | VMPCTRL | Video memory port control bitmask (see below) | RW | 1 |
| `$05:0535` | VMADDR | Address in VRAM/CRAM/OAM to read from/write to. Incremented based on bit 0 of `VMPCTRL`. 17-bit due to 128kb VRAM. | RW | 3 |
| `$05:0538` | VMDATAL | Low byte of word to write to (or read from) video memory | RW | 1 |
| `$05:0539` | VMDATAH | High byte of word to write to (or read from) video memory | RW | 1 |

- `VMPCTRL`:
  - Bit 0: Width. 0 -> byte operations, incrementing `VMADDR` by 1 and only using `VMDATAL`; 1 -> word operations, incrementing `VMADDR` by 2 and using both `VMDATAL` and `VMDATAH`.
  - Bit 1: Direction. 0 -> read from video memory into `VMDATAL`/`VMDATAH`; 1 -> write `VMDATAL`/`VMDATAH` into video memory.
  - Bits 2-3: Destination select: 0 -> VRAM, 1 -> CRAM, 2 -> OAM, 3 -> reserved.
  - Bits 4-7: Reserved.

To execute an I/O operation and increment `VMADDR` using the port:

- Reads: read from `VMDATAL` if Width = 0 or `VMDATAH` if Width = 1
- Writes: write to `VMDATAL` if Width = 0 or `VMDATAH` if Width = 1
