package MyGl

import "core:fmt"
import glm "core:math/linalg/glsl"
import gl "vendor:OpenGL"
import "core:strings"
import "core:slice"
import sdl "vendor:sdl3"

createLine :: proc(start, end : [3]f32) -> Mesh {
    LineData :: struct {
        position: [3]f32,
        color: [3]f32
    }
    line := []LineData{{start, {1, 1, 1}}, {end, {1, 1, 1}}}
    lineMesh := createMesh(line)
    return lineMesh
}

drawLine :: proc(start, end : [3]f32, shader: u32) {
    Data :: struct {
        position: [3]f32,
        color: [3]f32
    }
    line := []Data{{start, {1, 1, 1}}, {end, {1, 1, 1}}}
    lineMesh := createMesh(line)
    renderMesh(lineMesh, shader, mode = gl.LINES)
    deleteMesh(&lineMesh)
}

drawPoint :: proc(position: [3]f32, shader: u32, color: [3]f32 = {1, 1, 1}) {
    Data :: struct {
        position: [3]f32,
        color: [3]f32
    }
    point := createMesh([]Data{{position, color}})
    renderMesh(point, shader, mode = gl.POINTS)
    deleteMesh(&point)
}
