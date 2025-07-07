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
SCREEN_SIZE :: 1024

// Grid parameters
GRID_SIZE :: 100

// Cascade Probes Parameters

CASCADE_AMOUNT :: 1
PROBE_RENDER :: true
C0_RAY_COUNT :: 16
MAX_RAY_ANGLE :: 2 * math.PI / C0_RAY_COUNT
MIN_PROBE_RES :: 16
MIN_RAY_SIZE :: (2. / f32(MIN_PROBE_RES)) / 2
//MIN_SIZE :: 1. / 10.
//MIN_PROBE_DISTANCE :: MIN_SIZE / MAX_RAY_ANGLE

main :: proc() {
	fmt.println(MIN_RAY_SIZE)
	window, wind_ok := myGl.windowInit(
		SCREEN_SIZE,
		SCREEN_SIZE,
		GL_VERSION_MAJOR,
		GL_VERSION_MINOR,
	)
	if !wind_ok {
		fmt.eprintln("ERROR: No se ha podido crear ventana SDL")
		os.exit(-1)
	}
	defer myGl.windowDelete(&window)

	gl.Enable(gl.BLEND)

	// Empty vao to enable rendering with DSA
	emptyVao: u32
	gl.GenVertexArrays(1, &emptyVao)
	gl.BindVertexArray(emptyVao)
	defer gl.DeleteBuffers(1, &emptyVao)

	// ------Shader Load-------

	program, prog_ok := gl.load_shaders_file("shaders/base_line.vs", "shaders/base_line.fs")
	if !prog_ok {
		fmt.eprintln("Error creando shader")
		os.exit(-1)
	}
	defer gl.DeleteProgram(program)

	screen_sh, sh_ok := gl.load_shaders_file("shaders/base.vs", "shaders/base.fs")
	if !sh_ok {
		fmt.eprintln("Error creando shader")
		os.exit(-1)
	}
	defer gl.DeleteProgram(screen_sh)

	draw_prog, comp_ok := gl.load_compute_file("shaders/draw.glsl")
	if !comp_ok {
		os.exit(-1)
	}
	defer gl.DeleteProgram(draw_prog)

	floodfill, flood_ok := gl.load_compute_file("shaders/jumpflood.glsl")
	if !flood_ok {
		os.exit(-1)
	}
	defer gl.DeleteProgram(floodfill)

	probe_cast, probe_ok := gl.load_compute_file("shaders/probe_cast.glsl")
	if !probe_ok {
		os.exit(-1)
	}
	defer gl.DeleteProgram(probe_cast)

	render_probe, rend_ok := gl.load_shaders_file("shaders/draw_probe.vs", "shaders/draw_probe.fs")
	if !rend_ok {
		os.exit(-1)
	}
	defer gl.DeleteProgram(render_probe)

	probe_to_field, ptf_ok := gl.load_compute_file("shaders/probe_to_field.glsl")
	if !ptf_ok {
		os.exit(-1)
	}

	probe_merge, merge_ok := gl.load_compute_file("shaders/probe_merge.glsl")
	if !merge_ok {
		os.exit(-1)
	}

	// ---------------
	drawTarget := myGl.createTarget(SCREEN_SIZE, SCREEN_SIZE, gl.RGBA32F)
	defer myGl.deleteTarget(&drawTarget)

	screen := myGl.createQuadFS()
	defer myGl.deleteMesh(&screen)


	// El rango es de [-1, 1], osea que es de 2 de ancho
	//min_dist: f32 = 2. / MIN_PROBE_RES
	//num_probs: i32 = i32(2. / f32(min_dist))

	num_probs: i32 = MIN_PROBE_RES

	rcContext: RCContext = rc_create(
		SCREEN_SIZE,
		num_probs,
		C0_RAY_COUNT,
		MIN_RAY_SIZE,
		CASCADE_AMOUNT,
	)
	defer rc_delete(&rcContext)

	color: []f32 = {1., 1., 1.}
	loop: for {
		handle_events()
		if is_key_pressed(sdl.K_ESCAPE) do break loop
		if has_quit() do break loop
		if is_mouse_button_pressed(sdl.BUTTON_RIGHT) {
			rc_calculate_sdf(&rcContext, floodfill)
		}

		gl.ClearColor(0.2, 0.2, 0.2, 1.)
		gl.Clear(gl.COLOR_BUFFER_BIT)

		// Handle field drawing
		rc_draw_handle(rcContext, color, draw_prog)

		// Raycast from probes with SDFs
		rc_calculate_cascades(rcContext, probe_cast)

		// Cascades merging
		rc_merge_cascades(rcContext, probe_merge)

		// Probe to field
		rc_calculate_field(rcContext, probe_to_field)

		// Draw
		myGl.unbindTargets()

		gl.Viewport(0, 0, SCREEN_SIZE, SCREEN_SIZE)
		//myGl.setUniform(screen_sh, "screen_size", f32(SCREEN_SIZE))
		//myGl.setUniform(screen_sh, "range", f32(0.01))
		myGl.renderMesh(screen, screen_sh, rcContext.field)

		gl.LineWidth(2)
		gl.PointSize(2)
		if PROBE_RENDER {
			for i: i32 = 0; i < CASCADE_AMOUNT; i += 1 {
				drawCascade(rcContext, i, render_probe)
			}
		}

		sdl.GL_SwapWindow(window.window)
	}
}

// Jump Flood algorithm
// calculateSDF :: proc(compute: u32, field: myGl.Texture, sdf0, sdf1: ^myGl.Texture) {
// 	// Variable shadowing
// 	sdf0 := sdf0
// 	sdf1 := sdf1

// 	// Copy drawn image to base sdf
// 	gl.CopyImageSubData(
// 		field.id,
// 		gl.TEXTURE_2D,
// 		0,
// 		0,
// 		0,
// 		0,
// 		sdf0.id,
// 		gl.TEXTURE_2D,
// 		0,
// 		0,
// 		0,
// 		0,
// 		SCREEN_SIZE,
// 		SCREEN_SIZE,
// 		1,
// 	)

// 	// First iteration with i = 1 is used to set the initial SDF from the field texture
// 	// i >= 2 onward are the SDF Jump Flood steps
// 	for i: i32 = 1; i <= SCREEN_SIZE; i = i * 2 {
// 		myGl.setUniform(compute, "k", i32(SCREEN_SIZE / i))
// 		myGl.setUniform(compute, "screen_res", []f32{SCREEN_SIZE, SCREEN_SIZE})
// 		myGl.bindImage(0, sdf0^, .READ)
// 		myGl.bindImage(1, sdf1^, .WRITE)
// 		myGl.compute_run(compute, SCREEN_SIZE, SCREEN_SIZE)
// 		sdf0^, sdf1^ = sdf1^, sdf0^
// 	}

// 	// Last extra iteration with k = 1
// 	// Helps getting better results
// 	myGl.setUniform(compute, "k", i32(1))
// 	myGl.bindImage(0, sdf0^, .READ)
// 	myGl.bindImage(1, sdf1^, .WRITE)
// 	myGl.compute_run(compute, SCREEN_SIZE, SCREEN_SIZE)
// 	sdf0^, sdf1^ = sdf1^, sdf0^
// }

// calculateCascade :: proc(rcContext: RCContext, cascade_level: i32, program: u32) {
// 	nProbsX := rcContext.base_probe_res >> u32(cascade_level)
// 	nProbsY := rcContext.base_probe_res >> u32(cascade_level)
// 	ray_count := int(rcContext.base_ray_count) << u32(2 * (cascade_level))
// 	ray_tex_side: u32 = u32(math.sqrt_f32(f32(ray_count)))

// 	myGl.bindImage(0, rcContext.sdf0, .READ)
// 	myGl.bindImage(1, rcContext.cascades[cascade_level], .WRITE)
// 	myGl.setUniform(program, "sdf_res", []i32{rcContext.sdf0.width, rcContext.sdf0.height})
// 	myGl.setUniform(program, "num_probs", []i32{nProbsX, nProbsY})
// 	myGl.setUniform(program, "ray_count", i32(ray_count))
// 	myGl.setUniform(program, "ray_dist", f32(rcContext.base_ray_length))
// 	myGl.setUniform(program, "cascade_level", i32(cascade_level))
// 	myGl.compute_run(program, u32(nProbsX) * ray_tex_side, u32(nProbsY) * ray_tex_side)
// }

// mergeCascades :: proc(rcContext: RCContext, program: u32) {
// 	cascade_amount: i32 = i32(len(rcContext.cascades))

// 	for i: i32 = cascade_amount - 1; i > 0; i = i - 1 {
// 		// Cascades merging
// 		nProbsX := rcContext.base_probe_res >> u32(i - 1)
// 		nProbsY := rcContext.base_probe_res >> u32(i - 1)
// 		ray_count := int(rcContext.base_ray_count) << u32(2 * (i - 1))
// 		myGl.setUniform(program, "num_probs", []i32{nProbsX, nProbsY})
// 		myGl.setUniform(program, "ray_count", i32(ray_count))
// 		myGl.bindImage(0, rcContext.cascades[i - 1], .READ_WRITE)
// 		myGl.bindImage(1, rcContext.cascades[i], .READ)
// 		myGl.compute_run(
// 			program,
// 			u32(rcContext.cascades[0].width),
// 			u32(rcContext.cascades[0].height),
// 		)
// 	}
// }

drawCascade :: proc(rcContext: RCContext, cascade_level: i32, shader: u32) {
	min_probe_dist: f32 = 2. / f32(rcContext.base_probe_res) // OpenGL coords [-1, 1] -> length = 2
	ray_count: i32 = rcContext.base_ray_count << u32(2 * (cascade_level))
	probe_dist: f32 =
		min_probe_dist if cascade_level == 0 else min_probe_dist * f32(i32(1 << u32(cascade_level)))
	start_dist: f32 =
		(rcContext.base_ray_length * (1 - glm.pow_f32(4, f32(cascade_level)))) / (1 - 4)
	end_dist: f32 = rcContext.base_ray_length * glm.pow_f32(4, f32(cascade_level))

	nProbsX := rcContext.base_probe_res >> u32(cascade_level)
	nProbsY := rcContext.base_probe_res >> u32(cascade_level)

	myGl.bindTexture(0, rcContext.cascades[cascade_level])

	for i in 0 ..< nProbsX {
		for j in 0 ..< nProbsY {
			base_displace: [3]f32 = {probe_dist / 2, probe_dist / 2, 0}
			pos: [3]f32 =
				{probe_dist * f32((i)), probe_dist * f32((j)), 0} + {-1, -1, -1} + base_displace
			drawProbe(pos, ray_count, start_dist, end_dist, []i32{nProbsX, nProbsY}, shader)
		}
	}
}

drawProbe :: proc(
	position: [3]f32,
	ray_count: i32,
	ray_start: f32,
	ray_end: f32,
	probe_amount: []i32,
	shader: u32,
) {
	wRes: f32 = 2 * math.PI / f32(ray_count)
	angle: f32 = wRes / 2.

	dir: [3]f32
	for i in 0 ..< ray_count {
		dir = glm.normalize_vec3({math.cos(angle), math.sin(angle), 0})
		start: [3]f32 = position + dir * ray_start
		end: [3]f32 = position + dir * ray_end
		myGl.setUniform(shader, "probe_pos", []f32{position.x, position.y})
		myGl.setUniform(shader, "num_probs", probe_amount)
		myGl.setUniform(shader, "ray_count", i32(ray_count))
		myGl.setUniform(shader, "ray_id", i32(i))
		myGl.drawLine(start, end, shader)
		angle += wRes
	}

	myGl.drawPoint(position, shader, {0, 1, 0})
	gl.Finish()
}

vertex_shader: string = `
#version 450 core

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
#version 450 core

layout(binding = 0) uniform sampler2D textura;
uniform float screen_size;


in vec2 uvs;
out vec4 frag_color;

void main() {
	vec2 coords = gl_FragCoord.xy;
	vec4 color = texture(textura, uvs);

	float dist;
	if (color.y != 0. && color.z != 0.) {
		dist = length(color.yz-coords)/screen_size;
	} 
	else {
		dist = 0.;
	}

    frag_color = vec4(dist, dist, dist, 1.);
}

`

