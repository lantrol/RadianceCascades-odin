package main

import "core:fmt"
import "core:math"
import glm "core:math/linalg/glsl"
import "core:math/rand"
import "core:os"
import "core:strings"
import "core:time"
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
MIN_SIZE :: 1. / 10.
C0_RAY_COUNT :: 4
MAX_RAY_ANGLE :: 2 * math.PI / C0_RAY_COUNT
//MIN_PROBE_DISTANCE :: MIN_SIZE / MAX_RAY_ANGLE
MIN_PROBE_DISTANCE :: 0.25
MIN_RAY_SIZE :: MIN_PROBE_DISTANCE/2

main :: proc() {
	window, wind_ok := myGl.windowInit(800, 800, GL_VERSION_MAJOR, GL_VERSION_MINOR)
	if !wind_ok {
		fmt.eprintln("ERROR: No se ha podido crear ventana SDL")
		os.exit(-1)
	}
	defer myGl.windowDelete(&window)

	emptyVao: u32
	gl.GenVertexArrays(1, &emptyVao)
	gl.BindVertexArray(emptyVao)
	defer gl.DeleteBuffers(1, &emptyVao)

	program, prog_ok := gl.load_shaders_file("shaders/base_line.vs", "shaders/base_line.fs")
	if !prog_ok {
	    fmt.eprintln("Error creando shader")
	    os.exit(-1)
	}
	defer gl.DeleteProgram(program)

	line : myGl.Mesh = myGl.createLine({0, 0, 0}, {0.5, 0, 0})
	defer myGl.deleteMesh(&line)

	// El rango es de [-1, 1], osea que es de 2 de ancho
	min_dist : f32 = MIN_PROBE_DISTANCE
	fmt.println(min_dist)
	num_probs_x : i32 = i32(2./f32(min_dist))
	num_probs_y : i32 = i32(2./f32(min_dist))

	loop: for {
		event: sdl.Event
		for sdl.PollEvent(&event) {
			if event.type == .QUIT {
				break loop
			} else if event.type == .KEY_DOWN {
				if event.key.key == sdl.K_ESCAPE {
					break loop
				}
			}
		}
		gl.ClearColor(0.2, 0.2, 0.2, 1.)
		gl.Clear(gl.COLOR_BUFFER_BIT)

		// Draw
		gl.LineWidth(2)
		gl.PointSize(2)

		drawCascade(1, num_probs_x, num_probs_y, MIN_PROBE_DISTANCE, MIN_RAY_SIZE, 4, program)

		sdl.GL_SwapWindow(window.window)
	}
}

drawCascade :: proc(cascade_level: i32, num_probs_x, num_probs_y: i32, min_probe_dist:f32, min_ray_dist: f32, min_ray_count: i32, shader: u32) {
    ray_count: i32 = min_ray_count << u32(2 * (cascade_level))
    start_dist: f32 = 0 if cascade_level == 0 else min_ray_dist * f32(i32(1 << u32(2 * cascade_level - 1)))
    probe_dist: f32 = min_probe_dist if cascade_level == 0 else min_probe_dist * f32(i32(1 << u32(cascade_level)))
    end_dist: f32 = min_ray_dist * f32(i32(1 << u32(2 * cascade_level)))

    nProbsX := num_probs_x >> u32(cascade_level)
    nProbsY := num_probs_y >> u32(cascade_level)

    fmt.println(nProbsX, nProbsY)

    for i in 0..<nProbsX {
        for j in 0..<nProbsY {
            base_displace : [3]f32 = {probe_dist/2, probe_dist/2, 0}
            pos : [3]f32 =  {probe_dist*f32((i)), probe_dist*f32((j)), 0} + {-1, -1, -1} + base_displace
            drawProbe(pos, ray_count, start_dist, end_dist, shader)
  		}
	}
}

drawProbe :: proc(position: [3]f32, ray_count: i32, ray_start: f32, ray_end: f32, shader: u32){
    wRes : f32 = 2*math.PI/f32(ray_count)
    angle : f32 = wRes/2.

    dir : [3]f32
    for i in 0..<ray_count {
        dir = glm.normalize_vec3({math.cos(angle), math.sin(angle), 0})
        start: [3]f32 = position+dir*ray_start
        end: [3]f32 = position+dir*ray_end
        myGl.drawLine(start, end, shader)
        angle += wRes
    }

    myGl.drawPoint(position, shader, {0, 1, 0})
}

vertex_shader: string = `
#version 460 core

struct VertexData {
	float position[3];
	float uv[2];
};

layout(binding = 0, std430) readonly buffer ssbo1 {
	VertexData data[];
};

out vec2 uvs;

vec3 getPosition(int index) {
    return vec3(
        data[index].position[0],
        data[index].position[1],
        data[index].position[2]
    );
}

vec2 getUV(int index) {
    return vec2(
        data[index].uv[0],
        data[index].uv[1]
    );
}

void main() {
    uvs = getUV(gl_VertexID);
    gl_Position = vec4(getPosition(gl_VertexID), 1.0);
}
`

frag_shader: string = `
#version 460 core

layout(binding = 0) uniform sampler2D textura;

in vec2 uvs;
out vec4 frag_color;

void main() {
    frag_color = texture(textura, uvs);
}

`
