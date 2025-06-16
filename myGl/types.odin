package MyGl

import "core:fmt"
import glm "core:math/linalg/glsl"
import gl "vendor:OpenGL"
import "core:strings"

getTypeSize :: proc(type: u32) -> (size: i32, ok: bool) {
	switch type {
	case gl.UNSIGNED_BYTE:
		size = 1
	case gl.UNSIGNED_SHORT:
		size = 2
	case gl.UNSIGNED_INT:
		size = 4
	case gl.BYTE:
		size = 1
	case gl.SHORT:
		size = 2
	case gl.INT:
		size = 4
	case gl.HALF_FLOAT:
		size = 2
	case gl.FLOAT:
		size = 4
	case gl.DOUBLE:
		size = 8
	case:
		fmt.eprintln("ERROR: Tipo de dato inválido")
		return -1, false
	}
	return size, true
}