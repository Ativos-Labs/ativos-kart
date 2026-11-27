class_name ChaseCamera
extends Camera3D
## Câmera que segue o kart por trás, com tremida nas batidas e o campo de visão
## abrindo com a velocidade (veja `_speed_fov`). Com a asa-delta aberta ela se afasta e sobe um pouco, para a asa caber por cima do kart.
## Na tela dividida cada jogador tem a sua (veja `fit_aspect`).

## Medidas da câmera para os karts de antes, multiplicadas por KartScale.CAMERA (os karts
## e os pilotos encolheram no encaixe piloto × kart).
@export var distance := 3.15 * KartScale.CAMERA
@export var height := 1.55 * KartScale.CAMERA
@export var look_height := 0.65 * KartScale.CAMERA
@export var look_ahead := 2.2 * KartScale.CAMERA
@export var follow_sharpness := 6.0
@export var base_fov := 62.0

const POSITION_SHARPNESS := 12.0
## A altura segue mais devagar: no pulo a câmera fica um pouco para trás (dá a
## sensação de altura) e a aterrissagem não dá tranco na imagem. Parte do atraso é
## compensada pela velocidade vertical, para o kart não tapar a pista na subida.
## A altura do ponto que a câmera segue anda numa mola (frequência em rad/s): os
## solavancos de cada passo da física (encostar no chão, zebras, emendas da pista) somem
## e pulos e subidas viram um movimento liso. MAX_ANCHOR_LAG limita o atraso (m).
const ANCHOR_FREQ := 9.0
const MAX_ANCHOR_LAG := 1.6
## O avanço que compensa o atraso da posição também é alisado: uma batida na mureta
## (a velocidade muda de uma vez) não dá tranco na imagem.
const LEAD_SHARPNESS := 6.0
## Na subida (e no pulo) a mola atrasaria a câmera e o kart taparia a pista: parte do
## atraso é compensada pela velocidade de subida, alisada (VRATE_SHARPNESS, 1/s).
const ANCHOR_LEAD := 0.7
const VRATE_SHARPNESS := 5.0
## Quão rápido a câmera deita junto com o kart nas curvas inclinadas (1/s).
const UP_SHARPNESS := 10.0
## Quanto da inclinação a imagem acompanha (1 = a parede vira chão; menos que isso o
## horizonte fica torto e dá para ver que o kart está na parede).
const VIEW_ROLL := 0.8
## Planando: quanto a câmera se afasta, sobe e levanta o olhar (m), e a rapidez da
## troca (fração por segundo).
const GLIDE_DISTANCE := 1.8 * KartScale.ITEMS
const GLIDE_HEIGHT := 0.55 * KartScale.ITEMS
const GLIDE_LOOK := 1.0 * KartScale.ITEMS
const GLIDE_BLEND_SPEED := 1.5
## Superpreferência (o kart vira o ofício gigante): a câmera sobe e se afasta para a
## folha caber e o carimbo aparecer.
const SUPER_DISTANCE := 0.9 * KartScale.ITEMS
const SUPER_HEIGHT := 1.5 * KartScale.ITEMS
const SUPER_LOOK := 0.2 * KartScale.ITEMS
const SUPER_BLEND_SPEED := 2.0
## Campo de visão pela velocidade real (m/s), a mesma conta para todo kart e
## cilindrada (o 150cc abre mais que o 50cc): parado fica em `base_fov` e abre até
## SPEED_FOV graus em SPEED_FOV_FULL m/s (o 150cc no turbo); o turbo soma BOOST_FOV
## para dar o tranco. Os graus valem para a tela de um jogador (REFERENCE_FOV); em
## outro `base_fov` a abertura é proporcional (o mesmo "afastar" da imagem).
const SPEED_FOV_START := 4.0
const SPEED_FOV_FULL := 44.0
const SPEED_FOV := 30.0
const BOOST_FOV := 8.0
const REFERENCE_FOV := 62.0
## Abre rápido (o turbo pega na hora) e fecha mais devagar (frear, bater).
const FOV_OPEN_SHARPNESS := 5.0
const FOV_CLOSE_SHARPNESS := 3.0

var target: Kart
## 1 = começo da animação de apresentação (câmera na frente do kart), 0 = normal.
var intro := 0.0

var _dir := Vector3.FORWARD
## "Cima" da câmera: segue o do kart (deita nas curvas inclinadas).
var _up := Vector3.UP
var _shake := 0.0
## Ponto seguido = kart + _up * _anchor_off (a mola leva _anchor_off a 0).
var _anchor_off := 0.0
var _anchor_vel := 0.0
var _vrate := 0.0
var _last_target := Vector3.ZERO
var _lead := Vector3.ZERO
## 0 = no chão, 1 = planando (vai e volta suave).
var _glide := 0.0
var _super := 0.0


## Ajusta a câmera ao formato da tela. Numa faixa larga (2 jogadores, um em cima do
## outro) o campo de visão passa a ser medido na horizontal, senão a imagem ficaria
## esticada nas laterais, e a câmera sobe e se afasta um pouco para o kart caber.
func fit_aspect(aspect: float) -> void:
	if aspect > 2.4:
		keep_aspect = Camera3D.KEEP_WIDTH
		base_fov = 92.0
		distance = 5.2 * KartScale.CAMERA
		height = 2.25 * KartScale.CAMERA
		look_height = 0.8 * KartScale.CAMERA
		look_ahead = 3.0 * KartScale.CAMERA
	else:
		keep_aspect = Camera3D.KEEP_HEIGHT
	fov = base_fov


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


## Posiciona a câmera atrás do kart imediatamente (sem suavização).
func snap() -> void:
	if target == null:
		return
	_dir = target.get_forward()
	_up = target.get_up()
	_anchor_off = 0.0
	_anchor_vel = 0.0
	_vrate = 0.0
	_last_target = target.global_position
	_lead = Vector3.ZERO
	global_position = _desired_position()
	look_at(_look_point(), _view_up())
	reset_physics_interpolation()


func _physics_process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	_glide = move_toward(_glide, 1.0 if target.gliding else 0.0, GLIDE_BLEND_SPEED * delta)
	_super = move_toward(_super, 1.0 if target.is_super() else 0.0, SUPER_BLEND_SPEED * delta)
	var fwd := target.get_forward()
	# Nas curvas inclinadas a câmera deita junto com o kart (na parede, a parede vira chão).
	var goal_up := target.get_up()
	if goal_up == Vector3.UP and _up.dot(Vector3.UP) > 0.99999:
		_up = Vector3.UP
	else:
		_up = _up.slerp(goal_up, 1.0 - exp(-UP_SHARPNESS * delta)).normalized()
	_dir = (_dir - _up * _dir.dot(_up)).normalized() if _up != Vector3.UP else _dir
	var vel := target.velocity
	vel -= _up * vel.dot(_up)
	var wanted := fwd
	# Durante o drift a câmera acompanha um pouco a direção real do movimento.
	if vel.length() > 3.0 and vel.normalized().dot(fwd) > 0.0:
		wanted = fwd.lerp(vel.normalized(), 0.6 if target.drifting else 0.4).normalized()
	_dir = _dir.lerp(wanted, 1.0 - exp(-follow_sharpness * delta)).normalized()
	_update_anchor(delta)

	var desired := _desired_position()
	var smooth := 1.0 if intro > 0.0 else 1.0 - exp(-POSITION_SHARPNESS * delta)
	# Compensa quase todo o atraso da suavização para o kart não "fugir" da câmera
	# em alta velocidade (sobra um leve afastamento que dá sensação de velocidade).
	_lead = _lead.lerp(vel * (0.85 / POSITION_SHARPNESS), 1.0 - exp(-LEAD_SHARPNESS * delta))
	global_position = global_position.lerp(desired + _lead, smooth)
	var look := _look_point()
	if _shake > 0.0:
		_shake = move_toward(_shake, 0.0, delta * 2.5)
		look += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * _shake * 0.25 * KartScale.CAMERA
	if global_position.distance_to(look) > 0.01:
		look_at(look, _view_up())

	var target_fov := _speed_fov()
	var fov_sharpness := FOV_OPEN_SHARPNESS if target_fov > fov else FOV_CLOSE_SHARPNESS
	fov = lerpf(fov, target_fov, 1.0 - exp(-fov_sharpness * delta))


## A altura do ponto seguido: o quanto o kart subiu ou desceu neste passo entra na
## mola (o ponto fica onde estava) e a mola volta ao kart, criticamente amortecida.
func _update_anchor(delta: float) -> void:
	var p := target.global_position
	var moved := p - _last_target
	_last_target = p
	if intro > 0.0 or moved.length() > 8.0:
		# Apresentação ou teleporte: sem atraso.
		_anchor_off = 0.0
		_anchor_vel = 0.0
		_vrate = 0.0
		return
	var rise := moved.dot(_up)
	_anchor_off -= rise
	_vrate = lerpf(_vrate, rise / maxf(delta, 0.0001), 1.0 - exp(-VRATE_SHARPNESS * delta))
	var w := ANCHOR_FREQ
	# Alvo da mola: um pouco à frente na subida (o atraso de uma mola crítica seguindo
	# uma rampa é 2·v/w).
	var goal := clampf(_vrate * 2.0 / w * ANCHOR_LEAD, -MAX_ANCHOR_LAG, MAX_ANCHOR_LAG)
	var f := 1.0 + 2.0 * delta * w
	var hoo := delta * w * w
	var det := 1.0 / (f + delta * hoo)
	var x := (f * _anchor_off + delta * _anchor_vel + delta * hoo * goal) * det
	_anchor_vel = (_anchor_vel + hoo * (goal - _anchor_off)) * det
	_anchor_off = clampf(x, -MAX_ANCHOR_LAG, MAX_ANCHOR_LAG)


func _anchor() -> Vector3:
	return target.global_position + _up * _anchor_off


## "Cima" da imagem: no meio do caminho entre o mundo e o kart.
func _view_up() -> Vector3:
	if _up == Vector3.UP:
		return Vector3.UP
	return Vector3.UP.slerp(_up, VIEW_ROLL).normalized()


func _speed_fov() -> float:
	var t := clampf((absf(target.speed) - SPEED_FOV_START) / (SPEED_FOV_FULL - SPEED_FOV_START), 0.0, 1.0)
	var kick := SPEED_FOV * t + (BOOST_FOV if target.boost_time > 0.0 else 0.0)
	# Escala a tangente do meio-ângulo: o mesmo zoom em qualquer `base_fov`.
	var widen := tan(deg_to_rad(REFERENCE_FOV + kick) * 0.5) / tan(deg_to_rad(REFERENCE_FOV) * 0.5)
	return rad_to_deg(2.0 * atan(tan(deg_to_rad(base_fov) * 0.5) * widen))


func _desired_position() -> Vector3:
	var dir := _dir
	var dist := distance
	var h := height
	if intro > 0.0:
		# Gira em volta do kart, de frente para trás.
		var e := intro * intro * (3.0 - 2.0 * intro)
		dir = _dir.rotated(_up, e * PI * 0.92)
		dist = lerpf(distance, distance * 1.15, e)
		h = lerpf(height, 1.05 * KartScale.CAMERA, e)
	var g := _glide_amount()
	dist += GLIDE_DISTANCE * g
	h += GLIDE_HEIGHT * g
	var su := _super * _super * (3.0 - 2.0 * _super)
	dist += SUPER_DISTANCE * su
	h += SUPER_HEIGHT * su
	return _anchor() - dir * dist + _up * (h + _lift())


func _look_point() -> Vector3:
	var ahead := look_ahead * (1.0 - intro)
	var su := _super * _super * (3.0 - 2.0 * _super)
	return _anchor() + _up * (look_height + _lift() + GLIDE_LOOK * _glide_amount() + SUPER_LOOK * su) + _dir * ahead


## Veículos de banco alto (o piloto sentado mais alto que no Kart Padrão): a câmera e o
## ponto para onde ela olha sobem o mesmo tanto, para a cabeça do piloto tapar a pista do
## mesmo jeito em todos.
func _lift() -> float:
	if target == null or target.data == null:
		return 0.0
	return maxf(target.data.driver_origin().y, 0.0) * target.data.race_scale


func _glide_amount() -> float:
	return _glide * _glide * (3.0 - 2.0 * _glide)
