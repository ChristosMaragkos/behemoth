# Assembler

The legacy `bmasm` assembler has been removed in favor of `vasm`, to allow expressions, macros and real multi-file assembling using `vlink`.
Both `vasm` and `vlink` are vendored in this repo for your convenience as well as mine.
However, please note that they are subject to their own licenses (which include clauses that forbid redistribution for commercial purposes).

## Syntax

By default, the assembler uses `vasm`'s `std` syntax module which closely resembles GNU `as`.
This means the following:

- Directives use a dot prefix
- Temporary labels may be composed of a dot followed only by digits
- Integer literals use the same syntax as C: 0 prefix for octal, 0x prefix for hexadecimal, 0b for binary.

For more information please refer to [the vasm documentation](http://www.ibaug.de/vasm/doc/vasm.pdf) which, if the source tree is updated,
should also contain documentation regarding the BHMTH CPU module.

These are the directives the CPU module implements beyond the syntax module's own:

- `.faraddr i, [i1, ... , iN`: Emits packed 24-bit literals
- `.pageof i`: Emits the top 8 bits of a 24-bit expression
