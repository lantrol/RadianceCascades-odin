package CrumbsGL

import "core:fmt"
import "core:os"
import gl "vendor:OpenGL"
import sdl "vendor:sdl3"
import img "vendor:stb/image"
import ttf "vendor:stb/truetype"

ATLAS_SIZE :: 1024
FONT_SIZE :: 64.

FontVertex :: struct {
	pos:   [3]f32,
	uvs:   [2]f32,
	color: [4]f32,
}

FontQuad :: [6]FontVertex

FontData :: struct {
	info:         ttf.fontinfo,
	font_size:    f32,
	atlasTex:     Texture,
	packedChars:  []ttf.packedchar,
	alignedQuads: []ttf.aligned_quad,
	firstChar:    i32,
	charRange:    i32,
	ascent:       i32,
	descent:      i32,
	linegap:      i32,
	scale:        f32,
}

font_atlas_from_file :: proc(
	file: string,
	firstChar: i32,
	lastChar: i32,
	font_size: f32 = FONT_SIZE,
) -> (
	fontData: FontData,
	font_ok: bool,
) {
	fontFile, ok := os.read_entire_file_from_filename(file)
	if !ok {
		fmt.println("Error opening font file")
		return {}, false
	}
	defer delete(fontFile)

	if lastChar < firstChar {
		fmt.eprintln("ERROR: Invalid character range")
		os.exit(-1)
	}
	charRange: i32 = lastChar - firstChar + 1
	fontAtlas := make([]u8, ATLAS_SIZE * ATLAS_SIZE)
	packedChars := make([]ttf.packedchar, charRange)
	alignedQuads := make([]ttf.aligned_quad, charRange)
	defer delete(fontAtlas)

	fontCtx: ttf.pack_context
	ttf.PackBegin(&fontCtx, raw_data(fontAtlas), ATLAS_SIZE, ATLAS_SIZE, 0, 1, nil)
	ttf.PackFontRange(
		&fontCtx,
		raw_data(fontFile),
		0,
		f32(font_size),
		i32(' '),
		charRange,
		raw_data(packedChars),
	)
	ttf.PackEnd(&fontCtx)

	for i in 0 ..< charRange {
		unusedX, unusedY: f32
		ttf.GetPackedQuad(
			raw_data(packedChars),
			ATLAS_SIZE,
			ATLAS_SIZE,
			i,
			&unusedX,
			&unusedY,
			&alignedQuads[i],
			false,
		)
	}

	ttf.InitFont(&fontData.info, raw_data(fontFile), 0)
	fontData.atlasTex = createTexture2D(ATLAS_SIZE, ATLAS_SIZE)
	writeTexture2D(fontData.atlasTex, fontAtlas, 1, ATLAS_SIZE, ATLAS_SIZE)
	fontData.packedChars = packedChars
	fontData.alignedQuads = alignedQuads
	fontData.firstChar = firstChar
	fontData.charRange = charRange

	fontData.scale = ttf.ScaleForPixelHeight(&fontData.info, font_size)
	ttf.GetFontVMetrics(&fontData.info, &fontData.ascent, &fontData.descent, &fontData.linegap)

	return fontData, true
}

// font_font_to_png :: proc(fontData: FontData, $fileName: cstring) {
// 	img.write_png(fileName, ATLAS_SIZE, ATLAS_SIZE, 1, raw_data(fontData.atlas), ATLAS_SIZE)
// }

font_get_char_quad :: proc(
	font: FontData,
	char: rune,
	position: [2]f32,
	scale: f32 = 1.,
	color: [4]f32 = {1., 1., 1., 1.},
) -> (
	FontQuad,
	bool,
) {
	if i32(char) < font.firstChar || i32(char) > font.firstChar + font.charRange {
		return {}, false
	}
	charIndex: i32 = i32(char) - font.firstChar
	pixelScaleX: f32 = 2. * scale / f32(gContext.window.width)
	pixelScaleY: f32 = 2. * scale / f32(gContext.window.height)

	_packed := font.packedChars[charIndex]
	_aligned := font.alignedQuads[charIndex]
	quadSize := [2]f32{f32(_packed.x1) - f32(_packed.x0), f32(_packed.y1) - f32(_packed.y0)}

	quad: FontQuad = {
		{
			pos = {
				position[0] + f32(_packed.xoff) * pixelScaleX,
				position[1] - f32(_packed.yoff) * pixelScaleY,
				0.,
			},
			uvs = {f32(_aligned.s0), f32(_aligned.t0)},
			color = {1., 1., 1., 1.},
		},
		{
			pos = {
				position[0] + (f32(quadSize[0]) + f32(_packed.xoff)) * pixelScaleX,
				position[1] - f32(_packed.yoff) * pixelScaleY,
				0.,
			},
			uvs = {f32(_aligned.s1), f32(_aligned.t0)},
			color = {1., 1., 1., 1.},
		},
		{
			pos = {
				position[0] + f32(_packed.xoff) * pixelScaleX,
				position[1] - (f32(quadSize[1]) + f32(_packed.yoff)) * pixelScaleY,
				0.,
			},
			uvs = {f32(_aligned.s0), f32(_aligned.t1)},
			color = {1., 1., 1., 1.},
		},
		{
			pos = {
				position[0] + (f32(quadSize[0]) + f32(_packed.xoff)) * pixelScaleX,
				position[1] - f32(_packed.yoff) * pixelScaleY,
				0.,
			},
			uvs = {f32(_aligned.s1), f32(_aligned.t0)},
			color = {1., 1., 1., 1.},
		},
		{
			pos = {
				position[0] + f32(_packed.xoff) * pixelScaleX,
				position[1] - (f32(quadSize[1]) + f32(_packed.yoff)) * pixelScaleY,
				0.,
			},
			uvs = {f32(_aligned.s0), f32(_aligned.t1)},
			color = {1., 1., 1., 1.},
		},
		{
			pos = {
				position[0] + (f32(quadSize[0]) + f32(_packed.xoff)) * pixelScaleX,
				position[1] - (f32(quadSize[1]) + f32(_packed.yoff)) * pixelScaleY,
				0.,
			},
			uvs = {f32(_aligned.s1), f32(_aligned.t1)},
			color = {1., 1., 1., 1.},
		},
	}

	return quad, true
}

font_draw_text :: proc(
	font: FontData,
	text: string,
	position: [2]i32,
	scale: f32 = 1.,
	color: [4]f32 = {1., 1., 1., 1},
) {
	font := font
	line_jump: i32 = i32(f32(font.ascent - font.descent + font.linegap) * font.scale * scale)

	// The origin is displaced by the font ascent
	// The text position is defined by the top left position
	// But the glyph quad is made from the bottom left corner
	origin := position + {0, i32(f32(font.ascent) * font.scale * scale)}
	offset: f32 = 0

	// screenPos := position_pixel_to_screen(position) // For debug
	// drawPoint({screenPos[0], screenPos[1], 0.}, color = {1., 0., 1.}) // For debug
	for char in text {
		if char == '\n' {
			origin.x = position.x
			origin.y += line_jump
			offset = 0
			continue
		}

		screenPos := position_pixel_to_screen(origin + {i32(offset), 0})
		charQuad, char_ok := font_get_char_quad(font, char, screenPos, scale, color)
		if !char_ok {
			continue
		}
		charMesh := createMesh(charQuad[:])
		defer deleteMesh(&charMesh)
		renderMesh(charMesh, sh_get_default_font_shader(), font.atlasTex)
		offset += font_get_char_advance(font, char, scale)
	}
}

font_get_text_bbox :: proc(
	font: FontData,
	text: string,
	scale: f32 = 1.,
) -> (
	bboxWidth: f32,
	bboxHeight: f32,
) {
	font := font
	line_jump: i32 = i32(f32(font.ascent - font.descent + font.linegap) * font.scale * scale)

	textWidth, tempTextWidth: f32
	textHeight: f32 = f32(line_jump)

	for char in text {
		if char == '\n' {
			tempTextWidth = 0
			textHeight += f32(line_jump)
			continue
		}
		tempTextWidth += font_get_char_advance(font, char, scale)
		if textWidth < tempTextWidth {
			textWidth = tempTextWidth
		}
	}
	return textWidth, textHeight
}

font_get_char_advance :: proc(font: FontData, char: rune, scale: f32 = 1.) -> f32 {
	if i32(char) < font.firstChar || i32(char) > font.firstChar + font.charRange {
		return 0
	}
	charIndex: i32 = i32(char) - font.firstChar
	return font.packedChars[charIndex].xadvance * scale
}

@(private)
position_pixel_to_screen :: proc(position: [2]i32) -> (glPos: [2]f32) {
	windX := gContext.window.width
	windY := gContext.window.height
	glPos.x = (f32(position.x) / f32(windX)) * 2 - 1
	glPos.y = (1 - f32(position.y) / f32(windY)) * 2 - 1
	return glPos
}

@(private = "file")
size_pixel_to_screen :: proc(size: [2]i32) -> (glSize: [2]f32) {
	pixelScaleX: f32 = 2. / f32(gContext.window.width)
	pixelScaleY: f32 = 2. / f32(gContext.window.height)
	glSize.x = f32(size.x) * pixelScaleX
	glSize.y = f32(size.y) * pixelScaleY
	return glSize
}
