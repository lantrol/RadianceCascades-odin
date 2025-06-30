#version 450 core

layout(local_size_x = 1, local_size_y = 1, local_size_z = 1) in;

#define M_PI 3.1415926535897932384626433832795

layout(rgba32f, binding = 0) uniform image2D nearProbes;
layout(rgba32f, binding = 1) readonly uniform image2D farProbes;

// Information of near probes, far information is calculated
uniform ivec2 num_probs;
uniform int ray_count;
uniform int cascade_level;

// Working in normalized coordenates [0, 1] except for sdf texture read

ivec2 getRayPos(ivec2 probe_id, int ray_id, int probes_per_side, int ray_per_side) {
	vec2 ray_tex_coords = vec2((ray_id % ray_per_side) , int(ray_id / ray_per_side));
    vec2 data_coords = vec2(probe_id)*ray_per_side + ray_tex_coords;
    return data_coords;
}

void main() {
	ivec2 invocation = ivec2(gl_GlobalInvocationID.xy);

	if (max(invocation.x, invocation.y) >= int(num_probs.x)*sqrt(ray_count)) {
		return;
	}

	// Calculate which probe and which ray is the invocation based on texture coords
	int ray_tex_side = int(sqrt(ray_count));
	ivec2 near_probe_id = ivec2( int(invocation.x / ray_tex_side), int(invocation.y / ray_tex_side) );
	if (min(probe_id.x, probe_id.y) == 0 || max(probe_id.x, probe_id.y) >= num_probs.x-1) {
		return; // return if probe is in edge, not treated for now
	}
	int near_ray_id = (invocation.x % ray_tex_side) + ray_tex_side*(invocation.y % ray_tex_side);

	// Far probe info
	ivec2 far_probe_id = (near_probe_id-1)/2; // bottom left probe id of 2x2 grid
	ivec2 near_probe_inner_pos = ivec2( int(invocation.x / ray_tex_side), int(invocation.y / ray_tex_side) );

	for (int i = 0; i < 2; i++) {
		for (int j = 0; j < 2; j++) {
			
		}	
	}



	vec4 probeData = vec4(0.);
	if (hit) {
		probeData = vec4(1.);
	}
	imageStore(probes, invocation, probeData);
}