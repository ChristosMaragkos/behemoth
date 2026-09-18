package audio

EnvState :: struct {
	state:     enum u8 {
		Idle,
		Attack,
		Decay,
		Sustain,
		Release,
	},
	level:     u8,
	counter:   u32,
	prev_gate: bool,
}

envelope_step :: proc(
	env: ^EnvState,
	adsr: Envelope,
	gate_current: bool,
	reset_on_retrigger: bool,
	phase_current: ^f32,
) -> f32 {
	if gate_current && !env.prev_gate {
		env.state = .Attack
		if reset_on_retrigger do phase_current^ = 0
	} else if !gate_current && env.prev_gate {
		env.state = .Release
	}
	env.prev_gate = gate_current

	switch env.state {
		case .Idle:
			break
		case .Attack:
			a := adsr.a
			if a == 0 {
				env.level = 255
				env.counter = 0
				env.state = .Decay
			} else {
				env.counter += 1
				if env.counter >= samples_per_step_table[a] {
					env.level += 1
					env.counter = 0
				}
				if env.level == 255 do env.state = .Decay
			}
		case .Decay:
			env.counter += 1
			if env.counter < step_amount_decay_release(adsr.d) do break

			env.level -= 1
			env.counter = 0

			sustain_level := adsr.s << 4
			if env.level <= sustain_level {
				env.state = .Sustain
			}
		case .Sustain:
			break
		case .Release:
			if env.level == 0 {
				env.state = .Idle
				env.counter = 0
				break
			}
			env.counter += 1
			if env.counter < step_amount_decay_release(adsr.r) do break

			env.level -= 1
			env.counter = 0
			if env.level == 0 do env.state = .Idle
	}

	return q0_8_expand(env.level)
}

// Triple and clamp minimum to 1 for Decay and Release.
@(rodata)
@(private = "file")
samples_per_step_table := [16]u32{0, 1, 3, 4, 7, 10, 12, 14, 17, 43, 86, 138, 172, 517, 861, 1378}

@(private = "file")
step_amount_decay_release :: #force_inline proc "contextless" (idx: u8) -> u32 {
	return max(1, samples_per_step_table[idx] * 3)
}
