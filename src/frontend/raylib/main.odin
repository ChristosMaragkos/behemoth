package main

import emu "../../emulator"
import "base:runtime"
import "core:c"
import "core:fmt"
import "core:mem"
import "core:os"
import "core:strings"
import rl "vendor:raylib"

SCREEN_WIDTH :: 256
SCREEN_HEIGHT :: 240

sram_dirty: bool

main :: proc() {
	rl.SetTraceLogLevel(.ERROR)
	sys := emu.system_init()
	defer emu.system_cleanup(sys)

	save_path := ""

	fpath_passed := len(os.args) > 1
	load: if fpath_passed {
		fpath := os.args[1]
		if !strings.has_suffix(fpath, ".bhm") {
			fmt.printfln(
				"[BHMTH] Could not load cartridge: unknown file extension '%s' (cartridges must be .bhm files)",
				os.ext(fpath),
			)
			mem_free_all(context.temp_allocator)
			break load
		}
		load_err := emu.system_load_cart_from_file(sys, fpath)
		if load_err != os.General_Error.None {
			fmt.printfln(
				"[BHMTH] Could not load cartridge from command line argument; load failed with error: %s",
				load_err,
			)
		}

		save_path, _ = strings.replace(fpath, ".bhm", ".sav", 1)
		saved_data, save_error := os.read_entire_file(save_path, context.temp_allocator)
		if save_error != nil || len(saved_data) == 0 {
			fmt.println("[BHMTH] Could not load save data (file was not found or was empty)")
			break load
		}
		sys.bus.sram_high = u32(0xC6_0000 + len(saved_data) - 1)
		mem.copy(&sys.bus.ram[0xC6_0000], &saved_data[0], min(len(saved_data), 4 * 0xffff))
		mem_free_all(context.temp_allocator)
		fmt.printfln("[BHMTH] Successfully loaded save file '%s'", save_path)
	}

	rl.SetConfigFlags({.WINDOW_RESIZABLE})
	rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "BHMTH")
	rl.SetWindowMonitor(0)
	rl.MaximizeWindow()
	rl.SetTargetFPS(60)
	rl.SetWindowMinSize(SCREEN_WIDTH, SCREEN_HEIGHT)

	defer rl.CloseWindow()

	tex := rl.LoadRenderTexture(SCREEN_WIDTH, SCREEN_HEIGHT)
	defer rl.UnloadRenderTexture(tex)

	rl.InitAudioDevice()
	defer rl.CloseAudioDevice()

	stream := rl.LoadAudioStream(44100, 32, 2)
	rl.SetAudioStreamCallback(stream, audio_callback)
	rl.PlayAudioStream(stream)
	defer rl.UnloadAudioStream(stream)

	seen_pad := false
	for i in 1 ..< 4 {
		idx := i32(i)
		if rl.IsGamepadAvailable(idx) {
			fmt.printfln("[BHMTH] Found gamepad: '%s' (slot %d)", rl.GetGamepadName(idx), i)
			seen_pad = true
		}
	}
	if !seen_pad do fmt.println("[BHMTH] No gamepads detected, keyboard only")

	frame_counter: u32 = 0
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

		src := rl.Rectangle{0, 0, f32(tex.texture.width), f32(tex.texture.height)}
		rl.DrawTexturePro(tex.texture, src, dest, {0, 0}, 0.0, rl.WHITE)
		rl.EndDrawing()

		if sys.bus.sram_dirty {
			if frame_counter % 600 == 0 && save_path != "" {
				save_data := sys.bus.ram[0xC6_0000:sys.bus.sram_high + 1]
				err := dump_save_data(save_path, save_data)
				if err == nil do sys.bus.sram_dirty = false
			}
		}

		frame_counter += 1
	}

	if save_path != "" && sys.bus.sram_dirty {
		save_data := sys.bus.ram[0xC6_0000:sys.bus.sram_high + 1]
		dump_save_data(save_path, save_data)
	}
}

audio_callback :: proc "c" (buffer: rawptr, frames: c.uint) {
	context = runtime.default_context()
	@(static) last_l, last_r: f32
	samples := transmute([^]f32)buffer
	for i in 0 ..< frames {
		if emu.g_audio_fifo == nil {
			last_l, last_r = 0.0, 0.0
			samples[2 * i], samples[2 * i + 1] = 0.0, 0.0
			continue
		}
		l, r, ok := emu.audio_fifo_consume(emu.g_audio_fifo)
		if ok {
			last_l, last_r = l, r
		}
		samples[2 * i] = last_l
		samples[2 * i + 1] = last_r
	}
}

dump_save_data :: proc(path: string, data: []byte) -> os.Error {
	err := os.write_entire_file(path, data)
	if err != nil do fmt.printfln("[BHMTH] Cannot write to save file '%s': %s", path, err)
	else do fmt.printfln("[BHMTH] Wrote %d bytes to save file '%s'", len(data), path)
	return err
}
