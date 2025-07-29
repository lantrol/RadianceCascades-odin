#+feature dynamic-literals
package CrumbsGL


import "core:fmt"
import glm "core:math/linalg/glsl"
import "core:strings"
import gl "vendor:OpenGL"

typeSizes: map[u32]i32 = map[u32]i32 {
	gl.UNSIGNED_BYTE  = 1,
	gl.UNSIGNED_SHORT = 2,
	gl.UNSIGNED_INT   = 4,
	gl.BYTE           = 1,
	gl.SHORT          = 2,
	gl.INT            = 4,
	gl.HALF_FLOAT     = 2,
	gl.FLOAT          = 4,
	gl.DOUBLE         = 8,
}

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

