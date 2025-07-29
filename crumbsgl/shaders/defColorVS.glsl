#version 450 core

struct VertexData {
	float position[3];
	float color[3];
};

layout(binding = 0, std430) readonly buffer ssbo1 {
	VertexData data[];
};

out vec3 iColor;

vec3 getPosition(int index) {
    return vec3(
        data[index].position[0],
        data[index].position[1],
        data[index].position[2]
    );
}

vec3 getColor(int index) {
    return vec3(
        data[index].color[0],
        data[index].color[1],
        data[index].color[2]
    );
}

void main() {
    iColor = getColor(gl_VertexID);
    gl_Position = vec4(getPosition(gl_VertexID), 1.0);
}
