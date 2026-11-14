class_name StandingRow
extends Control
## Linha inclinada da classificação: posição (ouro, prata, bronze), cor do piloto,
## nome e tempo (ou pontos, no Grand Prix). A linha do jogador fica amarela; no
## multijogador cada jogador aparece com a etiqueta dele ("J2").

const MEDALS := [Color("ffc21a"), Color("c9d2e0"), Color("e08a4a")]

var place := 1
var racer_name := ""
var time_text := ""
var racer_color := Color.WHITE
var is_player := false
## Etiqueta do jogador ("J2"); vazia = "(você)" na linha do jogador.
var tag := ""
## Ganho ao lado do valor (Grand Prix: "+15").
var gain_text := ""
## Deslocamento horizontal do desenho (animação de entrada).
var slide := 0.0:
	set(value):
		slide = value
		queue_redraw()


func setup(p_place: int, p_name: String, p_time: String, p_color: Color, p_is_player: bool,
		p_tag := "", p_gain := "") -> void:
	place = p_place
	racer_name = p_name
	time_text = p_time
	racer_color = p_color
	is_player = p_is_player
	tag = p_tag
	gain_text = p_gain
	custom_minimum_size = Vector2(540, 34)
	queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2(slide, 0.0))
	var h := size.y
	var rect := Rect2(Vector2(h * 1.05, 0.0), Vector2(size.x - h * 1.05, h))
	var slant := h * 0.35
	var pts := UiKit.slant_points(rect, slant)
	draw_colored_polygon(UiKit.offset_points(pts, Vector2(0, 3)), Color(0, 0, 0, 0.25))
	draw_colored_polygon(pts, Color.WHITE)
	var top := UiKit.YELLOW_LIGHT if is_player else Color.WHITE
	var bottom := UiKit.YELLOW_DARK if is_player else UiKit.WHITE_BOTTOM
	UiKit.draw_gradient_poly(self, UiKit.slant_points(rect.grow(-2.5), slant - 1.0), top, bottom, 0.0, h)

	# Posição num losango (medalha no pódio).
	var c := Vector2(h * 0.5, h * 0.5)
	var r := h * 0.56
	var diamond := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
	var medal: Color = MEDALS[place - 1] if place <= 3 else UiKit.NAVY_LIGHT
	draw_colored_polygon(UiKit.offset_points(diamond, Vector2(0, 3)), Color(0, 0, 0, 0.25))
	draw_colored_polygon(diamond, medal)
	draw_polyline(UiKit.closed(diamond), Color.WHITE, 2.5, true)
	var pf: Font = UiKit.FONT_ITALIC
	var pfs := int(h * 0.62)
	var label := str(place)
	var pw := pf.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, pfs).x
	var pb := c.y + (pf.get_ascent(pfs) - pf.get_descent(pfs)) * 0.5
	var ink := UiKit.INK if place <= 3 else Color.WHITE
	draw_string(pf, Vector2(c.x - pw * 0.5, pb), label, HORIZONTAL_ALIGNMENT_LEFT, -1, pfs, ink)

	# Cor do piloto e nome.
	var dot := Vector2(rect.position.x + slant + 20.0, h * 0.5)
	draw_circle(dot, h * 0.27, Color.WHITE)
	draw_circle(dot, h * 0.2, racer_color)
	var font: Font = UiKit.FONT_BODY
	var fs := int(h * 0.56)
	var baseline := h * 0.5 + (font.get_ascent(fs) - font.get_descent(fs)) * 0.5
	var name_x := dot.x + h * 0.5
	if tag != "":
		# Etiqueta do jogador na cor dele, antes do nome.
		var tag_font: Font = UiKit.FONT_ITALIC
		var tag_fs := int(h * 0.55)
		var tag_w := tag_font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, tag_fs).x + h * 0.5
		var tag_rect := Rect2(Vector2(name_x, h * 0.14), Vector2(tag_w, h * 0.72))
		draw_rect(tag_rect, racer_color)
		var tag_base := h * 0.5 + (tag_font.get_ascent(tag_fs) - tag_font.get_descent(tag_fs)) * 0.5
		UiKit.draw_outlined(self, tag_font, Vector2(name_x + h * 0.25, tag_base), tag, tag_fs, Color.WHITE, UiKit.NAVY, 4)
		name_x += tag_w + h * 0.25
	var name_text := racer_name + ("  (você)" if is_player and tag == "" else "")
	draw_string(font, Vector2(name_x, baseline), name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiKit.INK)

	var tf: Font = UiKit.FONT_ITALIC
	var tfs := int(h * 0.68)
	var tb := h * 0.5 + (tf.get_ascent(tfs) - tf.get_descent(tfs)) * 0.5
	var tw := tf.get_string_size(time_text, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs).x
	var time_x := size.x - slant - 18.0 - tw
	draw_string(tf, Vector2(time_x, tb), time_text, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs, UiKit.INK)
	if gain_text != "":
		var gfs := int(h * 0.55)
		var gw := tf.get_string_size(gain_text, HORIZONTAL_ALIGNMENT_LEFT, -1, gfs).x
		var gb := h * 0.5 + (tf.get_ascent(gfs) - tf.get_descent(gfs)) * 0.5
		var gain_color := Color(0.1, 0.55, 0.2) if gain_text != "+0" else UiKit.INK_SOFT
		draw_string(tf, Vector2(time_x - 22.0 - gw, gb), gain_text, HORIZONTAL_ALIGNMENT_LEFT, -1, gfs, gain_color)
