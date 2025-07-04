#version 450 core

layout(binding = 0) uniform sampler2D probes;

uniform vec2 probe_pos;
uniform ivec2 num_probs;
uniform int ray_count;
uniform int ray_id;

in vec3 color;
out vec4 frag_color;

void main() {
    vec2 normalized_pos = (probe_pos + vec2(1.))/2.;
    int ray_tex_side = int(sqrt(ray_count));
    ivec2 pixel_position = ivec2(normalized_pos*num_probs.x*ray_tex_side);

    ivec2 probe_id = ivec2( int(pixel_position.x / ray_tex_side), int(pixel_position.y / ray_tex_side) );
    vec2 ray_tex_coords = vec2((ray_id % ray_tex_side) , int(ray_id / ray_tex_side));
    vec2 data_coords = vec2(probe_id)*ray_tex_side + ray_tex_coords;
    data_coords = data_coords/vec2(num_probs.x*ray_tex_side, num_probs.y*ray_tex_side);

    float has_hit = texture(probes, data_coords).a;

    vec4 finalColor = vec4(1.);
    if (has_hit >= 0.001) {
        finalColor = vec4(1., 0., 0., 1.);
    }

    frag_color = finalColor;
}
