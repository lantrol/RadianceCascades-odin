package MyGl

import "core:fmt"
import glm "core:math/linalg/glsl"
import "core:slice"
import "core:strings"
import gl "vendor:OpenGL"
import sdl "vendor:sdl3"

Texture :: struct {
	id:             u32,
	width:          i32,
	height:         i32,
	internalformat: u32,
}

Target :: struct {
	fbo:     u32,
	texture: Texture,
	width:   i32,
	height:  i32,
}

createTexture2D :: proc(
	width, height: i32,
	internalformat: u32 = gl.RGBA8,
	wrap: i32 = gl.REPEAT,
	filter: i32 = gl.NEAREST,
) -> (
	texture: Texture,
) {
	gl.CreateTextures(gl.TEXTURE_2D, 1, &texture.id)

	gl.TextureParameteri(texture.id, gl.TEXTURE_WRAP_S, wrap)
	gl.TextureParameteri(texture.id, gl.TEXTURE_WRAP_T, wrap)
	gl.TextureParameteri(texture.id, gl.TEXTURE_MIN_FILTER, filter)
	gl.TextureParameteri(texture.id, gl.TEXTURE_MAG_FILTER, filter)

	gl.TextureStorage2D(texture.id, 1, internalformat, width, height)

	texture.internalformat = internalformat
	texture.width = width
	texture.height = height
	return texture
}

writeTexture2D :: proc(texture: Texture, data: []$T, components: u32, width, height: i32) {
	format, type: u32

	switch typeid_of(T) {
	case u8:
		type = gl.UNSIGNED_BYTE
	case u16:
		type = gl.UNSIGNED_SHORT
	case u32:
		type = gl.UNSIGNED_INT
	case i8:
		type = gl.BYTE
	case i16:
		type = gl.SHORT
	case i32:
		type = gl.INT
	case f16:
		type = gl.HALF_FLOAT
	case f32:
		type = gl.FLOAT
	case f64:
		type = gl.DOUBLE
	case:
		fmt.eprintln("ERROR: Tipo de dato inválido")
		return
	}

	switch components {
	case 1:
		format = gl.RED
	case 2:
		format = gl.RG
	case 3:
		format = gl.RGB
	case 4:
		format = gl.RGBA
	case:
		fmt.eprintln("ERROR: Numero de componentes inválido")
		return
	}

	if data != nil {
		gl.TextureSubImage2D(texture.id, 0, 0, 0, width, height, format, type, raw_data(data))
	}
}

bindImage :: proc(unit: u32, texture: Texture, use: enum {
		READ,
		WRITE,
		READ_WRITE,
	}) {
	gl_use: u32
	switch use {
		case .READ:
			gl_use = gl.READ_ONLY
		case .WRITE:
			gl_use = gl.WRITE_ONLY
		case .READ_WRITE:
			gl_use = gl.READ_WRITE
	}

	gl.BindImageTexture(unit, texture.id, 0, false, 0, gl_use, texture.internalformat)
}

bindTexture :: proc(unit: u32, texture: Texture) {
	gl.BindTextureUnit(unit, texture.id)
}

createTarget :: proc(width, height: i32, format: u32 = gl.RGBA8) -> Target {
	fbo: u32
	gl.CreateFramebuffers(1, &fbo)
	texture := createTexture2D(width, height, format)
	gl.NamedFramebufferTexture(fbo, gl.COLOR_ATTACHMENT0, texture.id, 0)
	target: Target = {fbo, texture, width, height}
	return target
}

deleteTarget :: proc(target: ^Target) {
	gl.DeleteTextures(1, &(target.texture.id))
	gl.DeleteFramebuffers(1, &(target.fbo))
	target^ = {} // Zero the values
}

bindTarget :: proc(target: Target, mode: u32 = gl.FRAMEBUFFER) {
	gl.BindFramebuffer(mode, target.fbo)
	gl.Viewport(0, 0, target.width, target.height)
}

unbindTargets :: proc() {
    gl.BindFramebuffer(gl.FRAMEBUFFER, 0)
}
