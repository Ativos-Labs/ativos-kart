class_name KartAI
extends RefCounted
## Piloto controlado pelo computador. Segue a trajetória de corrida (RacingLine),
## derrapa nas curvas longas para ganhar mini-turbo, passa pelas placas de turbo,
## escolhe se pega a rampa estreita, faz manobra nos pulos, desvia dos outros karts
## e, de vez em quando, erra. Use como `kart.autopilot = ai.drive`.
##
## `skill` (0 a 1) diz o quanto ele pilota bem. `pace` multiplica a velocidade
## máxima do kart, e o elástico (`rubber_band`) acelera quem ficou para trás do
## jogador e segura quem disparou na frente, para a corrida ficar disputada.

enum Drift { NONE, HOP, ON }

## Nível do piloto: 0 = iniciante (trajetória larga, poucos drifts, erra mais),
## 1 = profissional.
var skill := 0.5
## Fração da velocidade máxima do kart com que o piloto corre.
var pace := 1.0
## Força do elástico (0 = desligado, 1 = normal).
var rubber_band := 1.0
## Distância (m) até o jogador na corrida (positivo = este kart está na frente).
## A corrida atualiza a cada quadro.
var gap_to_player := 0.0
## Depois da chegada o piloto só passeia pela pista.
var cruising := false

var kart: Kart
var track: Track
var line: RacingLine
## Todos os karts da corrida (para desviar e ultrapassar).
var karts: Array[Kart] = []

var _index := -1
var _last_along := 0.0
## Distância andada desde a largada (não volta a zero a cada volta).
var _travel := 0.0
var _lap := 0
var _time := 0.0
var _phase := 0.0
## Lado preferido na pista (m): cada piloto anda num lugar e o pelotão não vira fila.
var _lane := 0.0
var _avoid := 0.0
## Há um kart mais lento logo à frente, na mesma faixa (tira o pé para não bater).
var _blocked := false
var _mistake := 0.0
var _mistake_length := 1.0
var _mistake_offset := 0.0
var _mistake_check := 1.0

var _drift := Drift.NONE
var _drift_dir := 0
var _drift_goal := 1
var _drift_timer := 0.0
var _drift_wide := 0.0
## Até onde (em `_travel`) a curva atual já foi decidida (derrapar ou não).
var _curve_decided_until := -INF

var _trick_at := -1.0
var _was_jumping := false
var _reverse := 0.0
var _stuck := 0.0

var _ramps: Array[Dictionary] = []
var _pads := PackedFloat32Array()
## Escolhas sorteadas uma vez por volta (pegar a rampa estreita, a placa de turbo).
var _choices := {}

# Saídas do drift (preenchidas por _update_drift).
var _out_steer := 0.0
var _out_held := false
var _out_pressed := false


func setup(p_kart: Kart, p_track: Track, p_line: RacingLine, p_karts: Array[Kart], p_skill: float) -> void:
	kart = p_kart
	track = p_track
	line = p_line
	karts = p_karts
	skill = clampf(p_skill, 0.0, 1.0)
	_phase = randf() * TAU
	_lane = randf_range(-1.0, 1.0) * line.limit * 0.4
	var inner_half := track.road_width * 0.5 - track.curb_min_width - 0.1
	for r in track.ramps:
		if r == null:
			continue
		var half := inner_half * r.width
		_ramps.append({
			"lip": wrapf(r.at, 0.0, 1.0) * track.length,
			"length": r.length,
			"center": r.offset * (inner_half - half),
			"half": half,
			"narrow": r.width < 0.85,
		})
	for f in track.boost_pads:
		_pads.append(wrapf(f, 0.0, 1.0) * track.length)


## Esquece o estado da pilotagem (depois de reposicionar o kart).
func reset() -> void:
	_index = -1
	_drift = Drift.NONE
	_reverse = 0.0
	_stuck = 0.0
	_avoid = 0.0
	_mistake = 0.0
	_trick_at = -1.0


## Controle do kart neste quadro (mesmo formato do Kart._gather_input).
func drive(k: Kart) -> Dictionary:
	var delta := k.get_physics_process_delta_time()
	_time += delta
	var local := track.to_local(k.global_position)
	var first := _index < 0
	_index = track.get_closest_index(local, _index)
	var along := track.get_along(local, _index)
	if not first:
		var step := along - _last_along
		if step < -track.length * 0.5:
			step += track.length
			_lap += 1
		elif step > track.length * 0.5:
			step -= track.length
		_travel += step
	_last_along = along
	var lat_now := track.get_lateral(local, _index)
	var abs_speed := absf(k.speed)
	k.speed_multiplier = _speed_multiplier(k, delta)

	if _reverse > 0.0:
		return _drive_reverse(k, delta)

	# --- Para onde ir: um ponto da trajetória à frente (mais longe quanto mais rápido).
	var look := clampf(5.0 + abs_speed * 0.42, 7.0, 19.0)
	var target_d := along + look
	var lat := _target_lateral(k, along, target_d, lat_now, delta)
	var target_local := track.get_point_at(target_d) + _right_at(target_d) * lat
	var to_target := track.to_global(target_local) - k.global_position
	to_target.y = 0.0
	var dist := maxf(to_target.length(), 2.0)
	var alpha := k.get_forward().signed_angle_to(to_target, Vector3.UP)

	# Giro que leva o kart até o alvo (pure pursuit), em rad/s (+ = esquerda), e o
	# volante que dá esse giro (o mesmo cálculo do Kart, ao contrário).
	var yaw_wanted := abs_speed * 2.0 * sin(alpha) / dist
	var turn_factor := clampf(abs_speed / 7.0, 0.15, 1.0)
	var high_speed := lerpf(1.0, k.high_speed_turn, clampf(abs_speed / k.max_speed, 0.0, 1.0))
	var steer := clampf(yaw_wanted / (k.turn_rate * turn_factor * high_speed), -1.0, 1.0)
	if abs_speed < 4.0 or absf(alpha) > PI * 0.5:
		steer = clampf(alpha * 2.0, -1.0, 1.0)

	# --- Velocidade: alivia ou freia se a curva à frente for fechada demais.
	var throttle := 1.0
	var brake := 0.0
	var curve := line.max_curvature(along, abs_speed * 0.9 + 8.0)
	var cap := k.turn_rate * (Kart.DRIFT_TURN_TIGHT if _drift == Drift.ON else k.high_speed_turn)
	var v_safe := cap / maxf(curve, 0.001) * lerpf(0.93, 1.04, skill)
	if abs_speed > v_safe + 1.0:
		throttle = 0.0
	if abs_speed > v_safe + 5.0:
		brake = 0.35
	if _blocked:
		throttle = 0.0

	if cruising:
		throttle = 0.55 if abs_speed < k.max_speed * 0.55 else 0.0
		brake = 0.0

	# --- Drift e manobra no pulo.
	var near_ramp := _near_ramp(along)
	_update_drift(k, along, abs_speed, yaw_wanted, turn_factor, steer, near_ramp, delta)
	steer = _out_steer
	var drift_held := _out_held
	var drift_pressed := _out_pressed
	if k.ramp_jump and not _was_jumping and not cruising and randf() < lerpf(0.35, 0.95, skill):
		_trick_at = _time + randf_range(0.04, 0.28)
	_was_jumping = k.ramp_jump
	if _trick_at >= 0.0 and _time >= _trick_at:
		_trick_at = -1.0
		if k.ramp_jump:
			drift_pressed = true
			drift_held = true

	# --- Encalhado (parado contra a mureta): dá ré um pouco.
	if k.controls_enabled and not cruising and abs_speed < 1.5 and throttle > 0.5:
		_stuck += delta
		if _stuck > 1.0:
			_stuck = 0.0
			_reverse = 0.9
	else:
		_stuck = 0.0

	return {
		"throttle": throttle,
		"brake": brake,
		"steer": steer,
		"drift": drift_held,
		"drift_pressed": drift_pressed,
	}


func _drive_reverse(k: Kart, delta: float) -> Dictionary:
	_reverse -= delta
	var tangent := track.global_basis * track.tangents[_index]
	tangent.y = 0.0
	var alpha := k.get_forward().signed_angle_to(tangent, Vector3.UP)
	# Dando ré o volante vira ao contrário.
	var steer := -signf(alpha) if absf(alpha) > 0.15 else 0.0
	return {"throttle": 0.0, "brake": 1.0, "steer": steer, "drift": false, "drift_pressed": false}


func _right_at(dist: float) -> Vector3:
	return track.get_direction_at(dist).cross(Vector3.UP).normalized()


# --- Trajetória ------------------------------------------------------------------

func _target_lateral(k: Kart, along: float, target_d: float, lat_now: float, delta: float) -> float:
	# Iniciantes abrem menos as curvas (ficam mais no meio).
	var lat := line.lateral_at(target_d) * lerpf(0.55, 1.0, skill)
	# Lugar preferido do piloto: vale nas retas, some nas curvas.
	var straight := 1.0 - clampf(absf(line.curvature_at(target_d)) * 45.0, 0.0, 1.0)
	lat += _lane * straight
	# Balanço leve (iniciantes balançam mais).
	lat += sin(_time * 0.6 + _phase) * (1.0 - skill) * 1.2
	lat += _mistake_lateral(delta)
	lat = _aim_boost_pads(along, lat)
	_avoid = move_toward(_avoid, _avoid_offset(k, lat, lat_now), 7.0 * delta)
	lat += _avoid
	lat = _ramp_lane(target_d, lat)
	var edge := track.road_width * 0.5 - 1.5
	return clampf(lat, -edge, edge)


## Erro de vez em quando: o piloto abre demais por um instante.
func _mistake_lateral(delta: float) -> float:
	_mistake_check -= delta
	if _mistake_check <= 0.0:
		_mistake_check = 1.0
		if _mistake <= 0.0 and randf() < (1.0 - skill) * 0.07:
			_mistake_length = randf_range(0.7, 1.4)
			_mistake = _mistake_length
			_mistake_offset = randf_range(2.5, 4.5) * (1.0 if randf() < 0.5 else -1.0)
	if _mistake <= 0.0:
		return 0.0
	_mistake -= delta
	return _mistake_offset * sin(PI * clampf(1.0 - _mistake / _mistake_length, 0.0, 1.0))


## Sorteia uma escolha uma vez por volta (a mesma chave dá a mesma resposta na volta).
func _decided(key: String, chance: float) -> bool:
	var id := "%s:%d" % [key, _lap]
	if not _choices.has(id):
		_choices[id] = randf() < chance
	return _choices[id]


func _to_ahead(dist: float, along: float) -> float:
	return wrapf(dist - along, -track.length * 0.5, track.length * 0.5)


func _aim_boost_pads(along: float, lat: float) -> float:
	for i in _pads.size():
		var to_pad := _to_ahead(_pads[i], along)
		if to_pad < -3.0 or to_pad > 45.0:
			continue
		if not _decided("turbo%d" % i, lerpf(0.25, 0.9, skill)):
			continue
		var w := clampf(1.0 - (to_pad - 8.0) / 37.0, 0.0, 1.0)
		return lerpf(lat, 0.0, w)
	return lat


## Perto de uma rampa (antes da subida até a aterrissagem): sem drift.
func _near_ramp(along: float) -> bool:
	for r in _ramps:
		var to_lip := _to_ahead(r.lip, along)
		if to_lip > -35.0 and to_lip < r.length + 45.0:
			return true
	return false


## Na chegada de uma rampa: sobe nela reto. Rampa estreita: ou mira o meio dela ou
## passa longe, pelo outro lado.
func _ramp_lane(target_d: float, lat: float) -> float:
	for i in _ramps.size():
		var r: Dictionary = _ramps[i]
		var to_lip := _to_ahead(r.lip, target_d)
		if to_lip < -2.0 or to_lip > r.length + 40.0:
			continue
		if not r.narrow:
			return clampf(lat, r.center - r.half + 1.4, r.center + r.half - 1.4)
		if _decided("rampa%d" % i, lerpf(0.3, 0.9, skill)):
			var w := clampf(1.0 - (to_lip - r.length - 8.0) / 30.0, 0.0, 1.0)
			return lerpf(lat, r.center, w)
		var keep: float = r.half + 2.2
		return minf(lat, r.center - keep) if r.center > 0.0 else maxf(lat, r.center + keep)
	return lat


## Quanto sair da trajetória para não bater nos karts em volta. Testa algumas faixas
## (a trajetória e 2,6 / 5,2 m para cada lado) e fica com a mais livre: cada kart à
## frente (que este está alcançando) ou ao lado ocupa a faixa dele. Mudar de faixa
## custa um pouco, para o kart não ficar indo e voltando.
func _avoid_offset(k: Kart, lat: float, lat_now: float) -> float:
	var fwd := track.global_basis * track.tangents[_index]
	var right := track.global_basis * track.rights[_index]
	var edge := track.road_width * 0.5 - 1.5
	var others: Array[Vector3] = [] # (lateral do outro, peso, -)
	_blocked = false
	for o in karts:
		if o == k or not is_instance_valid(o):
			continue
		var d := o.global_position - k.global_position
		var ahead := d.dot(fwd)
		if ahead < -2.5 or ahead > 18.0:
			continue
		var side := d.dot(right)
		if absf(side) > 8.0:
			continue
		var closing := k.speed - o.speed
		# Colado atrás de um kart mais lento, na mesma faixa: tira o pé.
		if ahead > 0.5 and absf(side) < 2.2 and closing > 1.0 and ahead < 3.5 + closing * 0.5:
			_blocked = true
		# Para decidir a ultrapassagem vale a velocidade que este kart QUER ter (senão,
		# depois de tirar o pé atrás do outro, ele desistiria e voltaria para a fila).
		var wants := maxf(k.speed, k.max_speed * k.speed_multiplier * 0.97) - o.speed
		# Bem à frente e indo mais rápido: não atrapalha.
		if ahead > 3.0 and wants < 0.5:
			continue
		var w := 1.0 if ahead < 3.0 else clampf(1.0 - (ahead - 3.0) / 15.0, 0.0, 1.0)
		w *= 1.0 if ahead < 3.0 else clampf(0.4 + wants / 6.0, 0.4, 1.5)
		others.append(Vector3(lat_now + side, w, 0.0))
	if others.is_empty():
		return 0.0
	var best := 0.0
	var best_cost := INF
	for offset: float in [0.0, -2.6, 2.6, -5.2, 5.2]:
		var cand := clampf(lat + offset, -edge, edge)
		var cost := absf(cand - lat) * 0.12 + absf(cand - (lat + _avoid)) * 0.08
		for o in others:
			var gap := absf(cand - o.x)
			if gap < 2.8:
				cost += o.y * (2.8 - gap) * 2.0
		if cost < best_cost:
			best_cost = cost
			best = cand - lat
	return best


# --- Velocidade -------------------------------------------------------------------

## Ritmo do piloto mais o elástico em relação ao jogador.
func _speed_multiplier(k: Kart, delta: float) -> float:
	var mult := pace
	if not cruising:
		# Atrás do jogador: até +9% (bem longe). Na frente: até -10%. Mesmo com o
		# máximo, quem vem de trás não passa da velocidade do jogador numa reta.
		var g := gap_to_player
		if g < -30.0:
			mult += clampf((-g - 30.0) / 220.0, 0.0, 1.0) * 0.09 * rubber_band
		elif g > 25.0:
			mult -= clampf((g - 25.0) / 220.0, 0.0, 1.0) * 0.1 * rubber_band
	return lerpf(k.speed_multiplier, mult, 1.0 - exp(-1.5 * delta))


# --- Drift --------------------------------------------------------------------------

## Decide quando derrapar (curvas longas), segura a derrapagem acompanhando a
## trajetória e solta no fim da curva (ou quando carregou o turbo que queria).
func _update_drift(k: Kart, along: float, abs_speed: float, yaw_wanted: float, turn_factor: float,
		steer: float, near_ramp: bool, delta: float) -> void:
	_out_steer = steer
	_out_held = false
	_out_pressed = false
	match _drift:
		Drift.NONE:
			if cruising or near_ramp or abs_speed < 15.0 or not k.is_on_floor() or k.ramp_jump:
				return
			if _travel < _curve_decided_until:
				return
			var turn := line.turn_between(along + 3.0, 40.0)
			if absf(turn) < 0.7:
				return
			var dir := -1 if turn > 0.0 else 1
			# A curva já começou (para o lado certo)?
			if line.curvature_at(along + 6.0) * -dir < 1.0 / 80.0:
				return
			_curve_decided_until = _travel + 45.0
			if randf() > lerpf(0.3, 1.0, skill):
				return
			_drift = Drift.HOP
			_drift_dir = dir
			_drift_timer = 0.0
			if skill > 0.7 and absf(turn) > 1.6:
				_drift_goal = 3
			elif skill > 0.35 and absf(turn) > 1.0:
				_drift_goal = 2
			else:
				_drift_goal = 1
			_out_pressed = true
			_out_held = true
			_out_steer = float(dir)
		Drift.HOP:
			# Pulinho: segura o drift e o direcional para o lado da curva até cair.
			_drift_timer += delta
			_out_held = true
			_out_steer = _drift_dir * maxf(absf(steer), 0.6)
			if k.drifting:
				_drift = Drift.ON
				_drift_timer = 0.0
				_drift_wide = 0.0
			elif _drift_timer > 0.6:
				_drift = Drift.NONE
				_out_held = false
				_out_steer = steer
		Drift.ON:
			if not k.drifting:
				_drift = Drift.NONE
				return
			_drift_timer += delta
			# Abre ou fecha o arco para seguir a trajetória (inverso do Kart).
			var f := yaw_wanted * _drift_dir / (k.turn_rate * turn_factor)
			var rel := clampf(remap(f, Kart.DRIFT_TURN_WIDE, Kart.DRIFT_TURN_TIGHT, -1.0, 1.0), -1.0, 1.0)
			_out_steer = rel * _drift_dir
			_out_held = true
			_drift_wide = _drift_wide + delta if f < 0.18 else 0.0
			var still_curving := line.curvature_at(along + 6.0) * -_drift_dir > 1.0 / 90.0
			var release := near_ramp or _drift_wide > 0.2 or _drift_timer > 4.5
			if k.drift_level >= _drift_goal and not still_curving:
				release = true
			if release:
				_drift = Drift.NONE
				_out_held = false
				_out_steer = steer
