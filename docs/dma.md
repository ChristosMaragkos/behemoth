# DMA

DMA controllers perform bulk transfers that would otherwise be tedious to do in code. There are three:

- **System DMA**: copies from cartridge **ROM** or **SRAM** into **WRAM**. Because both sides live on the main
  24-bit bus, there is no PPU contention and transfers may run at any time.
- **Video memory DMA**: copies between the main bus and the video memories **VRAM**/**CRAM**/**OAM**.
- **Audio memory DMA**: copies from the main bus into **ARAM** (wavetable storage, write-only).

Direct main-bus to main-bus copying that does not originate from cartridge media (e.g. WRAM -> WRAM, WRAM -> SRAM)
is deliberately not supported by DMA; that is the job of the `blkcp`/`blkmv` instructions (see [isa.md](/docs/isa.md#block-moves)).

All controllers share the same shape: a control register, a source address, a destination address, a length, a
status register and a start strobe. All are synchronous: after the start register is written, the CPU stops
executing entirely, the DMA controller takes over the memory bus, the transfer is blasted through, and then normal
execution resumes.

## System memory DMA (ROM/SRAM -> WRAM)

Used to load assets and save data out of the cartridge into working memory, e.g. streaming a compressed tileset
into WRAM before a later video DMA uploads it to VRAM.

| Address | Name | Description | Read/Write? | Size (bytes) |
| :-------------: | :-------------: | --------------- | :-------------: | :-------------: |
| `$05:0600` | SDMACTL | DMA control bitmask (see below) | RW | 1 |
| `$05:0601` | SDMASRC | 24-bit source address; must lie in ROM or SRAM | RW | 3 |
| `$05:0604` | SDMADST | 24-bit destination address; must lie in WRAM | RW | 3 |
| `$05:0607` | SDMALEN | Transfer length in elements, where an element is one byte or one word per the width bit of `SDMACTL` | RW | 2 |
| `$05:0609` | SDMASTAT | System DMA status bitmask (see below) | R | 1 |
| `$05:060a` | SDMASTART | Write any value to start a transfer | W | 1 |

- SDMACTL:
  - Bit 0: Width. 0 -> elements are bytes. 1 -> elements are words (2 bytes).
  - Bits 1-7: Reserved.

- SDMASTAT:
  - Bit 0: `ERROR`. Set when a transfer is started with an invalid configuration and the transfer does not start;
    cleared on read of `SDMASTAT`.
  - Bits 1-7: Reserved.

A transfer is valid only if the source lies in one of the cartridge regions, meaning ROM (banks 6-197) or SRAM (banks
198-201), and the destination lies in WRAM (banks 0-3). Any other combination (e.g. a WRAM source, a ROM/SRAM
destination, or a source or destination overlapping the stack bank) sets `ERROR` and does nothing. The transfer
starts immediately when `SDMASTART` is written to and never causes bus contention.

When any value is written to `SDMASTART`:

- The CPU completely stops executing instructions
- The DMA controller initializes and hijacks control of the memory bus with a 10 CPU cycle overhead
- Data is blasted across at a rate of 1 CPU cycle per byte
- Afterwards, the DMA controller relinquishes the memory bus and execution resumes normally

## Video memory DMA

The video memory DMA controller performs bulk transfers between the main 24-bit bus and one of the video memory
spaces. Like the video memory port, a single controller covers VRAM, CRAM and OAM by selecting the destination per transfer,
and access outside of a blanking period causes bus contention.

Transfers always involve the main bus on one side (the source on uploads, the destination on readbacks) and exactly
one video space on the other. Direct video-to-video transfers (e.g. VRAM -> OAM) are not supported.

| Address | Name | Description | Read/Write? | Size (bytes) |
| :-------------: | :-------------: | --------------- | :-------------: | :-------------: |
| `$05:053a` | VDMACTRL | DMA control bitmask (see below) | RW | 1 |
| `$05:053b` | VDMASRC | 24-bit main bus source (upload) or destination (readback) address | RW | 3 |
| `$05:053e` | VDMADST | Destination address in the selected video space. 17-bit to cover VRAM; upper bits ignored for CRAM and OAM. | RW | 3 |
| `$05:0541` | VDMALEN | Transfer length in elements, where an element is one byte or one word depending on bit 3 of `VDMACTRL` | RW | 2 |
| `$05:0543` | VDMASTAT | DMA status bitmask (see below) | R | 1 |
| `$05:0544` | VDMASTART | Write any value to start a transfer | W | 1 |

- `VDMACTRL`:
  - Bits 0-1: Destination select: 0 -> VRAM, 1 -> CRAM, 2 -> OAM, 3 -> reserved.
  - Bit 2: Direction. 0 -> main bus to video memory (upload). 1 -> video memory to main bus (readback).
  - Bit 3: Width. 0 -> elements are bytes. 1 -> elements are words (2 bytes).
  - Bits 4-7: Reserved.

- `VDMASTAT`:
  - Bit 0: `ERROR`. Set when a transfer is started with an invalid configuration (e.g. an out-of-range source/destination) and the transfer does not start; cleared on read of `VDMASTAT`.
  - Bits 1-7: Reserved.

When any value is written to `VDMASTART`:

- The CPU completely stops executing instructions
- The DMA controller initializes and hijacks control of the memory bus with a 10 CPU cycle overhead
- Data is blasted across at a rate of 1 CPU cycle per byte
- Afterwards, the DMA controller relinquishes the memory bus and execution resumes normally

## Audio memory DMA (main bus -> ARAM)

The audio DMA controller performs bulk uploads of wavetable data from the main 24-bit bus into **ARAM**. It exists so
that wavetables can be streamed into audio RAM quickly (e.g. loading a table bank out of ROM during a frame). It is
strictly one-way (main bus -> ARAM); there is no readback because ARAM is write-only. The audio documents
([audio.md](./audio.md)) describe ARAM and how wavetable channels consume it.

A transfer is valid only if the destination address lies within ARAM (13 bits, covering the 8 KB) and the source lies
on the main bus in a readable region (WRAM, ROM or SRAM). Any other combination (out-of-range destination, a source
out of the main bus's readable range, or a destination overlapping an address treated specially by the APU) sets
`ERROR` and does nothing. The transfer starts immediately when `ADMASTART` is written; it never waits for blanking
because it does not touch the video memory bus.

| Address | Name | Description | Read/Write? | Size (bytes) |
| :-------------: | :-------------: | --------------- | :-------------: | :-------------: |
| `$05:0700` | ADMASTAT | Audio DMA status bitmask (see below) | R | 1 |
| `$05:0701` | ADMACTL | DMA control bitmask (see below) | RW | 1 |
| `$05:0702` | ADMASRC | 24-bit source address; must lie in WRAM, ROM or SRAM | RW | 3 |
| `$05:0705` | ADMADST | 13-bit ARAM destination address (covers the 8 KB) | RW | 2 |
| `$05:0707` | ADMALEN | Transfer length in elements, where an element is one byte or one word per the width bit of `ADMACTL` | RW | 2 |
| `$05:0709` | ADMASTART | Write any value to start a transfer | W | 1 |

- ADMACTL:
  - Bit 0: Width. 0 -> elements are bytes. 1 -> elements are words (2 bytes).
  - Bits 1-7: Reserved.

- ADMASTAT:
  - Bit 0: `ERROR`. Set when a transfer is started with an invalid configuration and the transfer does not start;
    cleared on read of `ADMASTAT`.
  - Bits 1-7: Reserved.

When any value is written to `ADMASTART`:

- The CPU completely stops executing instructions
- The DMA controller initializes and hijacks control of the memory bus with a 10 CPU cycle overhead
- Data is blasted across at a rate of 1 CPU cycle per byte
- Afterwards, the DMA controller relinquishes the memory bus and execution resumes normally
