class_name RaceItems
extends Node
## Itens das caixas na corrida (os poderes estão descritos em RaceItem).
##
## Cada kart guarda um item por vez. Ao passar por uma caixa sem item, a roleta gira
## (ROLL_TIME) e sorteia um poder conforme a posição (_draw_item): quem está atrás tem
## mais chance dos fortes (Deságio, Antecipação Celer, Superpreferência; o líder nunca os
## recebe) e quem está na frente, das moedas. Com item guardado (ou girando) a caixa não
## dá outro. Os de Caos ficam no slot (canto superior esquerdo do HUD, ItemSlot) até o
## jogador usar com o botão "usar_item"; o piloto do computador espera um pouco e usa
## quando faz sentido. Para o computador não emendar um poder no outro, cada item tem um
## tempo de espera depois que alguém o usa (RaceItem.cooldown) — o jogador pode usar
## quando quiser. Os de Velocidade ("auto") são usados assim que a roleta para. Os de
## Ataque (carimbo, envelope, Constituição, calculadora) voam pela pista em ItemAttacks;
## segurando o freio na hora de usar, o carimbo e a calculadora vão para trás. As
## Armadilhas (pilha de papel, caixa falsa) são largadas atrás do kart e a Liminar solta a
## onda — os dois também em ItemAttacks. O Trânsito em julgado deixa o kart invencível
## (Kart.start_judged; a aura e o martelo ficam em ItemEffects).
##
## Contra-relógio e corrida sem rivais: as caixas estouram, mas não dão item.

## Roleta girando (s) e contrato da Cessão de crédito sendo assinado (s).
const ROLL_TIME := 1.8
const STEAL_TIME := 2.0
## Deságio: tempo pequeno (s) do último colocado (x) ao primeiro (y): quem está na
## frente fica pequeno por mais tempo.
const SHRINK_TIME := Vector2(4.5, 7.5)
## Juridiquês: tempo (s) com a tinta na tela.
const INK_TIME := 5.0
## Piloto do computador: espera (s) entre o item chegar e pensar em usar.
const AI_HOLD := Vector2(2.0, 8.0)
## Computador com uma Cessão e ninguém para roubar: depois desse tempo (s) usa assim
## mesmo (o crédito vem novo, a roleta gira de novo).
const AI_CESSAO_PATIENCE := 12.0
## Item de uso imediato: a roleta para e o slot mostra o item por este tempo (s) antes
## de ele ser usado.
const AUTO_SHOW := 0.35
## RPV: duração do turbo (s).
const RPV_BOOST := 1.7
## Antecipação Celer: tempo com a maleta aberta (s), turbo de cada jato (s), intervalo
## mínimo entre jatos (s), o primeiro jato (quando a maleta termina de abrir) e de quanto
## em quanto tempo o computador solta um jato.
const CELER_TIME := 7.0
const CELER_JET := 1.0
const CELER_GAP := 0.2
const CELER_FIRST := 0.3
const AI_CELER_GAP := Vector2(0.45, 0.9)
## Superpreferência: duração (s) do meio do pelotão (x) ao último (y), velocidade (× a
## velocidade máxima do kart), quanto a velocidade sobe por segundo, raio (m) em que ele
## atropela quem alcança e o empurrão (m/s) que joga a vítima para o lado.
const SUPER_TIME := Vector2(4.5, 6.5)
const SUPER_SPEED := 1.6
const SUPER_ACCEL := 30.0
const SUPER_HIT_RADIUS := 2.8
const SUPER_PUSH := 7.0
## Correção monetária: quantas moedas.
const CORRECAO_COINS := 3
## Computador com um item de Ataque e ninguém na mira: depois desse tempo (s) usa assim
## mesmo; alcance (m) e abertura (rad) da mira para a frente e para trás.
const AI_ATTACK_PATIENCE := 14.0
const AI_AIM_FRONT := Vector2(34.0, 0.12)
const AI_AIM_BOMB := Vector2(26.0, 0.3)
const AI_AIM_BACK := Vector2(11.0, 0.4)
## Trânsito em julgado: tempo invencível (s).
const TRANSITO_TIME := 7.5
## Computador com o Trânsito em julgado: espera (s) até usar sem ameaça nenhuma; e o
## alcance (m) em que um ataque chegando o faz usar na hora.
const AI_STAR_HOLD := Vector2(3.0, 9.0)
const AI_STAR_THREAT := 30.0
## Computador com a Liminar: alcance (m) dos rivais que contam e quanto tempo (s) ele
## guarda a Liminar esperando uma ameaça (o líder guarda para a PEC).
const AI_HORN_PATIENCE := 16.0
## Modo dev: roleta curta (s) ao ganhar um item pelo painel e ao repor o item infinito.
const DEV_ROLL := 0.45
const DEV_REFILL := 0.35


## O trilho da Superpreferência (anda pela pista, perto da trajetória ideal).
class SuperRun:
	## Distância pela pista (m, não volta a zero) e lado (m, + = direita).
	var along := 0.0
	var lateral := 0.0
	## Diferença entre o kart e o trilho na hora de virar ofício (fora do asfalto, no
	## ar...): some aos poucos, sem dar um salto.
	var offset := Vector3.ZERO
	var speed := 0.0
	var top := 0.0
	var time := 0.0


## O item de um kart.
class Holder:
	## Race.Racer (sem tipo: race.gd não tem class_name).
	var racer
	var kart: Kart
	var item := RaceItem.NONE
	## Item a caminho (roleta girando ou contrato sendo assinado).
	var incoming := RaceItem.NONE
	var wait := 0.0
	var ai_timer := 0.0
	## Há quanto tempo (s) o item está guardado.
	var held := 0.0
	## Antecipação Celer: tempo de maleta aberta que falta (s), espera até o próximo
	## jato poder sair e o primeiro jato (automático) que falta.
	var celer := 0.0
	var celer_gap := 0.0
	var celer_first := -1.0
	## Superpreferência em andamento (null = não).
	var super_run: SuperRun

	func is_human() -> bool:
		return racer.slot != null

	func is_free() -> bool:
		return item == RaceItem.NONE and incoming == RaceItem.NONE and celer <= 0.0


## A corrida (race.gd).
var race: Node3D
var effects: ItemEffects
## Os itens de Ataque em jogo (carimbos, envelopes, a Constituição e as calculadoras).
var attacks: ItemAttacks
## false no contra-relógio e sem rivais (as caixas não dão nada).
var enabled := true
var _holders: Array[Holder] = []
var _cooldown := PackedFloat32Array()
## Trajetória ideal (o trilho da Superpreferência segue perto dela; a IA da
## Antecipação vê se a pista à frente é reta).
var _line: RacingLine
## Modo dev (DevPanel): o item usado pelo jogador volta para o slot; os rivais não pegam
## item nas caixas; alguma trapaça foi usada nesta corrida (não vale recorde).
var dev_infinite := false
var dev_no_ai_items := false
var dev_used := false


func _init() -> void:
	name = "Itens"
	_cooldown.resize(RaceItem.COUNT)


## Liga os itens à corrida: um Holder por kart, o slot de cada jogador e os efeitos 3D.
## Chame depois das câmeras e HUDs dos jogadores montados.
func setup(p_race: Node3D) -> void:
	race = p_race
	enabled = race.mode != GameState.Mode.TIME_TRIAL and race.racers.size() > 1
	for r in race.racers:
		var h := Holder.new()
		h.racer = r
		h.kart = r.kart
		_holders.append(h)
		r.kart.item_box_collected.connect(_on_item_box.bind(h))
		r.kart.knocked.connect(_on_knocked.bind(h))
		if h.is_human():
			r.kart.shrunk.connect(_on_human_shrunk.bind(h))
			r.kart.squashed.connect(_on_human_squashed.bind(h))
	if not enabled:
		return
	var cams: Array[Camera3D] = []
	for r in race.humans:
		cams.append(r.camera)
	effects = ItemEffects.new()
	race.add_child(effects)
	effects.setup(cams)
	_line = RacingLine.build(race.track)
	attacks = ItemAttacks.new()
	race.add_child(attacks)
	attacks.setup(self, _line)
	# Os pilotos do computador desviam das armadilhas na pista.
	for h in _holders:
		if h.racer.ai:
			h.racer.ai.traps = attacks.trap_spots
	_refresh_keys()
	if GameState.menu_input:
		GameState.menu_input.device_changed.connect(func(_pad: bool): _refresh_keys())


## Liga/desliga os efeitos por uns quadros para compilar os shaders (Race.warm_up).
func prewarm(on: bool) -> void:
	if effects == null or race.humans.is_empty():
		return
	var k: Kart = race.humans[0].kart
	var fwd := k.get_forward()
	var at := k.global_position + fwd * 6.0
	# O fantasma na frente do kart, de frente para a câmera.
	var xf := Transform3D(Basis.looking_at(-fwd, Vector3.UP), at)
	effects.prewarm(on, k, xf)
	attacks.prewarm(on, k, xf)


## Os itens de cada kart (um por kart, na ordem de Race.racers).
func holders() -> Array[Holder]:
	return _holders


## Tecla (ou botão) de usar o item, no canto do slot de cada jogador.
func _refresh_keys() -> void:
	for h in _holders:
		if h.is_human() and h.racer.hud:
			h.racer.hud.set_item_key(_key_label(h.racer.slot))


func _key_label(slot: PlayerSlot) -> String:
	var pad := slot.device >= 0
	if slot.device == PlayerSlot.DEVICE_ALL and GameState.menu_input:
		pad = GameState.menu_input.using_pad
	if pad:
		return "LB"
	var keys := GameState.settings.key_labels(&"usar_item")
	return keys[0] if not keys.is_empty() else "E"


# --- Quadro a quadro ---------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if not enabled:
		return
	for i in RaceItem.COUNT:
		_cooldown[i] = maxf(_cooldown[i] - delta, 0.0)
	var racing: bool = race.is_racing()
	for h in _holders:
		if h.incoming != RaceItem.NONE:
			h.wait -= delta
			if h.wait <= 0.0:
				_arrive(h)
		if h.super_run:
			_update_super(h, delta)
		if h.celer > 0.0:
			_update_celer(h, delta, racing)
		if not racing or h.racer.finished:
			continue
		if h.is_human():
			if Input.is_action_just_pressed(h.racer.slot.action(&"usar_item")):
				if h.celer > 0.0:
					_celer_jet(h)
				elif h.item != RaceItem.NONE:
					# Segurando o freio, o carimbo e a calculadora vão para trás.
					_use(h, Input.is_action_pressed(h.racer.slot.action(&"frear")))
		elif h.item != RaceItem.NONE:
			_think(h, delta)


func _on_item_box(_box: Node3D, h: Holder) -> void:
	if not enabled or not h.is_free() or h.racer.finished:
		return
	if dev_no_ai_items and not h.is_human():
		return
	_start_roll(h, _draw_item(h))


## A roleta gira e para em `kind` (no HUD do jogador também).
func _start_roll(h: Holder, kind: int) -> void:
	# Item de uso imediato: o slot mostra o item um instante antes de ele ser usado.
	_start_incoming(h, kind, ROLL_TIME + (AUTO_SHOW if RaceItem.is_auto(kind) else 0.0))
	if h.is_human():
		h.racer.hud.roll_item(kind, ROLL_TIME)


func _start_incoming(h: Holder, kind: int, wait: float) -> void:
	h.incoming = kind
	h.wait = wait


## O item chegou (a roleta parou ou o contrato foi assinado).
func _arrive(h: Holder) -> void:
	h.item = h.incoming
	h.incoming = RaceItem.NONE
	h.held = 0.0
	h.ai_timer = randf_range(AI_HOLD.x, AI_HOLD.y)
	if RaceItem.is_auto(h.item):
		if race.is_racing() and not h.racer.finished:
			_use(h)
		else:
			h.item = RaceItem.NONE
			if h.is_human():
				h.racer.hud.use_item()


## Sorteio pela posição (p: 0 = líder, 1 = último). `no_cessao`: a Cessão não sai.
## Na frente: moedas, Juridiquês, carimbos e uma RPV de vez em quando. No meio:
## Intimações e calculadoras. Atrás: turbos, Deságio, Antecipação, a PEC dos Precatórios
## e, nos últimos, a Superpreferência. Os itens "single" não saem enquanto alguém os tem
## ou logo depois de alguém usar.
func _draw_item(h: Holder, no_cessao := false) -> int:
	var count: int = race.racers.size()
	var place: int = h.racer.place
	var p := float(place - 1) / maxf(count - 1, 1.0)
	var w := PackedFloat32Array()
	w.resize(RaceItem.COUNT)
	w[RaceItem.Kind.DESAGIO] = 0.0 if p < 0.34 else lerpf(0.3, 1.2, p)
	# O líder também pode tirar Juridiquês (sem ninguém à frente, a tinta pega quem vem atrás).
	w[RaceItem.Kind.JURIDIQUES] = 0.45 if place == 1 else lerpf(0.75, 0.55, p)
	if not no_cessao:
		w[RaceItem.Kind.CESSAO] = lerpf(0.65, 0.8, p) if _steal_target(h) else 0.2
	w[RaceItem.Kind.RPV] = lerpf(0.55, 1.3, p)
	w[RaceItem.Kind.ANTECIPACAO] = 0.0 if p < 0.3 else lerpf(0.25, 0.9, (p - 0.3) / 0.7)
	w[RaceItem.Kind.SUPERPREFERENCIA] = 0.0 if p < 0.55 else lerpf(0.2, 0.75, (p - 0.55) / 0.45)
	# Moedas valem menos para quem já tem quase todas.
	var room := 1.0 - float(h.kart.coins) / Kart.MAX_COINS
	w[RaceItem.Kind.CORRECAO] = lerpf(1.1, 0.25, p) * lerpf(0.1, 1.0, room)
	w[RaceItem.Kind.CARIMBO] = lerpf(0.95, 0.4, p)
	# Intimação: o líder não tem ninguém à frente para perseguir.
	w[RaceItem.Kind.INTIMACAO] = 0.0 if place == 1 else lerpf(0.85, 0.7, p)
	w[RaceItem.Kind.PEC] = 0.0 if p < 0.3 else lerpf(0.12, 0.32, (p - 0.3) / 0.7)
	w[RaceItem.Kind.IMPUGNACAO] = 0.0 if p < 0.15 else lerpf(0.4, 0.5, p)
	# Armadilhas: coisa de quem está na frente (largar atrás para quem vem).
	w[RaceItem.Kind.PENDENCIA] = lerpf(0.85, 0.2, p)
	w[RaceItem.Kind.FILA] = lerpf(0.45, 0.1, p)
	# Trânsito em julgado: para quem ficou para trás. Liminar: rara; o líder (alvo da
	# PEC) tem um pouco mais de chance.
	w[RaceItem.Kind.TRANSITO] = 0.0 if p < 0.4 else lerpf(0.2, 0.65, (p - 0.4) / 0.6)
	w[RaceItem.Kind.LIMINAR] = 0.22 if place == 1 else lerpf(0.14, 0.18, p)
	for kind in RaceItem.COUNT:
		if RaceItem.is_single(kind) and w[kind] > 0.0 and (_cooldown[kind] > 0.0 or _in_play(kind)):
			w[kind] = 0.0
	var total := 0.0
	for x in w:
		total += x
	if total <= 0.0:
		return RaceItem.Kind.RPV
	var pick := randf() * total
	for i in w.size():
		pick -= w[i]
		if pick <= 0.0 and w[i] > 0.0:
			return i
	return RaceItem.Kind.RPV


## Alguém tem (ou está recebendo) este item?
func _in_play(kind: int) -> bool:
	for h in _holders:
		if h.item == kind or h.incoming == kind:
			return true
		if kind == RaceItem.Kind.ANTECIPACAO and h.celer > 0.0:
			return true
		if kind == RaceItem.Kind.SUPERPREFERENCIA and h.super_run != null:
			return true
	return attacks != null and attacks.has_kind(kind)


# --- Usar --------------------------------------------------------------------------

## Usa o item guardado. `backward`: o carimbo e a calculadora vão para trás. `target`
## (modo dev): a vítima escolhida dos itens que miram em alguém (as armadilhas caem na
## frente dela).
func _use(h: Holder, backward := false, target: Holder = null) -> void:
	var kind := h.item
	if kind == RaceItem.NONE:
		return
	h.item = RaceItem.NONE
	_cooldown[kind] = RaceItem.cooldown(kind)
	if h.is_human():
		if kind == RaceItem.Kind.ANTECIPACAO:
			h.racer.hud.item_timer(kind, CELER_TIME)
		else:
			h.racer.hud.use_item()
	match kind:
		RaceItem.Kind.DESAGIO:
			_desagio(h)
		RaceItem.Kind.JURIDIQUES:
			_juridiques(h, target)
		RaceItem.Kind.CESSAO:
			_cessao(h, target)
		RaceItem.Kind.RPV:
			_rpv(h)
		RaceItem.Kind.ANTECIPACAO:
			_antecipacao(h)
		RaceItem.Kind.SUPERPREFERENCIA:
			_superpreferencia(h)
		RaceItem.Kind.CORRECAO:
			_correcao(h)
		RaceItem.Kind.CARIMBO:
			attacks.throw_stamp(h, backward, target)
		RaceItem.Kind.INTIMACAO:
			attacks.throw_envelope(h, target)
		RaceItem.Kind.PEC:
			attacks.throw_pec(h, target)
		RaceItem.Kind.IMPUGNACAO:
			attacks.throw_calc(h, backward, target)
		RaceItem.Kind.PENDENCIA, RaceItem.Kind.FILA:
			attacks.drop_trap(h, kind, target)
		RaceItem.Kind.TRANSITO:
			_transito(h)
		RaceItem.Kind.LIMINAR:
			attacks.liminar(h)
	# Modo dev: item infinito (os de uso imediato não, senão nunca acabariam).
	if dev_infinite and h.is_human() and not RaceItem.is_auto(kind) and h.is_free():
		dev_give(h, kind, DEV_REFILL)


## Deságio: raio em todos os rivais (rodam e encolhem) e o "deságio −%" no céu. Quem usou
## volta ao tamanho normal, se estava pequeno.
func _desagio(h: Holder) -> void:
	h.kart.grow()
	effects.sky_sign()
	Sfx.play(race, &"thunder", -3.0)
	var count: int = race.racers.size()
	for o in _holders:
		# O ofício da Superpreferência e o Trânsito em julgado não levam raio.
		if o == h or o.racer.finished or o.kart.is_immune():
			continue
		var p := float(o.racer.place - 1) / maxf(count - 1, 1.0)
		o.kart.zap(lerpf(SHRINK_TIME.y, SHRINK_TIME.x, p))
		effects.strike(o.kart)
	for o in _holders:
		if not o.is_human():
			continue
		var hit: bool = o != h and not o.racer.finished and not o.kart.is_immune()
		o.racer.hud.flash(Color(1.0, 0.98, 0.8), 0.8 if hit else 0.45)
		o.racer.camera.shake(0.7 if hit else 0.3)
	if h.kart.driver:
		h.kart.driver.set_face(&"face_happy", 1.5)


## Juridiquês: tinta na tela de quem está à frente (o líder que usa acerta todo mundo).
## `only` (modo dev): só essa vítima.
func _juridiques(h: Holder, only: Holder = null) -> void:
	var targets: Array[Holder] = []
	for o in _holders:
		if o != h and not o.racer.finished and not o.kart.is_immune() \
				and (o == only if only else o.racer.place < h.racer.place):
			targets.append(o)
	if targets.is_empty():
		for o in _holders:
			if o != h and not o.racer.finished and not o.kart.is_immune():
				targets.append(o)
	var tag_layer: int = race.TAG_LAYER
	var human_hit := false
	for o in targets:
		o.kart.blind_time = INK_TIME
		# O "§" em cima do kart; o dono (jogador) vê a tinta na tela, não o "§".
		var layers := 1
		if o.is_human():
			layers = 1 << (tag_layer + o.racer.slot.index - 1)
			o.racer.hud.show_ink(INK_TIME)
			human_hit = true
		effects.ink_mark(o.kart, INK_TIME, layers)
	if human_hit:
		Sfx.play(race, &"ink", -4.0)
	if h.is_human():
		Sfx.play(race, &"item_use", -8.0)


## Cessão de crédito: rouba o item de um rival (de `victim`, no modo dev, se ele tiver
## item). Sem ninguém com item, o crédito vem novo: a roleta gira de novo (sem a Cessão).
func _cessao(h: Holder, victim: Holder = null) -> void:
	var target := victim if victim and victim.item != RaceItem.NONE else _steal_target(h)
	if target == null:
		_start_roll(h, _draw_item(h, true))
		return
	var stolen := target.item
	target.item = RaceItem.NONE
	target.ai_timer = randf_range(AI_HOLD.x, AI_HOLD.y)
	_start_incoming(h, stolen, STEAL_TIME)
	if target.is_human():
		target.racer.hud.item_stolen()
	if h.is_human():
		h.racer.hud.receive_item(stolen, target.racer.display_name(), h.racer.display_name(), STEAL_TIME)
	effects.ghost.play(target.kart, h.kart, STEAL_TIME)
	if h.is_human() or target.is_human():
		Sfx.play(race, &"ghost", -6.0)
	if target.kart.driver:
		target.kart.driver.set_face(&"face_confused", 1.6)


## De quem a Cessão rouba: um rival com item guardado — o mais perto à frente; sem
## ninguém à frente, o mais perto atrás. Uma Cessão não rouba outra Cessão (senão o
## crédito ficaria passando de mão em mão).
func _steal_target(h: Holder) -> Holder:
	var best: Holder = null
	var best_score := INF
	for o in _holders:
		if o == h or o.item == RaceItem.NONE or o.item == RaceItem.Kind.CESSAO or o.racer.finished:
			continue
		var gap: int = h.racer.place - o.racer.place
		var score := float(gap) if gap > 0 else 100.0 - gap
		if score < best_score:
			best_score = score
			best = o
	return best


## RPV: turbo curto e a guia verde vira foguete embaixo do kart.
func _rpv(h: Holder) -> void:
	h.kart.apply_boost(RPV_BOOST, 3)
	effects.rpv(h.kart, RPV_BOOST)
	if h.is_human():
		Sfx.play(race, &"rocket", -6.0)
	if h.kart.driver:
		h.kart.driver.set_face(&"face_happy", 1.2)


## Antecipação Celer: o Celerino aparece com a maleta; ela abre e solta o primeiro jato.
## Depois, cada toque no botão (ou a vontade do computador) solta outro, até o tempo
## acabar.
func _antecipacao(h: Holder) -> void:
	h.celer = CELER_TIME
	h.celer_gap = 0.0
	h.celer_first = CELER_FIRST
	h.ai_timer = CELER_FIRST + randf_range(AI_CELER_GAP.x, AI_CELER_GAP.y)
	effects.celer.open(h.kart)
	if h.is_human():
		Sfx.play(race, &"briefcase", -6.0)
	if h.kart.driver:
		h.kart.driver.set_face(&"face_happy", 1.5)


func _update_celer(h: Holder, delta: float, racing: bool) -> void:
	h.celer -= delta
	h.celer_gap -= delta
	if h.celer <= 0.0 or h.racer.finished or not racing:
		_close_celer(h)
		return
	if h.celer_first >= 0.0:
		h.celer_first -= delta
		if h.celer_first < 0.0:
			_celer_jet(h)
		return
	if not h.is_human():
		# Computador: um jato de tempos em tempos, menos numa curva fechada à frente.
		h.ai_timer -= delta
		if h.ai_timer <= 0.0:
			h.ai_timer = randf_range(AI_CELER_GAP.x, AI_CELER_GAP.y)
			var bend := _line.max_curvature(h.racer.along, 30.0) if _line else 0.0
			if bend < 0.035 and not h.kart.is_spinning():
				_celer_jet(h)


## Um jato de notas: turbo na hora.
func _celer_jet(h: Holder) -> void:
	if h.celer_gap > 0.0 or h.celer <= 0.0:
		return
	h.celer_gap = CELER_GAP
	h.celer_first = -1.0
	h.kart.apply_boost(CELER_JET, 2)
	if effects.celer.is_busy():
		effects.celer.jet()
	if h.is_human():
		h.racer.hud.item_pulse()
		Sfx.play(race, &"cash", -7.0)


func _close_celer(h: Holder) -> void:
	h.celer = 0.0
	h.celer_first = -1.0
	effects.celer.close()
	if h.is_human():
		h.racer.hud.use_item()


## Superpreferência: o kart vira o ofício e anda sozinho no trilho por alguns segundos
## (mais tempo para quem está mais atrás), atropelando quem alcança.
func _superpreferencia(h: Holder) -> void:
	var track: Track = race.track
	var k := h.kart
	var run := SuperRun.new()
	var count: int = race.racers.size()
	var p := float(h.racer.place - 1) / maxf(count - 1, 1.0)
	run.time = lerpf(SUPER_TIME.x, SUPER_TIME.y, clampf((p - 0.5) / 0.5, 0.0, 1.0))
	var local := track.to_local(k.global_position)
	var index := track.get_closest_index(local, h.racer.index)
	run.along = track.get_along(local, index)
	var edge := track.road_width * 0.5 - 2.0
	run.lateral = clampf(track.get_lateral(local, index), -edge, edge)
	var road := track.global_transform * track.get_transform_at(run.along, run.lateral).origin
	run.offset = k.global_position - road
	run.speed = maxf(k.speed, 12.0)
	run.top = k.max_speed * SUPER_SPEED
	h.super_run = run
	k.start_super(_super_rail.bind(h))
	effects.oficio.start(k)
	Sfx.play(race, &"paper", -6.0 if h.is_human() else -14.0)
	if h.is_human():
		h.racer.camera.shake(0.35)
		var stamp_tw := create_tween()
		stamp_tw.tween_interval(OficioSuper.STAMP_AT + OficioSuper.STAMP_TIME)
		stamp_tw.tween_callback(_stamp_landed.bind(h))


## O carimbo PRIORIDADE bateu no ofício do jogador.
func _stamp_landed(h: Holder) -> void:
	if h.super_run:
		Sfx.play(race, &"stamp", -4.0)
		h.racer.camera.shake(0.5)


## Onde o ofício está neste passo (chamado pelo Kart, veja Kart.start_super).
func _super_rail(k: Kart, delta: float, h: Holder) -> Transform3D:
	var run := h.super_run
	var track: Track = race.track
	if run == null:
		return k.global_transform
	run.speed = move_toward(run.speed, run.top, SUPER_ACCEL * delta)
	run.along += run.speed * delta
	var edge := track.road_width * 0.5 - 2.0
	var goal := clampf((_line.lateral_at(run.along + 20.0) if _line else 0.0) * 0.6, -edge, edge)
	run.lateral = move_toward(run.lateral, goal, 4.5 * delta)
	run.offset *= exp(-5.0 * delta)
	var pos := track.global_transform * track.get_transform_at(run.along, run.lateral).origin
	var fwd := track.global_basis * track.get_direction_at(run.along + 2.0)
	fwd.y = 0.0
	if fwd.length_squared() < 0.0001:
		fwd = k.get_forward()
	return Transform3D(Basis.looking_at(fwd.normalized(), Vector3.UP), pos + run.offset + Vector3.UP * 0.02)


func _update_super(h: Holder, delta: float) -> void:
	var run := h.super_run
	var k := h.kart
	if not k.is_super():
		# Reposicionado no meio (Kart.teleport encerra o ofício).
		_end_super(h, false)
		return
	run.time -= delta
	if run.time <= 0.0 or h.racer.finished:
		_end_super(h, not h.racer.finished)
		return
	# Atropela quem está embaixo da folha.
	var flat_hit := false
	for o in _holders:
		if o == h or o.racer.finished or o.kart.is_immune() or o.kart.is_flat():
			continue
		var d := o.kart.global_position - k.global_position
		if absf(d.y) > 2.5:
			continue
		d.y = 0.0
		if d.length() > SUPER_HIT_RADIUS:
			continue
		var side := k.global_basis.x * (1.0 if d.dot(k.global_basis.x) >= 0.0 else -1.0)
		o.kart.run_over(side * SUPER_PUSH)
		flat_hit = true
		if o.kart.driver:
			o.kart.driver.set_face(&"face_surprised", 1.4)
	if flat_hit and h.is_human():
		Sfx.play(race, &"stamp", -9.0, 1.3)


func _end_super(h: Holder, boost: bool) -> void:
	h.super_run = null
	if h.kart.is_super():
		h.kart.end_super(boost)
	effects.oficio.finish()
	if h.is_human():
		Sfx.play(race, &"paper", -8.0, 1.2)


## Trânsito em julgado: o kart fica invencível (aura dourada e o martelo girando).
func _transito(h: Holder) -> void:
	h.kart.start_judged(TRANSITO_TIME)
	effects.julgado(h.kart)
	if h.is_human():
		h.racer.hud.flash(Color(1.0, 0.92, 0.55), 0.4)
		h.racer.camera.shake(0.25)
	Sfx.play(race, &"julgado", -5.0 if h.is_human() else -16.0)
	if h.kart.driver:
		h.kart.driver.set_face(&"face_happy", TRANSITO_TIME)


## Com o Trânsito em julgado, `h` derrubou `other` (Kart.knocked): a martelada.
func _on_knocked(other: Kart, h: Holder) -> void:
	var near := h.is_human()
	for o in _holders:
		if o.kart == other and o.is_human():
			near = true
	if near:
		Sfx.play(race, &"gavel", -3.0)
	if other.driver:
		other.driver.set_face(&"face_screaming", 1.4)


## Correção monetária: três moedas com "%" caem dentro do kart.
func _correcao(h: Holder) -> void:
	var k := h.kart
	effects.coin_shower(k, CORRECAO_COINS, k.add_coin)
	if k.driver:
		k.driver.set_face(&"face_happy", 1.2)


# --- Computador ------------------------------------------------------------------------

## O piloto do computador decide se usa o item agora.
func _think(h: Holder, delta: float) -> void:
	h.held += delta
	h.ai_timer -= delta
	if h.ai_timer > 0.0:
		return
	var kind := h.item
	var ready := _cooldown[kind] <= 0.0 and not h.kart.is_spinning()
	var aim := 1
	var impatient := h.held > AI_ATTACK_PATIENCE
	match kind:
		RaceItem.Kind.JURIDIQUES:
			# Só com alguém à frente para levar a tinta.
			ready = ready and h.racer.place > 1
		RaceItem.Kind.CESSAO:
			ready = ready and (_steal_target(h) != null or h.held > AI_CESSAO_PATIENCE)
		RaceItem.Kind.CARIMBO:
			# Alguém na mira à frente (ou colado atrás); sem ninguém, joga depois de um tempo.
			aim = _aim(h, AI_AIM_FRONT)
			if aim == 0 and impatient:
				aim = 1
			ready = ready and aim != 0
		RaceItem.Kind.INTIMACAO:
			ready = ready and (h.racer.place > 1 or impatient)
		RaceItem.Kind.PEC:
			# Nunca em primeiro (ela cairia nele mesmo).
			ready = ready and h.racer.place > 1
		RaceItem.Kind.IMPUGNACAO:
			aim = _aim(h, AI_AIM_BOMB)
			if aim == 0 and impatient:
				aim = -1
			ready = ready and aim != 0
		RaceItem.Kind.PENDENCIA, RaceItem.Kind.FILA:
			# Larga quando tem alguém colado atrás; sem ninguém, depois de um tempo.
			ready = ready and (_aim(h, Vector2.ZERO) < 0 or impatient)
		RaceItem.Kind.TRANSITO:
			# Na hora de um ataque chegando ou depois de um tempo (para alcançar quem está
			# na frente).
			ready = ready and (attacks.threat_to(h, AI_STAR_THREAT) != RaceItem.NONE \
					or h.held > lerpf(AI_STAR_HOLD.y, AI_STAR_HOLD.x, float(h.racer.place) / race.racers.size()))
		RaceItem.Kind.LIMINAR:
			# A PEC ou um tiro chegando, rivais em volta ou (fora da liderança) cansou de
			# esperar. O líder guarda a Liminar para a PEC.
			var threat := attacks.threat_to(h, ItemAttacks.LIMINAR_RADIUS - 1.5)
			var near := _rivals_near(h, ItemAttacks.LIMINAR_RADIUS * 0.75)
			ready = ready and (threat != RaceItem.NONE or near >= 2 or (near >= 1 and h.held > 6.0) \
					or (h.held > AI_HORN_PATIENCE and h.racer.place > 1))
	if ready:
		_use(h, aim < 0)
	else:
		# Mirando, o computador olha de novo logo.
		h.ai_timer = randf_range(0.25, 0.6) if kind >= RaceItem.Kind.CARIMBO else randf_range(0.8, 2.0)


## Rivais (correndo, não invencíveis) a menos de `reach` m de `h`.
func _rivals_near(h: Holder, reach: float) -> int:
	var count := 0
	for o in _holders:
		if o == h or o.racer.finished or o.kart.is_immune():
			continue
		var d := o.kart.global_position - h.kart.global_position
		if absf(d.y) < 3.5 and Vector2(d.x, d.z).length() < reach:
			count += 1
	return count


## Mira do computador: 1 = um rival à frente dentro de `front` (alcance m, abertura rad),
## -1 = um rival colado atrás (AI_AIM_BACK), 0 = ninguém.
func _aim(h: Holder, front: Vector2) -> int:
	var k := h.kart
	var fwd := k.get_forward()
	var behind := false
	for o in _holders:
		if o == h or o.racer.finished or o.kart.is_immune():
			continue
		var d := o.kart.global_position - k.global_position
		if absf(d.y) > 3.0:
			continue
		d.y = 0.0
		var dist := d.length()
		if dist < 0.5:
			continue
		var cosine := d.dot(fwd) / dist
		if dist < front.x and cosine > cos(front.y):
			return 1
		if dist < AI_AIM_BACK.x and cosine < -cos(AI_AIM_BACK.y):
			behind = true
	return -1 if behind else 0


# --- Modo dev (DevPanel) ---------------------------------------------------------------

## Dá `kind` para `h` na hora (com uma roleta curta): troca o item que ele tinha, e os
## de uso imediato são usados assim que ela para.
func dev_give(h: Holder, kind: int, roll := DEV_ROLL) -> void:
	dev_used = true
	if RaceItem.is_single(kind):
		_dev_free_single(kind)
	if h.celer > 0.0:
		_close_celer(h)
	h.item = RaceItem.NONE
	_cooldown[kind] = 0.0
	_start_incoming(h, kind, roll + (AUTO_SHOW if RaceItem.is_auto(kind) else 0.0))
	if h.is_human():
		h.racer.hud.roll_item(kind, roll)


## Um rival usa `kind` mirando em `victim`. Quem usa depende do item: quem está logo
## atrás para os que vêm de trás (Juridiquês, Intimação, PEC, Superpreferência), o
## mais perto para os outros. Devolve a frase para o painel.
func dev_rival_use(kind: int, victim: Holder) -> String:
	if not race.is_racing():
		return "Espere a largada."
	var from_behind := kind in [RaceItem.Kind.JURIDIQUES, RaceItem.Kind.INTIMACAO, RaceItem.Kind.PEC,
			RaceItem.Kind.SUPERPREFERENCIA]
	var rival := _dev_rival(victim, from_behind)
	if rival == null:
		return "Nenhum rival na pista."
	dev_used = true
	if kind == RaceItem.Kind.CESSAO and victim.item == RaceItem.NONE:
		# Sem item não há o que roubar: o jogador ganha um carimbo, roubado um segundo
		# depois (dá tempo de ver ele no slot).
		victim.item = RaceItem.Kind.CARIMBO
		victim.incoming = RaceItem.NONE
		if victim.is_human():
			victim.racer.hud.item_slot.show_item(victim.item)
		get_tree().create_timer(1.0, false, true).timeout.connect(func():
			if race.is_racing() and victim.item != RaceItem.NONE and not victim.racer.finished:
				dev_rival_use(kind, victim))
		return "Você ganhou um Carimbo; um rival vai roubar."
	if RaceItem.is_single(kind):
		_dev_free_single(kind)
	_dev_clear(rival)
	rival.item = kind
	_use(rival, false, victim)
	var dist := roundi(rival.kart.global_position.distance_to(victim.kart.global_position))
	return "%s (a %d m) usou %s." % [rival.racer.display_name(), dist, RaceItem.item_name(kind)]


## Liga/desliga os itens dos rivais; ao desligar, eles perdem o que tinham.
func dev_set_no_ai_items(on: bool) -> void:
	dev_no_ai_items = on
	if not on:
		return
	dev_used = true
	for h in _holders:
		if not h.is_human():
			h.item = RaceItem.NONE
			h.incoming = RaceItem.NONE


## O rival (que ainda corre) logo atrás de `victim` pela pista (`behind`) ou o mais perto
## dele; sem ninguém atrás, o mais perto.
func _dev_rival(victim: Holder, behind: bool) -> Holder:
	var best: Holder = null
	var best_score := INF
	for o in _holders:
		if o == victim or o.is_human() or o.racer.finished:
			continue
		var score := o.kart.global_position.distance_to(victim.kart.global_position)
		if behind:
			var gap: float = victim.racer.progress - o.racer.progress
			score = gap if gap > 0.0 else 1000.0 + score
		if score < best_score:
			best_score = score
			best = o
	return best


## Os itens "single" com efeito único na tela (a maleta da Antecipação, o ofício da
## Superpreferência): encerra o que está em jogo antes de dar outro.
func _dev_free_single(kind: int) -> void:
	for o in _holders:
		if o.incoming == kind:
			o.incoming = RaceItem.NONE
			if o.is_human():
				o.racer.hud.use_item()
		if kind == RaceItem.Kind.ANTECIPACAO and o.celer > 0.0:
			_close_celer(o)
		elif kind == RaceItem.Kind.SUPERPREFERENCIA and o.super_run:
			_end_super(o, false)


## Tira o item (guardado ou a caminho) de um rival antes de ele usar um do painel.
func _dev_clear(h: Holder) -> void:
	h.item = RaceItem.NONE
	h.incoming = RaceItem.NONE
	if h.celer > 0.0:
		_close_celer(h)


# --- Sons e reações do jogador -----------------------------------------------------

func _on_human_shrunk(on: bool, h: Holder) -> void:
	Sfx.play(race, &"shrink" if on else &"grow", -8.0)
	if not on:
		h.racer.camera.shake(0.15)


func _on_human_squashed(h: Holder) -> void:
	Sfx.play(race, &"squish", -6.0)
	h.racer.camera.shake(0.5)
