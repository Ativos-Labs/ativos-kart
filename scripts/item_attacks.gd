class_name ItemAttacks
extends Node3D
## Itens de Ataque em jogo (RaceItems chama throw_* quando alguém usa um; os poderes
## estão descritos em RaceItem):
## - Carimbo INDEFERIDO: voa baixo em linha reta (para trás, se jogado segurando o freio)
##   e ricocheteia nas muretas — o limite lateral da pista, onde elas ficam — até
##   STAMP_BOUNCES batidas ou STAMP_LIFE s. Depois da primeira batida (ou de SAFE_TIME)
##   acerta até quem jogou, como no Mario Kart. Quem leva roda, perde moedas e fica com a
##   marca "INDEFERIDO" estampada atrás do kart.
## - Intimação: o envelope voa pela pista (num trilho, como o ofício da Superpreferência)
##   atrás do kart que estava logo à frente de quem jogou; perto dele (HOMING_GAP) vai
##   direto nele. Acerta quem encontrar no caminho. Jogada pelo líder, segue a pista sem
##   alvo até acabar o tempo.
## - PEC dos Precatórios: a Constituição sobe e voa alto pela pista até o 1º lugar (troca
##   de alvo se outro passar a liderar antes de ela passar dele), para em cima dele, cai
##   de chapa e o deixa parcelado (Kart.parcel); quem está perto roda.
## - Impugnação dos cálculos: a calculadora é jogada num arco para a frente (ou largada
##   atrás, segurando o freio), pousa e apita de 3 a 1; estoura no fim ou quando um kart
##   encosta, jogando todo mundo em volta (BLAST_RADIUS, quem jogou também) para o alto.
##   Carimbos e envelopes que passam por ela também a estouram.
## - Pendência documental e Fila do tribunal (armadilhas): largadas atrás do kart, caem
##   na pista e ficam lá (até TRAP_LIFE s; no máximo TRAP_MAX ao mesmo tempo). Na pilha de
##   papel o kart escorrega e roda numa chuva de folhas (ChuvaDeFolhas); a caixa falsa
##   (uma ItemBox com o logo de cabeça para baixo) estoura como uma de verdade e deixa o
##   kart parado na fila (Kart.hold_in_line) com a senha na mão (SenhaTribunal). Carimbos,
##   envelopes e a explosão da calculadora destroem as armadilhas; os pilotos do
##   computador desviam delas (trap_spots → KartAI.traps).
## - Liminar: uma onda (LiminarEscudo) em volta de quem usou destrói os tiros e as
##   armadilhas a LIMINAR_RADIUS m — e a PEC dos Precatórios, voando por perto, parada em
##   cima ou caindo, sai voando "suspensa" — e faz rodar os karts em volta.
## O jogador que é alvo de uma Intimação ou da PEC vê o aviso no alto da tela (Hud.item_alert).
## Tudo anda só em passos de física. A altura do chão vem de um raio para baixo (rampas,
## pontes) e, sem nada embaixo, da própria pista.

## Carimbo: velocidade (× a máxima de quem jogou, com um mínimo em m/s), vida (s),
## batidas na mureta, raio de acerto (m) e o tempo em que não acerta quem jogou (s).
const STAMP_SPEED := 1.55
const STAMP_MIN_SPEED := 36.0
const STAMP_LIFE := 7.0
const STAMP_BOUNCES := 5
const STAMP_RADIUS := 1.45 * KartScale.ITEMS
const SAFE_TIME := 0.6
## Folga (m) entre a mureta e o tiro quando ele bate.
const WALL_MARGIN := 0.6 * KartScale.ITEMS
## Marca "INDEFERIDO" atrás do kart: tempo na tela (s).
const MARK_TIME := 4.5
## Intimação: velocidade (× a máxima de quem jogou, mínimo m/s), quanto mais rápida que o
## alvo ela fica (m/s), vida (s), distância (m, pela pista) em que vai direto no alvo e
## raio de acerto (m).
const ENVELOPE_SPEED := 1.5
const ENVELOPE_MIN_SPEED := 36.0
const ENVELOPE_CATCH := 12.0
const ENVELOPE_LIFE := 10.0
const HOMING_GAP := 18.0
const ENVELOPE_RADIUS := 1.5 * KartScale.ITEMS
## PEC: velocidade (m/s, e quanto mais rápida que o líder), altura do voo, altura e
## distância à frente dele (m) onde ela para — baixa o bastante para a câmera do líder
## ver —, tempos (s) parada em cima, caindo, em cima do kart e subindo,
## parcelas (Kart.PARCEL_STEP cada) e o raio (m) em que quem está perto do líder roda.
const PEC_SPEED := 62.0
const PEC_CATCH := 22.0
const PEC_HEIGHT := 11.0
const PEC_HOVER_HEIGHT := 5.0 * KartScale.CAMERA
const PEC_HOVER_AHEAD := 3.5 * KartScale.CAMERA
const PEC_HOVER_TIME := 0.9
const PEC_DROP_TIME := 0.24
const PEC_STAY_TIME := 0.45
const PEC_RISE_TIME := 0.7
const PEC_PARCELS := 6
const PEC_SPLASH := 6.5 * KartScale.ITEMS
## Calculadora: arremesso (m/s para a frente além de 65% da velocidade do kart, e para cima),
## gravidade (m/s²), pavio (s, do arremesso ao estouro), tempo até ela poder estourar num
## kart (s) e até poder estourar em quem jogou (s), raio de contato e da explosão (m),
## e o pulo (m/s) de quem é pego.
const CALC_THROW_FWD := 8.0
const CALC_THROW_UP := 8.5
const CALC_GRAVITY := 28.0
const CALC_FUSE := 3.4
const CALC_ARM := 0.35
const CALC_OWNER_SAFE := 1.2
const CALC_RADIUS := 1.5 * KartScale.ITEMS
const BLAST_RADIUS := 7.0 * KartScale.ITEMS
const BLAST_LIFT := 9.0
## Armadilhas: quantas no máximo na pista (a mais velha some), vida (s), tempo até
## pegarem alguém (s) e até pegarem quem largou (s), raio de toque (m) da pilha e da caixa
## falsa (como o das caixas de verdade) e o arremesso para trás e para cima (m/s).
const TRAP_MAX := 14
const TRAP_LIFE := 80.0
const TRAP_ARM := 0.2
const TRAP_OWNER_SAFE := 0.9
const TRAP_RADIUS := 1.45 * KartScale.ITEMS
const FAKE_RADIUS := 1.65 * KartScale.ITEMS
const TRAP_TOSS := Vector2(3.0, 3.5)
## Pendência documental: fração da velocidade que sobra para quem escorrega.
const SLIP_SLOW := 0.4
## Fila do tribunal: tempo (s) parado esperando a senha.
const QUEUE_TIME := 2.4
## Liminar: raio da onda (m), até que altura (m) ela derruba a PEC e o empurrão (m/s)
## em quem está perto (some com a distância).
const LIMINAR_RADIUS := 7.0 * KartScale.ITEMS
const LIMINAR_REACH_UP := 14.0
const LIMINAR_PUSH := 10.0
## Até onde (m) um jogador ouve os tiros (mais baixo quanto mais longe).
const SOUND_REACH := 45.0

enum Phase { FLY, HOMING, HOVER, DROP, STAY, RISE, AIR, GROUND, BOOM }


## Um item de Ataque em jogo.
class Shot:
	var kind := RaceItem.NONE
	var owner: RaceItems.Holder
	var target: RaceItems.Holder
	var node: Node3D
	var phase := Phase.FLY
	var pos := Vector3.ZERO
	## Direção do voo (no plano) e velocidade (m/s); a calculadora usa `vel`.
	var dir := Vector3.FORWARD
	var speed := 0.0
	var vel := Vector3.ZERO
	var age := 0.0
	var timer := 0.0
	## Amostra da pista mais perto (dica para a busca).
	var index := -1
	## No trilho (Intimação, PEC): metros pela pista, lado (m, + = direita), a diferença
	## para o ponto de partida (some aos poucos) e a altura do chão suavizada.
	var progress := 0.0
	var lateral := 0.0
	var offset := Vector3.ZERO
	var ground := NAN
	var bounces := 0
	var fuse := 0.0
	var beep := 0.0
	var dead := false
	## Alvo escolhido (modo dev): a PEC não troca de alvo quando o líder muda, o
	## envelope voa por mais tempo e a calculadora corrige o rumo no ar sem bater nas
	## muretas (o rival que jogou pode estar bem longe, e a reta até o alvo corta as curvas).
	var locked := false
	## Armadilha: número de 0 a 1 sorteado ao largar (cada piloto do computador "vê" ou
	## não cada uma, veja KartAI.traps).
	var seed := 0.0


var race: Node3D
var items: RaceItems
## Armadilhas paradas na pista: (x, y, z, w) com w = o `seed` dela (Pendência) ou 1 +
## `seed` (a caixa falsa). Os pilotos do computador olham este mesmo array (KartAI.traps).
var trap_spots: Array[Vector4] = []
var _shots: Array[Shot] = []
## Chuvas de folhas e escudos da Liminar (reusados), e a senha de cada kart.
var _folhas: Array[ChuvaDeFolhas] = []
var _escudos: Array[LiminarEscudo] = []
var _senhas := {}
var _world_labels: Array[Label3D] = []
## Malha da caixa falsa e a sombra dela (as mesmas para todas).
static var _fake_mesh: ArrayMesh
static var _box_shadow: PlaneMesh
## Nós guardados para reusar, por tipo.
var _free := {}
var _marks := {}
var _pops := {}
var _parcel_labels := {}
var _tweens := {}
## Aviso mostrado no HUD de cada jogador (Holder → tipo).
var _alerts := {}
var _ray := PhysicsRayQueryParameters3D.new()
var _line: RacingLine


func setup(p_items: RaceItems, line: RacingLine) -> void:
	name = "Ataques"
	items = p_items
	race = items.race
	_line = line
	var rids: Array[RID] = []
	for h in items.holders():
		rids.append(h.kart.get_rid())
		h.kart.parcel_paid.connect(_on_parcel_paid.bind(h))
	_ray.exclude = rids
	_ray.collide_with_areas = false


## Algum deste tipo em jogo?
func has_kind(kind: int) -> bool:
	for s in _shots:
		if s.kind == kind and not s.dead:
			return true
	return false


# --- Jogar -----------------------------------------------------------------------

## Carimbo INDEFERIDO: sai reto para a frente (ou para trás). Com `target` (modo dev)
## sai na direção de onde esse kart vai estar quando o carimbo chegar.
func throw_stamp(h: RaceItems.Holder, backward: bool, target: RaceItems.Holder = null) -> void:
	var k := h.kart
	var dir := -k.get_forward() if backward else k.get_forward()
	var s := _new_shot(RaceItem.Kind.CARIMBO, h)
	s.speed = maxf(k.max_speed * STAMP_SPEED, STAMP_MIN_SPEED)
	if not backward:
		s.speed = maxf(s.speed, k.speed + 14.0)
	if target:
		dir = _lead_dir(k.global_position, target.kart, s.speed, dir)
	s.dir = dir
	s.pos = k.global_position + dir * 2.4 * KartScale.ITEMS + Vector3.UP * CarimboIndeferido.HOVER
	_show(s)
	_sound_at(s.pos, &"item_use", -5.0)


## Intimação: o envelope vai atrás do kart logo à frente de quem jogou (ou de `target`,
## no modo dev).
func throw_envelope(h: RaceItems.Holder, target: RaceItems.Holder = null) -> void:
	var k := h.kart
	var s := _new_shot(RaceItem.Kind.INTIMACAO, h)
	s.target = target if target else _ahead_of(h)
	s.locked = target != null
	s.progress = h.racer.progress + 2.0
	s.lateral = _clamp_lateral(_lateral_of(h), 1.2)
	s.speed = maxf(k.max_speed * ENVELOPE_SPEED, ENVELOPE_MIN_SPEED)
	s.dir = k.get_forward()
	s.pos = k.global_position + s.dir * 1.6 * KartScale.ITEMS + Vector3.UP * IntimacaoEnvelope.HOVER
	s.offset = s.pos - _rail_pos(s, IntimacaoEnvelope.HOVER, 1.0)
	_show(s)
	_sound_at(s.pos, &"paper", -5.0, 1.2)


## PEC dos Precatórios: a Constituição sobe do kart e voa até o líder (ou até `target`,
## no modo dev, mesmo que ele não seja o líder).
func throw_pec(h: RaceItems.Holder, target: RaceItems.Holder = null) -> void:
	var k := h.kart
	var s := _new_shot(RaceItem.Kind.PEC, h)
	s.target = target if target else _leader()
	s.locked = target != null
	s.progress = h.racer.progress
	s.lateral = _clamp_lateral(_lateral_of(h), 2.0)
	s.speed = PEC_SPEED * 0.5
	s.dir = k.get_forward()
	s.pos = k.global_position + Vector3.UP * 2.5 * KartScale.ITEMS
	s.offset = s.pos - _rail_pos(s, PEC_HEIGHT, 1.0)
	_show(s)
	var book := s.node as PecConstituicao
	book.scale = Vector3.ONE * 0.15 * KartScale.ITEMS
	var tw := _tween(book)
	tw.tween_property(book, "scale", Vector3.ONE * KartScale.ITEMS, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_sound_at(s.pos, &"paper", -3.0, 0.7)


## Impugnação dos cálculos: a calculadora vai num arco para a frente (ou cai atrás). Com
## `target` (modo dev) o arco cai logo na frente desse kart.
func throw_calc(h: RaceItems.Holder, backward: bool, target: RaceItems.Holder = null) -> void:
	var k := h.kart
	var fwd := k.get_forward()
	var s := _new_shot(RaceItem.Kind.IMPUGNACAO, h)
	s.phase = Phase.AIR
	s.fuse = CALC_FUSE
	s.beep = 0.0
	if backward:
		s.pos = k.global_position + (Vector3.UP * 0.9 - fwd * 2.2) * KartScale.ITEMS
		s.vel = -fwd * 3.0 + Vector3.UP * 3.0
	else:
		s.pos = k.global_position + (Vector3.UP * 1.4 + fwd * 1.4) * KartScale.ITEMS
		s.vel = fwd * (maxf(k.speed, 0.0) * 0.65 + CALC_THROW_FWD) + Vector3.UP * CALC_THROW_UP
	if target and not backward:
		# Cai onde o alvo vai estar (seguindo a pista, não em linha reta); de longe o arco
		# fica mais alto e demorado.
		var gap := Vector2(target.kart.global_position.x - s.pos.x, target.kart.global_position.z - s.pos.z).length()
		var t := clampf(gap / 28.0, 0.75, 2.2)
		var track: Track = race.track
		var ahead: float = target.racer.progress + maxf(target.kart.speed, 0.0) * t
		var land := track.global_transform * track.get_transform_at(ahead, _lateral_of(target)).origin
		var flat := land - s.pos
		var rise := flat.y
		flat.y = 0.0
		s.vel = flat / t + Vector3.UP * ((rise + 0.5 * CALC_GRAVITY * t * t) / t)
		s.target = target
		s.locked = true
	var calc := _get_node(s.kind) as ImpugnacaoCalculadora
	s.node = calc
	calc.arm("3")
	var track: Track = race.track
	var along := track.get_along(track.to_local(s.pos), maxi(s.index, 0))
	var road_dir := track.global_basis * track.get_direction_at(along)
	road_dir.y = 0.0
	calc.global_transform = Transform3D(Basis.looking_at(road_dir.normalized() if road_dir.length_squared() > 0.01 else fwd, Vector3.UP), s.pos)
	calc.reset_physics_interpolation()
	_shots.append(s)
	_sound_at(s.pos, &"item_use", -6.0, 0.8)


## Pendência documental ou Fila do tribunal: a armadilha é jogada um pouco para trás e
## cai na pista. `before` (modo dev): cai na pista um pouco à frente desse kart, na faixa
## dele.
func drop_trap(h: RaceItems.Holder, kind: int, before: RaceItems.Holder = null) -> void:
	var k := h.kart
	var fwd := k.get_forward()
	_limit_traps()
	var s := _new_shot(kind, h)
	s.phase = Phase.AIR
	s.seed = randf()
	s.timer = TRAP_LIFE
	s.pos = k.global_position + (Vector3.UP * 0.8 - fwd * 2.2) * KartScale.ITEMS
	s.vel = -fwd * TRAP_TOSS.x + Vector3.UP * TRAP_TOSS.y
	if before:
		var track: Track = race.track
		var ahead: float = before.racer.progress + clampf(before.kart.speed * 0.9, 16.0, 30.0)
		var lateral := _clamp_lateral(_lateral_of(before), 1.5)
		var spot := track.global_transform * track.get_transform_at(ahead, lateral).origin
		# Numa ponte a pista "de baixo" fica no chão: cai da altura do kart.
		spot.y = maxf(spot.y, before.kart.global_position.y)
		s.pos = spot + Vector3.UP * 2.0
		s.vel = Vector3.ZERO
		s.index = maxi(before.racer.index, 0)
	if kind == RaceItem.Kind.FILA:
		var box := _get_node(kind) as ItemBox
		box.restore()
		s.node = box
	else:
		s.node = _get_node(kind)
		s.node.call(&"reset")
	s.node.scale = Vector3.ONE * _scale_of(kind)
	s.dir = fwd
	_place_trap(s)
	s.node.reset_physics_interpolation()
	s.node.visible = true
	_shots.append(s)
	_sound_at(s.pos, &"paper" if kind == RaceItem.Kind.PENDENCIA else &"item_use", -8.0, 1.2)


## Liminar: a onda em volta de `h` faz rodar quem está perto e destrói os tiros, as
## armadilhas e a PEC que estiverem no alcance. Devolve quantas coisas ela pegou.
func liminar(h: RaceItems.Holder) -> int:
	var k := h.kart
	var center := k.global_position
	_get_escudo().play(k, LIMINAR_RADIUS)
	_sound_at(center, &"horn", 0.0, 1.0, 90.0)
	_shake_near(center, LIMINAR_RADIUS * 2.5, 0.6)
	var hits := 0
	for o in items.holders():
		if o == h or o.racer.finished:
			continue
		var d := o.kart.global_position - center
		if absf(d.y) > 3.5:
			continue
		d.y = 0.0
		var dist := d.length()
		if dist > LIMINAR_RADIUS:
			continue
		var away := d / dist if dist > 0.05 else o.kart.get_forward()
		if o.kart.hit_by_item(away * lerpf(LIMINAR_PUSH, LIMINAR_PUSH * 0.5, dist / LIMINAR_RADIUS), 0.45, 1.0):
			hits += 1
			if o.kart.driver:
				o.kart.driver.set_face(&"face_surprised", 1.4)
			if o.is_human():
				o.racer.hud.flash(Color(0.75, 1.0, 0.82), 0.45)
	for s in _shots:
		if s.dead:
			continue
		var d := s.pos - center
		var flat := Vector2(d.x, d.z).length()
		if s.kind == RaceItem.Kind.PEC:
			# A PEC é pega voando por perto, parada em cima ou caindo (alta, vale mais longe).
			if s.phase in [Phase.FLY, Phase.HOVER, Phase.DROP, Phase.STAY] and flat < LIMINAR_RADIUS * 1.3 \
					and d.y < LIMINAR_REACH_UP and d.y > -4.0:
				_suspend_pec(s, h)
				hits += 1
			continue
		if flat > LIMINAR_RADIUS or absf(d.y) > 4.0 or s.phase == Phase.BOOM:
			continue
		if s.kind == RaceItem.Kind.PENDENCIA or s.kind == RaceItem.Kind.FILA:
			_break_trap(s, Vector3(d.x, 0.0, d.z).normalized() * 6.0)
		else:
			# Carimbos e envelopes somem; a calculadora é desarmada (some sem estourar).
			_vanish(s)
		hits += 1
	if h.is_human():
		h.racer.hud.flash(Color(0.8, 1.0, 0.85), 0.35)
	if k.driver:
		k.driver.set_face(&"face_happy", 1.4)
	return hits


## A Liminar pegou a PEC: ela sai voando longe, girando, sem cair em ninguém.
func _suspend_pec(s: Shot, by: RaceItems.Holder) -> void:
	s.phase = Phase.RISE
	s.timer = PEC_RISE_TIME
	var book := s.node as PecConstituicao
	book.set_open(1.0)
	var away := s.pos - by.kart.global_position
	away.y = 0.0
	away = away.normalized() if away.length_squared() > 0.01 else -by.kart.get_forward()
	var tw := _tween(book).set_parallel()
	tw.tween_property(book, "position", book.position + Vector3.UP * 14.0 + away * 8.0, PEC_RISE_TIME) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(book, "rotation:z", book.rotation.z + TAU * 1.5, PEC_RISE_TIME)
	tw.tween_property(book, "scale", Vector3.ONE * 0.1 * KartScale.ITEMS, PEC_RISE_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# O aviso fica onde a Constituição estava (preso ao kart, na câmera de quem usou, ele
	# cobriria a tela); no HUD do alvo (e de quem usou) o "PEC A CAMINHO!" fica verde.
	_world_pop(s.pos, "PEC SUSPENSA!", Color("7ef0a8"))
	for h in [s.target, by]:
		if h and h.is_human():
			_alerts[h] = RaceItem.NONE
			h.racer.hud.item_resolved(RaceItem.Kind.PEC, "PEC SUSPENSA!")
	_sound_at(s.pos, &"boing", -3.0, 0.7, 80.0)


## Texto que aparece num ponto da pista, sobe e some (não fica preso a nenhum kart).
func _world_pop(pos: Vector3, text: String, color: Color) -> void:
	var label: Label3D = null
	for l: Label3D in _world_labels:
		if not l.visible:
			label = l
			break
	if label == null:
		if _world_labels.size() >= 3:
			label = _world_labels[0]
		else:
			label = _make_label("AvisoPista", 64)
			label.top_level = true
			add_child(label)
			_world_labels.append(label)
	label.text = text
	label.modulate = color
	label.outline_modulate = UiKit.NAVY
	label.global_position = pos
	label.scale = Vector3.ONE * 0.3
	label.visible = true
	label.reset_physics_interpolation()
	var tw := _tween(label)
	tw.tween_property(label, "scale", Vector3.ONE * 1.15, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "scale", Vector3.ONE, 0.1)
	tw.tween_property(label, "position:y", pos.y + 2.5, 1.1)
	tw.parallel().tween_property(label, "modulate:a", 0.0, 0.4).set_delay(0.7)
	tw.parallel().tween_property(label, "outline_modulate:a", 0.0, 0.4).set_delay(0.7)
	tw.tween_callback(label.hide)


## O que vem em cima de `h` a menos de `reach` m (no plano): a PEC mirando nele (voando,
## parada em cima ou caindo), uma Intimação atrás dele ou um carimbo vindo na direção
## dele. RaceItem.NONE = nada. O computador usa para decidir a Liminar e o Trânsito em
## julgado.
func threat_to(h: RaceItems.Holder, reach: float) -> int:
	var kp := h.kart.global_position
	var found := RaceItem.NONE
	for s in _shots:
		if s.dead:
			continue
		var d := s.pos - kp
		if Vector2(d.x, d.z).length() > reach:
			continue
		match s.kind:
			RaceItem.Kind.PEC:
				if s.target == h and s.phase in [Phase.FLY, Phase.HOVER, Phase.DROP]:
					return RaceItem.Kind.PEC
			RaceItem.Kind.INTIMACAO:
				if s.target == h:
					found = RaceItem.Kind.INTIMACAO
			RaceItem.Kind.CARIMBO:
				if found == RaceItem.NONE and absf(d.y) < 2.0 and s.dir.dot(-d) > 0.0:
					found = RaceItem.Kind.CARIMBO
	return found


func _new_shot(kind: int, h: RaceItems.Holder) -> Shot:
	var s := Shot.new()
	s.kind = kind
	s.owner = h
	s.index = maxi(h.racer.index, 0)
	return s


## Pega um nó da reserva, põe em `s.pos` olhando para `s.dir` e começa a voar.
func _show(s: Shot) -> void:
	s.node = _get_node(s.kind)
	s.node.call(&"reset")
	s.node.scale = Vector3.ONE * _scale_of(s.kind)
	_place(s.node, s.pos, s.dir)
	s.node.reset_physics_interpolation()
	s.node.visible = true
	_shots.append(s)


# --- Quadro a quadro ---------------------------------------------------------------

func _physics_process(delta: float) -> void:
	for i in range(_shots.size() - 1, -1, -1):
		var s := _shots[i]
		s.age += delta
		match s.kind:
			RaceItem.Kind.CARIMBO:
				_move_stamp(s, delta)
			RaceItem.Kind.INTIMACAO:
				_move_envelope(s, delta)
			RaceItem.Kind.PEC:
				_move_pec(s, delta)
			RaceItem.Kind.IMPUGNACAO:
				_move_calc(s, delta)
			RaceItem.Kind.PENDENCIA, RaceItem.Kind.FILA:
				_move_trap(s, delta)
		if s.dead:
			_shots.remove_at(i)
			_release(s)
	_update_alerts()
	trap_spots.clear()
	for s in _shots:
		if not s.dead and s.phase == Phase.GROUND and (s.kind == RaceItem.Kind.PENDENCIA or s.kind == RaceItem.Kind.FILA):
			trap_spots.append(Vector4(s.pos.x, s.pos.y, s.pos.z, s.seed + (1.0 if s.kind == RaceItem.Kind.FILA else 0.0)))


## Carimbo: reto, ricocheteando no limite da pista.
func _move_stamp(s: Shot, delta: float) -> void:
	s.pos += s.dir * s.speed * delta
	if _bounce(s):
		s.bounces += 1
		(s.node as CarimboIndeferido).bump()
		_sound_at(s.pos, &"boing", -7.0, randf_range(0.9, 1.15))
	var gy := _ground_under(s)
	s.pos.y = lerpf(s.pos.y, gy + CarimboIndeferido.HOVER, 1.0 - exp(-18.0 * delta))
	s.node.global_position = s.pos
	(s.node as CarimboIndeferido).fly(delta)
	if s.age > STAMP_LIFE or s.bounces > STAMP_BOUNCES:
		_vanish(s)
		return
	if _hit_ground_items(s):
		return
	var victim := _touching(s.pos, STAMP_RADIUS, s.owner if s.age < SAFE_TIME and s.bounces == 0 else null)
	if victim:
		_hit_by_stamp(s, victim)


## Passou do limite lateral (a mureta): reflete a direção e volta para dentro.
func _bounce(s: Shot) -> bool:
	var track: Track = race.track
	var local := track.to_local(s.pos)
	s.index = track.get_closest_index(local, s.index)
	var lateral := track.get_lateral(local, s.index)
	var limit := _wall_limit()
	if absf(lateral) <= limit:
		return false
	var n := track.global_basis * track.rights[s.index] * signf(lateral)
	n.y = 0.0
	n = n.normalized()
	s.pos -= n * (absf(lateral) - limit)
	if s.kind in [RaceItem.Kind.IMPUGNACAO, RaceItem.Kind.PENDENCIA, RaceItem.Kind.FILA]:
		var along := Vector3(s.vel.x, 0.0, s.vel.z).dot(n)
		if along <= 0.0:
			return false
		s.vel -= n * along * 1.6
		return true
	var out := s.dir.dot(n)
	if out <= 0.0:
		return false
	s.dir = s.dir - n * 2.0 * out
	s.dir.y = 0.0
	s.dir = s.dir.normalized()
	return true


## Intimação: trilho pela pista até perto do alvo, depois direto nele.
func _move_envelope(s: Shot, delta: float) -> void:
	if s.target and s.target.racer.finished:
		s.target = null
		s.phase = Phase.FLY
	var before := s.pos
	if s.phase == Phase.HOMING and s.target:
		var aim := s.target.kart.global_position + Vector3.UP * 0.7 * KartScale.ITEMS
		s.speed = maxf(s.speed, s.target.kart.speed + ENVELOPE_CATCH)
		var to := aim - s.pos
		var step := s.speed * delta
		s.pos = aim if to.length() <= step else s.pos + to.normalized() * step
		s.progress += step
	else:
		var goal := _line.lateral_at(s.progress + 15.0) * 0.6 if _line else 0.0
		if s.target:
			goal = _lateral_of(s.target)
			s.speed = maxf(s.speed, s.target.kart.speed + ENVELOPE_CATCH)
			if s.target.racer.progress - s.progress < HOMING_GAP:
				s.phase = Phase.HOMING
		s.progress += s.speed * delta
		s.lateral = move_toward(s.lateral, _clamp_lateral(goal, 1.0), 9.0 * delta)
		s.offset *= exp(-6.0 * delta)
		s.pos = _rail_pos(s, IntimacaoEnvelope.HOVER, delta) + s.offset
	var moved := s.pos - before
	moved.y = 0.0
	if moved.length_squared() > 0.0001:
		s.dir = s.dir.slerp(moved.normalized(), 1.0 - exp(-14.0 * delta)).normalized()
	_place(s.node, s.pos, s.dir)
	(s.node as IntimacaoEnvelope).fly(delta)
	if s.age > (ENVELOPE_LIFE * 3.0 if s.locked else ENVELOPE_LIFE):
		_vanish(s)
		return
	if _hit_ground_items(s):
		return
	var victim := _touching(s.pos, ENVELOPE_RADIUS, s.owner)
	if victim:
		_hit_by_envelope(s, victim)


## PEC: voa alto até o líder, para em cima, cai, fica um instante e sobe.
func _move_pec(s: Shot, delta: float) -> void:
	var book := s.node as PecConstituicao
	match s.phase:
		Phase.FLY:
			if s.locked and (s.target == null or s.target.racer.finished):
				s.locked = false
			var lead := _leader()
			if not s.locked and lead and lead != s.target and (s.target == null or s.target.racer.finished \
					or lead.racer.progress > s.progress):
				s.target = lead
			if s.target == null:
				_vanish(s)
				return
			var gap: float = s.target.racer.progress - s.progress
			s.speed = move_toward(s.speed, maxf(PEC_SPEED, s.target.kart.speed + PEC_CATCH), 40.0 * delta)
			s.progress += minf(s.speed * delta, maxf(gap, 0.0))
			s.lateral = move_toward(s.lateral, _clamp_lateral(_lateral_of(s.target), 1.0), 10.0 * delta)
			s.offset *= exp(-2.5 * delta)
			var before := s.pos
			s.pos = _rail_pos(s, PEC_HEIGHT, delta) + s.offset
			var moved := s.pos - before
			moved.y = 0.0
			if moved.length_squared() > 0.0001:
				s.dir = s.dir.slerp(moved.normalized(), 1.0 - exp(-6.0 * delta)).normalized()
			_place(book, s.pos, s.dir)
			book.fly(delta)
			if gap < 4.0 and s.offset.length() < 3.0:
				s.phase = Phase.HOVER
				s.timer = PEC_HOVER_TIME
				_sound_at(s.pos, &"alarm", -8.0, 1.0, 80.0)
		Phase.HOVER:
			s.timer -= delta
			var tk := s.target.kart
			var above := tk.global_position + Vector3.UP * PEC_HOVER_HEIGHT + tk.get_forward() * PEC_HOVER_AHEAD
			s.pos = s.pos.lerp(above, 1.0 - exp(-10.0 * delta))
			s.dir = s.dir.slerp(s.target.kart.get_forward(), 1.0 - exp(-4.0 * delta)).normalized()
			_place(book, s.pos, s.dir)
			book.fly(delta * 2.0)
			if s.timer <= 0.0 or s.target.racer.finished:
				s.phase = Phase.DROP
				s.timer = PEC_DROP_TIME
				s.offset = s.pos - s.target.kart.global_position
		Phase.DROP:
			s.timer -= delta
			var k := 1.0 - clampf(s.timer / PEC_DROP_TIME, 0.0, 1.0)
			var land := Vector3.UP * (PecConstituicao.SIZE.y * 0.5 + 0.35) * KartScale.ITEMS
			s.pos = s.target.kart.global_position + s.offset.lerp(land, k * k)
			book.set_open(1.0 - k)
			_place(book, s.pos, s.dir)
			book.fly(delta, 0.0)
			if s.timer <= 0.0:
				_pec_impact(s)
		Phase.STAY:
			s.timer -= delta
			s.pos = s.target.kart.global_position + Vector3.UP * (PecConstituicao.SIZE.y * 0.5 + 0.35) * KartScale.ITEMS
			book.global_position = s.pos
			if s.timer <= 0.0:
				s.phase = Phase.RISE
				s.timer = PEC_RISE_TIME
				if not s.target.kart.is_super():
					s.target.kart.parcel(PEC_PARCELS)
				var tw := _tween(book).set_parallel()
				tw.tween_property(book, "position", book.position + Vector3.UP * 9.0 + s.dir * 4.0, PEC_RISE_TIME) \
						.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				tw.tween_property(book, "rotation:y", book.rotation.y + 1.6, PEC_RISE_TIME)
				tw.tween_property(book, "scale", Vector3.ONE * 0.1 * KartScale.ITEMS, PEC_RISE_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				book.set_open(1.0)
		Phase.RISE:
			s.timer -= delta
			book.fly(delta)
			if s.timer <= 0.0:
				s.dead = true


## A Constituição bateu: o líder fica amassado e (quando ela sobe) parcelado; quem está
## perto roda. O ofício da Superpreferência não sente nada.
func _pec_impact(s: Shot) -> void:
	var t := s.target
	var k := t.kart
	s.phase = Phase.STAY
	s.timer = PEC_STAY_TIME
	(s.node as PecConstituicao).slam()
	_sound_at(k.global_position, &"slam", -2.0, 1.0, 80.0)
	_ground_ring(k.global_position, PEC_SPLASH, Color(0.95, 0.92, 0.82))
	_shake_near(k.global_position, PEC_SPLASH * 3.0, 0.9)
	if k.is_immune():
		# Ofício da Superpreferência ou Trânsito em julgado: a PEC bate e volta.
		s.timer = 0.0
		return
	k.hit_by_item(Vector3.ZERO, 0.1, 0.0)
	k.squash()
	if k.driver:
		k.driver.set_face(&"face_screaming", 1.8)
	if t.is_human():
		t.racer.hud.flash(Color(0.75, 0.82, 1.0), 0.55)
	for o in items.holders():
		if o == t or o.racer.finished:
			continue
		var d := o.kart.global_position - k.global_position
		if absf(d.y) > 3.0:
			continue
		d.y = 0.0
		if d.length() < PEC_SPLASH:
			var away := d.normalized() if d.length_squared() > 0.01 else o.kart.global_basis.x
			if o.kart.hit_by_item(away * 8.0, 0.4, 1.0) and o.kart.driver:
				o.kart.driver.set_face(&"face_surprised", 1.4)
	if s.owner.kart.driver and s.owner != t:
		s.owner.kart.driver.set_face(&"face_happy", 1.5)


## Calculadora: arco no ar, pousa, escorrega um pouco e apita até estourar.
func _move_calc(s: Shot, delta: float) -> void:
	var calc := s.node as ImpugnacaoCalculadora
	if s.phase == Phase.BOOM:
		s.timer -= delta
		if s.timer <= 0.0:
			s.dead = true
		return
	s.fuse -= delta
	s.beep -= delta
	var guided := s.locked and s.phase == Phase.AIR
	if guided and s.target and not s.target.racer.finished:
		_guide_calc(s)
	s.pos += s.vel * delta
	if not guided:
		_bounce(s)
	var gy := _ground_under(s)
	if s.phase == Phase.AIR:
		s.vel.y -= CALC_GRAVITY * delta
		calc.tumble(delta)
		if s.pos.y <= gy and s.vel.y < 0.0:
			s.pos.y = gy
			if s.vel.y < -6.0:
				# Quica uma vez.
				s.vel.y = -s.vel.y * 0.3
				s.vel.x *= 0.5
				s.vel.z *= 0.5
			else:
				s.vel.y = 0.0
				s.phase = Phase.GROUND
			calc.land()
			_sound_at(s.pos, &"bump", -10.0, 1.6)
	else:
		s.pos.y = lerpf(s.pos.y, gy, 1.0 - exp(-20.0 * delta))
		s.vel = Vector3(s.vel.x, 0.0, s.vel.z).move_toward(Vector3.ZERO, 26.0 * delta)
	calc.global_position = s.pos
	if s.beep <= 0.0 and s.phase == Phase.GROUND:
		s.beep = 1.0 if s.fuse > 1.2 else 0.22
		calc.beep(_calc_text(s.fuse))
		_sound_at(s.pos, &"calc_beep", -9.0, 1.0 if s.fuse > 1.2 else 1.15, 35.0)
	if s.fuse <= 0.0:
		_explode(s)
		return
	if s.age < CALC_ARM:
		return
	if _touching(s.pos + Vector3.UP * 0.4 * KartScale.ITEMS, CALC_RADIUS, s.owner if s.age < CALC_OWNER_SAFE else null):
		_explode(s)


## Calculadora com alvo (modo dev): no ar, acerta o rumo para cair em cima dele (onde ele
## vai estar quando ela descer).
func _guide_calc(s: Shot) -> void:
	var tk := s.target.kart
	var drop := s.pos.y - (tk.global_position.y + 0.5 * KartScale.ITEMS)
	var disc := s.vel.y * s.vel.y + 2.0 * CALC_GRAVITY * drop
	if disc < 0.0:
		return
	var left := (s.vel.y + sqrt(disc)) / CALC_GRAVITY
	if left < 0.05:
		return
	var aim := tk.global_position + tk.velocity * left - s.pos
	s.vel.x = aim.x / left
	s.vel.z = aim.z / left


func _calc_text(fuse: float) -> String:
	return "ERRO" if fuse < 0.45 else str(clampi(ceili(fuse - 0.4), 1, 3))


## Estoura a calculadora: todo mundo em volta (até quem jogou) é jogado para o alto.
func _explode(s: Shot) -> void:
	if s.phase == Phase.BOOM:
		return
	s.phase = Phase.BOOM
	s.timer = ImpugnacaoCalculadora.NUMBERS_TIME
	(s.node as ImpugnacaoCalculadora).explode()
	_sound_at(s.pos, &"boom", -1.0, 1.0, 70.0)
	_shake_near(s.pos, BLAST_RADIUS * 3.0, 0.8)
	for o in items.holders():
		if o.racer.finished:
			continue
		var d := o.kart.global_position - s.pos
		if absf(d.y) > 3.5:
			continue
		d.y = 0.0
		var dist := d.length()
		if dist > BLAST_RADIUS:
			continue
		var away := d / dist if dist > 0.05 else o.kart.get_forward()
		var k := 1.0 - dist / BLAST_RADIUS
		if o.kart.hit_by_item(away * lerpf(4.0, 10.0, k), 0.25, 2.0, BLAST_LIFT * lerpf(0.6, 1.0, k)):
			if o.kart.driver:
				o.kart.driver.set_face(&"face_screaming", 1.6)
			if o.is_human():
				o.racer.hud.flash(Color(1.0, 0.85, 0.5), 0.5 * k + 0.2)
	# As armadilhas em volta também vão pelos ares.
	for t in _shots:
		if t.dead or not _is_trap(t):
			continue
		var d := t.pos - s.pos
		if absf(d.y) < 3.5 and Vector2(d.x, d.z).length() < BLAST_RADIUS:
			_break_trap(t, Vector3(d.x, 0.0, d.z).normalized() * 6.0)


## Um carimbo ou envelope passou por uma calculadora no chão (os dois estouram) ou por
## uma armadilha (os dois somem).
func _hit_ground_items(s: Shot) -> bool:
	for c in _shots:
		if c.dead or c == s:
			continue
		if c.kind == RaceItem.Kind.IMPUGNACAO and c.phase != Phase.BOOM:
			var d := c.pos + Vector3.UP * 0.4 - s.pos
			if absf(d.y) < 1.6 and Vector2(d.x, d.z).length() < 1.4:
				_explode(c)
				_vanish(s)
				return true
		elif _is_trap(c):
			var d := _trap_center(c) - s.pos
			if absf(d.y) < 1.8 and Vector2(d.x, d.z).length() < 1.5:
				_break_trap(c, s.dir * 6.0)
				_vanish(s)
				return true
	return false


# --- Armadilhas ----------------------------------------------------------------------

func _is_trap(s: Shot) -> bool:
	return s.kind == RaceItem.Kind.PENDENCIA or s.kind == RaceItem.Kind.FILA


## Meio da armadilha (a caixa falsa flutua na altura das caixas de verdade).
func _trap_center(s: Shot) -> Vector3:
	if s.kind == RaceItem.Kind.FILA:
		return s.pos + Vector3.UP * ItemBox.FLOAT_HEIGHT
	return s.pos + Vector3.UP * 0.25


func _place_trap(s: Shot) -> void:
	s.node.global_position = s.pos + (Vector3.UP * ItemBox.FLOAT_HEIGHT if s.kind == RaceItem.Kind.FILA else Vector3.ZERO)


## Cai (arco curto) e fica parada na pista até alguém passar por cima ou o tempo acabar.
func _move_trap(s: Shot, delta: float) -> void:
	if s.phase == Phase.AIR:
		s.vel.y -= CALC_GRAVITY * delta
		s.pos += s.vel * delta
		_bounce(s)
		var gy := _ground_under(s)
		if s.pos.y <= gy and s.vel.y < 0.0:
			s.pos.y = gy
			s.vel = Vector3.ZERO
			s.phase = Phase.GROUND
			if s.node is PendenciaPapelada:
				(s.node as PendenciaPapelada).land()
			_sound_at(s.pos, &"paper", -14.0, 1.4, 25.0)
		_place_trap(s)
	s.timer -= delta
	if s.timer <= 0.0:
		_vanish(s)
		return
	if s.age < TRAP_ARM:
		return
	var radius := FAKE_RADIUS if s.kind == RaceItem.Kind.FILA else TRAP_RADIUS
	var victim := _touching(_trap_center(s), radius, s.owner if s.age < TRAP_OWNER_SAFE else null)
	if victim:
		_trap_hit(s, victim)


## Um kart passou pela armadilha. Na pilha de papel ele escorrega e roda numa chuva de
## folhas; na caixa falsa ela estoura como uma de verdade e ele fica parado na fila com
## a senha. Invencível (Trânsito em julgado, ofício), ele só a destrói.
func _trap_hit(s: Shot, h: RaceItems.Holder) -> void:
	var k := h.kart
	var center := _trap_center(s)
	if s.kind == RaceItem.Kind.PENDENCIA:
		_vanish(s)
		_paper_burst(s.pos + Vector3.UP * 0.3, k.velocity)
		_sound_at(center, &"paper", -3.0, 0.9)
		if k.hit_by_item(k.get_forward() * 1.5, SLIP_SLOW, 1.0):
			_sound_at(center, &"spin", -7.0)
			if k.driver:
				k.driver.set_face(&"face_surprised", 1.5)
			if s.owner != h and s.owner.kart.driver:
				s.owner.kart.driver.set_face(&"face_happy", 1.2)
		return
	_vanish(s)
	(s.node as ItemBox).shatter(k.velocity)
	# Parece uma caixa de verdade... até não ser.
	_sound_at(center, &"item_box", -6.0)
	if not k.hold_in_line(QUEUE_TIME):
		return
	_senha_of(k).play(QUEUE_TIME)
	_sound_at(center, &"wrong", -5.0, 1.0, 40.0)
	if h.is_human():
		h.racer.hud.flash(Color(0.75, 0.9, 1.0), 0.35)
	if s.owner != h and s.owner.kart.driver:
		s.owner.kart.driver.set_face(&"face_happy", 1.4)


## A armadilha foi destruída (tiro, explosão, Liminar, kart invencível).
func _break_trap(s: Shot, push: Vector3) -> void:
	if s.dead:
		return
	_vanish(s)
	if s.kind == RaceItem.Kind.PENDENCIA:
		_paper_burst(s.pos + Vector3.UP * 0.3, push * 0.4)
		_sound_at(s.pos, &"paper", -6.0, 1.1)
	else:
		(s.node as ItemBox).shatter(push)
		_sound_at(s.pos, &"bump", -8.0, 1.4)


## No máximo TRAP_MAX armadilhas: a mais velha some para dar lugar à nova.
func _limit_traps() -> void:
	var count := 0
	var oldest: Shot = null
	for s in _shots:
		if s.dead or not _is_trap(s):
			continue
		count += 1
		if oldest == null or s.age > oldest.age:
			oldest = s
	if count >= TRAP_MAX and oldest:
		_vanish(oldest)


## Chuva de folhas saindo de `pos` (as folhas herdam parte de `carry`).
func _paper_burst(pos: Vector3, carry: Vector3) -> void:
	var rain: ChuvaDeFolhas = null
	for r in _folhas:
		if not r.is_busy():
			rain = r
			break
	if rain == null:
		if _folhas.size() >= 4:
			rain = _folhas[0]
		else:
			rain = ChuvaDeFolhas.new()
			add_child(rain)
			rain.build()
			_folhas.append(rain)
	rain.play(pos, carry)


func _get_escudo() -> LiminarEscudo:
	for e in _escudos:
		if not e.is_busy():
			return e
	if _escudos.size() >= 3:
		return _escudos[0]
	var e := LiminarEscudo.new()
	add_child(e)
	e.build()
	_escudos.append(e)
	return e


## A senha do kart `k` (criada na primeira vez, presa no KartVisual dele).
func _senha_of(k: Kart) -> SenhaTribunal:
	var senha: SenhaTribunal = _senhas.get(k)
	if senha == null or not is_instance_valid(senha):
		senha = SenhaTribunal.new()
		k.kart_visual.add_child(senha)
		senha.build(k)
		senha.called.connect(func(): _sound_at(k.global_position, &"senha", -4.0, 1.0, 40.0))
		_senhas[k] = senha
	return senha


# --- Acertos -----------------------------------------------------------------------

func _hit_by_stamp(s: Shot, h: RaceItems.Holder) -> void:
	var k := h.kart
	_vanish(s)
	_sound_at(s.pos, &"stamp", -2.0)
	if not k.hit_by_item(s.dir * 6.0, 0.3, 1.0):
		return
	stamp_mark(k)
	if k.driver:
		k.driver.set_face(&"face_angry", 1.6)
	if s.owner != h and s.owner.kart.driver:
		s.owner.kart.driver.set_face(&"face_happy", 1.2)


func _hit_by_envelope(s: Shot, h: RaceItems.Holder) -> void:
	var k := h.kart
	_vanish(s)
	_sound_at(s.pos, &"paper", -3.0, 1.3)
	if not k.hit_by_item(s.dir * 5.0, 0.3, 1.0):
		return
	pop_text(k, "INTIMADO!", Color("ffd27a"))
	if k.driver:
		k.driver.set_face(&"face_surprised", 1.6)
	if s.owner.kart.driver:
		s.owner.kart.driver.set_face(&"face_happy", 1.2)


## Kart encostado em `pos` (o mais perto dentro de `radius`), menos `skip` e quem já
## terminou. O ofício da Superpreferência conta (o tiro some nele sem efeito).
func _touching(pos: Vector3, radius: float, skip: RaceItems.Holder) -> RaceItems.Holder:
	var best: RaceItems.Holder = null
	var best_d := radius * radius
	for h in items.holders():
		if h == skip or h.racer.finished:
			continue
		var d := h.kart.global_position + Vector3.UP * 0.5 * KartScale.ITEMS - pos
		if absf(d.y) > 1.6 * KartScale.ITEMS:
			continue
		var l := d.x * d.x + d.z * d.z
		if l < best_d:
			best_d = l
			best = h
	return best


# --- Marcas e avisos ---------------------------------------------------------------

## A marca "INDEFERIDO" bate atrás do kart (grande, achatando) e fica alguns segundos.
func stamp_mark(k: Kart) -> void:
	var mark: MeshInstance3D = _marks.get(k)
	if mark == null or not is_instance_valid(mark):
		mark = CarimboIndeferido.make_mark()
		k.visual.add_child(mark)
		_marks[k] = mark
	var size := k.hitbox_size
	var width := clampf(size.x * 0.95, 1.0 * KartScale.ITEMS, 1.4 * KartScale.ITEMS)
	mark.position = Vector3(0.0, 0.25 + size.y * 0.7, size.z * 0.5 - 0.05)
	mark.rotation = Vector3(-0.15, 0.0, randf_range(-0.22, 0.22))
	mark.scale = Vector3.ONE * width * 2.4
	mark.transparency = 1.0
	mark.visible = true
	var tw := _tween(mark)
	tw.tween_property(mark, "scale", Vector3.ONE * width, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(mark, "transparency", 0.0, 0.1)
	tw.tween_property(mark, "scale", Vector3.ONE * width * 1.06, 0.06)
	tw.tween_property(mark, "scale", Vector3.ONE * width, 0.08)
	tw.tween_interval(MARK_TIME)
	tw.tween_property(mark, "transparency", 1.0, 0.6)
	tw.tween_callback(mark.hide)


## Texto que pula em cima do kart e some ("INTIMADO!").
func pop_text(k: Kart, text: String, color: Color) -> void:
	var label: Label3D = _pops.get(k)
	if label == null or not is_instance_valid(label):
		label = _make_label("Aviso", 74)
		k.add_child(label)
		_pops[k] = label
	label.text = text
	label.modulate = color
	label.outline_modulate = UiKit.NAVY
	label.position = Vector3(0.0, 2.3 * KartScale.ITEMS, 0.0)
	label.scale = Vector3.ONE * 0.3
	label.visible = true
	label.reset_physics_interpolation()
	var tw := _tween(label)
	tw.tween_property(label, "scale", Vector3.ONE * 1.15, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "scale", Vector3.ONE, 0.1)
	tw.tween_property(label, "position:y", 2.8 * KartScale.ITEMS, 0.9)
	tw.parallel().tween_property(label, "modulate:a", 0.0, 0.4).set_delay(0.5)
	tw.parallel().tween_property(label, "outline_modulate:a", 0.0, 0.4).set_delay(0.5)
	tw.tween_callback(label.hide)


## Parcelado: mais uma parcela (o texto, o "plim" e a cara do piloto).
func _on_parcel_paid(paid: int, total: int, h: RaceItems.Holder) -> void:
	var k := h.kart
	_show_parcel(k, paid, total)
	_sound_at(k.global_position, &"parcela", -9.0, 1.0 + 0.06 * paid, 30.0)
	if paid == 1 and k.driver:
		k.driver.set_face(&"face_confused", total * Kart.PARCEL_STEP)


## "PARCELA 2/6" em cima do kart, pulando a cada parcela; some depois da última.
func _show_parcel(k: Kart, paid: int, total: int) -> void:
	var label: Label3D = _parcel_labels.get(k)
	if label == null or not is_instance_valid(label):
		label = _make_label("Parcela", 62)
		label.modulate = Color("ffe08a")
		label.outline_modulate = Color("1d3a8a")
		k.add_child(label)
		_parcel_labels[k] = label
	label.text = "PARCELA %d/%d" % [paid, total]
	label.visible = true
	label.modulate.a = 1.0
	label.outline_modulate.a = 1.0
	label.position = Vector3(0.0, 2.2 * KartScale.ITEMS, 0.0)
	label.scale = Vector3.ONE * 1.25
	var tw := _tween(label)
	tw.tween_property(label, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if paid >= total:
		tw.tween_interval(Kart.PARCEL_STEP)
		tw.tween_property(label, "modulate:a", 0.0, 0.3)
		tw.parallel().tween_property(label, "outline_modulate:a", 0.0, 0.3)
		tw.tween_callback(label.hide)


## Aviso no HUD de quem é alvo de uma PEC (a mais importante) ou de uma Intimação.
func _update_alerts() -> void:
	for h in items.holders():
		if not h.is_human():
			continue
		var kind := RaceItem.NONE
		for s in _shots:
			if s.target != h or s.dead:
				continue
			if s.kind == RaceItem.Kind.PEC and s.phase in [Phase.FLY, Phase.HOVER, Phase.DROP]:
				kind = RaceItem.Kind.PEC
			elif s.kind == RaceItem.Kind.INTIMACAO and kind == RaceItem.NONE:
				kind = RaceItem.Kind.INTIMACAO
		if h.racer.finished:
			kind = RaceItem.NONE
		if _alerts.get(h, RaceItem.NONE) != kind:
			_alerts[h] = kind
			h.racer.hud.item_alert(kind)
			if kind != RaceItem.NONE:
				Sfx.play(race, &"alarm", -10.0)


func _make_label(node_name: String, size: int) -> Label3D:
	var label := Label3D.new()
	label.name = node_name
	label.font = UiKit.FONT_TITLE
	label.font_size = size
	label.outline_size = 18
	label.pixel_size = 0.011 * KartScale.CAMERA
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.shaded = false
	label.no_depth_test = true
	label.render_priority = 3
	label.outline_render_priority = 2
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	label.visible = false
	return label


## Anel que se espalha no chão (impacto da PEC).
func _ground_ring(pos: Vector3, radius: float, color: Color) -> void:
	var ring: MeshInstance3D = null
	for list_ring: MeshInstance3D in _free.get(&"anel", []):
		ring = list_ring
		break
	if ring:
		_free[&"anel"].erase(ring)
	else:
		ring = MeshInstance3D.new()
		ring.name = "Anel"
		ring.mesh = ImpugnacaoCalculadora.ring_mesh()
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.albedo_color = color
		ring.material_override = mat
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ring)
	ring.global_position = pos + Vector3.UP * 0.1
	ring.scale = Vector3(1.0, 1.0, 1.0)
	ring.transparency = 0.0
	ring.visible = true
	ring.reset_physics_interpolation()
	var tw := _tween(ring).set_parallel()
	tw.tween_property(ring, "scale", Vector3(radius * 1.3, 1.0, radius * 1.3), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(ring, "transparency", 1.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(_park_ring.bind(ring))


func _park_ring(ring: MeshInstance3D) -> void:
	ring.visible = false
	if not _free.has(&"anel"):
		_free[&"anel"] = []
	_free[&"anel"].append(ring)


## Treme a câmera de quem está perto de `pos` (mais forte quanto mais perto).
func _shake_near(pos: Vector3, reach: float, amount: float) -> void:
	for r in race.humans:
		var d: float = r.kart.global_position.distance_to(pos)
		if d < reach:
			r.camera.shake(amount * (1.0 - d / reach))


## Toca `sound` se algum jogador estiver a menos de `reach` m de `pos` (mais baixo
## quanto mais longe).
func _sound_at(pos: Vector3, sound: StringName, volume_db: float, pitch := 1.0, reach := SOUND_REACH) -> void:
	var best := INF
	for r in race.humans:
		best = minf(best, r.kart.global_position.distance_to(pos))
	if best > reach:
		return
	Sfx.play(race, sound, volume_db - 14.0 * best / reach, pitch)


# --- Pista -------------------------------------------------------------------------

## Lado (m) até onde o tiro vai antes de bater na mureta.
func _wall_limit() -> float:
	var track: Track = race.track
	return track.road_width * 0.5 + track.shoulder_width - WALL_MARGIN


func _clamp_lateral(lateral: float, margin: float) -> float:
	var edge := _wall_limit() - margin
	return clampf(lateral, -edge, edge)


func _lateral_of(h: RaceItems.Holder) -> float:
	var track: Track = race.track
	return track.get_lateral(track.to_local(h.kart.global_position), maxi(h.racer.index, 0))


## Ponto do trilho (pela pista, em `s.progress` e `s.lateral`) `hover` m acima do chão.
## A altura do chão é suavizada (rampas não dão tranco).
func _rail_pos(s: Shot, hover: float, delta: float) -> Vector3:
	var track: Track = race.track
	var road := track.global_transform * track.get_transform_at(s.progress, s.lateral).origin
	var gy := _ground_y(road, road.y)
	s.ground = gy if is_nan(s.ground) else lerpf(s.ground, gy, 1.0 - exp(-12.0 * delta))
	s.index = track.get_closest_index(track.to_local(road), s.index)
	return Vector3(road.x, s.ground + hover, road.z)


## Altura do chão embaixo do tiro (atualiza a amostra da pista dele).
func _ground_under(s: Shot) -> float:
	var track: Track = race.track
	var local := track.to_local(s.pos)
	s.index = track.get_closest_index(local, s.index)
	var along := track.get_along(local, s.index)
	var lateral := clampf(track.get_lateral(local, s.index), -_wall_limit(), _wall_limit())
	var road := track.global_transform * track.get_transform_at(along, lateral).origin
	return _ground_y(s.pos, road.y)


## O que a física achar embaixo de `pos` (rampas, pontes, asfalto), de um pouco acima
## dele até 4 m abaixo da pista; sem nada, a altura da pista.
func _ground_y(pos: Vector3, road_y: float) -> float:
	_ray.from = Vector3(pos.x, maxf(pos.y, road_y) + 1.5, pos.z)
	_ray.to = Vector3(pos.x, road_y - 4.0, pos.z)
	var hit := get_world_3d().direct_space_state.intersect_ray(_ray)
	return hit.position.y if hit else road_y


## Direção (no plano) para acertar `target` saindo de `from` a `speed` m/s, mirando onde
## ele vai estar (duas passadas bastam). `fallback` se o alvo está em cima de `from`.
func _lead_dir(from: Vector3, target: Kart, speed: float, fallback: Vector3) -> Vector3:
	var aim := target.global_position
	for i in 2:
		var t := Vector2(aim.x - from.x, aim.z - from.z).length() / maxf(speed, 1.0)
		aim = target.global_position + target.velocity * t
	var d := aim - from
	d.y = 0.0
	return d.normalized() if d.length_squared() > 0.25 else fallback


## O 1º colocado que ainda corre.
func _leader() -> RaceItems.Holder:
	var best: RaceItems.Holder = null
	for h in items.holders():
		if h.racer.finished:
			continue
		if best == null or h.racer.place < best.racer.place:
			best = h
	return best


## O kart logo à frente de `h` na corrida (null = ninguém).
func _ahead_of(h: RaceItems.Holder) -> RaceItems.Holder:
	var best: RaceItems.Holder = null
	for o in items.holders():
		if o == h or o.racer.finished or o.racer.progress <= h.racer.progress:
			continue
		if best == null or o.racer.progress < best.racer.progress:
			best = o
	return best


## Põe o nó em `pos` virado para `dir` (no plano), sem mexer na escala dele.
func _place(node: Node3D, pos: Vector3, dir: Vector3) -> void:
	if dir.x * dir.x + dir.z * dir.z > 0.0001:
		node.rotation = Vector3(0.0, atan2(-dir.x, -dir.z), 0.0)
	node.global_position = pos


# --- Reserva de nós ----------------------------------------------------------------

## Escala de cada tiro/armadilha: os modelos foram feitos para os karts de antes do
## encaixe piloto × kart e encolhem com eles. A caixa falsa já usa as medidas das caixas
## de verdade (ItemBox, também encolhidas).
static func _scale_of(kind: int) -> float:
	return 1.0 if kind == RaceItem.Kind.FILA else KartScale.ITEMS


func _get_node(kind: int) -> Node3D:
	var list: Array = _free.get(kind, [])
	if not list.is_empty():
		return list.pop_back()
	var node: Node3D
	match kind:
		RaceItem.Kind.CARIMBO:
			var stamp := CarimboIndeferido.new()
			add_child(stamp)
			stamp.build()
			node = stamp
		RaceItem.Kind.INTIMACAO:
			var envelope := IntimacaoEnvelope.new()
			add_child(envelope)
			envelope.build()
			node = envelope
		RaceItem.Kind.PEC:
			var book := PecConstituicao.new()
			add_child(book)
			book.build()
			node = book
		RaceItem.Kind.IMPUGNACAO:
			var calc := ImpugnacaoCalculadora.new()
			add_child(calc)
			# O nó todo encolhe (_scale_of): o círculo de perigo dentro dele fica do raio real.
			calc.build(BLAST_RADIUS / KartScale.ITEMS)
			node = calc
		RaceItem.Kind.PENDENCIA:
			var pile := PendenciaPapelada.new()
			add_child(pile)
			pile.build()
			node = pile
		RaceItem.Kind.FILA:
			if _fake_mesh == null:
				_fake_mesh = ItemBox.make_fake_mesh()
				_box_shadow = ItemBox.make_shadow_mesh()
			var box := ItemBox.new()
			box.name = "CaixaFalsa"
			box.respawns = false
			add_child(box)
			box.setup(_fake_mesh, _box_shadow)
			node = box
	return node


## Some com o tiro (encolhe rapidinho) e o devolve à reserva.
func _vanish(s: Shot) -> void:
	if s.dead:
		return
	s.dead = true
	s.node.set_meta(&"vanish", true)


func _release(s: Shot) -> void:
	var node := s.node
	if node == null:
		return
	if node is ImpugnacaoCalculadora:
		(node as ImpugnacaoCalculadora).park()
		_park(node, s.kind)
		return
	if node is ItemBox and not (node as ItemBox).active:
		# Caixa falsa estourada: guarda depois que os pedaços caem.
		if node.has_meta(&"vanish"):
			node.remove_meta(&"vanish")
		var wait := _tween(node)
		wait.tween_interval(ItemBox.SHARD_LIFE + 0.05)
		wait.tween_callback(_park.bind(node, s.kind))
		return
	if node.has_meta(&"vanish"):
		node.remove_meta(&"vanish")
		var tw := _tween(node)
		tw.tween_property(node, "scale", Vector3.ONE * 0.05 * _scale_of(s.kind), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(_park.bind(node, s.kind))
	else:
		_park(node, s.kind)


func _park(node: Node3D, kind: int) -> void:
	_kill_tween(node)
	node.visible = false
	node.scale = Vector3.ONE
	if not _free.has(kind):
		_free[kind] = []
	_free[kind].append(node)


# --- Compilar shaders ----------------------------------------------------------------

## Mostra um de cada (e as marcas no kart `near`) parados em `xf`, atrás da tela de
## carregamento (Race.warm_up), para os shaders compilarem antes da corrida.
## Os itens mostrados no prewarm, um passo cada (depois deles: a chuva de folhas, o
## escudo e as marcas no kart).
const PREWARM_KINDS: Array[int] = [RaceItem.Kind.CARIMBO, RaceItem.Kind.INTIMACAO, RaceItem.Kind.PEC,
		RaceItem.Kind.IMPUGNACAO, RaceItem.Kind.PENDENCIA, RaceItem.Kind.FILA]
## Quantos passos o prewarm tem (veja `prewarm`).
const PREWARM_STEPS := 9


## `step`: -1 = tudo; 0 a PREWARM_STEPS - 1 = só aquele passo (criar os nós de todos
## de uma vez levava ~0,2 s num quadro só; o warm_up da corrida liga um por quadro).
func prewarm(on: bool, near: Kart, xf: Transform3D, step := -1) -> void:
	for i in PREWARM_KINDS.size():
		if step >= 0 and step != i:
			continue
		var kind := PREWARM_KINDS[i]
		var key := StringName("prewarm_%d" % kind)
		var node: Node3D = get_meta(key) if has_meta(key) else null
		if on:
			if node == null:
				node = _get_node(kind)
				set_meta(key, node)
			var offset := Vector3((kind - RaceItem.Kind.CARIMBO) * 1.6 - 2.4, 0.4, -1.0)
			if kind == RaceItem.Kind.PEC:
				offset = Vector3(0.0, 4.0, -8.0)
			node.global_transform = xf.translated_local(offset)
			node.scale = Vector3.ONE
			if node is ImpugnacaoCalculadora:
				(node as ImpugnacaoCalculadora).prewarm(true)
			elif node is ItemBox:
				(node as ItemBox).restore()
				node.visible = true
			else:
				node.call(&"reset")
				node.visible = true
		elif node:
			remove_meta(key)
			if node is ImpugnacaoCalculadora:
				(node as ImpugnacaoCalculadora).prewarm(false)
			_park(node, kind)
	# Chuva de folhas e o escudo da Liminar na frente do kart.
	var kinds := PREWARM_KINDS.size()
	if step < 0 or step == kinds:
		if on and _folhas.is_empty():
			var rain := ChuvaDeFolhas.new()
			add_child(rain)
			rain.build()
			_folhas.append(rain)
		if not _folhas.is_empty():
			_folhas[0].prewarm(on, xf.translated_local(Vector3(0.0, 1.0, -3.0)).origin)
	if step < 0 or step == kinds + 1:
		if on and _escudos.is_empty():
			_get_escudo()
		if not _escudos.is_empty():
			_escudos[0].prewarm(on, xf.translated_local(Vector3(0.0, 0.0, -10.0)))
	if near == null or (step >= 0 and step != kinds + 2):
		return
	if on:
		stamp_mark(near)
		pop_text(near, "INTIMADO!", Color("ffd27a"))
		_show_parcel(near, 1, PEC_PARCELS)
		_ground_ring(near.global_position, 3.0, Color(0.95, 0.92, 0.82))
		if near.kart_visual:
			_senha_of(near).prewarm(true)
	else:
		for dict: Dictionary in [_marks, _pops, _parcel_labels]:
			var node: Node3D = dict.get(near)
			if node:
				_kill_tween(node)
				node.hide()
		if _senhas.has(near):
			(_senhas[near] as SenhaTribunal).prewarm(false)



func _tween(node: Node) -> Tween:
	_kill_tween(node)
	var tw := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_tweens[node] = tw
	return tw


func _kill_tween(node: Node) -> void:
	var tw: Tween = _tweens.get(node)
	if tw:
		tw.kill()
		_tweens.erase(node)
