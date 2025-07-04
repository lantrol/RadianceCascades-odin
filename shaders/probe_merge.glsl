#version 450 core

layout(local_size_x = 1, local_size_y = 1, local_size_z = 1) in;

#define M_PI 3.1415926535897932384626433832795

layout(rgba32f, binding = 0) uniform image2D nearProbes;
layout(rgba32f, binding = 1) readonly uniform image2D farProbes;

// Information of near probes, far information is calculated
uniform ivec2 num_probs;
uniform int ray_count;

// Working in normalized coordenates [0, 1] except for sdf texture read

ivec2 getRayPos(ivec2 probe_id, int ray_id, int probes_per_side, int ray_per_side) {
	ivec2 ray_tex_coords = ivec2((ray_id % ray_per_side) , int(ray_id / ray_per_side));
    ivec2 data_coords = probe_id*ray_per_side + ray_tex_coords;
    return data_coords;
}

vec3 getFarProbeRayData(ivec2 probe_id, int ray_id, int probes_per_side, int ray_per_side) {	
	vec3 colorData = vec3(0.);
	for (int i = 0; i<4; i++) {
		vec4 ray_data = imageLoad(farProbes, getRayPos(probe_id, ray_id*4+i, probes_per_side, ray_per_side));
		colorData += ray_data.xyz;
	}
	return colorData;
}

void main() {
	ivec2 invocation = ivec2(gl_GlobalInvocationID.xy);

	if (max(invocation.x, invocation.y) >= int(num_probs.x)*sqrt(ray_count)) {
		return;
	}

	// Calculate which probe and which ray is the invocation based on texture coords
	int ray_tex_side = int(sqrt(ray_count));
	ivec2 near_probe_id = ivec2( int(invocation.x / ray_tex_side), int(invocation.y / ray_tex_side) );
	if (min(near_probe_id.x, near_probe_id.y) == 0 || max(near_probe_id.x, near_probe_id.y) >= num_probs.x-1) {
		return; // return if probe is in edge, not treated for now
	}
	int near_ray_id = (invocation.x % ray_tex_side) + ray_tex_side*(invocation.y % ray_tex_side);

	// Far probe info
	ivec2 far_probe_id = (near_probe_id-1)/2; // bottom left probe id of 2x2 grid
	int far_probes_per_side = num_probs.x >> 1;
	int far_ray_per_side = ray_tex_side << 1;

	vec4 near_ray_data = imageLoad(nearProbes, invocation);
	if (near_ray_data.a != 0.) {
		return;
	}

	ivec2 inner_probe_coords = ivec2((near_probe_id.x-1) % 2, (near_probe_id.y-1) % 2);
	
	for (int y = 0; y < 2; y++) {
		for (int x = 0; x < 2; x++) {
			float weight_x = x == inner_probe_coords.x ? 0.75 : 0.25;
			float weight_y = y == inner_probe_coords.y ? 0.75 : 0.25;
			vec3 farProbeData = getFarProbeRayData(
					far_probe_id+ivec2(x, y),
					near_ray_id,
					far_probes_per_side,
					far_ray_per_side
				);
			near_ray_data.xyz += farProbeData*weight_x*weight_y;
		}	
	}

	imageStore(nearProbes, invocation, near_ray_data);
}
