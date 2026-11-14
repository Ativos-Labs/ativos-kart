class_name ChaseCamera
extends Camera3D
## Câmera que segue o kart por trás, com zoom no turbo e tremida nas batidas.
## Na tela dividida cada jogador tem a sua (veja `fit_aspect`).

@export var distance := 3.15
@export var height := 1.55
@export var look_height := 0.65
@export var look_ahead := 2.2
@export var follow_sharpness := 6.0
@export var base_fov := 62.0

const POSITION_SHARPNESS := 12.0
## A altura segue mais devagar: no pulo a câmera fica um pouco para trás (dá a
## sensação de altura) e a aterrissagem não dá tranco na imagem. Parte do atraso é
## compensada pela velocidade vertical, para o kart não tapar a pista na subida.
const HEIGHT_SHARPNESS := 8.0
const HEIGHT_LEAD := 0.55

var target: Kart
## 1 = começo da animação de apresentação (câmera na frente do kart), 0 = normal.
var intro := 0.0
## Quanto o campo de visão abre com a velocidade e o turbo.
var fov_kick := 1.0

var _dir := Vector3.FORWARD
var _shake := 0.0


## Ajusta a câmera ao formato da tela. Numa faixa larga (2 jogadores, um em cima do
## outro) o campo de visão passa a ser medido na horizontal, senão a imagem ficaria
## esticada nas laterais, e a câmera sobe e se afasta um pouco para o kart caber.
func fit_aspect(aspect: float) -> void:
	if aspect > 2.4:
		keep_aspect = Camera3D.KEEP_WIDTH
		base_fov = 92.0
		distance = 5.2
		height = 2.25
		look_height = 0.8
		look_ahead = 3.0
		fov_kick = 1.2
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
	global_position = _desired_position()
	look_at(_look_point(), Vector3.UP)
	reset_physics_interpolation()


func _physics_process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	var fwd := target.get_forward()
	var vel := target.velocity
	vel.y = 0.0
	var wanted := fwd
	# Durante o drift a câmera acompanha um pouco a direção real do movimento.
	if vel.length() > 3.0 and vel.normalized().dot(fwd) > 0.0:
		wanted = fwd.lerp(vel.normalized(), 0.6 if target.drifting else 0.4).normalized()
	_dir = _dir.lerp(wanted, 1.0 - exp(-follow_sharpness * delta)).normalized()

	var desired := _desired_position()
	var smooth := 1.0 if intro > 0.0 else 1.0 - exp(-POSITION_SHARPNESS * delta)
	# Compensa quase todo o atraso da suavização para o kart não "fugir" da câmera
	# em alta velocidade (sobra um leve afastamento que dá sensação de velocidade).
	var lead := vel * (0.85 / POSITION_SHARPNESS)
	var height_smooth := 1.0 if intro > 0.0 else 1.0 - exp(-HEIGHT_SHARPNESS * delta)
	var pos := global_position.lerp(desired + lead, smooth)
	pos.y = lerpf(global_position.y, desired.y + target.velocity.y * (HEIGHT_LEAD / HEIGHT_SHARPNESS), height_smooth)
	global_position = pos
	var look := _look_point()
	if _shake > 0.0:
		_shake = move_toward(_shake, 0.0, delta * 2.5)
		look += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * _shake * 0.25
	if global_position.distance_to(look) > 0.01:
		look_at(look, Vector3.UP)

	var speed_ratio := clampf(absf(target.speed) / target.max_speed, 0.0, 1.4)
	var target_fov := base_fov + (speed_ratio * 6.0 + (7.0 if target.boost_time > 0.0 else 0.0)) * fov_kick
	fov = lerpf(fov, target_fov, 1.0 - exp(-4.0 * delta))


func _desired_position() -> Vector3:
	var dir := _dir
	var dist := distance
	var h := height
	if intro > 0.0:
		# Gira em volta do kart, de frente para trás.
		var e := intro * intro * (3.0 - 2.0 * intro)
		dir = _dir.rotated(Vector3.UP, e * PI * 0.92)
		dist = lerpf(distance, distance * 1.15, e)
		h = lerpf(height, 1.05, e)
	return target.global_position - dir * dist + Vector3.UP * h


func _look_point() -> Vector3:
	var ahead := look_ahead * (1.0 - intro)
	return target.global_position + Vector3.UP * look_height + _dir * ahead
