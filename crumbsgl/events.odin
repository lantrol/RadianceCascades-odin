package CrumbsGL

import "core:fmt"
import "core:math"
import "core:time"
import gl "vendor:OpenGL"
import sdl "vendor:sdl3"


ButtonState :: enum {
	NotPressed,
	JustPressed,
	Pressed,
	JustReleased,
}


// Event handling
@(private = "file")
Pressed_Keys: map[sdl.Keycode]ButtonState
@(private = "file")
Mouse_Buttons: map[sdl.MouseButtonFlag]ButtonState
@(private = "file")
Mouse_Position: [2]i32 = {}
@(private = "file")
Mouse_Displacement: [2]i32 = {}
@(private = "file")
Event_Quit: bool = false

handle_events :: proc() {
	// Pre event handle and resets
	for key, value in Pressed_Keys {
		if value == .JustPressed {
			Pressed_Keys[key] = .NotPressed
		}
	}
	Mouse_Displacement[0] = 0
	Mouse_Displacement[1] = 0

	// Event Handling
	event: sdl.Event
	for sdl.PollEvent(&event) {
		if event.type == .QUIT {
			Event_Quit = true
		} else if event.type == .KEY_DOWN {
			if Pressed_Keys[event.key.key] == .JustPressed {
				Pressed_Keys[event.key.key] = .Pressed
			} else if Pressed_Keys[event.key.key] != .Pressed {
				Pressed_Keys[event.key.key] = .JustPressed
			}
		} else if event.type == .KEY_UP {
			Pressed_Keys[event.key.key] = .JustReleased
		} else if event.type == .MOUSE_MOTION {
			Mouse_Displacement[0] = i32(event.motion.xrel)
			Mouse_Displacement[1] = i32(event.motion.yrel)
		}
	}

	// Mouse input handled here to get position at same time
	x, y: f32
	mouseState: sdl.MouseButtonFlags = sdl.GetMouseState(&x, &y)
	for button in sdl.MouseButtonFlag {
		if button in mouseState {
			#partial switch Mouse_Buttons[button] {
			case .Pressed:
			case .JustPressed:
				Mouse_Buttons[button] = .Pressed
			case:
				Mouse_Buttons[button] = .JustPressed
			}
		} else {
			#partial switch Mouse_Buttons[button] {
			case .NotPressed:
			case .JustReleased:
				Mouse_Buttons[button] = .NotPressed
			case:
				Mouse_Buttons[button] = .JustReleased
			}
		}
	}
	Mouse_Position[0] = i32(x)
	Mouse_Position[1] = i32(y)
}

reset_events :: proc() {
	for key, value in Pressed_Keys {
		Pressed_Keys[key] = .NotPressed
	}
	Mouse_Buttons = {}
	Event_Quit = false
}

is_key_just_pressed :: proc(key: sdl.Keycode) -> bool {
	return Pressed_Keys[key] == .JustPressed
}

is_button_just_pressed :: proc(button: sdl.MouseButtonFlag) -> bool {
	return Mouse_Buttons[button] == .JustPressed
}

is_button_pressed :: proc(button: sdl.MouseButtonFlag) -> bool {
	return Mouse_Buttons[button] == .Pressed
}

get_mouse_position :: proc() -> (x, y: i32) {
	return Mouse_Position[0], Mouse_Position[1]
}

get_mouse_displacement :: proc() -> (x, y: i32) {
	return Mouse_Displacement[0], Mouse_Displacement[1]
}

has_quit :: proc() -> bool {
	return Event_Quit
}
