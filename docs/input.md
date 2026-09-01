# Input

Native support for up to four joypad controllers. Controller state is updated automatically once per frame, right after the end of v-blank.
Each controller is represented in memory via a 16-bit read-only
MMIO register (`JOYPAD1`, `JOYPAD2`, `JOYPAD3`, `JOYPAD4`) using the following bitmask:

| Bit | Button | Description |
| :---: | :-------------: | --------------- |
| 0 | `UP` | D-pad up |
| 1 | `DOWN` | D-pad down |
| 2 | `LEFT` | D-pad left |
| 3 | `RIGHT` | D-pad right |
| 4 | `START` | Start |
| 5 | `OPTION` | Options/Select |
| 6 | `A` | Action button |
| 7 | `B` | Action button |
| 8 | `X` | Action button |
| 9 | `Y` | Action button |
| 10 | `L` | Left shoulder button |
| 11 | `R` | Right shoulder button |
| 12-14 | `EXT0`, `EXT1`, `EXT2` | Reserved for future expansion |
| 15 | `CONNECTED` | Connection flag (1 = connected, 0 = disconnected) |

The addresses and functions of all the input MMIO registers are as follows:

| Address | Name | Read/Write? | Size (bytes) | Description |
| :--------: | :-------: | :---------: | :----------: | --------------- |
| `$05:0400` | `JOYPAD1` | R | 2 | Controller 1 state |
| `$05:0402` | `JOYPAD2` | R | 2 | Controller 2 state |
| `$05:0404` | `JOYPAD3` | R | 2 | Controller 3 state |
| `$05:0406` | `JOYPAD4` | R | 2 | Controller 4 state |
