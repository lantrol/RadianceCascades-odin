#version 450 core

layout(local_size_x = 1, local_size_y = 1, local_size_z = 1) in;

#define M_PI 3.1415926535897932384626433832795

layout(rgba32f, binding = 0) readonly uniform image2D SDF;
layout(rgba32f, binding = 1) writeonly uniform image2D probes;

uniform ivec2 sdf_res;
uniform ivec2 num_probs;
uniform int ray_count;
uniform float ray_dist;
uniform int cascade_level;

// Working in normalized coordenates [0, 1] except for sdf texture read

bool raycast(vec2 start, vec2 end, float max_travel) {
	vec2 direction = normalize(end-start);
	float travel = 0.;

	vec2 current_pos = start;
	while (travel < max_travel) {
		ivec2 sdf_pos = ivec2(current_pos*sdf_res);
		vec4 sdf_data = imageLoad(SDF, sdf_pos);

		if (sdf_pos == sdf_data.yz) {
			return true;
		}

		float nearest = length(sdf_data.yz-vec2(sdf_pos))/sdf_res.x;
		current_pos += direction*nearest;
		travel += nearest;
	}
	return false;
}

void main() {
	ivec2 invocation = ivec2(gl_GlobalInvocationID.xy);

	if (max(invocation.x, invocation.y) >= int(num_probs.x)*sqrt(ray_count)) {
		return;
	}

	// Calculate which probe and which ray is the invocation based on texture coords
	int ray_tex_side = int(sqrt(ray_count));
	ivec2 probe_id = ivec2( int(invocation.x / ray_tex_side), int(invocation.y / ray_tex_side) );
	int ray_id = (invocation.x % ray_tex_side) + ray_tex_side*(invocation.y % ray_tex_side);

	// Calculate probe position and raycast
	float probe_dist = 1./num_probs.x;
	vec2 probe_coords = vec2(probe_dist/2.) + vec2(probe_id.x*probe_dist, probe_id.y*probe_dist);
	float ray_angle = (2*M_PI / ray_count)*(float(ray_id) + 0.5);
	vec2 ray_vec = normalize(vec2(cos(ray_angle), sin(ray_angle)));

	float max_travel = ray_dist/2.; // Ray dist comes in range [-1, 1], this is in [0, 1]
	float start_dist = (max_travel * (1 - pow(4, cascade_level))) / (1 - 4);
	float end_dist = max_travel * pow(4, cascade_level);

	bool hit = raycast(probe_coords+ray_vec*start_dist, probe_coords+ray_vec*end_dist, end_dist-start_dist);

	vec4 probeData = vec4(0.);
	if (hit) {
		probeData = vec4(1.);
	}
	imageStore(probes, invocation, probeData);
}