# Registers

## GPRs

7 general-purpose registers: a, b, c, d, e, f, g. 16-bit. Addressable also as their low bytes with an `l` prefix: al, bl, cl, dl, el, fl, gl.
All are capable of being used as pointers for full orthogonality. There is no hardwired accumulator or loop counter.

## Special registers

- sp: 16-bit stack pointer. Usable in exactly the same way as registers a-g, but its low byte is not addressable.

## Internal (non-addressable) registers

These registers can not be addressed directly but can instead by manipulated implicitly or explicitly by using certain instructions.

- flags: 16-bit processor status bitfield:
  - Bit 0: Carry flag C
  - Bit 1: Zero flag Z
  - Bit 2: Negative flag N
  - Bit 3: Overflow flag V
  - Bit 4: IRQ disable flag I. Set to 1 to ignore all (maskable) interrupts.
  - Bits 5-15: reserved
- pc: 16-bit program counter
- hi: 16-bit, receives high word (or byte) of multiplication and remainder of division. Accessed through "move from/to `hi`" instructions à la MIPS.
- dp: 8-bit data page (read [[#Memory]])
- pp: 8-bit program page

# Addressing Modes

Instructions support one or more of the below addressing modes, unless explicitly stated:

- Register, register direct (must be same size registers)
- Register, register pointer (must be a 16-bit register)
- Register, 8- or 16-bit immediate (depending on variant; see [[#Encoding]] below. Signedness depends on opcode.)
- Register, 16-bit immediate pointer
- Register, register pointer + signed 16-bit immediate offset
- Register, register pointer + register offset (signedness depends)
- Register, register pre- and post-increment/decrement (amount depends on register size)

In addition, long variants of addressing instructions (see [[#Memory]]) utilize the following addressing modes:

- Unsigned 24-bit immediate
- Pair of registers, where the first register provides the highest 8 bits in order to form a 24-bit address.
- Unsigned 24-bit immediate + 16-bit register offset

Lastly, 32-bit calculations require register pairs, so we use these addressing modes:

- pair of 16-bit registers, pair of 16-bit registers
- pair of 16-bit registers, 32-bit immediate

# Encoding

Variable length instructions starting at two bytes. Each fetch grabs a two-byte little endian word from memory,
laid out as such:

- Bits 0-8: opcode. This gives us 512 possible opcodes, but see [[#Opcode byte layout]] below.
- Bit 9: size bit. 0 -> 16-bit, 1 -> 8-bit. Applies to source and destination for direct addressing and only destination for indirect addressing (since pointers are always 16-bit)
- Bits 10-12: first register operand, if needed.
- Bits 13-15: second register operand, if needed.
- Any extra data required, such as extra registers or immediates, follows suit right after the instruction word. Register operands beyond the first two are encoded into the byte after the instruction word at a rate of two indices per byte (at 3 bits per index).

Thus, in bit notation, an opcode word looks like this: `rrr_rrr_s_ooooooooo`
Effectively, the size bit serves only semantic purposes. This encoding format has its drawbacks:
It's wasted space for instructions with fewer than two operands or only immediate operands,
as those do not fit within the 6 operand bits.
3 bits for each register operand maps, from 0-7, to: `a` through `g` and then `sp`.
Addressing `sp` as 8-bit is not explicitly disallowed at runtime, but try to avoid doing it (such as by manually editing opcode bytes).
Lastly, loading and storing multi-byte values at page boundaries is undefined behavior and should be avoided.

## Opcode byte layout

Because we have plenty of breathing room, we can lay 9 the opcode bits out in such a way as to keep
a sense of order rather than jam-pack all 512 possible opcodes together as tightly as possible:

- Bits 0-6: The actual opcode payload (ADD, SUB, LD, ST etc.)
- Bits 7-8: Opcode category (0 -> misc, 1->memory, 2->math, 3->control flow)

# Memory

We use a 24-bit address bus, allowing us to use up to 16 megabytes of total memory.
To bypass the limitation of having 16-bit registers, we use internal page registers like the SNES' 65816:

- `pp`: Program page. Supplies the top 8 bits of the 24-bit address that the program counter reads from (instructions fetch from `[pp:pc]`).
If at any point the program counter exceeds `0xFFFF`, it wraps to zero and `pp` is incremented. Conversely, if `pc` underflows from zero, `pp` is decremented.
- `dp`: Data page. Supplies the top 8 bits of the 24-bit address that load and store instructions operate on (by forming `[dp:reg16]`). The
exception to this is the stack pointer which is hardwired to page 4 (so dereferencing it loads from `[$04:sp]`).

The program and data page registers dictate which page a "near" pointer can reach: a raw register pointer simply acts as an offset to the currently mapped page.
Each page has a size of 64kb with 256 possible, usable pages (2^16 * 2^8 = 2^24).
To access data in another page without changing `pp` or `dp`, we can use long variants of load, store, call and return instructions,
which take either a 24-bit absolute address or a register pair, such as:

- `call.l $011234` -> push `pp` to stack, push `pc` to stack, set `pp` to `0x01` and `pc` to `0x1234`.
- `ret.l` -> pop `pc` and `pp` from stack.
- `ld.l a, [b:c]` -> load from 24-bit address formed by the low 8 bits of `b` as the highest byte, and the entirety of `c`.

## Memory map

The 16mb address space is split into 256 pages of 64kb each, for the following regions:

- Pages 0-3: WRAM (256kb)
- Page 4: Stack (64kb)
- Page 5: Interrupt vector table (256 24-bit little endian addresses), memory-mapped registers (PPU, APU), 3 DMA
  controllers, 2 expansion ports
  - The reset vector is not part of the IVT, and is instead located at `0x0000` within the ROM-mapped region. More below.
- Pages 6-197: Game ROM. The reset vector is located at `$06:0000`, so on boot, `pp` is set to `0x06` and `pc` to `0x0000`. Not writable.
- Pages 198-201: Cartridge SRAM (the save file, if found at boot, is mapped here, and writes are flushed periodically).
- Pages 202-255: Reserved for future expansion.

# Cycle Budget

122880 cycles per frame during active display (240 scanlines of 512 cycles each). H-blank triggers 239 times per frame at the end of each scanline
if not masked and lasts 200 CPU cycles. Vertical blanking triggers after drawing the 240th line and lasts 25 scanline periods' worth of active display time,
i.e. 12800 CPU cycles. In total:

- 240 scanlines of active display * 512 cycles per scanline = 122880
- 239 horizontal blanks * 200 cycles each = 47800
- 25 scanlines' worth of vertical blanking * 512 cycles per line = 12800

Sum total: 183480 cycles per frame. Targeting 60 frames per second, this amounts
to a frequency of ~11MHz.

> [!NOTE]
> Please keep in mind that this is purely a specification and future revisions may add or remove content.
