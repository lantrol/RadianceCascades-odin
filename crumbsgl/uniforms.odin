package CrumbsGL

import "core:fmt"
import glm "core:math/linalg/glsl"
import "core:os"
import "core:slice"
import "core:strings"
import gl "vendor:OpenGL"

setUniform :: proc {
	setUniformf32,
	setUniformf32v,
	setUniformi32,
	setUniformi32v,
	setUniformui32,
	setUniformui32v,
}

setUniformf32 :: proc(shader: u32, name: string, data: f32) {
	uniformName: cstring = strings.clone_to_cstring(name)
	defer delete(uniformName)
	location: i32 = gl.GetUniformLocation(shader, uniformName)

	if location == -1 {
		fmt.eprintln("ERROR: uniform", name, "does not exist")
		os.exit(1)
	}

	gl.ProgramUniform1f(shader, location, data)
}

setUniformf32v :: proc(shader: u32, name: string, data: []f32) {
	uniformName: cstring = strings.clone_to_cstring(name)
	defer delete(uniformName)
	location: i32 = gl.GetUniformLocation(shader, uniformName)

	if location == -1 {
		fmt.eprintln("ERROR: uniform", name, "does not exist")
		os.exit(1)
	}

	switch len(data) {
	case 1:
		gl.ProgramUniform1fv(shader, location, 1, raw_data(data))
	case 2:
		gl.ProgramUniform2fv(shader, location, 1, raw_data(data))
	case 3:
		gl.ProgramUniform3fv(shader, location, 1, raw_data(data))
	case 4:
		gl.ProgramUniform4fv(shader, location, 1, raw_data(data))
	}
}

setUniformi32 :: proc(shader: u32, name: string, data: i32) {
	uniformName: cstring = strings.clone_to_cstring(name)
	defer delete(uniformName)
	location: i32 = gl.GetUniformLocation(shader, uniformName)

	if location == -1 {
		fmt.eprintln("ERROR: uniform", name, "does not exist")
		os.exit(1)
	}

	gl.ProgramUniform1i(shader, location, data)
}

setUniformi32v :: proc(shader: u32, name: string, data: []i32) {
	uniformName: cstring = strings.clone_to_cstring(name)
	defer delete(uniformName)
	location: i32 = gl.GetUniformLocation(shader, uniformName)

	if location == -1 {
		fmt.eprintln("ERROR: uniform", name, "does not exist")
		os.exit(1)
	}

	switch len(data) {
	case 1:
		gl.ProgramUniform1iv(shader, location, 1, raw_data(data))
	case 2:
		gl.ProgramUniform2iv(shader, location, 1, raw_data(data))
	case 3:
		gl.ProgramUniform3iv(shader, location, 1, raw_data(data))
	case 4:
		gl.ProgramUniform4iv(shader, location, 1, raw_data(data))
	}
}

setUniformui32 :: proc(shader: u32, name: string, data: u32) {
	uniformName: cstring = strings.clone_to_cstring(name)
	defer delete(uniformName)
	location: i32 = gl.GetUniformLocation(shader, uniformName)

	if location == -1 {
		fmt.eprintln("ERROR: uniform", name, "does not exist")
		os.exit(1)
	}

	gl.ProgramUniform1ui(shader, location, data)
}

setUniformui32v :: proc(shader: u32, name: string, data: []u32) {
	uniformName: cstring = strings.clone_to_cstring(name)
	defer delete(uniformName)
	location: i32 = gl.GetUniformLocation(shader, uniformName)

	if location == -1 {
		fmt.eprintln("ERROR: uniform", name, "does not exist")
		os.exit(1)
	}

	switch len(data) {
	case 1:
		gl.ProgramUniform1uiv(shader, location, 1, raw_data(data))
	case 2:
		gl.ProgramUniform2uiv(shader, location, 1, raw_data(data))
	case 3:
		gl.ProgramUniform3uiv(shader, location, 1, raw_data(data))
	case 4:
		gl.ProgramUniform4uiv(shader, location, 1, raw_data(data))
	}
}

