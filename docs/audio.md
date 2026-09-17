# Audio

The APU is capable of synthesizing mono sound at 44.1kHz (44100 samples per second). This means that it produces
exactly 735 (44100 / 60) audio samples per frame, handing them to the host sound system.

## Channels

Six total audio channels, numbered from 0-5. The first four are mapped to individual waveforms:

- Channel 0: Pulse. Produces either -1 or +1 depending on the current value of `phase` and its duty cycle (see below).
- Channel 1: Saw. Rises linearly from -1 to +1, then immediately drops back down to -1.
- Channel 2: Triangle. Rises linearly from -1 to +1, then falls linearly back to -1.
- Channel 3: Noise. Uses LFSR to generate pseudo-random sequences of -1 and 1, repeating more or less often
depending on the noise mode in use (again, more below).
- Channels 4 & 5: Wavetables. Can be configured to use any waveform. Waveform data must be 64 bytes at 8 bits per sample,
and must be uploaded to audio RAM before accessing.

### Channel configuration

- Phase: for each channel (excluding noise), the emulator keeps track of a phase variable that is always between 0 and 1.
The phase of a channel dictates how far along its waveform it currently is, and it maps directly to what value the APU
will generate for its next sample.
- Pitch: Each time a sample is generated, the phase of each sample is internally advanced by `pitch / sample rate`,
meaning configuring a channel's pitch to be higher advances through its waveform faster, thus producing higher notes (or pitch, duh).
  - The noise channel does not have a notion of pitch or phase. Rather, it uses a `rate` control which dictates the rate (in samples) at which it
  advances its internal LFSR value.

- Volume: a 8-bit (0-255) value which dictates how loud the output of a channel is. Each generated sample is multiplied by `vol/256`, and the
volume value of each channel is initialized on boot as follows, to keep waveforms from overpowering one another:
  - Pulse: 208 (208/256 = 0.8125)
  - Saw: 192 (192/256 = 0.75)
  - Triangle: 248 (248/256 = 0.96875, our ceiling)
  - Noise: 192 (192/256 = 0.75)
  - Wavetable 1 & 2: 208 (208/256 = 0.8125)
Effectively, the volume of each channel is in the Q0.8 fixed point format. Setting the volume of a channel to zero immediately mutes it
but does not stop it from running - it'll just produce silence.

In addition to per-channel volume controls, there also exists a global 8-bit  "master volume" value (in Q0.8 fixed point) that the final
mix is multiplied by before being sent to the DAC.

> [!NOTE]
> Fixed-point arithmetic means we can not reach true 100% volume; however, it doesn't matter
> because the difference between the largest possible value and 100% in 0.8 fixed point is inaudible to the human ear.

Also, the pulse, noise and wavetable channels utilize additional configuration values:

- Pulse: Duty cycle. The duty cycle of a pulse wave is the percentage of the waveform it spends at the top level (ergo spitting out +1).
This is configured through MMIO via a 3-bit value (0-7) that is used internally as Q0.3 fixed point, allowing for the following duty cycle values:
  - 0 -> 0%
  - 1 -> 0.125 or 12.5%
  - 2 -> 0.25 or 25%
  - 3 -> 0.375 or 37.5%
  - 4 -> 0.5 or 50%
  - 5 -> 0.625 or 62.5%
  - 6 -> 0.75 or 75%
  - 7 -> 0.875 or 87.5%
At startup, the duty cycle is initialized to 4 (50%), producing a true square wave.
- Noise: Noise mode. A single bit value that can be switched between 0=Long mode and 1=Short mode.
  - Long mode: the LFSR register uses bit 1 as its tap bit and
    wraps back to its initial value less often, giving standard white noise. Useful for fire, explosions etc.
  - Short mode: bit 6 is the tap bit. The LFSR sequence collapses to much fewer steps before it cycles back to the initial
    value, producing a metallic buzzing tone.
- Wavetable: The wavetable channels can (or rather *must*) be configured as to which sample to play. As mentioned before,
samples must be uploaded to Audio RAM before playback. The sample value of the wavetable channels is a 7-bit integer mapping to a 64-byte
aligned memory region (8kb ARAM => 128 * 64-byte samples)

#### Wavetable sample data & indexing

Audio RAM (ARAM) is 8 KB and is divided into **128 tables** of **64 bytes each** (128 × 64 = 8192). A wavetable channel is
configured with a **7-bit table index** (0–127) that selects one of these 128 slots; the table index implicitly selects the byte
range `[index × 64, index × 64 + 63]` within ARAM.

Each table is a sequence of **64 signed 8-bit samples** (−128…+127), interpreted as the raw waveform one full cycle per table.
The channel plays the table as a loop: as its phase advances across the waveform, it reads the table position and emits the
sample value found there, wrapping back to byte 0 after byte 63.

Indexing details:

- The phase (0–1) maps onto the table linearly: table byte `floor(phase × 64)` is the current sample.
- Because 64 is a power of two, `phase × 64` is simply the top 6 fractional bits of the phase, so indexing is just a
  `phase >> (fraction_width − 6)` style shift — no multiplication needed in the emulator.
- The phase advances by `pitch / 44100` per tick, so a higher pitch advances through all 64 bytes faster, raising the tone
  (frequency = 44100 / (pitch × 64) cycles per second).
- Since the table is rectangular, any bytes you do not explicitly fill are whatever the previous ARAM contents hold; always
  write all 64 bytes (or start from a known-cleared slot) to avoid garbage.

Preparing a new sound at runtime:

1. Build or copy the desired 64-sample waveform into a **dedicated, unused slot** (filling all 64 bytes).
2. Switch the wavetable channel's table index to that slot.
3. Optionally re-trigger with the phase-reset bit so the note starts from the beginning of the table.

Because the APU reads the table live, editing a slot that is *currently playing* changes the sound immediately. It
is therefore advised to prepare new tables in spare slots and only switch when ready. The two wavetable
channels can each point at any slot independently, so a common trick is to point both at the same table but use
different `pitch` values for a detuned, fatter unison sound.

### ADSR

Finally, ADSR (attack, decay, sustain, release) envelopes are supported for all channels. ADSR is practically a
state machine that provides a multiplier (the amplitude) for the generated sample depending on the current state (and how long it has been maintained).
Each envelope value is a 4-bit integer, allowing programmers to neatly pack an ADSR envelope into a 16-bit word as such:

- Bits 0-3: Release
- Bits 4-7: Sustain
- Bits 8-11: Decay
- Bits 12-15: Attack

To reach amplitude 1.0 from 0.0 (or the inverse), the state machine must step 256 times. Attack, Decay and Release represent indices that map
to an integer that represents how many samples must be generated before one step occurs:

| Value | Attack Duration | Decay/Release Duration | Samples/Step (Attack) | Samples/Step (Decay/Release) |
| :---: | :---: | :---: | :---: | :---: |
| `0x0` | **0 ms** | **0 ms** | 0 | 1 |
| `0x1` | **5.8 ms** | **27.4 ms** | 1 | 4 |
| `0x2` | **16 ms** | **48 ms** | 3 | 8 |
| `0x3` | **24 ms** | **72 ms** | 4 | 12 |
| `0x4` | **38 ms** | **114 ms** | 7 | 20 |
| `0x5` | **56 ms** | **168 ms** | 10 | 29 |
| `0x6` | **68 ms** | **204 ms** | 12 | 35 |
| `0x7` | **80 ms** | **240 ms** | 14 | 41 |
| `0x8` | **100 ms** | **300 ms** | 17 | 52 |
| `0x9` | **250 ms** | **750 ms** | 43 | 129 |
| `0xA` | **500 ms** | **1.5 s** | 86 | 258 |
| `0xB` | **800 ms** | **2.4 s** | 138 | 413 |
| `0xC` | **1.0 s** | **3.0 s** | 172 | 517 |
| `0xD` | **3.0 s** | **9.0 s** | 517 | 1,551 |
| `0xE` | **5.0 s** | **15.0 s** | 861 | 2,584 |
| `0xF` | **8.0 s** | **24.0 s** | 1,378 | 4,134 |

> [!NOTE]
> The above table is courtesy of the genius behind the Commodore 64's SID audio chip, Bob Yannes.
> Decay/Release times are triple those of attack because of how the human ear perceives volume drops.

More specifically:

- Attack: How many cycles/step to go from 0.0 to 1.0. Once 1.0 has been reached, move to Decay.
- Decay: How many cycles/step to go from 1.0 to the Sustain level. Once that level has been reached, switch to Sustain.
- Sustain: Shifted left by four bits to sparsely calculate which of the 256 steps' amplitude to hold after Decay.
Held as long as the channel is playing.
- Release: After the channel is *manually* turned off, how many cycles/step to go from the Release level to 0.0 again.

#### Retriggering

Retriggering is the act of setting a channel to play while it is actively silencing itself (such as during the Release envelope phase).
All channels automatically perform soft retriggering: instead of zipping the envelope step back to zero and restarting,
the envelope is simply set to Attack and allowed to climb back up.
Additionally, the control register of each channel also allows you to set a specific bit to 1 in order to
also reset the waveform's `phase` to zero, therefore restarting the sample from the beginning (which is crucial for percussion).

## How a single sample is generated

At every tick, for each channel that is currently active:

- The ADSR envelope of the channel is stepped to calculate the current amplitude multiplier (between 0 and 1).
- The APU advances the channel's phase/rate and runs the channel's algorithm to get a sample (±1 *channel volume* amplitude).
- The APU calculates the sum of all the outputs, divides it by 3.3 to normalize, and calculates its hyperbolic tangent (`tanh`).
- The APU multiplies the mix by (global volume / 256) and hands the final value to the host.

## MMIO

The MMIO region dedicated to MMIO begins at `$05:0700`:

### Global controls

| Address | Name | Description | Read/Write? | Size (bytes) |
| --------------- | --------------- | --------------- | --------------- | --------------- |
| `$05:0700-9` | Audio DMA | Refer to [[dma#Audio memory DMA (main bus -> ARAM)]] | - | - |
| `$05:070a` | APUCTRL | APU control bitmask (see below) | RW | 1 |
| `$05:070b` | GLBLVOL | 8-bit master volume (Q0.8 fixed point) | RW | 1 |

`APUCTRL` layout:

- Bit 0: Enable/disable. Set to 1 to disable all output and freeze envelope state.
- Bits 1-7: Reserved.

### Pulse

| Address | Name | Description | Read/Write? | Size (bytes) |
| --------------- | --------------- | --------------- | --------------- | --------------- |
| `$05:070c` | PULCTRL | Pulse channel control bitmask (see below) | RW | 1 |
| `$05:070d` | PULPITCH | Pulse channel pitch | RW | 2 |
| `$05:070f` | PULVOL | Pulse channel volume (Q0.8 fixed point) | RW | 1 |
| `$05:0710` | PULADSR | Pulse channel ADSR envelope | RW | 2 |

`PULCTRL` layout:

- Bit 0: Disable (1 silences the channel and freezes envelope/phase state)
- Bit 1: Gate (drives ADSR - 0->1 note on -> Attack, 1->0 Release)
- Bit 2: Phase reset toggle (set 1 to reset waveform phase to 0 when retriggering)
- Bits 3-5: Duty cycle (Q0.3 fixed point)
- Bits 6-7: Reserved

### Saw

| Address | Name | Description | Read/Write? | Size (bytes) |
| --------------- | --------------- | --------------- | --------------- | --------------- |
| `$05:0712` | SAWCTRL | Saw channel control bitmask (see below) | RW | 1 |
| `$05:0713` | SAWPITCH | Saw channel pitch | RW | 2 |
| `$05:0715` | SAWVOL | Saw channel volume (Q0.8 fixed point) | RW | 1 |
| `$05:0716` | SAWADSR | Saw channel ADSR envelope | RW | 2 |

`SAWCTRL` layout:

- Bit 0: Disable (1 silences the channel and freezes envelope/phase state)
- Bit 1: Gate (drives ADSR - 0->1 note on -> Attack, 1->0 Release)
- Bit 2: Phase reset toggle (set 1 to reset waveform phase to 0 when retriggering)

### Triangle

| Address | Name | Description | Read/Write? | Size (bytes) |
| --------------- | --------------- | --------------- | --------------- | --------------- |
| `$05:0717` | TRICTRL | Triangle channel control bitmask (see below) | RW | 1 |
| `$05:0718` | TRIPITCH | Triangle channel pitch | RW | 2 |
| `$05:071a` | TRIVOL | Triangle channel volume (Q0.8 fixed point) | RW | 1 |
| `$05:071b` | TRIADSR | Triangle channel ADSR envelope | RW | 2 |

`TRICTRL` layout:

- Bit 0: Disable (1 silences the channel and freezes envelope/phase state)
- Bit 1: Gate (drives ADSR - 0->1 note on -> Attack, 1->0 Release)
- Bit 2: Phase reset toggle (set 1 to reset waveform phase to 0 when retriggering)

### Noise

| Address | Name | Description | Read/Write? | Size (bytes) |
| --------------- | --------------- | --------------- | --------------- | --------------- |
| `$05:071d` | NOICTRL | Noise channel control bitmask (see below) | RW | 1 |
| `$05:071e` | NOIRATE | Noise channel LFSR step rate | RW | 2 |
| `$05:0720` | NOIVOL | Noise channel volume (Q0.8 fixed point) | RW | 1 |
| `$05:0721` | NOIADSR | Noise channel ADSR envelope | RW | 2 |

`NOICTRL` layout:

- Bit 0: Disable (1 silences the channel and freezes envelope/phase state)
- Bit 1: Gate (drives ADSR - 0->1 note on -> Attack, 1->0 Release)
- Bit 2: Phase reset toggle (set 1 to reset waveform phase to 0 when retriggering)
- Bit 3: Noise mode. Set to 0 for long, 1 for short.

### Wavetables

| Address | Name | Description | Read/Write? | Size (bytes) |
| --------------- | --------------- | --------------- | --------------- | --------------- |
| `$05:0723` | WT1CTRL | Wavetable channel 1 control bitmask (see below) | RW | 1 |
| `$05:0724` | WT1PITCH | Wavetable channel 1 pitch | RW | 2 |
| `$05:0726` | WT1VOL | Wavetable channel 1 volume (Q0.8 fixed point) | RW | 1 |
| `$05:0727` | WT1ADSR | Wavetable channel 1 ADSR envelope | RW | 2 |
| `$05:0729` | WT1IDX | Wavetable channel 1 sample index | RW | 1 |
| `$05:072a` | WT2CTRL | Wavetable channel 2 control bitmask (see below) | RW | 1 |
| `$05:072b` | WT2PITCH | Wavetable channel 2 pitch | RW | 2 |
| `$05:072d` | WT2VOL | Wavetable channel 2 volume (Q0.8 fixed point) | RW | 1 |
| `$05:072e` | WT2ADSR | Wavetable channel 2 ADSR envelope | RW | 2 |
| `$05:0730` | WT2IDX | Wavetable channel 2 sample index | RW | 1 |

`WTnCTRL` layout:

- Bit 0: Disable (1 silences the channel and freezes envelope/phase state)
- Bit 1: Gate (drives ADSR - 0->1 note on -> Attack, 1->0 Release)
- Bit 2: Phase reset toggle (set 1 to reset waveform phase to 0 when retriggering)
- Bits 3-7: Reserved

As a reminder, wavetable samples are expected to be aligned to 64 bytes. The index is masked to 7 bits when selecting the sample.
