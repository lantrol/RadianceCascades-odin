package main

import "core:math"
import "core:os"
import crgl "crumbsgl"
import gl "vendor:OpenGL"
import sdl "vendor:sdl3"

DRAW_RADIUS :: 20.

RCContext :: struct {
	// Base values to calculate cascade level info
	base_ray_count:  i32,
	base_ray_length: f32,
	base_probe_res:  i32, // probes per side

	// Fields for calculations
	draw:            crgl.Texture,
	sdf0:            crgl.Texture,
	sdf1:            crgl.Texture, // second tex for Ping-Pong
	cascades:        []crgl.Texture,
	field:           crgl.Texture,
}

RCShaders :: struct {
	draw_prog:      u32,
	floodfill:      u32,
	probe_cast:     u32,
	probe_to_field: u32,
	probe_merge:    u32,
}

gRCShaders: RCShaders

rc_create :: proc(
	field_dim: i32,
	probe_res: i32,
	ray_count: i32,
	ray_length: f32,
	cascade_amount: i32,
) -> RCContext {
	rc: RCContext = {
		base_probe_res  = probe_res,
		base_ray_count  = ray_count,
		base_ray_length = ray_length,
		draw            = crgl.createTexture2D(field_dim, field_dim, gl.RGBA32F),
		sdf0            = crgl.createTexture2D(field_dim, field_dim, gl.RGBA32F),
		sdf1            = crgl.createTexture2D(field_dim, field_dim, gl.RGBA32F),
		cascades        = make([]crgl.Texture, i32(cascade_amount)),
		field           = crgl.createTexture2D(
			probe_res,
			probe_res,
			gl.RGBA32F,
			gl.CLAMP_TO_EDGE,
			gl.LINEAR,
		),
	}
	for i: i32 = 0; i < cascade_amount; i += 1 {
		rc.cascades[i] = crgl.createTexture2D(
			probe_res * i32(math.sqrt(f32(ray_count))),
			probe_res * i32(math.sqrt(f32(ray_count))),
			gl.RGBA32F,
		)
	}
	return rc
}

rc_delete :: proc(rc: ^RCContext) {
	crgl.deleteTexture(&rc.draw)
	crgl.deleteTexture(&rc.sdf0)
	crgl.deleteTexture(&rc.sdf1)
	crgl.deleteTexture(&rc.field)
	for i: int = 0; i < len(rc.cascades); i += 1 {
		crgl.deleteTexture(&rc.cascades[i])
	}
	delete(rc.cascades)
}

rc_load_shaders :: proc() {
	draw_prog, comp_ok := gl.load_compute_file("shaders/draw.glsl")
	if !comp_ok {
		os.exit(-1)
	}

	floodfill, flood_ok := gl.load_compute_file("shaders/jumpflood.glsl")
	if !flood_ok {
		os.exit(-1)
	}

	probe_cast, probe_ok := gl.load_compute_file("shaders/probe_cast.glsl")
	if !probe_ok {
		os.exit(-1)
	}

	probe_to_field, ptf_ok := gl.load_compute_file("shaders/probe_to_field.glsl")
	if !ptf_ok {
		os.exit(-1)
	}

	probe_merge, merge_ok := gl.load_compute_file("shaders/probe_merge.glsl")
	if !merge_ok {
		os.exit(-1)
	}

	gRCShaders = RCShaders{draw_prog, floodfill, probe_cast, probe_to_field, probe_merge}
}

rc_draw_handle :: proc(rc: RCContext, color: []f32) {
	x, y: f32
	mouseState := sdl.GetMouseState(&x, &y)
	if .LEFT in mouseState {
		crgl.setUniform(gRCShaders.draw_prog, "mouse_pos", []f32{x, SCREEN_SIZE - y})
		crgl.setUniform(gRCShaders.draw_prog, "color", color)
		crgl.setUniform(gRCShaders.draw_prog, "radius", DRAW_RADIUS)
		crgl.bindImage(0, rc.draw, .READ_WRITE)
		crgl.compute_run(
			gRCShaders.draw_prog,
			u32(rc.draw.width / 8) + 1,
			u32(rc.draw.height / 8) + 1,
		)
	}
}

rc_calculate_sdf :: proc(rc: ^RCContext) {
	calculateSDF(gRCShaders.floodfill, rc.draw, &rc.sdf0, &rc.sdf1)
}

rc_calculate_cascades :: proc(rc: RCContext) {
	for i: int = 0; i < len(rc.cascades); i += 1 {
		calculateCascade(rc, i32(i), gRCShaders.probe_cast)
	}
}

rc_merge_cascades :: proc(rcContext: RCContext) {
	cascade_amount: i32 = i32(len(rcContext.cascades))

	for i: i32 = cascade_amount - 1; i > 0; i = i - 1 {
		// Cascades merging
		nProbsX := rcContext.base_probe_res >> u32(i - 1)
		nProbsY := rcContext.base_probe_res >> u32(i - 1)
		ray_count := int(rcContext.base_ray_count) << u32(2 * (i - 1))
		crgl.setUniform(gRCShaders.probe_merge, "num_probs", []i32{nProbsX, nProbsY})
		crgl.setUniform(gRCShaders.probe_merge, "ray_count", i32(ray_count))
		crgl.setUniform(
			gRCShaders.probe_merge,
			"sdf_res",
			[]i32{rcContext.sdf0.width, rcContext.sdf0.height},
		)
		crgl.bindImage(0, rcContext.cascades[i - 1], .READ_WRITE)
		crgl.bindImage(1, rcContext.cascades[i], .READ)
		crgl.bindImage(2, rcContext.sdf0, .READ)
		crgl.compute_run(
			gRCShaders.probe_merge,
			u32(rcContext.cascades[0].width / 8) + 1,
			u32(rcContext.cascades[0].height / 8) + 1,
		)
	}
}

rc_calculate_field :: proc(rc: RCContext) {
	crgl.bindImage(0, rc.cascades[0], .READ)
	crgl.bindImage(1, rc.field, .WRITE)
	crgl.setUniform(
		gRCShaders.probe_to_field,
		"num_probs",
		[]i32{rc.base_probe_res, rc.base_probe_res},
	)
	crgl.setUniform(gRCShaders.probe_to_field, "ray_count", i32(rc.base_ray_count))
	crgl.compute_run(
		gRCShaders.probe_to_field,
		u32(rc.base_probe_res / 8) + 1,
		u32(rc.base_probe_res / 8) + 1,
	)
}

// Jump Flood algorithm
@(private = "file")
calculateSDF :: proc(compute: u32, field: crgl.Texture, sdf0, sdf1: ^crgl.Texture) {
	// Variable shadowing
	sdf0 := sdf0
	sdf1 := sdf1

	// Copy drawn image to base sdf
	gl.CopyImageSubData(
		field.id,
		gl.TEXTURE_2D,
		0,
		0,
		0,
		0,
		sdf0.id,
		gl.TEXTURE_2D,
		0,
		0,
		0,
		0,
		SCREEN_SIZE,
		SCREEN_SIZE,
		1,
	)

	// First iteration with i = 1 is used to set the initial SDF from the field texture
	// i >= 2 onward are the SDF Jump Flood steps
	for i: i32 = 1; i <= SCREEN_SIZE; i = i * 2 {
		crgl.setUniform(compute, "k", i32(SCREEN_SIZE / i))
		crgl.setUniform(compute, "screen_res", []f32{SCREEN_SIZE, SCREEN_SIZE})
		crgl.bindImage(0, sdf0^, .READ)
		crgl.bindImage(1, sdf1^, .WRITE)
		crgl.compute_run(compute, (SCREEN_SIZE / 8) + 1, (SCREEN_SIZE / 8) + 1)
		sdf0^, sdf1^ = sdf1^, sdf0^
	}

	// Last extra iteration with k = 1
	// Helps getting better results
	crgl.setUniform(compute, "k", i32(1))
	crgl.bindImage(0, sdf0^, .READ)
	crgl.bindImage(1, sdf1^, .WRITE)
	crgl.compute_run(compute, (SCREEN_SIZE / 8) + 1, (SCREEN_SIZE / 8) + 1)
	sdf0^, sdf1^ = sdf1^, sdf0^
}

@(private = "file")
calculateCascade :: proc(rcContext: RCContext, cascade_level: i32, program: u32) {
	nProbsX := rcContext.base_probe_res >> u32(cascade_level)
	nProbsY := rcContext.base_probe_res >> u32(cascade_level)
	ray_count := int(rcContext.base_ray_count) << u32(2 * (cascade_level))
	ray_tex_side: u32 = u32(math.sqrt_f32(f32(ray_count)))

	crgl.bindImage(0, rcContext.sdf0, .READ)
	crgl.bindImage(1, rcContext.cascades[cascade_level], .WRITE)
	crgl.bindImage(2, rcContext.draw, .READ)
	crgl.setUniform(program, "sdf_res", []i32{rcContext.sdf0.width, rcContext.sdf0.height})
	crgl.setUniform(program, "num_probs", []i32{nProbsX, nProbsY})
	crgl.setUniform(program, "ray_count", i32(ray_count))
	crgl.setUniform(program, "ray_dist", f32(rcContext.base_ray_length))
	crgl.setUniform(program, "cascade_level", i32(cascade_level))
	crgl.compute_run(
		program,
		(u32(nProbsX) * ray_tex_side) / 8 + 1,
		(u32(nProbsY) * ray_tex_side) / 8 + 1,
	)
}

