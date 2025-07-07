package main

import "core:math"
import "myGl"
import gl "vendor:OpenGL"
import sdl "vendor:sdl3"

RCContext :: struct {
	// Base values to calculate cascade level info
	base_ray_count:  i32,
	base_ray_length: f32,
	base_probe_res:  i32, // probes per side

	// Fields for calculations
	draw:            myGl.Texture,
	sdf0:            myGl.Texture,
	sdf1:            myGl.Texture, // second tex for Ping-Pong
	cascades:        []myGl.Texture,
	field:           myGl.Texture,
}

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
		draw            = myGl.createTexture2D(field_dim, field_dim, gl.RGBA32F),
		sdf0            = myGl.createTexture2D(field_dim, field_dim, gl.RGBA32F),
		sdf1            = myGl.createTexture2D(field_dim, field_dim, gl.RGBA32F),
		cascades        = make([]myGl.Texture, i32(cascade_amount)),
		field           = myGl.createTexture2D(
			probe_res,
			probe_res,
			gl.RGBA32F,
			gl.CLAMP_TO_EDGE,
			gl.LINEAR,
		),
	}
	for i: i32 = 0; i < cascade_amount; i += 1 {
		rc.cascades[i] = myGl.createTexture2D(
			probe_res * i32(math.sqrt(f32(ray_count))),
			probe_res * i32(math.sqrt(f32(ray_count))),
			gl.RGBA32F,
		)
	}
	return rc
}

rc_delete :: proc(rc: ^RCContext) {
	myGl.deleteTexture(&rc.draw)
	myGl.deleteTexture(&rc.sdf0)
	myGl.deleteTexture(&rc.sdf1)
	myGl.deleteTexture(&rc.field)
	for i: int = 0; i < len(rc.cascades); i += 1 {
		myGl.deleteTexture(&rc.cascades[i])
	}
	delete(rc.cascades)
}

rc_draw_handle :: proc(rc: RCContext, color: []f32, program: u32) {
	x, y: f32
	mouseState := sdl.GetMouseState(&x, &y)
	if .LEFT in mouseState {
		myGl.setUniform(program, "mouse_pos", []f32{x, SCREEN_SIZE - y})
		myGl.setUniform(program, "color", color)
		myGl.bindImage(0, rc.draw, .READ_WRITE)
		myGl.compute_run(program, u32(rc.draw.width), u32(rc.draw.height))
	}
}

rc_calculate_sdf :: proc(rc: ^RCContext, program: u32) {
	calculateSDF(program, rc.draw, &rc.sdf0, &rc.sdf1)
}

rc_calculate_cascades :: proc(rc: RCContext, program: u32) {
	for i: int = 0; i < len(rc.cascades); i += 1 {
		calculateCascade(rc, i32(i), program)
	}
}

rc_merge_cascades :: proc(rcContext: RCContext, program: u32) {
	cascade_amount: i32 = i32(len(rcContext.cascades))

	for i: i32 = cascade_amount - 1; i > 0; i = i - 1 {
		// Cascades merging
		nProbsX := rcContext.base_probe_res >> u32(i - 1)
		nProbsY := rcContext.base_probe_res >> u32(i - 1)
		ray_count := int(rcContext.base_ray_count) << u32(2 * (i - 1))
		myGl.setUniform(program, "num_probs", []i32{nProbsX, nProbsY})
		myGl.setUniform(program, "ray_count", i32(ray_count))
		myGl.bindImage(0, rcContext.cascades[i - 1], .READ_WRITE)
		myGl.bindImage(1, rcContext.cascades[i], .READ)
		myGl.compute_run(
			program,
			u32(rcContext.cascades[0].width),
			u32(rcContext.cascades[0].height),
		)
	}
}

rc_calculate_field :: proc(rc: RCContext, program: u32) {
	myGl.bindImage(0, rc.cascades[0], .READ)
	myGl.bindImage(1, rc.field, .WRITE)
	myGl.setUniform(program, "num_probs", []i32{rc.base_probe_res, rc.base_probe_res})
	myGl.setUniform(program, "ray_count", i32(rc.base_ray_count))
	myGl.compute_run(program, u32(rc.base_probe_res), u32(rc.base_probe_res))
}

// Jump Flood algorithm
@(private = "file")
calculateSDF :: proc(compute: u32, field: myGl.Texture, sdf0, sdf1: ^myGl.Texture) {
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
		myGl.setUniform(compute, "k", i32(SCREEN_SIZE / i))
		myGl.setUniform(compute, "screen_res", []f32{SCREEN_SIZE, SCREEN_SIZE})
		myGl.bindImage(0, sdf0^, .READ)
		myGl.bindImage(1, sdf1^, .WRITE)
		myGl.compute_run(compute, SCREEN_SIZE, SCREEN_SIZE)
		sdf0^, sdf1^ = sdf1^, sdf0^
	}

	// Last extra iteration with k = 1
	// Helps getting better results
	myGl.setUniform(compute, "k", i32(1))
	myGl.bindImage(0, sdf0^, .READ)
	myGl.bindImage(1, sdf1^, .WRITE)
	myGl.compute_run(compute, SCREEN_SIZE, SCREEN_SIZE)
	sdf0^, sdf1^ = sdf1^, sdf0^
}

@(private = "file")
calculateCascade :: proc(rcContext: RCContext, cascade_level: i32, program: u32) {
	nProbsX := rcContext.base_probe_res >> u32(cascade_level)
	nProbsY := rcContext.base_probe_res >> u32(cascade_level)
	ray_count := int(rcContext.base_ray_count) << u32(2 * (cascade_level))
	ray_tex_side: u32 = u32(math.sqrt_f32(f32(ray_count)))

	myGl.bindImage(0, rcContext.sdf0, .READ)
	myGl.bindImage(1, rcContext.cascades[cascade_level], .WRITE)
	myGl.setUniform(program, "sdf_res", []i32{rcContext.sdf0.width, rcContext.sdf0.height})
	myGl.setUniform(program, "num_probs", []i32{nProbsX, nProbsY})
	myGl.setUniform(program, "ray_count", i32(ray_count))
	myGl.setUniform(program, "ray_dist", f32(rcContext.base_ray_length))
	myGl.setUniform(program, "cascade_level", i32(cascade_level))
	myGl.compute_run(program, u32(nProbsX) * ray_tex_side, u32(nProbsY) * ray_tex_side)
}

