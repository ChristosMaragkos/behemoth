# Instruction Set

For reference on instruction encoding, see [Specification - Encoding](./spec.md#encoding).

## Legend

- Opcode: hexadecimal 7-bit opcode
- Mnemonic: assigned assembler mnemonic
- Operands: list of operands from first to last:
  - reg: register, size determined by value of size bit
  - reg8: register, always 8-bit
  - reg16: register, always 16-bit
  - (s)imm: (signed) immediate, 8- or 16-bit, determined by value of size bit
  - (s)imm8: (signed) 8-bit immediate
  - (s)imm16: (signed) 16-bit immediate
  - (s)imm32: (signed) 32-bit immediate
  - ptr24: 24-bit pointer/absolute address
  - `reg8:reg16`: pair of one 8-bit and one 16-bit register to form a 24-bit operand
  - `reg16:reg16`: pair of two 16-bit registers to form a 32-bit operand
  - regptr: 16-bit register as pointer
  - immptr: 16-bit immediate as pointer
- Cycles: how many cycles this opcode requires to finish
- Notes: instruction details Size: which size modes are supported by the instruction (determines size of `reg` operands)

## `SHOVE` opcode bitmask

The MSB of the 16-bit immediate operand of `shove` dictates whether the opcode pushes or pops registers.
The rest dictate whether their respective register is affected.
The instruction takes 3 + n cycles (where `n` is the number of registers affected) and is uninterruptible.
Note the lack of `sp` and `pp` from the bitmask; stack operations with them range from useless to outright dangerous.

| Bit   | Usage    |
|:-------------: | --------------- |
| 15   | Mode bit. 0 to push, 1 to pop   |
| 0 | a |
| 1 | b |
| 2 | c |
| 3 | d |
| 4 | e |
| 5 | f |
| 6 | flags |
| 7 | hi |
| 8 | dp |
| 9-14 | Reserved |

## Math opcodes & interaction with `FLAGS`

| Mnemonic | Flags altered |
| :-: | :-: |
| add(.l) | Computes Z C N V |
| sub(.l) | Computes Z C N V |
| mulu | Computes Z N, sets C and V if hi != 0 (cleared otherwise) |
| muls | Computes Z N, sets C and V if hi is not sign-extension of reg (cleared otherwise) |
| divu | Computes Z N, clears C V (division by 0 sets V or raises exception) |
| divs | Computes Z N, clears C, sets V on signed overflow (min_int / -1) |
| adc | Computes Z C N V |
| sbc | Computes Z C N V |
| cmp(.l) | Computes Z C N V |
| inc | Computes Z N V, preserves C |
| dec | Computes Z N V, preserves C |
| neg | Computes Z C N V (sets C if reg != 0, sets V on min_int overflow) |
| and | Computes Z N, clears C V |
| or | Computes Z N, clears C V |
| xor | Computes Z N, clears C V |
| bt | Computes Z N, clears C V |
| not | Computes Z N, preserves C V |
| lsl | Computes Z N, sets C to last bit shifted out, sets V if sign changes |
| lsr | Computes Z N, sets C to last bit shifted out, clears V |
| asr | Computes Z N, sets C to last bit shifted out, clears V |
| rol | Computes Z N, sets C to wrapped MSB |
| ror | Computes Z N, sets C to wrapped LSB |
| rcl | Computes Z N, sets C to shifted-out MSB |
| rcr | Computes Z N, sets C to shifted-out LSB |

## Misc (category 0)

| Opcode | Mnemonic | Operands | Cycles | Notes | Size |
| :---------------: | :---------------: | --------------- | :---------------: | --------------- | - |
| 0x00 | nop | - | 2 | No operation | - |
| 0x01 | wfi | - | - | Yield CPU until next non-masked interrupt | - |
| 0x02 | mov | reg, reg | 2 | Set value of reg1 to value of reg2 |8, 16|
| 0x03 | cbw | reg8 | 2 | Sign extend low-byte register into full register (e.g. `al` into `a`) | 8 |
| 0x04 | zxt | reg8 | 2 | Zero extend low-byte register into full register | 8 |
| 0x05 |xchg | reg, reg | 2 | Exchange register values | 8, 16 |
| 0x06 | swp | reg16| 2 | Swap low and high byte of 16-bit register (endianness swap) | 16 |
| 0x07 |mfhi | reg | 2 | Set register value to value of `hi` (or low byte of `hi` in 8-bit) | 8, 16 |
| 0x08 |mthi | reg | 2 | Set value of `hi` to value of register | 8, 16 |
| 0x09 |mfpp | reg8| 2 | Set value of 8-bit register to value of `pp` | 8 |
| 0x0a |mtpp | reg8| 2 | Set value of `pp` to value of 8-bit register | 8 |
| 0x0b |mfdp | reg8| 2 | Set value of 8-bit register to value of `dp` | 8 |
| 0x0c |mtdp | reg8| 2 | Set value of `dp` to value of 8-bit register | 8 |
| 0x0d | swi | imm8 | 2 | Push `flags`, `pp`, `pc` to stack and jump to (IVT + 2 * imm8) | - |
| 0x0e-0x7f| Reserved |<|<|<|<|

## Memory (category 1)

### Near forms (top 8 bits of 24-bit address supplied by `dp`)

| Opcode | Mnemonic | Operands | Cycles | Notes | Size |
| :---------------: | :---------------: | --------------- | :---------------: | --------------- | - |
| 0x00 | ld | reg, simm | 3 | Set value of register to immediate value | 8, 16 |
| 0x01 | ld | reg, regptr | 3 | Set value of register to value stored in `dp:regptr` | 8, 16 |
| 0x02 | ld | reg, immptr | 4 | Set value of register to value stored in `dp:immptr` | 8, 16 |
| 0x03 | ld | reg, regptr + simm16 | 4 | Set value of register to value stored in (`dp:regptr` + simm16) | 8, 16 |
| 0x04 | ld | reg, regptr + reg16 | 4 | Set value of register to value stored in (`dp:regptr` + reg16) | 8, 16 |
| 0x05 | ld | reg, (regptr+) | 3 | Dereference pointer and increment (by 1 in 8-bit mode, 2 in 16-bit) | 8, 16 |
| 0x06 | ld | reg, (+regptr) | 3 | Increment and dereference pointer | 8, 16 |
| 0x07 | ld | reg, (regptr-) | 3 | Dereference pointer and decrement (by 1 in 8-bit mode, 2 in 16-bit) | 8, 16 |
| 0x08 | ld | reg, (-regptr) | 3 | Decrement and dereference pointer | 8, 16 |
| 0x09 | st | reg, regptr | 3 | Store value of register into word/byte starting at `dp:regptr` | 8, 16 |
| 0x0a | st | reg, immptr | 4 | Store value of register into `dp:immptr` | 8, 16 |
| 0x0b | st | reg, regptr + simm16 | 4 | Store value of register into address (`dp:regptr` + simm16) | 8, 16 |
| 0x0c | st | reg, regptr + reg16 | 4 | Store value of register into address (`dp:regptr` + reg16) | 8, 16 |
| 0x0d | st | reg, (regptr+) | 3 | Store value of register and increment pointer (by 1 in 8-bit mode, 2 in 16-bit mode) | 8, 16 |
| 0x0e | st | reg, (+regptr) | 3 | Increment pointer and store register value | 8, 16 |
| 0x0f | st | reg, (regptr-) | 3 | Store value of register and decrement pointer | 8, 16 |
| 0x10 | st | reg, (-regptr) | 3 | Decrement pointer and store register value | 8, 16 |
| 0x11 | push | reg16 | 3 | Push register onto stack and decrement `sp` | 16 |
| 0x12 | pop | reg16 | 3 | Pop register from stack and increment `sp` | 16 |
| 0x13 | shove | imm16 | 3 + n | Push or pop multiple registers from the stack (see [[#`SHOVE` opcode bitmask]]). | 16 |

### Long forms (ignore `dp`)

These hard-code the full 24-bit address. All offsets are sign-extended into 24 bits.

| Opcode | Mnemonic | Operands | Cycles | Notes | Size |
| :---------------: | :---------------: | --------------- | :---------------: | --------------- | - |
| 0x14 | ld.l | reg, `ptr24` | 5 | Load from absolute 24-bit address (ptr24 = 3 bytes) | 8, 16 |
| 0x15 | ld.l | reg, `ptr24 + reg16` | 5 | Load from ptr24 + sign-extended offset | 8, 16 |
| 0x16 | ld.l | reg, `reg8:reg16` | 4 | Load from address formed by: reg8 = bank, reg16 = offset). | 8, 16 |
| 0x17 | ld.l | reg, `reg8:reg16 + simm16` | 5 | Load from pair address + simm16 (pack word + offset word) | 8, 16 |
| 0x18 | ld.l | reg, `reg8:reg16 + reg16` | 4 | Load from pair address + sign-extended reg offset (both extra regs in one pack byte) | 8, 16 |
| 0x19 | st.l | reg, `ptr24` | 5 | Store to absolute 24-bit address | 8, 16 |
| 0x1a | st.l | reg, `ptr24 + reg16` | 5 | Store to ptr24 + sign-extended offset | 8, 16 |
| 0x1b | st.l | reg, `reg8:reg16` | 4 | Store to address formed by pair | 8, 16 |
| 0x1c | st.l | reg, `reg8:reg16 + simm16` | 5 | Store to pair address + simm16 | 8, 16 |
| 0x1d | st.l | reg, `reg8:reg16 + reg16` | 4 | Store to pair address + sign-extended reg offset | 8, 16 |

### Block moves

Block move instructions can be used to move data across the 24-bit address space without tedious `ld.l` -> `st.l` loops.
They implicitly update both their register pair operands (as one 24-bit integer, so addition is carried) as well as their amount parameter,
and the program counter is kept on that instruction until `amount = 0xFFFF`, meaning they are interruptible. No status flags are altered in the
process. Consider this example:

```asm
ld al, $00
ld b, $FFFF

ld cl, $01
ld d, $0000

ld e, #299 ; N - 1 bytes

blkcp al:b, cl:d, e
; Every loop iteration:
; - Copies one byte
; - Increments b and d
; - If b or d overflows, al or cl respectively is incremented
; - Decrements e and stops if its new value is 0xFFFF
```

| Opcode | Mnemonic | Operands | Cycles | Notes | Size |
| :---------------: | :---------------: | --------------- | :---------------: | --------------- | - |
| 0x1e | BLKCP | reg8:reg16, reg8:reg16, reg16 | 6/byte | Moves (last register value + 1) bytes from first 24-bit pointer to second 24-bit pointer. | - |
| 0x1f | BLKMV | reg8:reg16, reg8:reg16, reg16 | 6/byte | Moves bytes like `BLKCP` but in reverse order. | - |
| 0x20-0x7f | Reserved | < | < | < | < |

## Math (category 2)

Unless stated otherwise, these instructions implicitly use and update the `flags` register. Notice the lack of long addressing;
dereferencing 24-bit pointers for arithmetic must go through a long load first e.g. `ld.l a, [$012345]` -> `add b, a`. All pointer
source operands implicitly dereference from `dp:ptr` with the exception of the stack pointer which is hardwired to use bank 4.

Keep in mind that `mul` and `div` clobber `hi`: `mul` sets it to the high word of the multiplication and `div` sets it to the remainder.
8-bit multiplication and division store an 8-bit byte in `mul` and zero-extends it.

For a reference on which flags are altered by which opcodes, check [[#Math opcodes & interaction with `FLAGS`]]

### Arithmetic operations

| Opcode | Mnemonic | Operands | Cycles | Notes | Size |
| :----: | :------: | -------- | :----: | ----- | ---- |
| 0x00 | add | reg, reg | 2 | Set reg1 = reg1 + reg2 | 8, 16 |
| 0x01 | add | reg, imm | 3 | Set reg = reg + imm | 8, 16 |
| 0x02 | add | reg, regptr | 3 | Set reg = reg + value stored in `dp:regptr` | 8, 16 |
| 0x03 | add | reg, immptr | 4 | Set reg = reg + value stored in `dp:immptr` | 8, 16 |
| 0x04 | add | reg, regptr + simm16 | 4 | Set reg = reg + value stored in `dp:regptr` + signed 16-bit offset | 8, 16 |
| 0x05 | add | reg, regptr + reg16 | 4 | Set reg = reg + value stored in `dp:regptr` + signed 16-bit offset | 8, 16 |
| 0x06 | sub | reg, reg | 2 | Set reg1 = reg1 - reg2 | 8, 16 |
| 0x07 | sub | reg, imm | 3 | Set reg = reg - imm | 8, 16 |
| 0x08 | sub | reg, regptr | 3 | Set reg = reg - value stored in `dp:regptr` | 8, 16 |
| 0x09 | sub | reg, immptr | 4 | Set reg = reg - value stored in `dp:immptr` | 8, 16 |
| 0x0a | sub | reg, regptr + simm16 | 4 | Set reg = reg - value stored in `dp:regptr` + signed 16-bit offset | 8, 16 |
| 0x0b | sub | reg, regptr + reg16 | 4 | Set reg = reg - value stored in `dp:regptr` + signed 16-bit offset | 8, 16 |
| 0x0c | mulu | reg, reg | 8 | Unsigned. Set reg1 = reg1 * reg2 | 8, 16 |
| 0x0d | mulu | reg, imm | 9 | Unsigned. Set reg = reg * imm | 8, 16 |
| 0x0e | mulu | reg, regptr | 9 | Unsigned. Set reg = reg * value stored in `dp:regptr` | 8, 16 |
| 0x0f | mulu | reg, immptr | 10 | Unsigned. Set reg = reg * value stored in `dp:immptr` | 8, 16 |
| 0x10 | mulu | reg, regptr + simm16 | 10 | Unsigned. Set reg = reg * value stored in `dp:regptr` + signed 16-bit offset | 8, 16 |
| 0x11 | mulu | reg, regptr + reg16 | 10 | Unsigned. Set reg = reg * value stored in `dp:regptr` + signed 16-bit offset | 8, 16 |
| 0x12 | divu | reg, reg | 10 | Unsigned. Set reg1 = reg1 / reg2| 8, 16 |
| 0x13 | divu | reg, imm | 11 | Unsigned. Set reg = reg / imm | 8, 16 |
| 0x14 | divu | reg, regptr | 11 | Unsigned. Set reg = reg / value stored in `dp:regptr` | 8, 16 |
| 0x15 | divu | reg, immptr | 12 | Unsigned. Set reg = reg / value stored in `dp:immptr` | 8, 16 |
| 0x16 | divu | reg, regptr + simm16 | 12 | Unsigned. Set reg = reg / value stored in `dp:regptr` + signed 16-bit offset | 8, 16 |
| 0x17 | divu | reg, regptr + reg16 | 12 | Unsigned. Set reg = reg / value stored in `dp:regptr` + signed 16-bit offset | 8, 16 |
| 0x18 | muls | reg, reg | 8 | Signed. Set reg1 = reg1 * reg2 | 8, 16 |
| 0x19 | muls | reg, imm | 9 | Signed. Set reg = reg * imm | 8, 16 |
| 0x1a | muls | reg, regptr | 9 | Signed. Set reg = reg * value stored in `dp:regptr` | 8, 16 |
| 0x1b | muls | reg, immptr | 10 | Signed. Set reg = reg * value stored in `dp:immptr` | 8, 16 |
| 0x1c | muls | reg, regptr + simm16 | 10 | Signed. Set reg = reg * value stored in `dp:regptr` + signed 16-bit offset | 8, 16 |
| 0x1d | muls | reg, regptr + reg16 | 10 | Signed. Set reg = reg * value stored in `dp:regptr` + signed 16-bit offset | 8, 16 |
| 0x1e | divs | reg, reg | 10 | Signed. Set reg1 = reg1 / reg2| 8, 16 |
| 0x1f | divs | reg, imm | 11 | Signed. Set reg = reg / imm | 8, 16 |
| 0x20 | divs | reg, regptr | 11 | Signed. Set reg = reg / value stored in `dp:regptr` | 8, 16 |
| 0x21 | divs | reg, immptr | 12 | Signed. Set reg = reg / value stored in `dp:immptr` | 8, 16 |
| 0x22 | divs | reg, regptr + simm16 | 12 | Signed. Set reg = reg / value stored in `dp:regptr` + signed 16-bit offset | 8, 16 |
| 0x23 | divs | reg, regptr + reg16 | 12 | Signed. Set reg = reg / value stored in `dp:regptr` + signed 16-bit offset | 8, 16 |
| 0x24 | adc | reg, reg | 2 | Set reg1 = reg1 + reg2 + 1 if carry flag is on | 8, 16 |
| 0x25 | adc | reg, imm | 3 | Set reg = reg + imm + 1 if carry flag is on | 8, 16 |
| 0x26 | adc | reg, regptr | 3 | Set reg = reg + value stored in `dp:regptr` + 1 if carry flag is on | 8, 16 |
| 0x27 | adc | reg, immptr | 4 | Set reg = reg + value stored in `dp:immptr` + 1 if carry flag is on | 8, 16 |
| 0x28 | adc | reg, regptr + simm16 | 4 | Set reg = reg + value stored in `dp:regptr` + signed 16-bit offset + 1 if carry flag is on | 8, 16 |
| 0x29 | adc | reg, regptr + reg16 | 4 | Set reg = reg + value stored in `dp:regptr` + signed 16-bit offset + 1 if carry flag is on | 8, 16 |
| 0x2a | sbc | reg, reg | 2 | Set reg1 = reg1 - reg2 - 1 if carry flag is on | 8, 16 |
| 0x2b | sbc | reg, imm | 3 | Set reg = reg - imm - 1 if carry flag is on | 8, 16 |
| 0x2c | sbc | reg, regptr | 3 | Set reg = reg - value stored in `dp:regptr` - 1 if carry flag is on | 8, 16 |
| 0x2d | sbc | reg, immptr | 4 | Set reg = reg - value stored in `dp:immptr` - 1 if carry flag is on | 8, 16 |
| 0x2e | sbc | reg, regptr + simm16 | 4 | Set reg = reg - value stored in `dp:regptr` + signed 16-bit offset - 1 if carry flag is on| 8, 16 |
| 0x2f | sbc | reg, regptr + reg16 | 4 | Set reg = reg - value stored in `dp:regptr` + signed 16-bit offset - 1 if carry flag is on| 8, 16 |
| 0x30 | cmp | reg, reg | 2 | Compute and discard reg1 = reg1 - reg2. Updates flags. | 8, 16 |
| 0x31 | cmp | reg, imm | 3 | Compute and discard reg = reg - imm. Updates flags. | 8, 16 |
| 0x32 | cmp | reg, regptr | 3 | Compute and discard reg = reg - value stored in `dp:regptr`. Updates flags. | 8, 16 |
| 0x33 | cmp | reg, immptr | 4 | Compute and discard reg = reg - value stored in `dp:immptr`. Updates flags. | 8, 16 |
| 0x34 | cmp | reg, regptr + simm16 | 4 | Compute and discard reg = reg - value stored in `dp:regptr` + signed 16-bit offset. Updates flags. | 8, 16 |
| 0x35 | cmp | reg, regptr + reg16 | 4 | Compute and discard reg = reg - value stored in `dp:regptr` + signed 16-bit offset. Updates flags. | 8, 16 |
| 0x36 | inc | reg | 2 | Increment register value by 1. Does not alter carry flag. | 8, 16 |
| 0x37 | dec | reg | 2 | Decrement register value by 1. Does not alter carry flag. | 8, 16 |
| 0x38 | neg | reg | 2 | Set value of register to 0 - value (two's complement negation) | 8, 16 |

### Bitwise

| Opcode | Mnemonic | Operands | Cycles | Notes | Size |
| :----: | :------: | -------- | :----: | ----- | ---- |
| 0x39 | and | reg, reg | 2 | Set reg1 = reg1 AND reg2 | 8, 16 |
| 0x3a | and | reg, imm | 3 | Set reg = reg AND imm | 8, 16 |
| 0x3b | and | reg, regptr | 3 | Set reg = reg AND value stored in `dp:regptr` | 8, 16 |
| 0x3c | and | reg, immptr | 4 | Set reg = reg AND value stored in `dp:immptr` | 8, 16 |
| 0x3d | and | reg, regptr + simm16 | 4 | Set reg = reg AND value stored in `dp:regptr` + signed 16-bit offset | 8, 16 |
| 0x3e | and | reg, regptr + reg16 | 4 | Set reg = reg AND value stored in `dp:regptr` + signed 16-bit offset | 8, 16 |
| 0x3f | or | reg, reg | 2 | Set reg1 = reg1 OR reg2 | 8, 16 |
| 0x40 | or | reg, imm | 3 | Set reg = reg OR imm | 8, 16 |
| 0x41 | or | reg, regptr | 3 | Set reg = reg OR value stored in `dp:regptr` | 8, 16 |
| 0x42 | or | reg, immptr | 4 | Set reg = reg OR value stored in `dp:immptr` | 8, 16 |
| 0x43 | or | reg, regptr + simm16 | 4 | Set reg = reg OR value stored in `dp:regptr` + signed 16-bit offset | 8, 16 |
| 0x44 | or | reg, regptr + reg16 | 4 | Set reg = reg OR value stored in `dp:regptr` + signed 16-bit offset | 8, 16 |
| 0x45 | xor | reg, reg | 2 | Set reg1 = reg1 XOR reg2 | 8, 16 |
| 0x46 | xor | reg, imm | 3 | Set reg = reg XOR imm | 8, 16 |
| 0x47 | xor | reg, regptr | 3 | Set reg = reg XOR value stored in `dp:regptr` | 8, 16 |
| 0x48 | xor | reg, immptr | 4 | Set reg = reg XOR value stored in `dp:immptr` | 8, 16 |
| 0x49 | xor | reg, regptr + simm16 | 4 | Set reg = reg XOR value stored in `dp:regptr` + signed 16-bit offset | 8, 16 |
| 0x4a | xor | reg, regptr + reg16 | 4 | Set reg = reg XOR value stored in `dp:regptr` + signed 16-bit offset | 8, 16 |
| 0x4b | bt | reg, reg | 2 | Compute and discard reg1 = reg1 AND reg2. Updates Z flag. | 8, 16 |
| 0x4c | bt | reg, imm | 3 | Compute and discard reg = reg AND imm. Updates Z flag. | 8, 16 |
| 0x4d | bt | reg, regptr | 3 | Compute and discard reg = reg AND value stored in `dp:regptr`. Updates Z flag. | 8, 16 |
| 0x4e | bt | reg, immptr | 4 | Compute and discard reg = reg AND value stored in `dp:immptr`. Updates Z flag. | 8, 16 |
| 0x4f | bt | reg, regptr + simm16 | 4 | Compute and discard reg = reg AND value stored in `dp:regptr` + signed 16-bit offset. Updates Z flag. | 8, 16 |
| 0x50 | bt | reg, regptr + reg16 | 4 | Compute and discard reg = reg AND value stored in `dp:regptr` + signed 16-bit offset. Updates Z flag. | 8, 16 |
| 0x51 | not | reg | 2 | Set reg = NOT reg (bitwise invert) | 8, 16 |
| 0x52 | lsl | reg, reg | 2 | Logical shift reg1 left by value of reg2 | 8, 16 |
| 0x53 | lsl | reg, imm8 | 3 | Logical shift reg1 left by value of imm8 | 8, 16 |
| 0x54 | lsr | reg, reg | 2 | Logical shift reg1 right by value of reg2 | 8, 16 |
| 0x55 | lsr | reg, imm8 | 3 | Logical shift reg1 right by value of imm8 | 8, 16 |
| 0x56 | asr | reg, reg | 2 | Arithmetic shift reg1 right by value of reg2 | 8, 16 |
| 0x57 | asr | reg, imm8 | 3 | Arithmetic shift reg1 right by value of imm8 | 8, 16 |
| 0x58 | rol | reg, reg | 2 | Rotate reg1 left by value of reg2 (bit shifted out of MSB goes back to the LSB) | 8, 16 |
| 0x59 | rol | reg, imm8 | 3 | Rotate reg1 left by value of imm8 | 8, 16 |
| 0x5a | ror | reg, reg | 2 | Rotate reg1 right by value of reg2 (bit shifted out of LSB goes back to the MSB) | 8, 16 |
| 0x5b | ror | reg, imm8 | 3 | Rotate reg1 right by value of imm8 | 8, 16 |
| 0x5c | rcl | reg, reg | 2 | Rotate reg1 left by value of reg2 through carry (MSB -> Carry flag -> LSB) | 8, 16 |
| 0x5d | rcl | reg, imm8 | 3 | Rotate reg1 left by value of imm8 through carry | 8, 16 |
| 0x5e | rcr | reg, reg | 2 | Rotate reg1 right by value of reg2 through carry (LSB -> Carry flag -> MSB) | 8, 16 |
| 0x5f | rcr | reg, imm8 | 3 | Rotate reg1 right by value of imm8 through carry | 8, 16 |

### 32-bit arithmetic

32-bit arithmetic operates on register pairs (`reg16:reg16`) or 32-bit immediates. The first register of the destination pair holds the high word, the second the low word. Any register pair may be used. The source pair, when register-based, is encoded into the pack byte after the instruction word.

| Opcode | Mnemonic | Operands | Cycles | Notes | Size |
| :----: | :------: | -------- | :----: | ----- | ---- |
| 0x60 | add.l | reg16:reg16, reg16:reg16 | 3 | Set reg1:reg2 = reg1:reg2 + reg3:reg4 | - |
| 0x61 | add.l | reg16:reg16, imm32 | 4 | Set reg1:reg2 = reg1:reg2 + imm32 | - |
| 0x62 | sub.l | reg16:reg16, reg16:reg16 | 3 | Set reg1:reg2 = reg1:reg2 - reg3:reg4 | - |
| 0x63 | sub.l | reg16:reg16, imm32 | 4 | Set reg1:reg2 = reg1:reg2 - imm32 | - |
| 0x64 | cmp.l | reg16:reg16, reg16:reg16 | 3 | Compute and discard reg1:reg2 - reg3:reg4. Updates flags. | - |
| 0x65 | cmp.l | reg16:reg16, imm32 | 4 | Compute and discard reg1:reg2 - imm32. Updates flags. | - |
| 0x66-0x7f | Reserved | < | < | < | < |

## Control flow (category 3)

| Opcode | Mnemonic | Operands | Cycles | Notes | Size |
| :----: | :------: | -------- | :----: | ----- | ---- |
| 0x00 | call | imm16 | 5 | Push `pc` to stack and jump to 16-bit immediate address | - |
| 0x01 | call | reg16 | 4 | Push `pc` to stack and jump to value stored in register | - |
| 0x02 | jmp | imm16 | 4 | Jump to 16-bit immediate address | - |
| 0x03 | jmp | reg16 | 3 | Jump to value stored in register | - |
| 0x04 | ret | - | 3 | Pop `pc` from stack | - |
| 0x05 | iret | - | 5 | Pop `pc`, `pp` and `flags` from stack | - |

### Conditional jumps

All of these instructions take signed immediate operands,
which represent an offset (in bytes) from the position of the program counter *after* the conditional jump opcode.
If an offset causes `pc` to overflow in either direction, `pp` is also bumped by 1 in the same direction.
Branches incur a 1-cycle penalty when taken.

| Opcode | Mnemonic | Operands | Cycles | Notes | Size |
| :----: | :------: | -------- | :----: | ----- | ---- |
| 0x06 | jz | simm | 4 (5 if taken) | Jump if zero flag set | - |
| 0x07 | jnz | simm | 4 (5 if taken) | Jump if zero flag not set | - |
| 0x08 | jc | simm | 4 (5 if taken) | Jump if carry flag set | - |
| 0x09 | jnc | simm | 4 (5 if taken) | Jump if carry flag not set | - |
| 0x0a | jmi | simm | 4 (5 if taken) | Jump if negative flag set | - |
| 0x0b | jpl | simm | 4 (5 if taken) | Jump if negative flag not set | - |
| 0x0c | jv | simm | 4 (5 if taken) | Jump if overflow flag set | - |
| 0x0d | jnv | simm | 4 (5 if taken) | Jump if overflow flag not set | - |
| 0x0e | jge | simm | 4 (5 if taken) | Jump if greater or equal (V = N) | - |
| 0x0f | jgt | simm | 4 (5 if taken) | Jump if greater (Z not set, V = N) | - |
| 0x10 | jle | simm | 4 (5 if taken) | Jump if less or equal (V != N) | - |
| 0x11 | jlt | simm | 4 (5 if taken) | Jump if less (Z not set, V != N) | - |
| 0x12 | djnz | reg, simm | 5 (6 if taken) | Decrement register by 1 and jump if result is not zero | 8, 16 |

### Long jumps

These instructions use the same 24-bit addressing as loads and stores (though only with direct immediate and register addressing modes).

| Opcode | Mnemonic | Operands | Cycles | Notes | Size |
| :----: | :------: | -------- | :----: | ----- | ---- |
| 0x13 | call.l | imm24 | 8 | Push `pp` and `pc` to stack, set `pp` to highest byte of imm24, set `pc` to low word of imm24 | - |
| 0x14 | call.l | reg8:reg16 | 6 | Push `pp` and `pc` to stack, set `pp` to reg8, set `pc` to reg16 | - |
| 0x15 | jmp.l | imm24 | 6 | Set `pp` to highest byte of imm24, set `pc` to low word of imm24 | - |
| 0x16 | jmp.l | reg8:reg16 | 4 | Set `pp` to reg8, set `pc` to reg16 | - |
| 0x17 | ret.l | - | 4 | Pop `pc` and `pp` from stack | - |
