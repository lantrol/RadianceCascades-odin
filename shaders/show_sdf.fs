#version 450 core

layout(binding = 0) uniform sampler2D sdf;
uniform float screen_size;
uniform float range;


in vec2 uvs;
out vec4 frag_color;

void main() {
	vec2 coords = gl_FragCoord.xy;
	vec4 color = texture(sdf, uvs);

	float dist;
	vec3 finalColor;
	if (color.y != 0. && color.z != 0.) {
		dist = length(color.yz-coords)/screen_size;
		// if (abs(dist - range) <= 0.001) {
		// 	finalColor = vec3(0., 1., 0.);
		// }
		if (dist <= 0.001 && range < 10.){
			finalColor = vec3(0., 0., 1.);
		}
		else {
			finalColor = vec3(dist);
		}
	} 
	else {
		finalColor = vec3(0., 0., 0.);
	}

    frag_color = vec4(finalColor, 1.);
}