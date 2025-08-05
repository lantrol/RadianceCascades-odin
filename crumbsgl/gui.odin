package CrumbsGL

import "core:fmt"
import glm "core:math/linalg/glsl"
import "core:slice"
import "core:strings"
import gl "vendor:OpenGL"
import sdl "vendor:sdl3"

GuiRect :: struct {
	x, y:          i32,
	width, height: i32,
	color:         [4]f32,
}

GuiVertex :: struct {
	position: [3]f32,
	uv:       [2]f32,
	color:    [4]f32,
}

GuiRectData :: [6]GuiRect

GuiText :: struct {
	text: string,
	x, y: i32,
}

GuiWindowContext :: struct {
	x, y:          i32,
	width, height: i32,
	color:         [4]f32,
	alpha:         f32,
	voffset:       i32,
	hidden:        bool,
	moving:        bool,
	rectCount:     i32,
	textCount:     i32,
}

GuiOptions :: struct {
	windowWidth:  i32,
	elemHeight:   i32,
	topBarHeight: i32,
	vpadding:     i32,
	font:         FontData,
	textScale:    f32,
}

@(private = "file")
allGuiWindows: map[string]GuiWindowContext
@(private = "file")
activeWindow: ^GuiWindowContext
@(private = "file")
gGuiOptions := GuiOptions {
	windowWidth  = 300,
	elemHeight   = 40,
	topBarHeight = 25,
	vpadding     = 10,
	font         = {},
	textScale    = 0.5,
}
@(private = "file")
guiRectsArray: [200]GuiRect
@(private = "file")
guiCharQuadArray: [1000]FontQuad
@(private = "file")
guiTextArray: [1000]GuiText

gui_set_font :: proc(font: FontData) {
	gGuiOptions.font = font
}

gui_draw :: proc(rect: GuiRect) {
	meshData: [6]GuiVertex = gui_vertex_from_rect(rect)
	mesh := createMesh(meshData[:])
	renderMesh(mesh, sh_get_default_rect_shader(), mode = gl.TRIANGLES)
	deleteMesh(&mesh)
}

gui_is_pressed :: proc(rect: GuiRect) -> bool {
	if !is_button_just_pressed(.LEFT) do return false
	x, y := get_mouse_position()
	if x > rect.x && x < rect.x + rect.width && y > rect.y && y < rect.y + rect.height {
		return true
	}
	return false
}

gui_in_window :: proc() -> bool {
	x, y := get_mouse_position()
	for key, window in allGuiWindows {
		if x > window.x &&
		   x < window.x + window.width &&
		   y > window.y &&
		   y < window.y + window.height {
			return true
		}
	}
	return false
}

gui_begin_window :: proc(name: string, alpha: f32 = 1.) {
	if name not_in allGuiWindows {
		newWindow := GuiWindowContext {
			x         = 10,
			y         = 10,
			width     = gGuiOptions.windowWidth,
			height    = 0,
			color     = {0.5, 0.5, 0.5, alpha},
			alpha     = alpha,
			voffset   = gGuiOptions.vpadding,
			hidden    = false,
			moving    = false,
			rectCount = 0,
			textCount = 0,
		}
		allGuiWindows[name] = newWindow
	}
	activeWindow = &allGuiWindows[name]

	// Handle window movement
	topBar := GuiRect {
		activeWindow.x + gGuiOptions.topBarHeight,
		activeWindow.y,
		activeWindow.width - gGuiOptions.topBarHeight,
		gGuiOptions.topBarHeight,
		{0, 0, 1, 1},
	}
	if gui_is_pressed(topBar) && !activeWindow.moving {
		activeWindow.moving = true
	} else if activeWindow.moving && is_button_pressed(.LEFT) {
		mouseX, mouseY: i32 = get_mouse_displacement()
		activeWindow.x += mouseX
		activeWindow.y += mouseY
	} else {
		activeWindow.moving = false
	}

	// Hndle window hide
	topBarHide := GuiRect {
		activeWindow.x,
		activeWindow.y,
		gGuiOptions.topBarHeight,
		gGuiOptions.topBarHeight,
		{1, 0, 1, 1},
	}
	if gui_is_pressed(topBarHide) {
		activeWindow.hidden = !activeWindow.hidden
	}
}

gui_end_window :: proc() {
	// Window drawing
	topBarHide := GuiRect {
		activeWindow.x,
		activeWindow.y,
		gGuiOptions.topBarHeight,
		gGuiOptions.topBarHeight,
		{166. / 255., 95. / 255., 194. / 255., activeWindow.alpha},
	}
	gui_draw(topBarHide)

	topBar := GuiRect {
		activeWindow.x + gGuiOptions.topBarHeight,
		activeWindow.y,
		activeWindow.width - gGuiOptions.topBarHeight,
		gGuiOptions.topBarHeight,
		{200. / 255., 144. / 255., 222. / 255., activeWindow.alpha},
	}
	gui_draw(topBar)

	if !activeWindow.hidden {
		windowRect := GuiRect {
			activeWindow.x,
			activeWindow.y + gGuiOptions.topBarHeight,
			activeWindow.width,
			activeWindow.voffset,
			{79. / 255., 51. / 255., 89. / 255., activeWindow.alpha},
		}
		gui_draw(windowRect)

		// Window buttons drawing
		for rect, index in guiRectsArray {
			if i32(index) == activeWindow.rectCount do break
			gui_draw(rect)
		}

		// Window Text drawing
		for text, index in guiTextArray {
			if i32(index) == activeWindow.textCount do break
			font_draw_text(
				gGuiOptions.font,
				text.text,
				{text.x, text.y},
				scale = gGuiOptions.textScale,
			)
		}
	}

	activeWindow.height = gGuiOptions.topBarHeight + activeWindow.voffset
	activeWindow.rectCount = 0
	activeWindow.textCount = 0
	activeWindow.voffset = gGuiOptions.vpadding
}

gui_button :: proc(text: string) -> bool {
	if activeWindow.hidden do return false
	if activeWindow.rectCount == len(guiRectsArray) {
		fmt.println("Error: max rect count reached")
		return false
	}
	if activeWindow.textCount == len(guiTextArray) {
		fmt.println("Error: max text count reached")
		return false
	}

	x: i32 = activeWindow.x + gGuiOptions.vpadding
	y: i32 = activeWindow.y + gGuiOptions.topBarHeight + activeWindow.voffset
	width: i32 = activeWindow.width - 2 * gGuiOptions.vpadding
	height: i32 = gGuiOptions.elemHeight

	// Button rect
	rect := GuiRect {
		x,
		y,
		width,
		height,
		{138. / 255., 85. / 255., 158. / 255., activeWindow.alpha},
	}
	guiRectsArray[activeWindow.rectCount] = rect

	activeWindow.voffset += height + gGuiOptions.vpadding
	activeWindow.rectCount += 1

	// Button text
	bboxWidth, bboxHeight := font_get_text_bbox(gGuiOptions.font, text, gGuiOptions.textScale)
	textPosX: i32 = x + i32((f32(width) - bboxWidth) / 2)
	textPosY: i32 = y + i32((f32(height) - bboxHeight) / 2)

	guiTextArray[activeWindow.textCount] = GuiText{text, textPosX, textPosY}
	activeWindow.textCount += 1

	return gui_is_pressed(rect)
}

gui_text :: proc(args: ..any) {
	if activeWindow.hidden do return
	if activeWindow.textCount == len(guiTextArray) {
		fmt.println("Error: max text count reached")
		return
	}
	text := fmt.tprint(..args)

	x: i32 = activeWindow.x + gGuiOptions.vpadding
	y: i32 = activeWindow.y + gGuiOptions.topBarHeight + activeWindow.voffset
	bboxWidth, bboxHeight := font_get_text_bbox(gGuiOptions.font, text, gGuiOptions.textScale)

	activeWindow.voffset += i32(bboxHeight) + gGuiOptions.vpadding
	guiTextArray[activeWindow.textCount] = GuiText{text, x, y}
	activeWindow.textCount += 1
}

@(private)
gui_vertex_from_rect :: proc(rect: GuiRect) -> [6]GuiVertex {
	windX, windY: i32
	_ = sdl.GetWindowSize(gContext.window.window, &windX, &windY)
	glX: f32 = (f32(rect.x) / f32(windX)) * 2 - 1
	glY: f32 = (1 - f32(rect.y) / f32(windY)) * 2 - 1
	glWidth: f32 = (f32(rect.width) / f32(windX)) * 2
	glHeight: f32 = (f32(rect.height) / f32(windY)) * 2
	data: [6]GuiVertex = {
		{{glX, glY, 0.}, {0, 0}, rect.color},
		{{glX + glWidth, glY, 0.}, {1, 0}, rect.color},
		{{glX, glY - glHeight, 0.}, {0, 1}, rect.color},
		{{glX + glWidth, glY, 0.}, {1, 0}, rect.color},
		{{glX, glY - glHeight, 0.}, {0, 1}, rect.color},
		{{glX + glWidth, glY - glHeight, 0.}, {1, 1}, rect.color},
	}
	return data
}

@(private = "file")
defaultVS: string = `
#version 450 core

struct VertexData {
	float position[3];
	float color[3];
	float uv[2];
};

layout(binding = 0, std430) readonly buffer ssbo1 {
	VertexData data[];
};

out vec2 iUvs;
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
vec2 getUV(int index) {
    return vec2(
        data[index].uv[0],
        data[index].uv[1]
    );
}

void main() {
    iUvs = getUV(gl_VertexID);
    iColor = getColor(gl_VertexID);
    gl_Position = vec4(getPosition(gl_VertexID), 1.0);
}
`


@(private = "file")
defaultFS: string = `
#version 450 core

in vec2 iUvs;
in vec3 iColor;
out vec4 frag_color;

void main() {
	frag_color = vec4(iColor, 1.);
}

`

