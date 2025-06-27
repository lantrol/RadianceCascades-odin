#version 450 core

layout(binding = 0) uniform sampler2D textura;

in vec2 uvs;
out vec4 frag_color;

void main() {
	vec2 coords = gl_FragCoord.xy;
	vec4 color = texture(textura, uvs);
    frag_color = color;
}