#version 450 core

layout(local_size_x = 1, local_size_y = 1, local_size_z = 1) in;

layout(rgba32f, binding = 0) readonly uniform image2D inSDF;
layout(rgba32f, binding = 1) writeonly uniform image2D outSDF;
uniform vec2 screen_res;
uniform int k;

void main() {
	ivec2 position = ivec2(gl_GlobalInvocationID.xy);

	ivec2 indexes[8] = {
		ivec2(k, 0),
		ivec2(k, -k),
		ivec2(0, -k),
		ivec2(-k, -k),
		ivec2(-k, 0),
		ivec2(-k, k),
		ivec2(0, k),
		ivec2(k, k)
	};

	vec4 currColor = imageLoad(inSDF, position);

	if (currColor.z == 0. && currColor.a >= 0.9) { 
		currColor.xy = position;
		imageStore(outSDF, position, currColor);
		return;
	}

	float dist = 1000000.;
	ivec2 tex_offset;
	for (int i = 0; i < 8; i++) {

		if (position+indexes[i] != clamp(position+indexes[i], 0, screen_res.x)) {
			continue;
		}

		vec4 q = imageLoad(inSDF, position+indexes[i]);
		float offset_dist = length(indexes[i]);

		if (currColor.a == 0. && q.a >= 0.9) {
			currColor.z = offset_dist;
			currColor.xy = position+indexes[i];
			currColor.a = 1.;
			continue;
		}
		else if (currColor.a >= 0.9 && q.a >= 0.9) {
			if (currColor.z > q.z) {
				currColor = q;
			}
		}
	}
	imageStore(outSDF, position, currColor);
}