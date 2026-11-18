class_name ChaseCamera
extends Camera3D
## Câmera que segue o kart por trás, com tremida nas batidas e o campo de visão
## abrindo com a velocidade (veja `_speed_fov`). Com a asa-delta aberta ela se afasta e sobe um pouco, para a asa caber por cima do kart.
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
## Planando: quanto a câmera se afasta, sobe e levanta o olhar (m), e a rapidez da
## troca (fração por segundo).
const GLIDE_DISTANCE := 1.8
const GLIDE_HEIGHT := 0.55
const GLIDE_LOOK := 1.0
const GLIDE_BLEND_SPEED := 1.5
## Campo de visão pela velocidade real (m/s), a mesma conta para todo kart e
## cilindrada (o 150cc abre mais que o 50cc): parado fica em `base_fov` e abre até
## SPEED_FOV graus em SPEED_FOV_FULL m/s (o 150cc no turbo); o turbo soma BOOST_FOV
## para dar o tranco. Os graus valem para a tela de um jogador (REFERENCE_FOV); em
## outro `base_fov` a abertura é proporcional (o mesmo "afastar" da imagem).
const SPEED_FOV_START := 4.0
const SPEED_FOV_FULL := 44.0
const SPEED_FOV := 18.0
const BOOST_FOV := 3.0
const REFERENCE_FOV := 62.0
## Abre rápido (o turbo pega na hora) e fecha mais devagar (frear, bater).
const FOV_OPEN_SHARPNESS := 5.0
const FOV_CLOSE_SHARPNESS := 3.0

var target: Kart
## 1 = começo da animação de apresentação (câmera na frente do kart), 0 = normal.
var intro := 0.0

var _dir := Vector3.FORWARD
var _shake := 0.0
## 0 = no chão, 1 = planando (vai e volta suave).
var _glide := 0.0


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
	_glide = move_toward(_glide, 1.0 if target.gliding else 0.0, GLIDE_BLEND_SPEED * delta)
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

	var target_fov := _speed_fov()
	var fov_sharpness := FOV_OPEN_SHARPNESS if target_fov > fov else FOV_CLOSE_SHARPNESS
	fov = lerpf(fov, target_fov, 1.0 - exp(-fov_sharpness * delta))


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
		dir = _dir.rotated(Vector3.UP, e * PI * 0.92)
		dist = lerpf(distance, distance * 1.15, e)
		h = lerpf(height, 1.05, e)
	var g := _glide_amount()
	dist += GLIDE_DISTANCE * g
	h += GLIDE_HEIGHT * g
	return target.global_position - dir * dist + Vector3.UP * h


func _look_point() -> Vector3:
	var ahead := look_ahead * (1.0 - intro)
	return target.global_position + Vector3.UP * (look_height + GLIDE_LOOK * _glide_amount()) + _dir * ahead


func _glide_amount() -> float:
	return _glide * _glide * (3.0 - 2.0 * _glide)
