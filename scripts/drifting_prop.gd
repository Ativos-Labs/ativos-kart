class_name DriftingProp
extends Node3D
## Movimento simples de cenário: o dirigível dá voltas em cima da pista e os
## balões flutuam devagar. (Não roda no editor, só no jogo.)

## Centro da volta (no espaço do pai). Com raio 0 o objeto só flutua no lugar.
@export var orbit_center := Vector3.ZERO
@export var orbit_radius := 0.0
## Velocidade da volta em radianos por segundo (negativo = sentido contrário).
@export var orbit_speed := 0.035
@export var bob_height := 1.2
@export var bob_speed := 0.35
@export var spin_speed := 0.04

var _angle := 0.0
var _base_y := 0.0
var _time := 0.0


func _ready() -> void:
	_base_y = position.y
	_time = randf() * 10.0
	if orbit_radius > 0.0:
		_angle = atan2(position.z - orbit_center.z, position.x - orbit_center.x)


func _process(delta: float) -> void:
	_time += delta
	var bob := sin(_time * bob_speed) * bob_height
	if orbit_radius > 0.0:
		_angle += orbit_speed * delta
		var p := orbit_center + Vector3(cos(_angle), 0.0, sin(_angle)) * orbit_radius
		p.y = _base_y + bob
		position = p
		var dir := Vector3(-sin(_angle), 0.0, cos(_angle)) * signf(orbit_speed)
		basis = Basis.looking_at(dir, Vector3.UP)
	else:
		position.y = _base_y + bob
		rotate_y(delta * spin_speed)
