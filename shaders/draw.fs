#version 450 core

in vec2 uvs;
out vec4 frag_color;

uniform vec2 mouse_pos;
uniform vec2 screen_res;

void main() {
	vec2 fragPos = gl_FragCoord.xy;

	if (length(mouse_pos-fragPos) < 20) {
		frag_color = vec4(1., 1., 1., 1.);
	}
	else {
		frag_color = gl_Color;
	}

	//vec2 mouse_uvs = mouse_pos/screen_res;
    //frag_color = vec4(mouse_uvs.x, mouse_uvs.y, 0., 1.);
}