class_name Kart
extends CharacterBody3D
## Kart arcade no estilo Mario Kart.
## Acelerar, frear/ré, virar, pulinho + drift com mini-turbo (azul, laranja, roxo),
## pulos de rampa (com manobra no ar que dá turbo na aterrissagem) e caixas de item.

signal bumped(strength: float)
signal boost_started(power: int)
signal drift_level_changed(level: int)
## Decolou de uma rampa de pulo.
signal jumped
## Voltou ao chão depois de um pulo de rampa (`strength` 0..1 = força da queda).
signal landed(strength: float)
## Fez uma manobra no ar (drift apertado logo na saída da rampa).
signal trick_performed
## Passou por uma caixa de item. A lógica dos itens entra em quem ouve este sinal.
signal item_box_collected(box: Node3D)
## Encostou em outro kart (`strength` 0..1). Os dois karts emitem.
signal kart_bumped(other: Kart, strength: float)

const GRAVITY := 32.0
const HOP_VELOCITY := 4.6
const MIN_DRIFT_SPEED := 9.0
## Tempo de drift (s) para atingir cada nível de mini-turbo.
const DRIFT_LEVEL_TIMES := [0.0, 0.8, 1.8, 3.0]
## Duração do turbo (s) ao soltar o drift em cada nível.
const DRIFT_BOOST_TIMES := [0.0, 0.6, 1.05, 1.6]
## Giro no drift como fração do turn_rate: direcional para fora (arco aberto)
## e para dentro (arco fechado). Solto fica no meio.
const DRIFT_TURN_WIDE := 0.3
const DRIFT_TURN_TIGHT := 0.85
## Quanto o modelo gira para dentro da curva no drift (rad), e o extra ao fechar o arco.
const DRIFT_VISUAL_YAW := 0.13
const DRIFT_VISUAL_YAW_TIGHT := 0.04
## Motos (KartData.turn_lean_degrees > 0): fração da velocidade máxima em que a
## inclinação chega ao máximo, e rapidez com que o veículo deita e levanta.
const BIKE_LEAN_FULL_SPEED := 0.55
const BIKE_LEAN_SHARPNESS := 6.0
## --- Pulos de rampa ---
## A frente do kart passou da borda da rampa (m antes da borda): decola.
const LIP_REACH := 0.9
## Desvio máximo (rad) entre o kart e a rampa na decolagem; acima disso a rampa
## endireita o kart (assim ninguém sai voando de lado por cima da mureta).
const RAMP_ALIGN_MAX := 0.24
## Manobra: apertar o drift até TRICK_WINDOW s depois de decolar (ou até
## TRICK_EARLY s antes, ainda na rampa). Dá TRICK_BOOST s de turbo ao aterrissar.
const TRICK_WINDOW := 0.4
const TRICK_EARLY := 0.25
const TRICK_TIME := 0.5
const TRICK_BOOST := 0.9
## Altura do eixo do giro da manobra (meio do kart).
const TRICK_PIVOT := 0.55
## Queda livre (sem rampa) a partir deste tempo no ar também conta como pulo.
const LONG_AIR_TIME := 0.5
const DRIFT_COLORS := [
	Color(1.0, 0.95, 0.8, 0.55),
	Color(0.25, 0.65, 1.0),
	Color(1.0, 0.55, 0.1),
	Color(0.95, 0.35, 1.0),
]

## Dados do kart (modelo e atributos). Defina antes de adicionar à cena.
@export var data: KartData
## Piloto sentado no kart (opcional). Defina antes de adicionar à cena.
@export var character: CharacterData
## Kart de um jogador (lê o controle dele). Os adversários do computador usam o
## `autopilot`. Defina antes de adicionar à cena.
@export var is_player := true
## Só um jogador na corrida: o kart dele tem o som de motor sintetizado e a luz do
## turbo. Na tela dividida todos usam o som 3D mais leve (cada jogador ouve o seu
## kart mais perto da câmera dele). Defina antes de adicionar à cena.
@export var lone_player := true
## Prefixo das ações do controle deste jogador ("" = teclado e todos os controles;
## "j2_" = só o controle do J2). Veja PlayerSlot.
@export var input_prefix := ""
## Classe de velocidade (GameState.SPEED_CLASSES): multiplica a velocidade máxima e a
## aceleração. Defina antes de adicionar à cena.
@export var speed_class := 1.0

@export_group("Direção")
@export var max_speed := 27.0
@export var acceleration := 15.0
@export var brake_force := 32.0
@export var reverse_speed := 9.0
@export var coast_drag := 5.0
@export var turn_rate := 1.72
## Fração do giro que sobra na velocidade máxima (menor = mais estável em alta).
@export var high_speed_turn := 0.75
@export var grip := 9.0
## Aderência no drift: baixa demais faz o kart rodar em vez de deslizar.
@export var drift_grip := 7.25
## Fator de velocidade máxima na grama.
@export var offroad_factor := 0.5
## Multiplicador de velocidade máxima durante o turbo.
@export var boost_factor := 1.35

@export_group("Sensibilidade")
## Quão rápido o volante vai até o fim (por segundo). Menor = mais suave.
@export var steer_speed := 4.5
## Quão rápido o volante volta ao centro (por segundo).
@export var steer_return_speed := 7.0
## Curva do analógico: acima de 1 os movimentos pequenos viram menos (mais precisão).
@export var steer_curve := 1.5
## Suavização da rotação do kart (maior = responde mais rápido).
@export var yaw_smoothing := 10.0

## Liga/desliga o controle (desligado na contagem regressiva).
var controls_enabled := false
## Se válido, substitui o controle do jogador: func(kart) -> Dictionary.
var autopilot: Callable
## Velocidade para frente em m/s (negativa = ré).
var speed := 0.0
var steer_input := 0.0
var throttle_input := 0.0
## Definido pela corrida: true quando o kart está fora do asfalto.
var is_offroad := false
var drifting := false
var drift_dir := 0
var drift_level := 0
var boost_time := 0.0
## Multiplica a velocidade máxima (o piloto do computador usa para o ritmo e o elástico).
var speed_multiplier := 1.0
## Peso (1 a 5, kart + piloto): nas batidas entre karts o mais pesado empurra mais.
var weight_stat := 3
## Tela dividida: cada tela é menor e o kart aparece menor de longe, então o detalhe do
## piloto cai mais perto da câmera (as distâncias contam multiplicadas por isto).
var lod_scale := 1.0

var _vertical := 0.0
var _steer := 0.0
var _yaw_rate := 0.0
var _want_drift := false
var _drift_time := 0.0
var _prev_speed := 0.0
var _visual_yaw := 0.0
var _visual_roll := 0.0
var _visual_pitch := 0.0
## Inclinação do chão (rampas e pontes) aplicada ao modelo.
var _ground_pitch := 0.0
var _ground_roll := 0.0
var _was_on_floor := true
var _bump_cooldown := 0.0
var _kart_bump_cooldown := 0.0
## true no ar depois de decolar de uma rampa (até aterrissar).
var ramp_jump := false
var _air_time := 0.0
## Velocidade vertical do chão sob o kart (subindo uma rampa = positiva).
var _ground_vy := 0.0
var _trick_buffer := 0.0
var _trick_window := 0.0
## Progresso da manobra em segundos (-1 = sem manobra).
var _trick_t := -1.0
var _trick_dir := 1.0
var _trick_boost := false
## Mola da suspensão (aterrissagem): deslocamento vertical do modelo e velocidade.
var _squash := 0.0
var _squash_vel := 0.0
var _land_dust := 0.0
var _engine: AudioStreamGeneratorPlayback
var _engine_phase := 0.0
var _engine_rev := 0.0
## Motor dos adversários: um som curto em loop, com o tom mudando pela velocidade.
var _engine_3d: AudioStreamPlayer3D
## Rampas de pulo da pista (relidas de vez em quando, veja _current_ramp).
var _ramps: Array[Node] = []
var _ramps_frame := -1

@onready var visual: Node3D = $Visual
@onready var model_slot: Node3D = $Visual/ModelSlot
@onready var sparks_left: GPUParticles3D = $Visual/SparksL
@onready var sparks_right: GPUParticles3D = $Visual/SparksR
@onready var dust: GPUParticles3D = $Visual/Dust
@onready var engine_audio: AudioStreamPlayer = $EngineAudio

## Modelo do kart com o piloto (rodas, volante e personagem).
var kart_visual: KartVisual
## Fogo do turbo saindo dos escapamentos deste kart (KartData.exhausts).
var boost_fx: BoostExhaustFx
## O personagem sentado no kart (null se o kart estiver sem piloto).
var driver: CharacterRig:
	get:
		return kart_visual.driver if kart_visual else null


func _ready() -> void:
	# O material das faíscas é da cena: cada kart precisa do seu, senão a cor do
	# drift de um kart muda as faíscas de todos.
	var spark_mat := sparks_left.process_material.duplicate() as ParticleProcessMaterial
	sparks_left.process_material = spark_mat
	sparks_right.process_material = spark_mat
	if data:
		apply_data(data, character)
	_set_sparks(-1)
	_setup_engine_audio()


## Monta o modelo com o piloto e ajusta a física pelos atributos do kart + piloto.
func apply_data(d: KartData, c: CharacterData = null) -> void:
	data = d
	character = c
	for child in model_slot.get_children():
		child.queue_free()
	kart_visual = KartVisual.new()
	kart_visual.name = "KartVisual"
	model_slot.add_child(kart_visual)
	kart_visual.setup(d, c)
	kart_visual.scale = Vector3.ONE * d.race_scale
	boost_fx = BoostExhaustFx.new()
	boost_fx.name = "FogoTurbo"
	kart_visual.add_child(boost_fx)
	# Só o kart do jogador acende uma luz no chão, e não na web: lá cada luz extra
	# redesenha o que ela ilumina (asfalto incluído), caro para um enfeite.
	boost_fx.setup(d, is_player and lone_player and not OS.has_feature("web"))
	var stats := d.combined_stats(c)
	max_speed = (22.0 + stats.speed * 1.7) * speed_class
	acceleration = (9.0 + stats.acceleration * 2.0) * speed_class
	# No 150cc o kart vira um pouco mais (senão as curvas fechadas ficam impossíveis);
	# no 50cc vira o mesmo, com o raio de curva menor pela velocidade.
	turn_rate = (1.3 + stats.handling * 0.14) * sqrt(maxf(speed_class, 1.0))
	grip = 7.5 + stats.handling * 0.5
	drift_grip = 6.5 + stats.handling * 0.25
	offroad_factor = 0.44 + stats.weight * 0.02
	weight_stat = stats.weight


func get_forward() -> Vector3:
	var f := -global_basis.z
	f.y = 0.0
	return f.normalized() if f.length_squared() > 0.0001 else Vector3.FORWARD


func get_speed_kmh() -> float:
	return absf(speed) * 3.6


## Dá um turbo por `duration` segundos. Com `instant` a velocidade pula na hora;
## sem (turbo de largada, com karts logo à frente no grid) ela sobe bem rápido.
func apply_boost(duration: float, power := 1, instant := true) -> void:
	boost_time = maxf(boost_time, duration)
	if instant:
		speed = maxf(speed, max_speed * speed_multiplier * 1.12)
	boost_started.emit(power)
	if boost_fx:
		boost_fx.ignite(power)
	if driver:
		driver.react_boost(power)


## Coloca o kart numa posição e zera o movimento.
func teleport(xform: Transform3D) -> void:
	# O corpo do kart fica sempre em pé (só gira no eixo vertical); numa rampa a
	# inclinação aparece só no modelo (veja _update_visuals).
	var fwd := -xform.basis.z
	fwd.y = 0.0
	if fwd.length_squared() < 0.0001:
		fwd = Vector3.FORWARD
	global_transform = Transform3D(Basis.looking_at(fwd.normalized(), Vector3.UP), xform.origin)
	_ground_pitch = 0.0
	_ground_roll = 0.0
	velocity = Vector3.ZERO
	speed = 0.0
	_vertical = 0.0
	boost_time = 0.0
	_steer = 0.0
	_yaw_rate = 0.0
	_want_drift = false
	_cancel_drift()
	ramp_jump = false
	_air_time = 0.0
	_ground_vy = 0.0
	_trick_t = -1.0
	_trick_boost = false
	_trick_window = 0.0
	_trick_buffer = 0.0
	reset_physics_interpolation()


func _physics_process(delta: float) -> void:
	var input := _gather_input()
	var throttle: float = input.throttle
	var brake: float = input.brake
	var raw_steer: float = input.steer
	var drift_held: bool = input.drift
	var drift_pressed: bool = input.drift_pressed
	var steer := _smooth_steer(raw_steer, delta)
	steer_input = steer
	throttle_input = throttle
	var on_floor := is_on_floor()
	var ramp := _current_ramp() if on_floor else null
	_trick_buffer = maxf(_trick_buffer - delta, 0.0)
	_trick_window = maxf(_trick_window - delta, 0.0)

	# --- Pulinho, drift e manobra --------------------------------------------
	if drift_pressed:
		if ramp:
			# Na rampa o botão não dá pulinho (estragaria a decolagem): vale como
			# manobra assim que o kart sair da borda.
			_trick_buffer = TRICK_EARLY
			_want_drift = true
		elif on_floor:
			# Na subida o pulinho soma a velocidade com que o chão sobe.
			_vertical = HOP_VELOCITY + maxf(_ground_vy, 0.0)
			on_floor = false
			_want_drift = true
			if driver:
				driver.bounce(-0.5)
		elif _trick_window > 0.0 and _trick_t < 0.0:
			_start_trick(raw_steer)
			_want_drift = true
	if not drift_held:
		_want_drift = false
		if drifting:
			_release_drift()
	# O lado do drift usa o direcional cru, para responder na hora do pulinho.
	if _want_drift and not drifting and on_floor and ramp == null and absf(raw_steer) > 0.25 and speed > MIN_DRIFT_SPEED:
		_start_drift(1 if raw_steer > 0.0 else -1)

	# --- Velocidade ----------------------------------------------------------
	var top := max_speed * speed_multiplier * (offroad_factor if is_offroad and on_floor else 1.0)
	if boost_time > 0.0:
		boost_time -= delta
		top = max_speed * boost_factor * speed_multiplier
		speed = move_toward(speed, top, acceleration * 3.0 * delta)
	elif not on_floor:
		pass # No ar não há chão para acelerar nem frear: a velocidade se mantém.
	elif throttle > 0.05 and brake < 0.5:
		if speed < 0.0:
			speed = move_toward(speed, 0.0, brake_force * delta)
		var target := top * throttle
		if speed < target:
			var ratio := clampf(speed / max_speed, 0.0, 1.0)
			speed = move_toward(speed, target, acceleration * lerpf(1.5, 0.45, ratio) * delta)
		else:
			speed = move_toward(speed, target, (16.0 if is_offroad else coast_drag) * delta)
	elif brake > 0.05:
		if speed > 0.5:
			speed = move_toward(speed, 0.0, brake_force * brake * delta)
		else:
			speed = move_toward(speed, -reverse_speed * brake, acceleration * 0.6 * delta)
	else:
		speed = move_toward(speed, 0.0, (coast_drag + (10.0 if is_offroad else 0.0)) * delta)

	# --- Curva ----------------------------------------------------------------
	var turn_factor := clampf(absf(speed) / 7.0, 0.0, 1.0)
	var yaw := 0.0
	if drifting:
		# O drift sempre curva para o lado escolhido; o direcional só abre ou fecha
		# o arco. Segurando para dentro ele fecha mais e carrega mais rápido.
		var rel := steer * drift_dir
		yaw = drift_dir * turn_rate * remap(rel, -1.0, 1.0, DRIFT_TURN_WIDE, DRIFT_TURN_TIGHT) * turn_factor
		_drift_time += delta * (1.0 + 0.6 * maxf(rel, 0.0))
		_update_drift_level()
		if speed < MIN_DRIFT_SPEED * 0.6 or brake > 0.5:
			_cancel_drift()
	else:
		var high_speed := lerpf(1.0, high_speed_turn, clampf(absf(speed) / max_speed, 0.0, 1.0))
		yaw = steer * turn_rate * turn_factor * high_speed * (1.0 if speed >= 0.0 else -1.0)
	if not on_floor:
		yaw *= 0.35
	# Suaviza a velocidade de giro: o kart não dá trancos ao entrar/sair do drift.
	_yaw_rate = lerpf(_yaw_rate, yaw, 1.0 - exp(-yaw_smoothing * delta))
	rotate_y(_yaw_rate * delta)

	# --- Movimento ------------------------------------------------------------
	var fwd := get_forward()
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var traction := drift_grip if drifting else grip
	if not on_floor:
		traction *= 0.4
	horizontal = horizontal.lerp(fwd * speed, 1.0 - exp(-traction * delta))
	# Decolagem: quando a frente do kart passa da borda da rampa ele sai do chão
	# com a inclinação da borda (só a gravidade age a partir daí).
	if ramp and _vertical <= 0.0:
		var along := horizontal.dot(ramp.get_forward())
		if along > 2.0 and ramp.to_lip_space(global_position).z + along * delta >= -LIP_REACH:
			horizontal = _launch(ramp, horizontal)
			on_floor = false
	if on_floor and _vertical <= 0.0:
		_vertical = -2.0
	else:
		_vertical -= GRAVITY * delta
	velocity = horizontal + Vector3.UP * _vertical
	move_and_slide()
	var now_on_floor := is_on_floor()
	if now_on_floor:
		if not _was_on_floor:
			_on_landed(-_vertical)
		if _vertical < 0.0:
			_vertical = 0.0
		var n := get_floor_normal()
		_ground_vy = -(n.x * horizontal.x + n.z * horizontal.z) / maxf(n.y, 0.3)
		_air_time = 0.0
	else:
		if _was_on_floor and _vertical < 0.0:
			# Passou de uma borda sem pular: continua subindo com a velocidade com
			# que o chão subia (sem isso o kart "grudaria" e cairia reto).
			_vertical = maxf(_vertical, _ground_vy)
		_air_time += delta
	_was_on_floor = now_on_floor
	_handle_walls(fwd, delta)

	_update_visuals(delta, steer)
	_prev_speed = speed


func _process(_delta: float) -> void:
	if _engine_3d:
		_engine_3d.pitch_scale = _engine_frequency() / Sfx.ENGINE_BASE_FREQ
		_update_driver_detail()
	else:
		_fill_engine_audio()


func _exit_tree() -> void:
	_engine = null
	if engine_audio:
		engine_audio.stop()


func _gather_input() -> Dictionary:
	if is_player:
		_engine_rev = Input.get_action_strength(input_prefix + "acelerar")
	if not controls_enabled:
		return {"throttle": 0.0, "brake": 0.0, "steer": 0.0, "drift": false, "drift_pressed": false}
	if autopilot.is_valid():
		return autopilot.call(self)
	var steer := Input.get_axis(input_prefix + "direita", input_prefix + "esquerda")
	# No analógico, toques leves viram pouco (o teclado continua indo de 0 a 1).
	steer = signf(steer) * pow(absf(steer), steer_curve)
	return {
		"throttle": Input.get_action_strength(input_prefix + "acelerar"),
		"brake": Input.get_action_strength(input_prefix + "frear"),
		"steer": steer,
		"drift": Input.is_action_pressed(input_prefix + "drift"),
		"drift_pressed": Input.is_action_just_pressed(input_prefix + "drift"),
	}


## Leva o volante até o valor pedido aos poucos (no teclado, de 0 a 1 em ~0,2 s)
## e o devolve ao centro um pouco mais rápido.
func _smooth_steer(target: float, delta: float) -> float:
	var returning := absf(target) < absf(_steer) or target * _steer < 0.0
	_steer = move_toward(_steer, target, (steer_return_speed if returning else steer_speed) * delta)
	return _steer


func _handle_walls(fwd: Vector3, delta: float) -> void:
	_bump_cooldown -= delta
	_kart_bump_cooldown -= delta
	var wall_done := false
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var other := collision.get_collider() as Kart
		if other:
			_bump_kart(other, collision.get_normal(), fwd)
			continue
		if wall_done:
			continue
		var normal := collision.get_normal()
		if absf(normal.y) > 0.6:
			continue
		normal.y = 0.0
		normal = normal.normalized()
		var impact := -fwd.dot(normal) * speed
		if impact > 4.0 and _bump_cooldown <= 0.0:
			var strength := clampf(impact / max_speed, 0.0, 1.0)
			speed *= lerpf(0.8, 0.3, strength)
			velocity += normal * minf(impact * 0.45, 8.0)
			if drifting:
				_cancel_drift()
			_bump_cooldown = 0.25
			bumped.emit(strength)
			if driver:
				driver.react_bump(strength)
		else:
			speed = move_toward(speed, 0.0, 6.0 * delta)
		wall_done = true


## Encostou em outro kart: os dois se empurram para os lados (o mais pesado empurra
## mais). Quem bate por trás perde velocidade; o da frente quase nada.
## `normal` aponta do outro kart para este.
func _bump_kart(other: Kart, normal: Vector3, fwd: Vector3) -> void:
	if _kart_bump_cooldown > 0.0 or other._kart_bump_cooldown > 0.0:
		return
	var push := normal
	push.y = 0.0
	if push.length_squared() < 0.04:
		# Em cima do outro kart (caiu de um pulo): escorrega para o lado.
		push = global_position - other.global_position
		push.y = 0.0
	if push.length_squared() < 0.0001:
		push = global_basis.x
	push = push.normalized()
	var closing := maxf((fwd * speed - other.get_forward() * other.speed).dot(-push), 0.0)
	var strength := clampf(closing / 12.0, 0.0, 1.0)
	var my_share := float(other.weight_stat) / float(weight_stat + other.weight_stat)
	var impulse := 3.0 + closing * 0.55
	velocity += push * impulse * my_share * 2.0
	other.velocity -= push * impulse * (1.0 - my_share) * 2.0
	var nose_hit := -fwd.dot(push)
	if nose_hit > 0.5 and speed > other.speed:
		speed = lerpf(speed, other.speed, 0.5 * nose_hit)
	if strength > 0.35:
		if drifting:
			_cancel_drift()
		if driver:
			driver.react_bump(strength * 0.6)
		if other.driver:
			other.driver.react_bump(strength * 0.6)
	_kart_bump_cooldown = 0.3
	other._kart_bump_cooldown = 0.3
	kart_bumped.emit(other, strength)
	other.kart_bumped.emit(self, strength)


## Recebe uma caixa de item (chamado pela caixa).
func collect_item_box(box: Node3D) -> void:
	item_box_collected.emit(box)


# --- Rampas e manobras -----------------------------------------------------------

## A rampa embaixo do kart (só vale com o kart no chão), ou null.
func _current_ramp() -> JumpRamp:
	# As rampas só mudam com a pista: a lista é relida a cada segundo, não a cada
	# quadro (eram 8 karts × 60 listas novas por segundo).
	var frame := Engine.get_physics_frames()
	if _ramps_frame < 0 or frame - _ramps_frame >= 60:
		_ramps = get_tree().get_nodes_in_group(&"jump_ramp")
		_ramps_frame = frame
	for node in _ramps:
		if not is_instance_valid(node):
			continue
		var r := node as JumpRamp
		if r and r.contains(global_position):
			return r
	return null


## Sai do chão na borda da rampa. Devolve a velocidade horizontal (endireitada).
func _launch(ramp: JumpRamp, horizontal: Vector3) -> Vector3:
	var dir := ramp.get_forward()
	var heading := horizontal.normalized() if horizontal.length_squared() > 0.01 else get_forward()
	var deviation := dir.signed_angle_to(heading, Vector3.UP)
	if absf(deviation) > RAMP_ALIGN_MAX:
		var fix := (absf(deviation) - RAMP_ALIGN_MAX) * signf(deviation)
		rotate_y(-fix)
		horizontal = horizontal.rotated(Vector3.UP, -fix)
	# A subida não rouba velocidade: decola com a velocidade do kart.
	horizontal = horizontal.normalized() * maxf(horizontal.length(), absf(speed))
	# A subida é dividida pela classe de velocidade: o tempo no ar fica o mesmo e o
	# pulo só fica mais comprido (no 150cc com turbo ainda cai na reta depois da rampa).
	_vertical = horizontal.dot(dir) * tan(ramp.launch_angle) / maxf(speed_class, 0.1)
	ramp_jump = true
	_air_time = 0.0
	_trick_window = TRICK_WINDOW
	jumped.emit()
	if _trick_buffer > 0.0:
		_start_trick(steer_input)
	return horizontal


func _start_trick(steer: float) -> void:
	_trick_t = 0.0
	# Gira para o lado do direcional (ou alterna, com o direcional no meio).
	_trick_dir = signf(steer) if absf(steer) > 0.2 else -_trick_dir
	_trick_boost = true
	_trick_window = 0.0
	_trick_buffer = 0.0
	trick_performed.emit()
	if driver:
		driver.set_face(&"face_happy", 1.0)
		driver.play_gesture(&"gesture_cheer", 0.55)


## Tocou o chão. `fall_speed` = velocidade de queda (m/s) no toque.
func _on_landed(fall_speed: float) -> void:
	var big := ramp_jump or _air_time > LONG_AIR_TIME
	ramp_jump = false
	_trick_window = 0.0
	if not big:
		if driver:
			driver.bounce(-0.8)
		return
	var strength := clampf(fall_speed / 22.0, 0.0, 1.0)
	# A suspensão afunda e volta (mola no _update_visuals).
	_squash_vel -= 0.6 + strength * 1.1
	_land_dust = 0.3
	if driver:
		driver.bounce(-1.0 - strength * 1.2)
	landed.emit(strength)
	if _trick_boost:
		_trick_boost = false
		apply_boost(TRICK_BOOST, 1)


# --- Drift ---------------------------------------------------------------------

func _start_drift(dir: int) -> void:
	drifting = true
	drift_dir = dir
	drift_level = 0
	_drift_time = 0.0
	_set_sparks(0)


func _update_drift_level() -> void:
	var level := 0
	for i in range(DRIFT_LEVEL_TIMES.size() - 1, 0, -1):
		if _drift_time >= DRIFT_LEVEL_TIMES[i]:
			level = i
			break
	if level != drift_level:
		drift_level = level
		_set_sparks(level)
		drift_level_changed.emit(level)
		if driver:
			driver.react_drift(level)


func _release_drift() -> void:
	var level := drift_level
	_cancel_drift()
	if level > 0:
		apply_boost(DRIFT_BOOST_TIMES[level], level)


func _cancel_drift() -> void:
	if drifting and driver:
		driver.react_drift_end()
	drifting = false
	drift_dir = 0
	drift_level = 0
	_drift_time = 0.0
	_set_sparks(-1)


## Liga os efeitos que só aparecem durante a corrida (turbo, faíscas do drift, poeira)
## para os shaders deles compilarem atrás da tela de carregamento (Race.warm_up).
func prewarm_effects(on: bool) -> void:
	if boost_fx:
		boost_fx.prewarm(on)
	for p: GPUParticles3D in [sparks_left, sparks_right, dust]:
		if on:
			p.emitting = true
		else:
			p.restart()
			p.emitting = false


func _set_sparks(level: int) -> void:
	if sparks_left == null:
		return
	var on := level >= 0
	sparks_left.emitting = on
	sparks_right.emitting = on
	if on:
		var mat := sparks_left.process_material as ParticleProcessMaterial
		if mat:
			mat.color = DRIFT_COLORS[level]


# --- Visual -----------------------------------------------------------------------

func _update_visuals(delta: float, steer: float) -> void:
	var speed_ratio := clampf(absf(speed) / max_speed, 0.0, 1.0)
	var smooth := 1.0 - exp(-8.0 * delta)
	# No drift o bico aponta para dentro da curva; fechando o arco ele aponta mais.
	var target_yaw := drift_dir * (DRIFT_VISUAL_YAW + DRIFT_VISUAL_YAW_TIGHT * steer * drift_dir) if drifting else 0.0
	var target_roll := -steer * 0.05 * speed_ratio - drift_dir * 0.07
	var roll_smooth := smooth
	if data and data.turn_lean_degrees > 0.0:
		target_roll = _bike_lean(steer, speed_ratio)
		roll_smooth = 1.0 - exp(-BIKE_LEAN_SHARPNESS * delta)
	var accel := (speed - _prev_speed) / maxf(delta, 0.0001)
	var target_pitch := clampf(accel / 45.0, -0.05, 0.05)
	_visual_yaw = lerpf(_visual_yaw, target_yaw, smooth)
	_visual_roll = lerpf(_visual_roll, target_roll, roll_smooth)
	_visual_pitch = lerpf(_visual_pitch, target_pitch, smooth * 0.6)
	# Acompanha a inclinação do chão (rampas e pontes): bico para cima na subida.
	var ground_pitch := 0.0
	var ground_roll := 0.0
	var ground_rate := 10.0
	if is_on_floor():
		var n := get_floor_normal()
		ground_pitch = -asin(clampf(n.dot(get_forward()), -1.0, 1.0))
		ground_roll = -asin(clampf(n.dot(global_basis.x), -1.0, 1.0))
	elif ramp_jump or _air_time > LONG_AIR_TIME:
		# No pulo o bico acompanha o arco: sobe na decolagem e desce na queda.
		var hs := Vector2(velocity.x, velocity.z).length()
		ground_pitch = clampf(atan2(_vertical, maxf(hs, 4.0)) * 0.75, -0.4, 0.4)
		ground_rate = 5.0
	else:
		ground_pitch = _ground_pitch * 0.98
		ground_roll = _ground_roll * 0.98
	var ground_smooth := 1.0 - exp(-ground_rate * delta)
	_ground_pitch = lerpf(_ground_pitch, ground_pitch, ground_smooth)
	_ground_roll = lerpf(_ground_roll, ground_roll, ground_smooth)
	# Mola da suspensão (afunda na aterrissagem e volta).
	_squash_vel += (-_squash * 170.0 - _squash_vel * 13.0) * delta
	_squash = clampf(_squash + _squash_vel * delta, -0.16, 0.08)
	var xf := Transform3D(Basis.from_euler(Vector3(_visual_pitch + _ground_pitch, _visual_yaw, _visual_roll + _ground_roll)),
			Vector3(0.0, _squash, 0.0))
	# Manobra: um giro completo em volta do eixo do kart (termina rápido se ele
	# aterrissar antes).
	if _trick_t >= 0.0:
		_trick_t += delta * (3.0 if is_on_floor() else 1.0)
		var k := clampf(_trick_t / TRICK_TIME, 0.0, 1.0)
		if k >= 1.0:
			_trick_t = -1.0
		else:
			var pivot := Vector3(0.0, TRICK_PIVOT, 0.0)
			var spin := Basis(Vector3.BACK, TAU * k * k * (3.0 - 2.0 * k) * _trick_dir)
			xf = xf * Transform3D(spin, pivot - spin * pivot)
	visual.transform = xf

	# Rodas, guidão/volante e piloto.
	if kart_visual:
		kart_visual.update_motion(delta, speed, steer, drift_dir)

	if boost_fx:
		boost_fx.update(delta, boost_time > 0.0)
	_land_dust = maxf(_land_dust - delta, 0.0)
	var dusty := (is_offroad and absf(speed) > 4.0 and is_on_floor()) or _land_dust > 0.0
	if dust.emitting != dusty:
		dust.emitting = dusty


## Inclinação de moto (rad, positivo = deita para a esquerda): para dentro da curva,
## crescendo com a velocidade. No drift deita para o lado da derrapagem (mais ao
## fechar o arco, menos ao abrir) e no pulo quase endireita.
func _bike_lean(steer: float, speed_ratio: float) -> float:
	var max_lean := deg_to_rad(data.turn_lean_degrees)
	var k := clampf(speed_ratio / BIKE_LEAN_FULL_SPEED, 0.0, 1.0)
	var lean := steer
	if drifting:
		lean = drift_dir * (0.8 + 0.3 * clampf(steer * drift_dir, -1.0, 1.0))
	if not is_on_floor() and (ramp_jump or _air_time > LONG_AIR_TIME):
		lean *= 0.3
	return clampf(lean * k, -1.1, 1.1) * max_lean


# --- Som do motor (sintetizado) --------------------------------------------------

func _setup_engine_audio() -> void:
	if not (is_player and lone_player):
		# Adversários (e todos os karts na tela dividida): som 3D (mais alto perto da
		# câmera) feito com um loop curto. O motor sintetizado do jogador gera cada
		# amostra em GDScript, caro para 8 karts.
		engine_audio.queue_free()
		engine_audio = null
		_engine_3d = AudioStreamPlayer3D.new()
		_engine_3d.name = "Motor3D"
		_engine_3d.stream = Sfx.get_engine_loop()
		_engine_3d.volume_db = -8.0 if is_player else -12.0
		_engine_3d.unit_size = 5.0
		_engine_3d.max_distance = 60.0
		_engine_3d.position = Vector3(0.0, 0.5, 0.4)
		add_child(_engine_3d)
		_engine_3d.play()
		return
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = 22050.0
	generator.buffer_length = 0.1
	engine_audio.stream = generator
	# Na web o padrão é tocar como "sample" (Web Audio), que não aceita stream gerado
	# em tempo real; o motor precisa passar pelo mixer do Godot.
	engine_audio.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	engine_audio.play()
	_engine = engine_audio.get_stream_playback() as AudioStreamGeneratorPlayback


func _fill_engine_audio() -> void:
	if _engine == null:
		return
	var frames := _engine.get_frames_available()
	if frames <= 0:
		return
	var freq := _engine_frequency()
	var volume := 0.16 + maxf(throttle_input, _engine_rev) * 0.08
	var step := TAU * freq / 22050.0
	for i in frames:
		_engine_phase = fmod(_engine_phase + step, TAU * 2.0)
		var p := _engine_phase
		var s := sin(p) * 0.55 + sin(p * 2.0) * 0.3 + sin(p * 3.0 + 0.4) * 0.12 + sin(p * 0.5) * 0.3
		s = clampf(s * 1.3, -1.0, 1.0) * volume
		_engine.push_frame(Vector2(s, s))


## Frequência do ronco do motor (Hz) pela velocidade (e pelo acelerador na largada).
func _engine_frequency() -> float:
	var ratio := clampf(absf(speed) / max_speed, 0.0, 1.4)
	var rev := maxf(ratio, _engine_rev * (0.35 if not controls_enabled else 0.0))
	return 42.0 + rev * 92.0 + (16.0 if boost_time > 0.0 else 0.0)


## Piloto longe da câmera: a pose é refeita menos vezes (ninguém vê a diferença e o
## personagem é a parte mais cara de cada kart: cada pose nova também deforma a malha
## na GPU). Na tela dividida vale a câmera mais perto (grupo "race_camera").
func _update_driver_detail() -> void:
	var rig := driver
	if rig == null:
		return
	var cams := get_tree().get_nodes_in_group(&"race_camera")
	if cams.is_empty():
		var main_cam := get_viewport().get_camera_3d()
		if main_cam == null:
			return
		cams = [main_cam]
	var every := 6
	for node in cams:
		var cam := node as Camera3D
		if cam == null or not cam.is_inside_tree():
			continue
		var d2 := cam.global_position.distance_squared_to(global_position) * lod_scale * lod_scale
		if cam.is_position_behind(global_position):
			every = mini(every, 6)
		elif d2 < 15.0 * 15.0:
			every = 1
		elif d2 < 35.0 * 35.0:
			every = mini(every, 2)
		elif d2 < 70.0 * 70.0:
			every = mini(every, 3)
		else:
			every = mini(every, 5)
	rig.update_every = every
