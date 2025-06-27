package MyGl

import "core:fmt"
import glm "core:math/linalg/glsl"
import "core:slice"
import "core:strings"
import gl "vendor:OpenGL"
import sdl "vendor:sdl3"

Vertex :: struct {
	pos: [3]f32,
	tex: [2]f32,
}

Mesh :: struct {
	ssbo:       u32,
	vertAmount: i32,
}

Material :: struct {
	shader:  u32,
	texture: Texture,
}

Renderable :: struct {
	mesh:     Mesh,
	material: Material,
	mode:     u32,
}

// Geometry :: struct {
// 	ssbo: 		u32,
// 	amount: 	i32,
// 	mode: 		u32,
// 	program: 	u32,
// 	texture: 	Texture,
// }

Window :: struct {
	window:     ^sdl.Window,
	gl_context: ^sdl.GLContextState,
}

Program :: struct {
	// Not really used
	id:  u32,
	vao: u32,
}

windowInit :: proc(width, height, GLmajor, GLminor: i32) -> (win: Window, ok: bool) {
	if !sdl.Init({.VIDEO, .EVENTS}) {
		fmt.eprintln("Error inicializando SDL3")
		return {}, false
	}

	sdl.GL_SetAttribute(.CONTEXT_MAJOR_VERSION, GLmajor)
	sdl.GL_SetAttribute(.CONTEXT_MINOR_VERSION, GLminor)
	sdl.GL_SetAttribute(.CONTEXT_PROFILE_MASK, gl.CONTEXT_CORE_PROFILE_BIT)

	window := sdl.CreateWindow("Example", width, height, sdl.WindowFlags{.OPENGL})
	gl_context := sdl.GL_CreateContext(window)
	sdl.GL_MakeCurrent(window, gl_context)

	gl.load_up_to(int(GLmajor), int(GLminor), sdl.gl_set_proc_address)
	win = {window, gl_context}
	return win, true
}

windowDelete :: proc(win: ^Window) {
	sdl.GL_DestroyContext(win.gl_context)
	sdl.DestroyWindow(win.window)
	sdl.Quit()
	win^ = {}
}

createBuffer :: proc(data: []$T, usage: u32 = gl.STATIC_DRAW) -> (vbo: u32) {
	gl.CreateBuffers(1, &vbo)
	gl.NamedBufferData(vbo, size_of(data[0]) * len(data), raw_data(slice.to_bytes(data)), usage)
	return vbo
}

bindAttributes :: proc(program: Program, vbo: u32, attributes: []struct {
		type:   u32,
		amount: i32,
		name:   string,
	}) -> (ok: bool) {

	offset: i32 = 0
	for attribute, index in attributes {
		attribName: cstring = strings.clone_to_cstring(attribute.name)
		defer delete(attribName)
		attribLocation := gl.GetAttribLocation(program.id, attribName)

		if attribLocation == -1 {
			fmt.eprintln("ERROR: atributo no encontrado")
			return false
		}
		gl.EnableVertexArrayAttrib(program.vao, u32(index))
		gl.VertexArrayAttribBinding(program.vao, u32(attribLocation), 0)

		typeSize, ok := getTypeSize(attribute.type)
		gl.VertexArrayAttribFormat(
			program.vao,
			u32(attribLocation),
			attribute.amount,
			attribute.type,
			false,
			u32(offset * typeSize),
		)
		offset += attribute.amount
	}
	typeSize, okay := getTypeSize(attributes[0].type)
	gl.VertexArrayVertexBuffer(program.vao, 0, vbo, 0, offset * typeSize)
	return true
}


// createQuadFS :: proc() -> (quad: Geometry) {
// 	screen_vert := []Vertex {
// 		{{-1, 1, 0}, {0, 1}},
// 		{{-1, -1, 0}, {0, 0}},
// 		{{1, 1, 0}, {1, 1}},
// 		{{1, -1, 0}, {1, 0}},
// 	}
// 	screen_elems := []u32{0, 1, 2, 1, 2, 3}

// 	gl.CreateVertexArrays(1, &quad.vao)
// 	gl.CreateBuffers(1, &quad.vbo)
// 	gl.CreateBuffers(1, &quad.ebo)

// 	gl.NamedBufferData(
// 		quad.vbo,
// 		size_of(screen_vert[0]) * len(screen_vert),
// 		raw_data(screen_vert),
// 		gl.STATIC_DRAW,
// 	)
// 	gl.NamedBufferData(
// 		quad.ebo,
// 		size_of(screen_elems[0]) * len(screen_elems),
// 		raw_data(screen_elems),
// 		gl.STATIC_DRAW,
// 	)

// 	gl.EnableVertexArrayAttrib(quad.vao, 0)
// 	gl.VertexArrayAttribBinding(quad.vao, 0, 0)
// 	gl.VertexArrayAttribFormat(quad.vao, 0, 3, gl.FLOAT, false, 0)

// 	gl.EnableVertexArrayAttrib(quad.vao, 1)
// 	gl.VertexArrayAttribBinding(quad.vao, 1, 0)
// 	gl.VertexArrayAttribFormat(quad.vao, 1, 2, gl.FLOAT, false, 3 * size_of(f32))

// 	gl.VertexArrayVertexBuffer(quad.vao, 0, quad.vbo, 0, 5 * size_of(f32))
// 	gl.VertexArrayElementBuffer(quad.vao, quad.ebo)

// 	return quad
// }

createMesh :: proc(data: []$T, usage: u32 = gl.DYNAMIC_STORAGE_BIT) -> (mesh: Mesh) {
	ssbo: u32
	gl.CreateBuffers(1, &ssbo)
	gl.NamedBufferStorage(ssbo, size_of(data[0]) * len(data), raw_data(data), usage)
	mesh.ssbo = ssbo
	mesh.vertAmount = i32(len(data))
	return mesh
}

deleteMesh :: proc(mesh: ^Mesh) {
	gl.DeleteBuffers(1, &(mesh.ssbo))
	mesh^ = {0, 0}
}

render :: proc(rend: Renderable) {
	gl.UseProgram(rend.material.shader)
	gl.BindBufferBase(gl.SHADER_STORAGE_BUFFER, 0, rend.mesh.ssbo)
	gl.BindTextureUnit(0, rend.material.texture.id)
	gl.DrawArrays(rend.mode, 0, rend.mesh.vertAmount)
}

renderMesh :: proc(mesh: Mesh, shader: u32, texture: Texture = {}, mode: u32 = gl.TRIANGLE_STRIP) {
	gl.UseProgram(shader)
	gl.BindBufferBase(gl.SHADER_STORAGE_BUFFER, 0, mesh.ssbo)
	if texture != {} {
		gl.BindTextureUnit(0, texture.id)
	}
	gl.DrawArrays(mode, 0, mesh.vertAmount)
}

createQuadFS :: proc() -> (mesh: Mesh) {
	screen_vert := []Vertex {
		{{-1, 1, 0}, {0, 1}},
		{{-1, -1, 0}, {0, 0}},
		{{1, 1, 0}, {1, 1}},
		{{1, -1, 0}, {1, 0}},
	}
	mesh = createMesh(screen_vert)
	// rend.mesh = mesh
	// rend.mode = gl.TRIANGLE_STRIP
	return mesh
}

createRenderable :: proc {
	createRenderableMeshMaterial,
	createRenderableMeshShaderTexture,
}

createRenderableMeshMaterial :: proc(
	mesh: Mesh,
	material: Material,
	mode: u32 = gl.TRIANGLE_STRIP,
) -> Renderable {
	rend: Renderable
	rend.mesh = mesh
	rend.material = material
	rend.mode = gl.TRIANGLE_STRIP
	return rend
}

createRenderableMeshShaderTexture :: proc(
	mesh: Mesh,
	shader: u32,
	texture: Texture,
	mode: u32 = gl.TRIANGLE_STRIP,
) -> Renderable {
	material: Material
	material.shader = shader
	material.texture = texture

	rend: Renderable
	rend.mesh = mesh
	rend.material = material
	rend.mode = mode
	return rend
}

compute_run :: proc(compute: u32, group_x: u32 = 1, group_y: u32 = 1, group_z: u32 = 1) {
	gl.UseProgram(compute)
	gl.DispatchCompute(group_x, group_y, 1)
	gl.MemoryBarrier(gl.ALL_BARRIER_BITS)
}
