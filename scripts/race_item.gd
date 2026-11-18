class_name RaceItem
extends RefCounted
## Os itens das caixas: nome, cores, tempo de espera entre usos e o ícone (desenhado por
## código, o mesmo no slot do HUD, na roleta e no contrato da Cessão de crédito).
##
## Poderes de "Caos" (a lógica fica em RaceItems):
## - DESAGIO (o raio): todo mundo encolhe, menos quem usou. Um "−%" gigante aparece no
##   céu e os outros karts diminuem (mais lentos e leves; um kart grande os amassa).
## - JURIDIQUES (a tinta na tela): cobre a visão dos rivais à frente com borrões de
##   tinta cheios de texto miúdo ("Outrossim, data venia, considerando-se…").
## - CESSAO (o fantasma): rouba o item de um rival. O Celerino, de fantasma, assina um
##   contrato no ar e o item muda de dono.
##
## Item de uso imediato (um turbo, por exemplo): marque "auto" em INFO e ele é usado
## assim que a roleta para, sem ficar guardado no slot.

enum Kind { DESAGIO, JURIDIQUES, CESSAO }

const NONE := -1
const COUNT := 3

## name = nome por extenso; short = legenda embaixo do slot; color = cor do item;
## auto = usado na hora; cooldown = segundos em que o computador não usa outro igual
## depois que alguém usou (e o Deságio não sai na roleta).
const INFO := [
	{"name": "Deságio", "short": "DESÁGIO", "color": Color("ffd21a"), "auto": false, "cooldown": 22.0},
	{"name": "Juridiquês", "short": "JURIDIQUÊS", "color": Color("b48cff"), "auto": false, "cooldown": 18.0},
	{"name": "Cessão de crédito", "short": "CESSÃO DE CRÉDITO", "color": Color("9fe8ff"), "auto": false, "cooldown": 8.0},
]

const INK := Color("0f1838")
const BOLT := Color("ffd21a")
const BOLT_LIGHT := Color("fff7b0")
const BOLT_DARK := Color("f29a00")
const BADGE := Color("ff3d3d")
const INK_BLOB := Color("151a33")
const INK_SHEEN := Color("3b4373")
const PAPER := Color("fbf6e4")
const GHOST := Color("f4f9ff")
const GHOST_SHADE := Color("cfe1f5")


static func item_name(kind: int) -> String:
	return INFO[kind].name if kind >= 0 and kind < COUNT else ""


static func short_name(kind: int) -> String:
	return INFO[kind].short if kind >= 0 and kind < COUNT else ""


static func color(kind: int) -> Color:
	return INFO[kind].color if kind >= 0 and kind < COUNT else Color.WHITE


static func is_auto(kind: int) -> bool:
	return kind >= 0 and kind < COUNT and INFO[kind].auto


static func cooldown(kind: int) -> float:
	return INFO[kind].cooldown if kind >= 0 and kind < COUNT else 0.0


# --- Ícones -----------------------------------------------------------------------

## Desenha o ícone do item centrado em `c`, cabendo num círculo de raio `r`.
static func draw_icon(ci: CanvasItem, kind: int, c: Vector2, r: float) -> void:
	match kind:
		Kind.DESAGIO:
			_draw_desagio(ci, c, r)
		Kind.JURIDIQUES:
			_draw_juridiques(ci, c, r)
		Kind.CESSAO:
			_draw_cessao(ci, c, r)


## Raio amarelo com contorno escuro e um selo vermelho "−%".
static func _draw_desagio(ci: CanvasItem, c: Vector2, r: float) -> void:
	var shape := [Vector2(0.02, -0.98), Vector2(0.62, -0.98), Vector2(0.2, -0.2), Vector2(0.56, -0.2),
			Vector2(-0.42, 0.98), Vector2(-0.1, 0.08), Vector2(-0.46, 0.08)]
	var pts := PackedVector2Array()
	var origin := c + Vector2(-0.1, 0.0) * r
	for p: Vector2 in shape:
		pts.append(origin + p * r * 0.92)
	ci.draw_colored_polygon(UiKit.offset_points(pts, Vector2(2.0, 4.0)), Color(0, 0, 0, 0.3))
	ci.draw_polyline(UiKit.closed(pts), INK, maxf(r * 0.1, 3.0), true)
	ci.draw_colored_polygon(pts, BOLT)
	# Brilho no lado de cima/esquerdo de cada pedaço do raio.
	var light := PackedVector2Array([pts[0], pts[1], origin + Vector2(0.44, -0.86) * r * 0.92,
			origin + Vector2(0.08, -0.86) * r * 0.92, origin + Vector2(-0.3, 0.02) * r * 0.92, pts[6]])
	ci.draw_colored_polygon(light, BOLT_LIGHT)
	var dark := PackedVector2Array([pts[3], pts[4], origin + Vector2(0.3, -0.12) * r * 0.92])
	ci.draw_colored_polygon(dark, BOLT_DARK)
	# Selo "−%" embaixo à direita.
	var bc := c + Vector2(0.5, 0.5) * r
	var br := r * 0.44
	ci.draw_circle(bc + Vector2(1.5, 3.0), br, Color(0, 0, 0, 0.3))
	ci.draw_circle(bc, br + maxf(r * 0.06, 2.0), Color.WHITE)
	ci.draw_circle(bc, br, BADGE)
	var font: Font = UiKit.FONT_TITLE
	var fs := int(br * 1.15)
	var text := "−%"
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var base := bc.y + (font.get_ascent(fs) - font.get_descent(fs)) * 0.5
	ci.draw_string(font, Vector2(bc.x - w * 0.5, base), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)


## Borrão de tinta (com gotinhas e um pingo escorrendo) e um "§" no meio.
static func _draw_juridiques(ci: CanvasItem, c: Vector2, r: float) -> void:
	var blob := blob_points(c, r * 0.72, 3.1, 40)
	ci.draw_colored_polygon(UiKit.offset_points(blob, Vector2(2.0, 4.0)), Color(0, 0, 0, 0.3))
	ci.draw_polyline(UiKit.closed(blob), Color.WHITE, maxf(r * 0.07, 2.0), true)
	ci.draw_colored_polygon(blob, INK_BLOB)
	# Pingo escorrendo e gotinhas em volta.
	var drip := Rect2(c + Vector2(0.18, 0.3) * r, Vector2(0.17, 0.5) * r)
	ci.draw_rect(drip, INK_BLOB)
	ci.draw_circle(Vector2(drip.get_center().x, drip.end.y), r * 0.13, INK_BLOB)
	for d: Vector3 in [Vector3(-0.8, -0.55, 0.11), Vector3(0.84, -0.3, 0.08), Vector3(-0.72, 0.62, 0.09), Vector3(0.6, -0.82, 0.07)]:
		ci.draw_circle(c + Vector2(d.x, d.y) * r, d.z * r + 1.5, Color.WHITE)
		ci.draw_circle(c + Vector2(d.x, d.y) * r, d.z * r, INK_BLOB)
	ci.draw_circle(c + Vector2(-0.28, -0.32) * r, r * 0.16, Color(INK_SHEEN, 0.8))
	var font: Font = UiKit.FONT_TITLE
	var fs := int(r * 1.15)
	var text := "§"
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var base := c.y + (font.get_ascent(fs) - font.get_descent(fs)) * 0.5
	ci.draw_string(font, Vector2(c.x - w * 0.5, base), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, PAPER)


## Fantasminha branco segurando um contrato com selo vermelho.
static func _draw_cessao(ci: CanvasItem, c: Vector2, r: float) -> void:
	var body := ghost_points(c + Vector2(-0.14, -0.04) * r, r * 0.78)
	ci.draw_colored_polygon(UiKit.offset_points(body, Vector2(2.0, 4.0)), Color(0, 0, 0, 0.3))
	ci.draw_polyline(UiKit.closed(body), INK, maxf(r * 0.08, 2.5), true)
	ci.draw_colored_polygon(body, GHOST)
	# Sombra azulada do lado direito do corpo.
	ci.draw_circle(c + Vector2(0.18, 0.2) * r, r * 0.22, Color(GHOST_SHADE, 0.6))
	# Olhos e boca de "uuuh".
	var eye := r * 0.1
	for x: float in [-0.38, -0.06]:
		var e := c + Vector2(x, -0.3) * r
		ci.draw_colored_polygon(ellipse_points(e, Vector2(eye, eye * 1.45), 14), INK)
		ci.draw_circle(e + Vector2(-0.3, -0.5) * eye, eye * 0.35, Color.WHITE)
	ci.draw_colored_polygon(ellipse_points(c + Vector2(-0.22, -0.02) * r, Vector2(0.07, 0.1) * r, 12), INK)
	# Contrato: papel inclinado, linhas de texto e o selo.
	var paper := PackedVector2Array()
	var pc := c + Vector2(0.46, 0.4) * r
	var half := Vector2(0.3, 0.38) * r
	var rot := 0.22
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		paper.append(pc + (corner * half).rotated(rot))
	ci.draw_colored_polygon(UiKit.offset_points(paper, Vector2(1.5, 3.0)), Color(0, 0, 0, 0.3))
	ci.draw_polyline(UiKit.closed(paper), INK, maxf(r * 0.06, 2.0), true)
	ci.draw_colored_polygon(paper, PAPER)
	for i in 3:
		var y := -0.55 + i * 0.32
		var a := pc + (Vector2(-0.6, y) * half).rotated(rot)
		var b := pc + (Vector2(0.6 - i * 0.25, y) * half).rotated(rot)
		ci.draw_line(a, b, Color(0.55, 0.58, 0.68), maxf(r * 0.04, 1.5), true)
	ci.draw_circle(pc + (Vector2(0.45, 0.62) * half).rotated(rot), r * 0.11, BADGE)
	# Mãozinha do fantasma segurando o papel.
	ci.draw_circle(pc + (Vector2(-1.0, 0.25) * half).rotated(rot), r * 0.11, INK)
	ci.draw_circle(pc + (Vector2(-1.0, 0.25) * half).rotated(rot), r * 0.11 - maxf(r * 0.04, 1.5), GHOST)


# --- Formas ----------------------------------------------------------------------

## Contorno de mancha (borrão de tinta): círculo com o raio ondulado.
static func blob_points(c: Vector2, r: float, seed_value: float, count := 48) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in count:
		var a := TAU * i / count
		var k := 1.0 + 0.1 * sin(a * 3.0 + seed_value) + 0.07 * sin(a * 5.0 + seed_value * 2.3) \
				+ 0.045 * sin(a * 9.0 + seed_value * 4.1)
		pts.append(c + Vector2(cos(a), sin(a)) * r * k)
	return pts


## Fantasma: cabeça redonda, corpo reto e a barra ondulada embaixo.
static func ghost_points(c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var head := c + Vector2(0.0, -0.18) * r
	var hr := 0.62 * r
	for i in 17:
		var a := PI + PI * i / 16.0
		pts.append(head + Vector2(cos(a), sin(a)) * hr)
	var bottom := c.y + 0.7 * r
	pts.append(Vector2(head.x + hr, bottom))
	for i in 13:
		var t := float(i) / 12.0
		var x := head.x + hr - t * hr * 2.0
		pts.append(Vector2(x, bottom - absf(sin(t * PI * 3.0)) * r * 0.2))
	pts.append(Vector2(head.x - hr, bottom))
	return pts


static func ellipse_points(c: Vector2, radii: Vector2, count := 16) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in count:
		var a := TAU * i / count
		pts.append(c + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	return pts

