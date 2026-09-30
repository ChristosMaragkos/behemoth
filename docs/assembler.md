# Assembler

The `bmasm` assembler parses the mnemonics found in [The ISA specification](./isa.md) to emit machine code instructions.

## Syntax

Operands must be comma-separated, like so:

```asm
ld a, 25
add a, 5
.db 20, 20
```

Integers use modern syntax:

- No prefix: decimal
- `0x` prefix: hexadecimal
- `0b` prefix: binary
- `0o` prefix: octal

Operands that dereference memory must be surrounded by brackets, as such:

```asm
ld.l a, [0x123456]
ld.l a, [al:b]
ld a, [c]
```

Symbols can also be dereferenced or loaded directly:

```asm
label:
    ld a, label ; Loads the address that 'label' resolves to
    ld a, [label] ; Loads the word at the address 'label' points to
```

Temporary labels can be created by prefixing them with an '@' sign.

```asm
@loop:
    djnz al, @loop
```

A temporary label is only valid between the two non-temporary labels that surround it:

```asm
first:
    jmp @loop ; Invalid

second:
    ld al, 25
    @loop:
        djnz al, @loop ; Valid

    @loop2:
        jnz @loop ; Valid

third:
    jmp @loop ; Invalid
```

Macros and inline constant folding (const ± const) are not yet supported.

## Directives

| Directive | Operands | Effect |
| --------------- | --------------- | --------------- |
| `.org` | Any 24-bit integer | Change address that symbols and instructions are emitted at. Address must not be lower than the current emitter address. |
| `.db` | Any amount of 8-bit integers | Emits bytes starting at the current address and advances the cursor by (amount of operands) |
| `.dw` | Any amount of 16-bit integers | Emits 16-bit words starting at the current address and advances the cursor by (2 * amount of operands) |
| `.d24` | Any amount of 24-bit integers | Emits 24-bit integers starting at the current address and advances the cursor by (3 * amount of operands) |
| `.dl` | Any amount of 32-bit integers | Emits doublewords starting at the current address and advances the cursor by (4 * amount of operands) |
| `.equ` | (name), (value) | Creates a constant with name (name) and value (value) |
| `.include` | (path) | Assembles file at (path) starting at the current address. Advances the cursor by the length of the output. Path may be absolute or relative. |
| `.incbin` | (path) | Dumps all bytes of byte at (path) instead of assembling it. Path may be absolute or relative. |
| `.pad` | Any 24-bit integer | Advances the cursor by (amount). Empty space is filled with zeroes. |
| `.wram` | - | Sets emitter into WRAM region. See below. |
| `.rom` | - | Sets emitter into ROM region. See below. |

### `.wram`/`.rom` directives

`.wram` and `.rom` change the way the emitter behaves:

- When in WRAM, no data can be emitted, either through mnemonics or through `.db`/`.dw`/`.d24`/`.dl`/`.incbin`.
Instead, `.wram` can be used to define labels that point to 24-bit addresses in the WRAM space. When in WRAM,
any symbol definition or `.pad` directive that would result in landing past the end of page 3 (`0x03FFFF`) results in
an error. Example:

```asm
.wram
.org 0x00_0000 ; Page 0, offset 0
some_variable:
    .pad 2 ; Two bytes
some_other_variable:
    .pad 4 ; Four bytes
.include "file_with_vars.asm" ; Files can also be .include'd provided their contents are valid for WRAM

.equ MY_CONST, 20 ; Constants can be defined without issue since they emit no data
```

- When in ROM, emission can continue normally. All mnemonics and directives can be used.
