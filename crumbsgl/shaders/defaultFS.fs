#version 450 core

in vec2 iUvs;
in vec3 iColor;
out vec4 frag_color;

void main() {
	frag_color = vec4(iColor, 1.);
}
