package main

import "core:fmt"
import "core:os"
import "core:math"
import "core:math/rand"
import "core:time"
import "core:strings"
import glm "core:math/linalg/glsl"
import "myGl"

import gl "vendor:OpenGL"
import sdl "vendor:sdl3"

VSYNC :: 1
GL_VERSION_MAJOR :: 4
GL_VERSION_MINOR :: 5

// Grid parameters
GRID_SIZE :: 100

// Cascade Probes Parameters

CASCADE_AMOUNT :: 2
MIN_SIZE :: 1./100.
MIN_RAY_COUNT :: 4
MAX_RAY_ANGLE :: 2*math.PI/MIN_RAY_COUNT
MIN_PROBE_DISTANCE :: MIN_SIZE/MAX_RAY_ANGLE

main :: proc() {
	// window, wind_ok := myGl.windowInit(800, 800, GL_VERSION_MAJOR, GL_VERSION_MINOR)
	// if !wind_ok {
	// 	fmt.eprintln("ERROR: No se ha podido crear ventana SDL")
	// 	os.exit(-1)
	// }
	// defer myGl.windowDelete(&window)

	// emptyVao: u32
	// gl.GenVertexArrays(1, &emptyVao)
	// gl.BindVertexArray(emptyVao)
	// defer gl.DeleteBuffers(1, &emptyVao)

	// loop: for {
	// 	event: sdl.Event
	// 	for sdl.PollEvent(&event) {
	// 		if event.type == .QUIT {
	// 			break loop
	// 		} else if event.type == .KEY_DOWN {
	// 			if event.key.key == sdl.K_ESCAPE {
	// 				break loop
	// 			}
	// 		}
	// 	}
	// }

	fmt.println(MIN_SIZE)
	fmt.println(MIN_PROBE_DISTANCE)

}