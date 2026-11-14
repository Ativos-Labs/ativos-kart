class_name UiKit
extends RefCounted
## Paleta, fontes e funções de desenho compartilhadas pela interface
## (botões brilhantes, faixas inclinadas, ícones vetoriais).

const FONT_TITLE := preload("res://assets/fonts/LilitaOne-Regular.woff2")
const FONT_ITALIC := preload("res://ui/fonts/lilita_italic.tres")
const FONT_BODY := preload("res://assets/fonts/Nunito-ExtraBold.woff2")

# --- Paleta -------------------------------------------------------------------------
const YELLOW := Color("ffd21a")
const YELLOW_LIGHT := Color("fff47e")
const YELLOW_DARK := Color("f2a900")
const ORANGE := Color("ff8a1f")
const INK := Color("262a35")
const INK_SOFT := Color("5b6275")
const NAVY := Color("0f1838")
const NAVY_LIGHT := Color("22305f")
const WHITE_TOP := Color("ffffff")
const WHITE_BOTTOM := Color("d5dce8")
const BORDER := Color("a9b3c6")
const RED := Color("ff3d3d")
const GREEN := Color("3fe05a")
const BLUE := Color("2b62ee")
const SKY := Color("33b5ff")


## Hexágono alongado (pontas em "flecha" dos dois lados).
static func hex_points(rect: Rect2, notch: float) -> PackedVector2Array:
	var p := rect.position
	var s := rect.size
	return PackedVector2Array([
		p + Vector2(notch, 0.0),
		p + Vector2(s.x - notch, 0.0),
		p + Vector2(s.x, s.y * 0.5),
		p + Vector2(s.x - notch, s.y),
		p + Vector2(notch, s.y),
		p + Vector2(0.0, s.y * 0.5),
	])


## Paralelogramo inclinado (faixas de título, linhas de resultado).
static func slant_points(rect: Rect2, slant: float) -> PackedVector2Array:
	var p := rect.position
	var s := rect.size
	return PackedVector2Array([
		p + Vector2(slant, 0.0),
		p + Vector2(s.x, 0.0),
		p + Vector2(s.x - slant, s.y),
		p + Vector2(0.0, s.y),
	])


## Preenche um polígono com degradê vertical (de `top` em y0 para `bottom` em y1).
static func draw_gradient_poly(ci: CanvasItem, pts: PackedVector2Array, top: Color, bottom: Color,
		y0: float, y1: float) -> void:
	var colors := PackedColorArray()
	for p in pts:
		var t := clampf((p.y - y0) / maxf(y1 - y0, 0.001), 0.0, 1.0)
		colors.append(top.lerp(bottom, t))
	ci.draw_polygon(pts, colors)


static func offset_points(pts: PackedVector2Array, offset: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(p + offset)
	return out


static func closed(pts: PackedVector2Array) -> PackedVector2Array:
	var out := pts.duplicate()
	out.append(pts[0])
	return out


## Faixa inclinada com sombra, borda clara e brilho em cima.
static func draw_ribbon(ci: CanvasItem, rect: Rect2, slant: float, color: Color, edge := Color(1, 1, 1, 0.9)) -> void:
	var pts := slant_points(rect, slant)
	ci.draw_colored_polygon(offset_points(pts, Vector2(0, 5)), Color(0, 0, 0, 0.3))
	draw_gradient_poly(ci, pts, color.lightened(0.18), color.darkened(0.12), rect.position.y, rect.end.y)
	var gloss := slant_points(Rect2(rect.position, Vector2(rect.size.x, rect.size.y * 0.45)), slant * 0.45)
	draw_gradient_poly(ci, gloss, Color(1, 1, 1, 0.22), Color(1, 1, 1, 0.04), rect.position.y, rect.position.y + rect.size.y * 0.45)
	ci.draw_polyline(closed(pts), edge, 3.0, true)


## Ícones vetoriais simples para os botões.
static func draw_icon(ci: CanvasItem, kind: String, c: Vector2, r: float, color: Color) -> void:
	match kind:
		"play":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.4, -r * 0.6), c + Vector2(r * 0.65, 0), c + Vector2(-r * 0.4, r * 0.6)]), color)
		"flag":
			ci.draw_line(c + Vector2(-r * 0.55, -r * 0.7), c + Vector2(-r * 0.55, r * 0.75), color, r * 0.16, true)
			var cell := r * 0.27
			for row in 3:
				for col in 4:
					var rect := Rect2(c + Vector2(-r * 0.47 + col * cell, -r * 0.7 + row * cell), Vector2(cell, cell))
					if (row + col) % 2 == 0:
						ci.draw_rect(rect, color)
					else:
						ci.draw_rect(rect, color, false, maxf(1.0, r * 0.06))
		"gamepad":
			var body := Rect2(c + Vector2(-r * 0.78, -r * 0.42), Vector2(r * 1.56, r * 0.84))
			ci.draw_rect(body.grow(-r * 0.05), color)
			ci.draw_circle(c + Vector2(-r * 0.62, r * 0.18), r * 0.36, color)
			ci.draw_circle(c + Vector2(r * 0.62, r * 0.18), r * 0.36, color)
			var bg := Color(1, 1, 1, 0.95)
			ci.draw_rect(Rect2(c + Vector2(-r * 0.55, -r * 0.07), Vector2(r * 0.36, r * 0.13)), bg)
			ci.draw_rect(Rect2(c + Vector2(-r * 0.43, -r * 0.19), Vector2(r * 0.12, r * 0.37)), bg)
			ci.draw_circle(c + Vector2(r * 0.33, -r * 0.08), r * 0.09, bg)
			ci.draw_circle(c + Vector2(r * 0.5, r * 0.08), r * 0.09, bg)
		"exit":
			ci.draw_rect(Rect2(c + Vector2(-r * 0.7, -r * 0.7), Vector2(r * 0.75, r * 1.4)), color, false, r * 0.14)
			ci.draw_line(c + Vector2(-r * 0.15, 0), c + Vector2(r * 0.55, 0), color, r * 0.18, true)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(r * 0.8, 0), c + Vector2(r * 0.4, -r * 0.38), c + Vector2(r * 0.4, r * 0.38)]), color)
		"retry":
			ci.draw_arc(c, r * 0.55, deg_to_rad(-60), deg_to_rad(220), 24, color, r * 0.2, true)
			var tip := c + Vector2.from_angle(deg_to_rad(-60)) * r * 0.55
			ci.draw_colored_polygon(PackedVector2Array([tip + Vector2(r * 0.32, -r * 0.05), tip + Vector2(-r * 0.2, -r * 0.3), tip + Vector2(-r * 0.05, r * 0.28)]), color)
		"home":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r * 0.75), c + Vector2(r * 0.8, 0), c + Vector2(-r * 0.8, 0)]), color)
			ci.draw_rect(Rect2(c + Vector2(-r * 0.55, -r * 0.05), Vector2(r * 1.1, r * 0.75)), color)
			ci.draw_rect(Rect2(c + Vector2(-r * 0.15, r * 0.25), Vector2(r * 0.3, r * 0.45)), Color(1, 1, 1, 0.95))
		"back":
			ci.draw_line(c + Vector2(-r * 0.3, 0), c + Vector2(r * 0.65, 0), color, r * 0.22, true)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.7, 0), c + Vector2(-r * 0.15, -r * 0.5), c + Vector2(-r * 0.15, r * 0.5)]), color)
		"next":
			ci.draw_line(c + Vector2(-r * 0.65, 0), c + Vector2(r * 0.3, 0), color, r * 0.22, true)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(r * 0.7, 0), c + Vector2(r * 0.15, -r * 0.5), c + Vector2(r * 0.15, r * 0.5)]), color)
		"person":
			ci.draw_circle(c + Vector2(0, -r * 0.32), r * 0.34, color)
			ci.draw_colored_polygon(_arc_points(c + Vector2(0, r * 0.75), r * 0.68, PI, TAU, 16), color)
		"kart":
			ci.draw_rect(Rect2(c + Vector2(-r * 0.8, -r * 0.1), Vector2(r * 1.6, r * 0.4)), color)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.3, -r * 0.1), c + Vector2(-r * 0.05, -r * 0.55), c + Vector2(r * 0.35, -r * 0.55), c + Vector2(r * 0.45, -r * 0.1)]), color)
			ci.draw_circle(c + Vector2(-r * 0.5, r * 0.38), r * 0.27, color)
			ci.draw_circle(c + Vector2(r * 0.5, r * 0.38), r * 0.27, color)
		"track":
			# Estrada sinuosa sumindo no horizonte, com a faixa do meio tracejada.
			var pts := PackedVector2Array()
			for i in 17:
				var t := i / 16.0
				pts.append(c + Vector2(sin(t * TAU * 0.85) * r * 0.42 * (1.0 - t * 0.35), lerpf(r * 0.8, -r * 0.8, t)))
			for i in 16:
				var w := lerpf(r * 0.52, r * 0.2, i / 16.0)
				ci.draw_line(pts[i], pts[i + 1], color, w, true)
				ci.draw_circle(pts[i + 1], w * 0.5, color)
			ci.draw_circle(pts[0], r * 0.26, color)
			for i in range(0, 16, 2):
				ci.draw_line(pts[i].lerp(pts[i + 1], 0.15), pts[i].lerp(pts[i + 1], 0.85), Color(1, 1, 1, 0.95), lerpf(r * 0.1, r * 0.05, i / 16.0), true)
		"pause":
			ci.draw_rect(Rect2(c + Vector2(-r * 0.45, -r * 0.55), Vector2(r * 0.3, r * 1.1)), color)
			ci.draw_rect(Rect2(c + Vector2(r * 0.15, -r * 0.55), Vector2(r * 0.3, r * 1.1)), color)
		"clock":
			# Cronômetro: mostrador, botão em cima e ponteiro.
			ci.draw_rect(Rect2(c + Vector2(-r * 0.14, -r * 0.95), Vector2(r * 0.28, r * 0.2)), color)
			ci.draw_arc(c + Vector2(0, r * 0.08), r * 0.68, 0.0, TAU, 28, color, r * 0.18, true)
			ci.draw_line(c + Vector2(0, r * 0.08), c + Vector2(r * 0.3, -r * 0.24), color, r * 0.15, true)
			ci.draw_circle(c + Vector2(0, r * 0.08), r * 0.12, color)
		"people":
			# Dois bonequinhos (multijogador).
			for k in 2:
				var o := c + Vector2((k * 2 - 1) * r * 0.42, 0.0)
				ci.draw_circle(o + Vector2(0, -r * 0.36), r * 0.26, color)
				ci.draw_colored_polygon(_arc_points(o + Vector2(0, r * 0.62), r * 0.48, PI, TAU, 12), color)
		"trophy":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.55, -r * 0.65), c + Vector2(r * 0.55, -r * 0.65), c + Vector2(r * 0.4, r * 0.05), c + Vector2(0, r * 0.25), c + Vector2(-r * 0.4, r * 0.05)]), color)
			ci.draw_rect(Rect2(c + Vector2(-r * 0.1, r * 0.2), Vector2(r * 0.2, r * 0.3)), color)
			ci.draw_rect(Rect2(c + Vector2(-r * 0.4, r * 0.5), Vector2(r * 0.8, r * 0.18)), color)
			ci.draw_arc(c + Vector2(-r * 0.55, -r * 0.35), r * 0.25, PI * 0.5, PI * 1.5, 10, color, r * 0.1, true)
			ci.draw_arc(c + Vector2(r * 0.55, -r * 0.35), r * 0.25, -PI * 0.5, PI * 0.5, 10, color, r * 0.1, true)


static func _arc_points(center: Vector2, radius: float, from: float, to: float, steps: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in steps + 1:
		pts.append(center + Vector2.from_angle(lerpf(from, to, float(i) / steps)) * radius)
	return pts


## Tecla desenhada (para a barra de dicas e a tela de controles). Retorna a largura usada.
static func draw_key(ci: CanvasItem, pos: Vector2, height: float, label: String, font_size: int,
		fill := Color(1, 1, 1), text_color := INK) -> float:
	var font: Font = FONT_BODY
	var text_w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var w := maxf(height, text_w + height * 0.6)
	var rect := Rect2(pos, Vector2(w, height))
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(int(height * 0.5) if w <= height * 1.05 else int(height * 0.32))
	box.border_color = Color(0, 0, 0, 0.25)
	box.border_width_bottom = 3
	box.draw(ci.get_canvas_item(), rect)
	var baseline := pos.y + height * 0.5 + (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5 - 2.0
	ci.draw_string(font, Vector2(pos.x + (w - text_w) * 0.5, baseline), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)
	return w


## Texto com contorno (para títulos sobre o 3D).
static func draw_outlined(ci: CanvasItem, font: Font, pos: Vector2, text: String, size: int,
		color: Color, outline: Color, outline_size: int) -> void:
	ci.draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline_size, outline)
	ci.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
