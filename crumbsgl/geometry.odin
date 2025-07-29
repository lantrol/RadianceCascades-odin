package CrumbsGL

import "core:fmt"
import glm "core:math/linalg/glsl"
import "core:slice"
import "core:strings"
import gl "vendor:OpenGL"
import sdl "vendor:sdl3"

createLine :: proc(start, end: [3]f32) -> Mesh {
	LineData :: struct {
		position: [3]f32,
		color:    [3]f32,
	}
	line := []LineData{{start, {1, 1, 1}}, {end, {1, 1, 1}}}
	lineMesh := createMesh(line)
	return lineMesh
}

drawLine :: proc(start, end: [3]f32, shader: u32) {
	Data :: struct {
		position: [3]f32,
		color:    [3]f32,
	}
	line := []Data{{start, {1, 1, 1}}, {end, {1, 1, 1}}}
	lineMesh := createMesh(line)
	renderMesh(lineMesh, shader, mode = gl.LINES)
	deleteMesh(&lineMesh)
}

drawPoint :: proc(position: [3]f32, shader: Maybe(u32) = nil, color: [3]f32 = {1, 1, 1}) {
	shader := shader
	Data :: struct {
		position: [3]f32,
		color:    [3]f32,
	}
	point := createMesh([]Data{{position, color}})

	_shader: u32
	if _, ok := shader.(u32); !ok {
		_shader = gContext.defColorSh
	} else {
		_shader = shader.(u32)
	}

	gl.PointSize(4.)
	renderMesh(point, _shader, mode = gl.POINTS)
	deleteMesh(&point)
}

@(private = "file")
defaultVS: string = `
#version 450 core

struct VertexData {
	float position[3];
	float color[3];
};

layout(binding = 0, std430) readonly buffer ssbo1 {
	VertexData data[];
};

out vec3 iColor;

vec3 getPosition(int index) {
    return vec3(
        data[index].position[0],
        data[index].position[1],
        data[index].position[2]
    );
}

vec3 getColor(int index) {
    return vec3(
        data[index].color[0],
        data[index].color[1],
        data[index].color[2]
    );
}

void main() {
    iColor = getColor(gl_VertexID);
    gl_Position = vec4(getPosition(gl_VertexID), 1.0);
}
`


@(private = "file")
defaultFS: string = `
#version 450 core

in vec3 iColor;
out vec4 frag_color;

void main() {
	frag_color = vec4(iColor, 1.);
}

`
