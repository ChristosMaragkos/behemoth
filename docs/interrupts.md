# Interrupts

Starting at address `05:0000`, there exists a 256-entry interrupt vector table.
Each entry is a 3-byte (24-bit) absolute address pointing to an interrupt handler.
These handlers are initialized to zero and must be set by the
programmer at runtime (most likely during the reset vector, which is not part of this table and must physically exist at `$06:0000`).

## Masking interrupts

Setting the `I` bit of the `flags` register simply ignores all current and future interrupt requests (IRQs) until the bit is cleared.
Disabling a maskable interrupt by writing to MMIO registers (such as `PPUCTRL`'s "disable H-blank" bit) also drops it if it was pending while
interrupts were being masked. This is equivalent to acknowledging the interrupt but not servicing it.

## Servicing interrupts

Before the beginning of each fetch-decode-execute cycle, the CPU checks the bits of its IRQ line and services the first pending IRQ.
The order in which IRQs are serviced is the same as the one in which they appear in the IVT: lowest vector index 0 means higher priority.

If multiple requests of the same interrupt are fired, they do not compound; only the latest is ever serviced and the previous ones are implicitly
dropped. Non-maskable interrupts (such as V-blank and hardware faults) do not issue an IRQ, instead jumping to their designated vector immediately.

Fault-type interrupts trigger before any side-effects occur, and they save and restore the pre-instruction state in `$05:0300`-`$05:0304`
to avoid stack I/O.

| Address | Index | Name | Fired When | Maskable? |
| :-------------: | :-------------: | --------------- | --------------- | --------------- |
| `05:0000` | 0 | VBLNK | PPU finishes drawing frame | No |
| `05:0003` | 1 | HBLNK | PPU finishes drawing scanline | Yes |
| `05:0006` | 2 | DIV0 | `divu`/`divs` executed with zero for divisor | No (fault) |
| `05:0009` | 3 | STOF | `sp` wraps from `$04:0000` back to `$04:FFFF` | No (fault) |
| `05:000C` | 4 | STUF | `sp` wraps from `$04:FFFF` to `$04:0000` | No (fault) |
| `05:000F` | 5 | INVOP | CPU tries to execute invalid/reserved opcode | No (fault) |
| `05:0180` - `05:02FD` | 128-255 | Software Interrupts | Not used by the hardware, can be defined for use with `swi` | No (triggered deliberately) |

When an interrupt fires:

- `flags` is pushed to the stack (1 cycle)
- `pp` is pushed to the stack (1 cycle)
- `pc` is pushed to the stack (1 cycle)
- The hardware fetches the address of the
appropriate vector from the IVT (2 cycles because the address is 24-bit)
- `pp` is set to its highest byte
- `pc` is set to its low 16 bits

Execution then resumes from the first instruction of the interrupt vector.
The total setup overhead amounts to 5 CPU cycles and counts towards limited-duration hardware states
(such as vertical blanking).

When a fault is triggered:

- `flags` is stored to `$05:0300`-`$05:0301`
- `pp` is stored to `$05:0302`
- `pc` is stored to `$05:0303`-`$05:0304`

The registers are then loaded from the same addresses once handling is finished.
In both cases, the `I` bit of the flags register is set to 1 after jumping to the interrupt handler to prevent nested interrupts.

To return from a handler, use the `rti` (`rtf` for faults) instruction.
