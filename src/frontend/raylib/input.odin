package main

import inp "../../emulator/input"
import rl "vendor:raylib"

DEADZONE :: 0.3

get_input :: proc() -> (j1, j2, j3, j4: inp.Joypad) {
	j1 += {.Connected}
	if rl.IsKeyDown(.UP) do j1 += {.Up}
	if rl.IsKeyDown(.DOWN) do j1 += {.Down}
	if rl.IsKeyDown(.LEFT) do j1 += {.Left}
	if rl.IsKeyDown(.RIGHT) do j1 += {.Right}
	if rl.IsKeyDown(.X) do j1 += {.A}
	if rl.IsKeyDown(.Z) do j1 += {.B}
	if rl.IsKeyDown(.S) do j1 += {.X}
	if rl.IsKeyDown(.A) do j1 += {.Y}
	if rl.IsKeyDown(.Q) do j1 += {.L}
	if rl.IsKeyDown(.W) do j1 += {.R}
	if rl.IsKeyDown(.TAB) do j1 += {.Option}
	if rl.IsKeyDown(.ENTER) do j1 += {.Start}

	j1 = apply_controller_state(0, j1)
	j2 = apply_controller_state(1, j2)
	j3 = apply_controller_state(2, j3)
	j4 = apply_controller_state(3, j4)

	return
}

apply_controller_state :: proc(idx: i32, joy_in: inp.Joypad) -> inp.Joypad {
	joy_out := joy_in
	if rl.IsGamepadAvailable(idx) {
		if rl.IsGamepadButtonDown(idx, .LEFT_FACE_UP) do joy_out += {.Up}
		if rl.IsGamepadButtonDown(idx, .LEFT_FACE_DOWN) do joy_out += {.Down}
		if rl.IsGamepadButtonDown(idx, .LEFT_FACE_LEFT) do joy_out += {.Left}
		if rl.IsGamepadButtonDown(idx, .LEFT_FACE_RIGHT) do joy_out += {.Right}
		if rl.IsGamepadButtonDown(idx, .RIGHT_FACE_RIGHT) do joy_out += {.A}
		if rl.IsGamepadButtonDown(idx, .RIGHT_FACE_DOWN) do joy_out += {.B}
		if rl.IsGamepadButtonDown(idx, .RIGHT_FACE_UP) do joy_out += {.X}
		if rl.IsGamepadButtonDown(idx, .RIGHT_FACE_LEFT) do joy_out += {.Y}
		if rl.IsGamepadButtonDown(idx, .MIDDLE_LEFT) do joy_out += {.Option}
		if rl.IsGamepadButtonDown(idx, .MIDDLE_RIGHT) do joy_out += {.Start}

		axisX := rl.GetGamepadAxisMovement(idx, .LEFT_X)
		axisY := rl.GetGamepadAxisMovement(idx, .LEFT_Y)

		if axisX > DEADZONE do joy_out += {.Right}
		else if axisX < -DEADZONE do joy_out += {.Left}

		if axisY > DEADZONE do joy_out += {.Up}
		else if axisY < -DEADZONE do joy_out += {.Down}
	}

	return joy_out
}
