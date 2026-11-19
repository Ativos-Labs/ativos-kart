class_name RaceItem
extends RefCounted
## Os itens das caixas: nome, cores, tempo de espera entre usos e o ícone (desenhado por
## código, o mesmo no slot do HUD, na roleta e no contrato da Cessão de crédito).
##
## Poderes de "Caos" (ficam guardados no slot até o jogador usar; a lógica fica em
## RaceItems):
## - DESAGIO (o raio): todo mundo encolhe, menos quem usou. Um "deságio" vermelho gigante
##   (com um "−%" pequeno embaixo) aparece no céu e os outros karts diminuem (mais lentos
##   e leves; um kart grande os amassa).
## - JURIDIQUES (a tinta na tela): cobre a visão dos rivais à frente com borrões de
##   tinta cheios de texto miúdo ("Outrossim, data venia, considerando-se…").
## - CESSAO (o fantasma): rouba o item de um rival. O Celerino, de fantasma, assina um
##   contrato no ar e o item muda de dono.
##
## Poderes de "Velocidade" (usados assim que a roleta para, sem ficar no slot):
## - RPV (o cogumelo): turbo curto. Uma guia de pagamento verde vira foguete embaixo do
##   kart — a RPV é paga em uns 60 dias, então é o crédito rápido.
## - ANTECIPACAO (Antecipação Celer, o cogumelo dourado): turbo à vontade por alguns
##   segundos. O Celerino abre uma maleta e cada toque solta um jato de notas atrás do kart.
## - SUPERPREFERENCIA (o Bill Bala): piloto automático que fura a fila. O kart vira um
##   ofício gigante com o carimbo PRIORIDADE e passa por cima de todo mundo (idosos e
##   doentes graves furam a ordem de pagamento).
## - CORRECAO (Correção monetária, as moedas): três moedas com "%" gravado; cada uma
##   aumenta um pouco a velocidade máxima, como as da pista.
##
## Poderes de "Ataque" (ficam no slot; a lógica dos tiros fica em ItemAttacks). Segurando
## o freio na hora de usar, o carimbo e a calculadora vão para trás:
## - CARIMBO (Carimbo INDEFERIDO, o casco verde): um carimbo de borracha sai voando em
##   linha reta e ricocheteia nas muretas; o rival atingido roda e fica com a marca
##   vermelha "INDEFERIDO" estampada.
## - INTIMACAO (o casco vermelho): um envelope oficial com asinhas persegue o kart da
##   frente.
## - PEC (PEC dos Precatórios, o casco azul): uma Constituição gigante voa até o 1º
##   lugar, cai do céu em cima dele e o "parcela": ele avança aos pedacinhos por alguns
##   segundos.
## - IMPUGNACAO (Impugnação dos cálculos, a bomba): uma calculadora que apita em contagem
##   regressiva e estoura numa chuva de números, acertando todo mundo em volta.
##
## Poderes de "Armadilha" (ficam no slot; largados atrás do kart, a lógica fica em
## ItemAttacks):
## - PENDENCIA (Pendência documental, a banana): uma pilha de papel com clipe fica na
##   pista; quem bate escorrega e roda numa chuva de folhas.
## - FILA (Fila do tribunal, a caixa falsa): igual a uma caixa de item, só que com o logo
##   de cabeça para baixo. Quem pega fica parado segurando a senha "AGUARDE SUA VEZ" até
##   ela ser chamada.
##
## Poderes de "Defesa" (ficam no slot):
## - TRANSITO (Trânsito em julgado, a estrela): o kart fica invencível por alguns
##   segundos, com uma aura dourada e um martelo de juiz girando em volta — nada mais
##   muda a decisão. Corre mais, a grama não segura e quem encosta roda.
## - LIMINAR (a super buzina): uma onda que destrói tudo por perto — tiros, armadilhas e
##   até a PEC dos Precatórios — e faz rodar quem está em volta. Aparece um escudo-documento
##   com LIMINAR DEFERIDA.
##
## Item de uso imediato: "auto" em INFO; ele é usado assim que a roleta para.

enum Kind { DESAGIO, JURIDIQUES, CESSAO, RPV, ANTECIPACAO, SUPERPREFERENCIA, CORRECAO,
		CARIMBO, INTIMACAO, PEC, IMPUGNACAO, PENDENCIA, FILA, TRANSITO, LIMINAR }

const NONE := -1
const COUNT := 15
## Texto do Deságio: a palavra em vermelho e, pequeno embaixo dela, o "−%" (na etiqueta do
## ícone e gigante no céu).
const DESAGIO_TEXT := "deságio"
const DESAGIO_MINUS := "−%"

## name = nome por extenso; short = legenda embaixo do slot; color = cor do item;
## auto = usado na hora; cooldown = segundos depois de alguém usar em que o computador
## não usa outro igual; com "single" o item também não sai na roleta nesse tempo nem
## enquanto alguém o tem (só um de cada vez na pista).
const INFO := [
	{"name": "Deságio", "short": "DESÁGIO", "color": Color("ffd21a"), "auto": false, "cooldown": 22.0, "single": true},
	{"name": "Juridiquês", "short": "JURIDIQUÊS", "color": Color("b48cff"), "auto": false, "cooldown": 18.0, "single": false},
	{"name": "Cessão de crédito", "short": "CESSÃO DE CRÉDITO", "color": Color("9fe8ff"), "auto": false, "cooldown": 8.0, "single": false},
	{"name": "RPV", "short": "RPV · CRÉDITO RÁPIDO", "color": Color("5ce08a"), "auto": true, "cooldown": 0.0, "single": false},
	{"name": "Antecipação Celer", "short": "ANTECIPAÇÃO CELER", "color": Color("ffc93a"), "auto": true, "cooldown": 12.0, "single": true},
	{"name": "Superpreferência", "short": "SUPERPREFERÊNCIA", "color": Color("ff6259"), "auto": true, "cooldown": 18.0, "single": true},
	{"name": "Correção monetária", "short": "CORREÇÃO MONETÁRIA", "color": Color("ffe066"), "auto": true, "cooldown": 0.0, "single": false},
	{"name": "Carimbo INDEFERIDO", "short": "CARIMBO INDEFERIDO", "color": Color("ff5a4f"), "auto": false, "cooldown": 3.0, "single": false},
	{"name": "Intimação", "short": "INTIMAÇÃO", "color": Color("f2c98a"), "auto": false, "cooldown": 5.0, "single": false},
	{"name": "PEC dos Precatórios", "short": "PEC DOS PRECATÓRIOS", "color": Color("5d95ff"), "auto": false, "cooldown": 30.0, "single": true},
	{"name": "Impugnação dos cálculos", "short": "IMPUGNAÇÃO DOS CÁLCULOS", "color": Color("ff9a3c"), "auto": false, "cooldown": 6.0, "single": false},
	{"name": "Pendência documental", "short": "PENDÊNCIA DOCUMENTAL", "color": Color("f5e3a8"), "auto": false, "cooldown": 3.0, "single": false},
	{"name": "Fila do tribunal", "short": "FILA DO TRIBUNAL", "color": Color("7fd6ff"), "auto": false, "cooldown": 6.0, "single": false},
	{"name": "Trânsito em julgado", "short": "TRÂNSITO EM JULGADO", "color": Color("ffd84a"), "auto": false, "cooldown": 14.0, "single": false},
	{"name": "Liminar", "short": "LIMINAR", "color": Color("4fd98a"), "auto": false, "cooldown": 8.0, "single": false},
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
const GUIA := Color("5ccf86")
const GUIA_LIGHT := Color("c9f2d4")
const GUIA_DARK := Color("1d7a46")
const FLAME := Color("ff8a1f")
const FLAME_CORE := Color("ffe45c")
const GOLD := Color("ffc93a")
const GOLD_LIGHT := Color("fff1a8")
const GOLD_DARK := Color("c98a12")
const NOTE := Color("7cc98c")
const NOTE_DARK := Color("2f7d47")
const STAMP := Color("e0262e")
const UP_GREEN := Color("2fbf5b")
const WOOD := Color("b9773f")
const WOOD_DARK := Color("7a4520")
const LACQUER := Color("9c1c22")
const LACQUER_LIGHT := Color("e86a5c")
const ENVELOPE := Color("ecd6a8")
const ENVELOPE_DARK := Color("c4a670")
const WAX := Color("c41c22")
const WING := Color("ffffff")
const WING_SHADE := Color("d6e4f6")
const WING_LINE := Color("6e88b0")
const CF_BLUE := Color("1d3a8a")
const CF_BLUE_LIGHT := Color("3a63c4")
const CF_GOLD := Color("e8c05c")
const PAGES := Color("f6f0de")
const CALC := Color("3a404e")
const CALC_LIGHT := Color("5a6274")
const CALC_LCD := Color("aabf96")
const CALC_KEY := Color("e2e6ee")
const CALC_ORANGE := Color("ff8c1e")
const CLIP := Color("cfd8e4")
const CLIP_DARK := Color("6d7b90")
const GLASS := Color("9fe2ff")
const GLASS_DARK := Color("4fa8e0")
const TICKET := Color("fffdf4")
const GAVEL := Color("8a4b22")
const GAVEL_DARK := Color("4f2810")
const GAVEL_BAND := Color("ffd24a")
const AURA := Color("ffe680")
const LIMINAR_GREEN := Color("1f9d55")
const LIMINAR_LIGHT := Color("7ef0a8")
## O logo da caixa de item (a Fila do tribunal mostra ele de cabeça para baixo).
const LOGO := preload("res://assets/logos/ativos_icone.png")


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


static func is_single(kind: int) -> bool:
	return kind >= 0 and kind < COUNT and INFO[kind].single


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
		Kind.RPV:
			_draw_rpv(ci, c, r)
		Kind.ANTECIPACAO:
			_draw_antecipacao(ci, c, r)
		Kind.SUPERPREFERENCIA:
			_draw_superpreferencia(ci, c, r)
		Kind.CORRECAO:
			_draw_correcao(ci, c, r)
		Kind.CARIMBO:
			_draw_carimbo(ci, c, r)
		Kind.INTIMACAO:
			_draw_intimacao(ci, c, r)
		Kind.PEC:
			_draw_pec(ci, c, r)
		Kind.IMPUGNACAO:
			_draw_impugnacao(ci, c, r)
		Kind.PENDENCIA:
			_draw_pendencia(ci, c, r)
		Kind.FILA:
			_draw_fila(ci, c, r)
		Kind.TRANSITO:
			_draw_transito(ci, c, r)
		Kind.LIMINAR:
			_draw_liminar(ci, c, r)


## Raio amarelo com contorno escuro e uma etiqueta "deságio" (vermelho) com "−%" embaixo.
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
	# Etiqueta branca com "deságio" em vermelho e, numa abinha embaixo, um "−%" pequeno (a
	# fonte encolhe para caber).
	var font: Font = UiKit.FONT_TITLE
	var fs := maxi(int(r * 0.46), 6)
	var w := font.get_string_size(DESAGIO_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	if w > r * 1.5:
		fs = maxi(int(fs * r * 1.5 / w), 6)
		w = font.get_string_size(DESAGIO_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var small := maxi(int(fs * 0.62), 5)
	var sw := font.get_string_size(DESAGIO_MINUS, HORIZONTAL_ALIGNMENT_LEFT, -1, small).x
	var half := Vector2(w * 0.5 + fs * 0.4, fs * 0.58)
	var tab_half := Vector2(sw * 0.5 + small * 0.5, small * 0.58)
	var bc := c + Vector2(0.04, 0.48) * r
	var tc := bc + Vector2(0.0, half.y + tab_half.y * 0.5)
	var rim := maxf(r * 0.05, 1.5)
	var shadow := Color(0, 0, 0, 0.3)
	_pill(ci, bc + Vector2(1.5, 3.0), half, shadow)
	_pill(ci, tc + Vector2(1.5, 3.0), tab_half, shadow)
	for pass_i in 2:
		var grow := Vector2(rim, rim) if pass_i == 0 else Vector2.ZERO
		var col := INK if pass_i == 0 else Color.WHITE
		_pill(ci, bc, half + grow, col)
		_pill(ci, tc, tab_half + grow, col)
	_center_text(ci, font, bc, DESAGIO_TEXT, fs, w, BADGE)
	_center_text(ci, font, tc, DESAGIO_MINUS, small, sw, BADGE)


## Escreve `text` (largura `w`) centrado em `c`.
static func _center_text(ci: CanvasItem, font: Font, c: Vector2, text: String, fs: int, w: float, color: Color) -> void:
	var base := c.y + (font.get_ascent(fs) - font.get_descent(fs)) * 0.5
	ci.draw_string(font, Vector2(c.x - w * 0.5, base), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)


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


## Foguete de papel verde (a guia da RPV enrolada) subindo na diagonal, com "RPV"
## escrito no corpo, aletas e o fogo saindo de trás.
static func _draw_rpv(ci: CanvasItem, c: Vector2, r: float) -> void:
	var axis := Vector2(1.0, -1.0).normalized()
	var side := Vector2(axis.y, -axis.x)
	# Espaço do foguete: x ao longo dele (para o bico), y para o lado; em unidades de r.
	var at := Transform2D(axis * r, side * r, c + Vector2(-0.04, 0.04) * r)
	# Fogo atrás (gota laranja com miolo amarelo).
	var flame := PackedVector2Array()
	var core := PackedVector2Array()
	for i in 13:
		var a := PI * 0.5 + PI * i / 12.0
		var k := 1.0 - 0.18 * absf(sin(a * 3.0))
		flame.append(at * Vector2(-0.52 + cos(a) * 0.5 * k, sin(a) * 0.24))
		core.append(at * Vector2(-0.5 + cos(a) * 0.3 * k, sin(a) * 0.13))
	ci.draw_colored_polygon(flame, FLAME)
	ci.draw_colored_polygon(core, FLAME_CORE)
	# Aletas (atrás) e corpo com o bico.
	var fin_a := PackedVector2Array([at * Vector2(-0.3, 0.2), at * Vector2(-0.62, 0.48), at * Vector2(-0.6, 0.2), at * Vector2(-0.5, 0.2)])
	var fin_b := PackedVector2Array([at * Vector2(-0.3, -0.2), at * Vector2(-0.62, -0.48), at * Vector2(-0.6, -0.2), at * Vector2(-0.5, -0.2)])
	var body := PackedVector2Array([at * Vector2(-0.5, 0.25), at * Vector2(0.38, 0.25), at * Vector2(0.58, 0.17),
			at * Vector2(0.78, 0.0), at * Vector2(0.58, -0.17), at * Vector2(0.38, -0.25), at * Vector2(-0.5, -0.25)])
	for poly: PackedVector2Array in [fin_a, fin_b, body]:
		ci.draw_colored_polygon(UiKit.offset_points(poly, Vector2(2.0, 4.0)), Color(0, 0, 0, 0.3))
	var line := maxf(r * 0.08, 2.5)
	for poly: PackedVector2Array in [fin_a, fin_b]:
		ci.draw_polyline(UiKit.closed(poly), INK, line, true)
		ci.draw_colored_polygon(poly, GUIA_DARK)
	ci.draw_polyline(UiKit.closed(body), INK, line, true)
	ci.draw_colored_polygon(body, GUIA)
	# Faixa clara de papel (brilho) e a faixa escura da guia perto da traseira.
	ci.draw_colored_polygon(PackedVector2Array([at * Vector2(-0.46, -0.21), at * Vector2(0.4, -0.21), at * Vector2(0.5, -0.12),
			at * Vector2(-0.46, -0.12)]), GUIA_LIGHT)
	ci.draw_colored_polygon(PackedVector2Array([at * Vector2(-0.42, 0.25), at * Vector2(-0.3, 0.25), at * Vector2(-0.3, -0.25),
			at * Vector2(-0.42, -0.25)]), GUIA_DARK)
	# "RPV" ao longo do corpo.
	var font: Font = UiKit.FONT_TITLE
	var fs := int(r * 0.42)
	var text := "RPV"
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	ci.draw_set_transform(at * Vector2(0.06, 0.04), axis.angle(), Vector2.ONE)
	ci.draw_string_outline(font, Vector2(-w * 0.5, fs * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
			maxi(int(r * 0.08), 2), GUIA_DARK)
	ci.draw_string(font, Vector2(-w * 0.5, fs * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Maleta dourada da Celer, entreaberta, com notas saindo e brilhos.
static func _draw_antecipacao(ci: CanvasItem, c: Vector2, r: float) -> void:
	var body := Rect2(c + Vector2(-0.8, -0.18) * r, Vector2(1.6, 0.98) * r)
	var line := maxf(r * 0.08, 2.5)
	# Notas saindo pela tampa (atrás da maleta).
	for n: Vector3 in [Vector3(-0.42, -0.42, -0.35), Vector3(0.05, -0.56, 0.12), Vector3(0.45, -0.4, 0.42)]:
		var nc := c + Vector2(n.x, n.y) * r
		var half := Vector2(0.34, 0.17) * r
		var pts := PackedVector2Array()
		for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			pts.append(nc + (corner * half).rotated(n.z))
		ci.draw_polyline(UiKit.closed(pts), NOTE_DARK, maxf(r * 0.05, 2.0), true)
		ci.draw_colored_polygon(pts, NOTE)
		ci.draw_circle(nc, r * 0.08, Color(1, 1, 1, 0.7))
	# Alça.
	var handle_c := Vector2(c.x, body.position.y)
	ci.draw_arc(handle_c, r * 0.24, PI, TAU, 16, INK, r * 0.16, true)
	ci.draw_arc(handle_c, r * 0.24, PI, TAU, 16, GOLD_DARK, r * 0.08, true)
	# Corpo: sombra, contorno, dourado e a faixa escura de baixo.
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(int(r * 0.18))
	style.bg_color = Color(0, 0, 0, 0.3)
	ci.draw_style_box(style, Rect2(body.position + Vector2(2.0, 4.0), body.size))
	style.bg_color = GOLD
	style.border_color = INK
	style.set_border_width_all(int(line))
	ci.draw_style_box(style, body)
	ci.draw_rect(Rect2(body.position + Vector2(line, body.size.y * 0.62), Vector2(body.size.x - line * 2.0, body.size.y * 0.38 - line - r * 0.1)), GOLD_DARK)
	ci.draw_rect(Rect2(body.position + Vector2(line + r * 0.06, line + r * 0.04), Vector2(body.size.x * 0.55, r * 0.12)), GOLD_LIGHT)
	# Tampa (linha) e os dois fechos abertos.
	ci.draw_line(Vector2(body.position.x + line, body.position.y + body.size.y * 0.3), Vector2(body.end.x - line, body.position.y + body.size.y * 0.3), INK, maxf(r * 0.05, 1.5), true)
	for x: float in [-0.48, 0.48]:
		var lc := Vector2(c.x + x * r, body.position.y + body.size.y * 0.3)
		ci.draw_rect(Rect2(lc - Vector2(0.1, 0.08) * r, Vector2(0.2, 0.16) * r), INK)
		ci.draw_rect(Rect2(lc - Vector2(0.06, 0.04) * r, Vector2(0.12, 0.08) * r), GOLD_LIGHT)
	# Selo "C" da Celer no meio.
	var sc := c + Vector2(0.0, 0.4) * r
	ci.draw_circle(sc, r * 0.22, INK)
	ci.draw_circle(sc, r * 0.17, GOLD_LIGHT)
	var font: Font = UiKit.FONT_TITLE
	var fs := int(r * 0.32)
	var w := font.get_string_size("C", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	ci.draw_string(font, Vector2(sc.x - w * 0.5, sc.y + (font.get_ascent(fs) - font.get_descent(fs)) * 0.5), "C",
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, GOLD_DARK)
	# Brilhos.
	_sparkle(ci, c + Vector2(-0.82, -0.66) * r, r * 0.16)
	_sparkle(ci, c + Vector2(0.86, -0.78) * r, r * 0.12)


## Ofício (folha com linhas de texto) inclinado, o carimbo vermelho PRIORIDADE e riscos
## de velocidade.
static func _draw_superpreferencia(ci: CanvasItem, c: Vector2, r: float) -> void:
	var rot := -0.16
	var pc := c + Vector2(0.08, 0.02) * r
	var half := Vector2(0.6, 0.8) * r
	var sheet := PackedVector2Array()
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		sheet.append(pc + (corner * half).rotated(rot))
	# Riscos de velocidade à esquerda.
	for i in 3:
		var y := (-0.4 + i * 0.4) * r
		ci.draw_line(c + Vector2(-0.98, y), c + Vector2(-0.68, y + 0.05 * r), Color(1, 1, 1, 0.85), maxf(r * 0.07, 2.0), true)
	ci.draw_colored_polygon(UiKit.offset_points(sheet, Vector2(2.0, 4.0)), Color(0, 0, 0, 0.3))
	ci.draw_polyline(UiKit.closed(sheet), INK, maxf(r * 0.08, 2.5), true)
	ci.draw_colored_polygon(sheet, PAPER)
	# Cabeçalho e linhas.
	var at := Transform2D(rot, half, 0.0, pc)
	ci.draw_line(at * Vector2(-0.7, -0.74), at * Vector2(0.2, -0.74), INK, maxf(r * 0.09, 2.0), true)
	for i in 6:
		var y := -0.48 + i * 0.22
		var x_end := 0.7 - 0.25 * float((i * 7) % 3) / 2.0
		ci.draw_line(at * Vector2(-0.7, y), at * Vector2(x_end, y), Color(0.55, 0.58, 0.68), maxf(r * 0.045, 1.5), true)
	# Carimbo: retângulo vermelho torto com PRIORIDADE.
	var sr := -0.42
	var scc := pc + Vector2(-0.02, 0.18) * r
	var sh := Vector2(0.72, 0.24) * r
	var box := PackedVector2Array()
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		box.append(scc + (corner * sh).rotated(sr))
	ci.draw_colored_polygon(box, Color(PAPER, 0.85))
	ci.draw_polyline(UiKit.closed(box), STAMP, maxf(r * 0.07, 2.0), true)
	var font: Font = UiKit.FONT_TITLE
	var fs := int(r * 0.25)
	var text := "PRIORIDADE"
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var k := minf(1.0, sh.x * 1.8 / maxf(w, 1.0))
	ci.draw_set_transform(scc, sr, Vector2(k, 1.0))
	ci.draw_string(font, Vector2(-w * 0.5, fs * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, STAMP)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Moeda dourada com "%" gravado e um selo verde "+" (a correção sobe o valor).
static func _draw_correcao(ci: CanvasItem, c: Vector2, r: float) -> void:
	var cc := c + Vector2(-0.08, -0.06) * r
	var cr := r * 0.78
	ci.draw_circle(cc + Vector2(2.0, 4.0), cr, Color(0, 0, 0, 0.3))
	ci.draw_circle(cc, cr, INK)
	ci.draw_circle(cc, cr - maxf(r * 0.08, 2.5), GOLD_DARK)
	ci.draw_circle(cc, cr * 0.8, GOLD)
	ci.draw_circle(cc + Vector2(-0.24, -0.26) * cr, cr * 0.36, Color(GOLD_LIGHT, 0.5))
	# "%" gravado: anéis e a barra, escuros com um fio claro embaixo.
	var lw := maxf(cr * 0.13, 2.0)
	for pass_i in 2:
		var off := Vector2(0.0, lw * 0.35) if pass_i == 0 else Vector2.ZERO
		var col := GOLD_LIGHT if pass_i == 0 else Color("8a5a06")
		ci.draw_arc(cc + Vector2(-0.27, -0.26) * cr + off, cr * 0.15, 0.0, TAU, 20, col, lw, true)
		ci.draw_arc(cc + Vector2(0.27, 0.26) * cr + off, cr * 0.15, 0.0, TAU, 20, col, lw, true)
		ci.draw_line(cc + Vector2(-0.32, 0.48) * cr + off, cc + Vector2(0.32, -0.48) * cr + off, col, lw, true)
	# Selo verde "+".
	var bc := c + Vector2(0.52, 0.52) * r
	var br := r * 0.34
	ci.draw_circle(bc + Vector2(1.5, 3.0), br, Color(0, 0, 0, 0.3))
	ci.draw_circle(bc, br + maxf(r * 0.06, 2.0), Color.WHITE)
	ci.draw_circle(bc, br, UP_GREEN)
	var arm := br * 0.55
	var t := maxf(br * 0.3, 2.0)
	ci.draw_line(bc - Vector2(arm, 0.0), bc + Vector2(arm, 0.0), Color.WHITE, t, true)
	ci.draw_line(bc - Vector2(0.0, arm), bc + Vector2(0.0, arm), Color.WHITE, t, true)


## Carimbo de borracha (cabo vermelho, base de madeira, borracha) inclinado, com riscos
## de velocidade, e embaixo a marca "INDEFERIDO" que ele deixa.
static func _draw_carimbo(ci: CanvasItem, c: Vector2, r: float) -> void:
	var line := maxf(r * 0.08, 2.5)
	# A marca: papel claro torto com o "INDEFERIDO" vermelho.
	var sr := -0.18
	var mc := c + Vector2(0.08, 0.56) * r
	var mh := Vector2(0.84, 0.27) * r
	var mark := PackedVector2Array()
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		mark.append(mc + (corner * mh).rotated(sr))
	ci.draw_colored_polygon(UiKit.offset_points(mark, Vector2(2.0, 4.0)), Color(0, 0, 0, 0.3))
	ci.draw_colored_polygon(mark, PAPER)
	var inner := PackedVector2Array()
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		inner.append(mc + (corner * (mh - Vector2(0.08, 0.07) * r)).rotated(sr))
	ci.draw_polyline(UiKit.closed(inner), STAMP, maxf(r * 0.05, 1.5), true)
	var font: Font = UiKit.FONT_TITLE
	var fs := int(r * 0.27)
	var text := "INDEFERIDO"
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var k := minf(1.0, mh.x * 1.7 / maxf(w, 1.0))
	ci.draw_set_transform(mc, sr, Vector2(k, 1.0))
	ci.draw_string(font, Vector2(-w * 0.5, fs * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, STAMP)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Riscos de velocidade à esquerda do carimbo.
	for i in 3:
		var y := (-0.62 + i * 0.26) * r
		ci.draw_line(c + Vector2(-0.98, y), c + Vector2(-0.7, y + 0.02 * r), Color(1, 1, 1, 0.85), maxf(r * 0.07, 2.0), true)
	# O carimbo, girado (espaço próprio em unidades de r).
	var at := Transform2D(0.3, Vector2(r, r), 0.0, c + Vector2(0.04, -0.3) * r)
	var base := _quad(at, Vector2(-0.56, -0.02), Vector2(0.56, 0.24))
	var rubber := _quad(at, Vector2(-0.5, 0.24), Vector2(0.5, 0.36))
	var neck := _quad(at, Vector2(-0.12, -0.42), Vector2(0.12, -0.02))
	for poly: PackedVector2Array in [base, rubber, neck]:
		ci.draw_colored_polygon(UiKit.offset_points(poly, Vector2(2.0, 4.0)), Color(0, 0, 0, 0.3))
	ci.draw_polyline(UiKit.closed(rubber), INK, line, true)
	ci.draw_colored_polygon(rubber, STAMP)
	ci.draw_polyline(UiKit.closed(base), INK, line, true)
	ci.draw_colored_polygon(base, WOOD)
	ci.draw_colored_polygon(_quad(at, Vector2(-0.5, 0.13), Vector2(0.5, 0.2)), WOOD_DARK)
	ci.draw_colored_polygon(_quad(at, Vector2(-0.42, 0.03), Vector2(0.2, 0.08)), Color(1, 1, 1, 0.35))
	ci.draw_polyline(UiKit.closed(neck), INK, line, true)
	ci.draw_colored_polygon(neck, WOOD_DARK)
	var knob := at * Vector2(0.0, -0.6)
	ci.draw_circle(knob + Vector2(2.0, 4.0), r * 0.27, Color(0, 0, 0, 0.3))
	ci.draw_circle(knob, r * 0.27 + line * 0.5, INK)
	ci.draw_circle(knob, r * 0.27 - line * 0.5, LACQUER)
	ci.draw_circle(knob + Vector2(-0.08, -0.09) * r, r * 0.09, LACQUER_LIGHT)


## Envelope oficial (aba em V e lacre vermelho) com duas asinhas batendo.
static func _draw_intimacao(ci: CanvasItem, c: Vector2, r: float) -> void:
	var line := maxf(r * 0.08, 2.5)
	var ec := c + Vector2(0.0, 0.12) * r
	_draw_wing(ci, ec + Vector2(-0.5, -0.18) * r, -1.0, r * 0.62)
	_draw_wing(ci, ec + Vector2(0.5, -0.18) * r, 1.0, r * 0.62)
	var body := Rect2(ec - Vector2(0.62, 0.42) * r, Vector2(1.24, 0.84) * r)
	var pts := PackedVector2Array([body.position, Vector2(body.end.x, body.position.y), body.end, Vector2(body.position.x, body.end.y)])
	ci.draw_colored_polygon(UiKit.offset_points(pts, Vector2(2.0, 4.0)), Color(0, 0, 0, 0.3))
	ci.draw_polyline(UiKit.closed(pts), INK, line, true)
	ci.draw_colored_polygon(pts, ENVELOPE)
	# Dobras de baixo e a aba de cima.
	var tip := ec + Vector2(0.0, 0.1) * r
	ci.draw_line(Vector2(body.position.x, body.end.y), ec + Vector2(0.0, -0.02) * r, ENVELOPE_DARK, maxf(r * 0.04, 1.5), true)
	ci.draw_line(body.end, ec + Vector2(0.0, -0.02) * r, ENVELOPE_DARK, maxf(r * 0.04, 1.5), true)
	var flap := PackedVector2Array([body.position, Vector2(body.end.x, body.position.y), tip])
	ci.draw_colored_polygon(flap, ENVELOPE.lightened(0.25))
	ci.draw_polyline(flap, INK, maxf(r * 0.05, 1.5), true)
	# Lacre.
	var seal := blob_points(tip, r * 0.17, 1.7, 20)
	ci.draw_colored_polygon(UiKit.offset_points(seal, Vector2(1.0, 2.0)), Color(0, 0, 0, 0.3))
	ci.draw_colored_polygon(seal, WAX)
	ci.draw_circle(tip + Vector2(-0.05, -0.05) * r, r * 0.05, Color(1, 0.6, 0.6, 0.8))


## Constituição gigante (capa azul com letras douradas e as páginas aparecendo), com
## asinhas, e o selo vermelho "1º" (ela vai no primeiro lugar).
static func _draw_pec(ci: CanvasItem, c: Vector2, r: float) -> void:
	var line := maxf(r * 0.08, 2.5)
	var at := Transform2D(-0.12, Vector2(r, r), 0.0, c + Vector2(-0.06, -0.04) * r)
	_draw_wing(ci, at * Vector2(-0.5, -0.3), -1.0, r * 0.55)
	_draw_wing(ci, at * Vector2(0.52, -0.3), 1.0, r * 0.55)
	# Páginas (atrás, à direita e embaixo) e a capa.
	var pages := _quad(at, Vector2(-0.46, -0.62), Vector2(0.58, 0.74))
	var cover := _quad(at, Vector2(-0.54, -0.7), Vector2(0.48, 0.64))
	ci.draw_colored_polygon(UiKit.offset_points(pages, Vector2(2.0, 4.0)), Color(0, 0, 0, 0.3))
	ci.draw_polyline(UiKit.closed(pages), INK, line, true)
	ci.draw_colored_polygon(pages, PAGES)
	for i in 3:
		var y := 0.66 + i * 0.03
		ci.draw_line(at * Vector2(-0.4, y), at * Vector2(0.52, y), Color(0.75, 0.7, 0.6), maxf(r * 0.02, 1.0), true)
	ci.draw_polyline(UiKit.closed(cover), INK, line, true)
	ci.draw_colored_polygon(cover, CF_BLUE)
	ci.draw_colored_polygon(_quad(at, Vector2(-0.54, -0.7), Vector2(-0.42, 0.64)), CF_BLUE_LIGHT)
	ci.draw_polyline(UiKit.closed(_quad(at, Vector2(-0.36, -0.58), Vector2(0.38, 0.52))), CF_GOLD, maxf(r * 0.035, 1.2), true)
	# Título (barrinhas douradas) e a estrela.
	ci.draw_line(at * Vector2(-0.24, -0.4), at * Vector2(0.26, -0.4), CF_GOLD, maxf(r * 0.09, 2.0), true)
	ci.draw_line(at * Vector2(-0.16, -0.24), at * Vector2(0.18, -0.24), CF_GOLD, maxf(r * 0.05, 1.5), true)
	var star := PackedVector2Array()
	for i in 10:
		var a := -PI * 0.5 + PI * i / 5.0
		star.append(at * (Vector2(0.01, 0.12) + Vector2(cos(a), sin(a)) * (0.2 if i % 2 == 0 else 0.085)))
	ci.draw_colored_polygon(star, CF_GOLD)
	# Selo "1º".
	var bc := c + Vector2(0.54, 0.54) * r
	var br := r * 0.34
	ci.draw_circle(bc + Vector2(1.5, 3.0), br, Color(0, 0, 0, 0.3))
	ci.draw_circle(bc, br + maxf(r * 0.06, 2.0), Color.WHITE)
	ci.draw_circle(bc, br, BADGE)
	var font: Font = UiKit.FONT_TITLE
	var fs := int(br * 1.1)
	var text := "1º"
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var base := bc.y + (font.get_ascent(fs) - font.get_descent(fs)) * 0.5
	ci.draw_string(font, Vector2(bc.x - w * 0.5, base), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)


## Calculadora com o visor em "3" (contagem regressiva), teclas e o apito saindo.
static func _draw_impugnacao(ci: CanvasItem, c: Vector2, r: float) -> void:
	var line := maxf(r * 0.08, 2.5)
	var at := Transform2D(-0.14, Vector2(r, r), 0.0, c + Vector2(-0.1, 0.06) * r)
	var body := PackedVector2Array()
	var half := Vector2(0.5, 0.74)
	var rad := 0.14
	for q in 4:
		var corner := Vector2(1 if q == 0 or q == 3 else -1, 1 if q < 2 else -1)
		var center := Vector2(corner.x * (half.x - rad), corner.y * (half.y - rad))
		for i in 6:
			var a := q * PI * 0.5 + PI * 0.5 * i / 5.0
			body.append(at * (center + Vector2(cos(a), sin(a)) * rad))
	ci.draw_colored_polygon(UiKit.offset_points(body, Vector2(2.0, 4.0)), Color(0, 0, 0, 0.3))
	ci.draw_polyline(UiKit.closed(body), INK, line, true)
	ci.draw_colored_polygon(body, CALC)
	ci.draw_colored_polygon(_quad(at, Vector2(-0.42, -0.66), Vector2(0.42, -0.6)), CALC_LIGHT)
	# Visor com o "3".
	var lcd := _quad(at, Vector2(-0.38, -0.56), Vector2(0.38, -0.2))
	ci.draw_colored_polygon(lcd, CALC_LCD)
	var font: Font = UiKit.FONT_TITLE
	var fs := int(r * 0.34)
	var w := font.get_string_size("3", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	ci.draw_set_transform(at * Vector2(0.24, -0.38), -0.14, Vector2.ONE)
	ci.draw_string(font, Vector2(-w * 0.5, fs * 0.36), "3", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("26301f"))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Teclas (3 x 3) e o "=" laranja.
	for row in 3:
		for col in 3:
			var p := Vector2(-0.36 + col * 0.25, -0.1 + row * 0.2)
			var color := BADGE if row == 0 and col == 0 else CALC_KEY
			ci.draw_colored_polygon(_quad(at, p, p + Vector2(0.19, 0.14)), color)
	ci.draw_colored_polygon(_quad(at, Vector2(-0.36, 0.5), Vector2(0.33, 0.62)), CALC_ORANGE)
	# Apito: dois arcos saindo do canto de cima.
	var bc := c + Vector2(0.56, -0.62) * r
	for i in 2:
		var rr := r * (0.18 + i * 0.16)
		ci.draw_arc(bc, rr, -PI * 0.75, PI * 0.15, 10, INK, maxf(r * 0.1, 3.0), true)
		ci.draw_arc(bc, rr, -PI * 0.75, PI * 0.15, 10, BADGE, maxf(r * 0.055, 2.0), true)


## Pilha de três folhas tortas com linhas de texto, os "X" do que falta, um clipe grande
## no canto e o selo "!" (pendência).
static func _draw_pendencia(ci: CanvasItem, c: Vector2, r: float) -> void:
	var line := maxf(r * 0.07, 2.0)
	var half := Vector2(0.54, 0.66) * r
	# (deslocamento x, y em unidades de r, giro): a de baixo primeiro.
	var sheets: Array[Vector3] = [Vector3(0.16, 0.2, 0.22), Vector3(0.06, 0.1, -0.14), Vector3(-0.06, -0.02, 0.05)]
	var top := Transform2D()
	for i in sheets.size():
		var s := sheets[i]
		var at := Transform2D(s.z, half, 0.0, c + Vector2(s.x, s.y) * r)
		var pts := _quad(at, Vector2(-1, -1), Vector2(1, 1))
		if i == 0:
			ci.draw_colored_polygon(UiKit.offset_points(pts, Vector2(2.0, 4.0)), Color(0, 0, 0, 0.3))
		ci.draw_polyline(UiKit.closed(pts), INK, line, true)
		ci.draw_colored_polygon(pts, PAPER.darkened(0.07 * (sheets.size() - 1 - i)))
		top = at
	# Cabeçalho, linhas e os "X" vermelhos do que falta.
	ci.draw_line(top * Vector2(-0.62, -0.62), top * Vector2(0.3, -0.62), INK, maxf(r * 0.08, 2.0), true)
	for i in 5:
		var y := -0.32 + i * 0.27
		ci.draw_line(top * Vector2(-0.62, y), top * Vector2(0.28 - 0.12 * float(i % 2), y), Color(0.55, 0.58, 0.68),
				maxf(r * 0.045, 1.5), true)
		if i % 2 == 0:
			var xc := top * Vector2(0.6, y)
			var k := r * 0.07
			ci.draw_line(xc - Vector2(k, k), xc + Vector2(k, k), STAMP, maxf(r * 0.05, 1.5), true)
			ci.draw_line(xc + Vector2(-k, k), xc + Vector2(k, -k), STAMP, maxf(r * 0.05, 1.5), true)
	# Clipe prendendo o canto de cima (metade para fora da folha).
	var clip := Transform2D(sheets[2].z, Vector2(r, r), 0.0, top * Vector2(-0.5, -1.0))
	var path := PackedVector2Array()
	path.append(clip * Vector2(-0.09, 0.4))
	_arc_points(path, clip * Vector2(0.0, -0.22), r * 0.09, PI, TAU)
	_arc_points(path, clip * Vector2(0.03, 0.3), r * 0.06, 0.0, PI)
	path.append(clip * Vector2(-0.03, -0.1))
	ci.draw_polyline(path, CLIP_DARK, maxf(r * 0.075, 2.5), true)
	ci.draw_polyline(path, CLIP, maxf(r * 0.035, 1.2), true)
	# Selo "!".
	_badge(ci, c + Vector2(0.56, 0.56) * r, r * 0.32, BADGE, "!")


## A caixa de item (vidro azulado, moldura branca) com o logo de cabeça para baixo e a
## senha saindo dela.
static func _draw_fila(ci: CanvasItem, c: Vector2, r: float) -> void:
	var line := maxf(r * 0.08, 2.5)
	var bc := c + Vector2(-0.08, -0.08) * r
	var half := r * 0.72
	var box := Rect2(bc - Vector2(half, half), Vector2(half, half) * 2.0)
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(int(r * 0.2))
	style.bg_color = Color(0, 0, 0, 0.3)
	ci.draw_style_box(style, Rect2(box.position + Vector2(2.0, 4.0), box.size))
	style.bg_color = GLASS
	style.border_color = INK
	style.set_border_width_all(int(line))
	ci.draw_style_box(style, box)
	# Reflexo do vidro e a moldura branca por dentro.
	ci.draw_colored_polygon(PackedVector2Array([box.position + Vector2(line, line), box.position + Vector2(half * 1.3, line),
			box.position + Vector2(line, half * 1.3)]), Color(1, 1, 1, 0.45))
	ci.draw_colored_polygon(PackedVector2Array([box.end - Vector2(line, line), box.end - Vector2(half * 0.9, line),
			box.end - Vector2(line, half * 0.9)]), Color(GLASS_DARK, 0.6))
	var frame := StyleBoxFlat.new()
	frame.draw_center = false
	frame.set_corner_radius_all(int(r * 0.12))
	frame.border_color = Color.WHITE
	frame.set_border_width_all(maxi(int(r * 0.06), 2))
	ci.draw_style_box(frame, box.grow(-line - r * 0.05))
	# Logo de cabeça para baixo (girado meia volta).
	var lw := half * 1.5
	var lh := lw * LOGO.get_height() / LOGO.get_width()
	ci.draw_set_transform(bc, PI, Vector2.ONE)
	ci.draw_texture_rect(LOGO, Rect2(-lw * 0.5, -lh * 0.5, lw, lh), false)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# A senha saindo por baixo, à direita.
	var at := Transform2D(0.22, Vector2(r, r), 0.0, c + Vector2(0.56, 0.6) * r)
	var slip := PackedVector2Array([at * Vector2(-0.3, -0.24), at * Vector2(0.3, -0.24)])
	for i in 7:
		slip.append(at * Vector2(0.3 - i * 0.1, 0.24 + (0.05 if i % 2 == 0 else 0.0)))
	ci.draw_colored_polygon(UiKit.offset_points(slip, Vector2(1.5, 3.0)), Color(0, 0, 0, 0.3))
	ci.draw_polyline(UiKit.closed(slip), INK, maxf(r * 0.05, 1.5), true)
	ci.draw_colored_polygon(slip, TICKET)
	var font: Font = UiKit.FONT_TITLE
	var fs := int(r * 0.24)
	var text := "087"
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	ci.draw_set_transform(at * Vector2(0.0, 0.02), 0.22, Vector2.ONE)
	ci.draw_string(font, Vector2(-w * 0.5, fs * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, STAMP)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Martelo de juiz inclinado na frente de um brilho dourado de oito pontas.
static func _draw_transito(ci: CanvasItem, c: Vector2, r: float) -> void:
	var line := maxf(r * 0.08, 2.5)
	# Brilho: halo e a estrela de pontas.
	ci.draw_circle(c, r * 0.9, Color(AURA, 0.3))
	var burst := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0 - PI * 0.5
		burst.append(c + Vector2(cos(a), sin(a)) * r * (0.98 if i % 2 == 0 else 0.5))
	ci.draw_colored_polygon(burst, GOLD)
	ci.draw_polyline(UiKit.closed(burst), GOLD_DARK, maxf(r * 0.04, 1.5), true)
	ci.draw_circle(c, r * 0.46, GOLD_LIGHT)
	# O martelo: cabo descendo para a esquerda e a cabeça em cima à direita.
	var at := Transform2D(0.7, Vector2(r, r), 0.0, c + Vector2(0.12, -0.14) * r)
	var handle := _quad(at, Vector2(-0.075, -0.1), Vector2(0.075, 0.86))
	var head := _quad(at, Vector2(-0.46, -0.44), Vector2(0.46, -0.06))
	var caps := [_quad(at, Vector2(-0.58, -0.5), Vector2(-0.42, 0.0)), _quad(at, Vector2(0.42, -0.5), Vector2(0.58, 0.0))]
	for poly: PackedVector2Array in [handle, head]:
		ci.draw_colored_polygon(UiKit.offset_points(poly, Vector2(2.0, 4.0)), Color(0, 0, 0, 0.3))
	ci.draw_polyline(UiKit.closed(handle), INK, line, true)
	ci.draw_colored_polygon(handle, GAVEL)
	ci.draw_circle(at * Vector2(0.0, 0.9), r * 0.11, INK)
	ci.draw_circle(at * Vector2(0.0, 0.9), r * 0.11 - line * 0.5, GAVEL_DARK)
	ci.draw_polyline(UiKit.closed(head), INK, line, true)
	ci.draw_colored_polygon(head, GAVEL)
	ci.draw_colored_polygon(_quad(at, Vector2(-0.42, -0.4), Vector2(0.42, -0.3)), Color(1, 1, 1, 0.25))
	for cap: PackedVector2Array in caps:
		ci.draw_polyline(UiKit.closed(cap), INK, line, true)
		ci.draw_colored_polygon(cap, GAVEL_DARK)
	for x: float in [-0.24, 0.24]:
		ci.draw_colored_polygon(_quad(at, Vector2(x - 0.04, -0.44), Vector2(x + 0.04, -0.06)), GAVEL_BAND)
	_sparkle(ci, c + Vector2(-0.66, -0.6) * r, r * 0.17)
	_sparkle(ci, c + Vector2(0.7, 0.56) * r, r * 0.13)


## Escudo-documento (papel em forma de brasão, faixa verde "LIMINAR" e o visto de
## deferido) com as ondas da buzina dos dois lados.
static func _draw_liminar(ci: CanvasItem, c: Vector2, r: float) -> void:
	var line := maxf(r * 0.08, 2.5)
	# Ondas.
	for side: float in [-1.0, 1.0]:
		var from := 0.0 if side > 0.0 else PI
		for i in 2:
			var rr := r * (0.78 + i * 0.17)
			ci.draw_arc(c, rr, from - 0.5, from + 0.5, 10, INK, maxf(r * 0.1, 3.0), true)
			ci.draw_arc(c, rr, from - 0.5, from + 0.5, 10, LIMINAR_LIGHT, maxf(r * 0.055, 2.0), true)
	var shield := shield_points(c + Vector2(0.0, -0.02) * r, r * 0.62)
	ci.draw_colored_polygon(UiKit.offset_points(shield, Vector2(2.0, 4.0)), Color(0, 0, 0, 0.3))
	ci.draw_polyline(UiKit.closed(shield), INK, line, true)
	ci.draw_colored_polygon(shield, PAPER)
	ci.draw_polyline(UiKit.closed(shield_points(c + Vector2(0.0, -0.02) * r, r * 0.5)), LIMINAR_GREEN, maxf(r * 0.04, 1.5), true)
	# Faixa verde com "LIMINAR".
	var band := Rect2(c + Vector2(-0.56, -0.44) * r, Vector2(1.12, 0.3) * r)
	ci.draw_rect(band, LIMINAR_GREEN)
	var font: Font = UiKit.FONT_TITLE
	var fs := int(r * 0.24)
	var text := "LIMINAR"
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var k := minf(1.0, band.size.x * 0.88 / maxf(w, 1.0))
	ci.draw_set_transform(band.get_center(), 0.0, Vector2(k, 1.0))
	ci.draw_string(font, Vector2(-w * 0.5, fs * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# O visto de deferido.
	var check := PackedVector2Array([c + Vector2(-0.26, 0.12) * r, c + Vector2(-0.06, 0.34) * r, c + Vector2(0.3, -0.06) * r])
	ci.draw_polyline(check, INK, maxf(r * 0.16, 4.0), true)
	ci.draw_polyline(check, LIMINAR_GREEN, maxf(r * 0.09, 2.5), true)


## Selo redondo com `text` (como o "1º" da PEC).
static func _badge(ci: CanvasItem, bc: Vector2, br: float, color: Color, text: String) -> void:
	ci.draw_circle(bc + Vector2(1.5, 3.0), br, Color(0, 0, 0, 0.3))
	ci.draw_circle(bc, br + maxf(br * 0.18, 2.0), Color.WHITE)
	ci.draw_circle(bc, br, color)
	var font: Font = UiKit.FONT_TITLE
	var fs := int(br * 1.25)
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var base := bc.y + (font.get_ascent(fs) - font.get_descent(fs)) * 0.5
	ci.draw_string(font, Vector2(bc.x - w * 0.5, base), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)


## Pílula (retângulo de pontas redondas) com meio em `c` e meia-largura/meia-altura `half`.
static func _pill(ci: CanvasItem, c: Vector2, half: Vector2, color: Color) -> void:
	var inner := maxf(half.x - half.y, 0.0)
	ci.draw_rect(Rect2(c.x - inner, c.y - half.y, inner * 2.0, half.y * 2.0), color)
	ci.draw_circle(c - Vector2(inner, 0.0), half.y, color)
	ci.draw_circle(c + Vector2(inner, 0.0), half.y, color)


## Acrescenta a `path` um arco de `from` a `to` (rad) em volta de `center`.
static func _arc_points(path: PackedVector2Array, center: Vector2, radius: float, from: float, to: float) -> void:
	for i in 9:
		var a := lerpf(from, to, i / 8.0)
		path.append(center + Vector2(cos(a), sin(a)) * radius)


## Asinha de três penas saindo de `root` para o lado `side` (+1 direita, -1 esquerda).
static func _draw_wing(ci: CanvasItem, root: Vector2, side: float, s: float) -> void:
	var feathers := [Vector3(0.72, -0.34, 0.2), Vector3(0.66, -0.06, 0.19), Vector3(0.52, 0.18, 0.17)]
	var line := maxf(s * 0.1, 2.0)
	for f: Vector3 in feathers:
		var tip := root + Vector2(f.x * side, f.y) * s
		var mid := root.lerp(tip, 0.55)
		var ang := (tip - root).angle()
		var pts := PackedVector2Array()
		for i in 18:
			var a := TAU * i / 18.0
			pts.append(mid + Vector2(cos(a) * (tip - root).length() * 0.55, sin(a) * f.z * s).rotated(ang))
		ci.draw_polyline(UiKit.closed(pts), WING_LINE, line, true)
		ci.draw_colored_polygon(pts, WING)
	ci.draw_circle(root + Vector2(0.12 * side, -0.12) * s, s * 0.22, WING_LINE)
	ci.draw_circle(root + Vector2(0.12 * side, -0.12) * s, s * 0.22 - line * 0.6, WING_SHADE)


## Quadrilátero de `a` a `b` (cantos opostos) no espaço `at`.
static func _quad(at: Transform2D, a: Vector2, b: Vector2) -> PackedVector2Array:
	return PackedVector2Array([at * a, at * Vector2(b.x, a.y), at * b, at * Vector2(a.x, b.y)])


## Brilho de quatro pontas.
static func _sparkle(ci: CanvasItem, c: Vector2, s: float) -> void:
	var pts := PackedVector2Array()
	for i in 8:
		var a := TAU * i / 8.0
		var k := s if i % 2 == 0 else s * 0.28
		pts.append(c + Vector2(cos(a), sin(a)) * k)
	ci.draw_colored_polygon(pts, Color.WHITE)


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


## Brasão (escudo): topo reto com as pontas para cima, lados retos e a ponta embaixo.
## `s` = meia largura; a altura vai de -1,15·s a +1,3·s em volta de `c`.
static func shield_points(c: Vector2, s: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.append(c + Vector2(-1.0, -1.15) * s)
	pts.append(c + Vector2(-0.5, -1.0) * s)
	pts.append(c + Vector2(0.0, -1.12) * s)
	pts.append(c + Vector2(0.5, -1.0) * s)
	pts.append(c + Vector2(1.0, -1.15) * s)
	# Lados descendo em curva (Bézier) até a ponta de baixo: o direito e depois o esquerdo.
	var p0 := Vector2(1.0, 0.1)
	var p1 := Vector2(1.0, 0.95)
	var p2 := Vector2(0.0, 1.3)
	for i in 9:
		var t := i / 8.0
		pts.append(c + (p0 * (1.0 - t) * (1.0 - t) + p1 * 2.0 * (1.0 - t) * t + p2 * t * t) * s)
	for i in range(7, -1, -1):
		var t := i / 8.0
		var p := p0 * (1.0 - t) * (1.0 - t) + p1 * 2.0 * (1.0 - t) * t + p2 * t * t
		pts.append(c + Vector2(-p.x, p.y) * s)
	return pts


static func ellipse_points(c: Vector2, radii: Vector2, count := 16) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in count:
		var a := TAU * i / count
		pts.append(c + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	return pts

