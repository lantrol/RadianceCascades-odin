#version 450 core

layout(local_size_x = 1, local_size_y = 1, local_size_z = 1) in;

layout(rgba32f, binding = 0) uniform image2D texture;
uniform vec2 mouse_pos;
uniform float color;

// Unused but might be usefull
float line_segment(in vec2 p, in vec2 a, in vec2 b) {
	vec2 ba = b - a;
	vec2 pa = p - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0., 1.);
	return length(pa - h * ba);
}

void main() {
	ivec2 position = ivec2(gl_GlobalInvocationID.xy);

	vec4 newColor;
	if (length(mouse_pos - vec2(position)) < 18.) {
		newColor = vec4(color, 0., 0., 1.);
	}
	else {
		newColor = imageLoad(texture, position);
	}

	imageStore(texture, position, newColor);
}