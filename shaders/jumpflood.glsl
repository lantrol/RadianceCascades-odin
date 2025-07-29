#version 450 core

layout(local_size_x = 1, local_size_y = 1, local_size_z = 1) in;

layout(rgba32f, binding = 0) readonly uniform image2D inSDF;
layout(rgba32f, binding = 1) writeonly uniform image2D outSDF;
uniform vec2 screen_res;
uniform int k;

// Data packing information:
// x: Color value in greyscale
// yz: seed pixel coordinates
// w: check to see if pixel is colored; might remove it later

void main() {
    ivec2 position = ivec2(gl_GlobalInvocationID.xy);
    vec4 currColor = imageLoad(inSDF, position);

    // If K == screen_size -> Is the first iteration, so we set up the initial SDF
    // Initial setup -> If there is color, save its own coords in yz and set w to 1
    if (k == int(screen_res.x)) {
        if (currColor.a != 0.) {
            currColor.yz = vec2(position);
            currColor.a = 1.;
        }
    }

    for (int i = -1; i < 2; i++) {
        for (int j = -1; j < 2; j++) {
            if (i == 0 && j == 0) {
                continue;
            }

            ivec2 currentIndx = ivec2(i * k, j * k);

            if (position + currentIndx != clamp(position + currentIndx, 0, screen_res.x - 1)) {
                continue;
            }

            vec4 q = imageLoad(inSDF, position + currentIndx);
            float offset_dist = length(currentIndx);

            if (currColor.w <= 0.1 && q.w >= 0.9) {
                currColor.w = 1.;
                currColor.x = q.x;
                currColor.yz = q.yz;
                continue;
            }
            else if (currColor.w >= 0.9 && q.w >= 0.9) {
                if (length(currColor.yz - position) > length(q.yz - position)) {
                    currColor.yz = q.yz;
                    currColor.x = q.x;
                }
            }
        }
    }
    imageStore(outSDF, position, currColor);
}
