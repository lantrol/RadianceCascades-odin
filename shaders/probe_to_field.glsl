#version 450 core

layout(local_size_x = 1, local_size_y = 1, local_size_z = 1) in;

layout(rgba32f, binding = 0) readonly uniform image2D probes;
layout(rgba32f, binding = 1) writeonly uniform image2D field;

// Information of near probes, far information is calculated
uniform ivec2 num_probs;
uniform int ray_count;

// Working in normalized coordenates [0, 1] except for sdf texture read

ivec2 getRayPos(ivec2 probe_id, int ray_id, int probes_per_side, int ray_per_side) {
	vec2 ray_tex_coords = vec2((ray_id % ray_per_side) , int(ray_id / ray_per_side));
    vec2 data_coords = vec2(probe_id)*ray_per_side + ray_tex_coords;
    return ivec2(data_coords);
}

void main() {
	ivec2 probe_id = ivec2(gl_GlobalInvocationID.xy);

	if (max(probe_id.x, probe_id.y) >= int(num_probs.x)) {
		return;
	}

	int ray_tex_side = int(sqrt(ray_count));
	
	vec3 sum = vec3(0.);
	for (int i = 0; i < ray_count; i++) {
		ivec2 ray_coords = getRayPos(probe_id, i, num_probs.x, ray_tex_side);
		vec4 ray = imageLoad(probes, ray_coords);
		sum += ray.xyz;
	}

	imageStore(field, probe_id, vec4(sum/4., 1.0));
}