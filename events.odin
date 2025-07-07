package main

import "core:fmt"
import "core:math"
import "myGl"
import gl "vendor:OpenGL"
import sdl "vendor:sdl3"

// Event handling
@(private = "file")
Pressed_Keys: [322]bool = {}
@(private = "file")
Mouse_Buttons: [5]bool = {}
@(private = "file")
Event_Quit: bool = false

@(deferred_none = reset_events)
handle_events :: proc() {
	event: sdl.Event
	for sdl.PollEvent(&event) {
		if event.type == .QUIT {
			Event_Quit = true
		} else if event.type == .KEY_DOWN {
			Pressed_Keys[event.key.key] = true
			// if event.key.key == sdl.K_ESCAPE {
			// 	break loop
			// }
		} else if event.type == .MOUSE_BUTTON_DOWN {
			Mouse_Buttons[event.button.button] = true
			// if event.button.button == sdl.BUTTON_RIGHT {
			// 	calculateSDF(floodfill, rcContext.draw, &rcContext.sdf0, &rcContext.sdf1)
			// }
		}
	}
}

reset_events :: proc() {
	for i in 0 ..< len(Pressed_Keys) {
		Pressed_Keys[i] = false
	}
	for i in 0 ..< len(Mouse_Buttons) {
		Mouse_Buttons[i] = false
	}
	Event_Quit = false
}

is_key_pressed :: proc(key: sdl.Keycode) -> bool {
	return Pressed_Keys[key]
}

is_mouse_button_pressed :: proc(button: u8) -> bool {
	return Mouse_Buttons[button]
}

has_quit :: proc() -> bool {
	return Event_Quit
}

