package main

import emu "../../emulator"
import "base:runtime"
import "core:c"
import "core:fmt"
import "core:os"
import rl "vendor:raylib"

SCREEN_WIDTH :: 256
SCREEN_HEIGHT :: 240

main :: proc() {
	sys := emu.system_init()
	defer emu.system_cleanup(sys)

	fpath_passed := len(os.args) > 1
	if fpath_passed {
		fpath := os.args[1]
		load_err := emu.system_load_cart_from_file(sys, fpath)
		if load_err != os.General_Error.None {
			fmt.printfln(
				"Could not load cartridge from command line argument; load failed with error: %s",
				load_err,
			)
		}
	}

	rl.SetConfigFlags({.WINDOW_RESIZABLE})
	rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "BHMTH")
	rl.SetWindowMonitor(0)
	rl.SetTargetFPS(60)
	rl.SetWindowMinSize(SCREEN_WIDTH, SCREEN_HEIGHT)

	defer rl.CloseWindow()

	tex := rl.LoadRenderTexture(SCREEN_WIDTH, SCREEN_HEIGHT)
	defer rl.UnloadRenderTexture(tex)

	rl.InitAudioDevice()
	defer rl.CloseAudioDevice()

	stream := rl.LoadAudioStream(44100, 32, 1)
	rl.SetAudioStreamCallback(stream, audio_callback)
	rl.PlayAudioStream(stream)
	defer rl.UnloadAudioStream(stream)

	for !rl.WindowShouldClose() {
		win_w := f32(rl.GetScreenWidth())
		win_h := f32(rl.GetScreenHeight())
		scale := min(win_w / SCREEN_WIDTH, win_h / SCREEN_HEIGHT)
		dst_w := SCREEN_WIDTH * scale
		dst_h := SCREEN_HEIGHT * scale
		off_x := (win_w - dst_w) * 0.5
		off_y := (win_h - dst_h) * 0.5
		dest := rl.Rectangle{off_x, off_y, dst_w, dst_h}

		scale_scaled := 1.0 / scale
		rl.SetMouseScale(scale_scaled, scale_scaled)
		rl.SetMouseOffset(i32(-off_x), i32(-off_y))

		emu.system_write_input(sys, get_input())
		emu.system_step_frame(sys)
		rl.UpdateTexture(tex.texture, &sys.ppu.frame_buffer[0])
		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)

		src := rl.Rectangle{0, 0, f32(tex.texture.width), -f32(tex.texture.height)}
		rl.DrawTexturePro(tex.texture, src, dest, {0, 0}, 0.0, rl.WHITE)
		rl.EndDrawing()
	}

}

audio_callback :: proc "c" (buffer: rawptr, amnt: c.uint) {
	context = runtime.default_context()
	samples := transmute([^]f32)buffer
	for i in 0 ..< amnt {
		samples[i] = emu.system_stream_audio(emu.g_apu)
	}
}
