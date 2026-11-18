class_name RaceItems
extends Node
## Itens das caixas na corrida (os poderes estão descritos em RaceItem).
##
## Cada kart guarda um item por vez. Ao passar por uma caixa sem item, a roleta gira
## (ROLL_TIME) e sorteia um poder conforme a posição: quem está atrás tem mais chance do
## Deságio, o líder nunca o recebe. Com item guardado (ou girando) a caixa não dá outro.
## O jogador usa com o botão "usar_item" (o slot fica no canto superior esquerdo do HUD,
## ItemSlot); o piloto do computador espera um pouco e usa quando faz sentido. Para o
## computador não emendar um poder no outro, cada item tem um tempo de espera depois que
## alguém o usa (RaceItem.cooldown) — o jogador pode usar quando quiser.
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

	func is_human() -> bool:
		return racer.slot != null

	func is_free() -> bool:
		return item == RaceItem.NONE and incoming == RaceItem.NONE


## A corrida (race.gd).
var race: Node3D
var effects: ItemEffects
## false no contra-relógio e sem rivais (as caixas não dão nada).
var enabled := true
var _holders: Array[Holder] = []
var _cooldown := PackedFloat32Array()


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
	effects.prewarm(on, k, Transform3D(Basis.looking_at(-fwd, Vector3.UP), at))


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
		if not racing or h.item == RaceItem.NONE or h.racer.finished:
			continue
		if h.is_human():
			if Input.is_action_just_pressed(h.racer.slot.action(&"usar_item")):
				_use(h)
		else:
			_think(h, delta)


func _on_item_box(_box: Node3D, h: Holder) -> void:
	if not enabled or not h.is_free() or h.racer.finished:
		return
	var kind := _draw_item(h)
	_start_incoming(h, kind, ROLL_TIME)
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
	if RaceItem.is_auto(h.item) and race.is_racing():
		_use(h)


## Sorteio pela posição (0 = líder, 1 = último). `no_cessao`: a Cessão não sai.
func _draw_item(h: Holder, no_cessao := false) -> int:
	var count: int = race.racers.size()
	var place: int = h.racer.place
	var p := float(place - 1) / maxf(count - 1, 1.0)
	var weights := PackedFloat32Array([0.0, 0.0, 0.0])
	var desagio_out := _cooldown[RaceItem.Kind.DESAGIO] > 0.0 or _in_play(RaceItem.Kind.DESAGIO)
	weights[RaceItem.Kind.DESAGIO] = 0.0 if p < 0.34 or desagio_out else lerpf(0.3, 1.3, p)
	# O líder também pode tirar Juridiquês (sem ninguém à frente, a tinta pega quem vem atrás).
	weights[RaceItem.Kind.JURIDIQUES] = 0.6 if place == 1 else lerpf(1.1, 0.9, p)
	if not no_cessao:
		weights[RaceItem.Kind.CESSAO] = lerpf(0.8, 1.0, p) if _steal_target(h) else 0.25
	var total := 0.0
	for w in weights:
		total += w
	if total <= 0.0:
		return RaceItem.Kind.JURIDIQUES
	var pick := randf() * total
	for i in weights.size():
		pick -= weights[i]
		if pick <= 0.0 and weights[i] > 0.0:
			return i
	return RaceItem.Kind.JURIDIQUES


## Alguém tem (ou está recebendo) este item?
func _in_play(kind: int) -> bool:
	for h in _holders:
		if h.item == kind or h.incoming == kind:
			return true
	return false


# --- Usar --------------------------------------------------------------------------

func _use(h: Holder) -> void:
	var kind := h.item
	if kind == RaceItem.NONE:
		return
	h.item = RaceItem.NONE
	_cooldown[kind] = RaceItem.cooldown(kind)
	if h.is_human():
		h.racer.hud.use_item()
	match kind:
		RaceItem.Kind.DESAGIO:
			_desagio(h)
		RaceItem.Kind.JURIDIQUES:
			_juridiques(h)
		RaceItem.Kind.CESSAO:
			_cessao(h)


## Deságio: raio em todos os rivais (rodam e encolhem) e o "−%" no céu. Quem usou
## volta ao tamanho normal, se estava pequeno.
func _desagio(h: Holder) -> void:
	h.kart.grow()
	effects.sky_sign()
	Sfx.play(race, &"thunder", -3.0)
	var count: int = race.racers.size()
	for o in _holders:
		if o == h or o.racer.finished:
			continue
		var p := float(o.racer.place - 1) / maxf(count - 1, 1.0)
		o.kart.zap(lerpf(SHRINK_TIME.y, SHRINK_TIME.x, p))
		effects.strike(o.kart)
	for o in _holders:
		if not o.is_human():
			continue
		var hit: bool = o != h and not o.racer.finished
		o.racer.hud.flash(Color(1.0, 0.98, 0.8), 0.8 if hit else 0.45)
		o.racer.camera.shake(0.7 if hit else 0.3)
	if h.kart.driver:
		h.kart.driver.set_face(&"face_happy", 1.5)


## Juridiquês: tinta na tela de quem está à frente (o líder que usa acerta todo mundo).
func _juridiques(h: Holder) -> void:
	var targets: Array[Holder] = []
	for o in _holders:
		if o != h and not o.racer.finished and o.racer.place < h.racer.place:
			targets.append(o)
	if targets.is_empty():
		for o in _holders:
			if o != h and not o.racer.finished:
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


## Cessão de crédito: rouba o item de um rival. Sem ninguém com item, o crédito vem
## novo: a roleta gira de novo (sem a Cessão).
func _cessao(h: Holder) -> void:
	var target := _steal_target(h)
	if target == null:
		var kind := _draw_item(h, true)
		_start_incoming(h, kind, ROLL_TIME)
		if h.is_human():
			h.racer.hud.roll_item(kind, ROLL_TIME)
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


# --- Computador ------------------------------------------------------------------------

## O piloto do computador decide se usa o item agora.
func _think(h: Holder, delta: float) -> void:
	h.held += delta
	h.ai_timer -= delta
	if h.ai_timer > 0.0:
		return
	var kind := h.item
	var ready := _cooldown[kind] <= 0.0 and not h.kart.is_spinning()
	match kind:
		RaceItem.Kind.JURIDIQUES:
			# Só com alguém à frente para levar a tinta.
			ready = ready and h.racer.place > 1
		RaceItem.Kind.CESSAO:
			ready = ready and (_steal_target(h) != null or h.held > AI_CESSAO_PATIENCE)
	if ready:
		_use(h)
	else:
		h.ai_timer = randf_range(0.8, 2.0)


# --- Sons e reações do jogador -----------------------------------------------------

func _on_human_shrunk(on: bool, h: Holder) -> void:
	Sfx.play(race, &"shrink" if on else &"grow", -8.0)
	if not on:
		h.racer.camera.shake(0.15)


func _on_human_squashed(h: Holder) -> void:
	Sfx.play(race, &"squish", -6.0)
	h.racer.camera.shake(0.5)
