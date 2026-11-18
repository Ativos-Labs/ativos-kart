@tool
class_name JumpRamp
extends StaticBody3D
## Colisão de uma rampa de pulo (montada por TrackRampBuilder). Guarda a borda de
## onde o kart decola: o kart consulta `contains` e `to_lip_space` para saber que
## está na rampa e quando a frente dele passa da borda (veja Kart._launch).

## Borda da rampa no espaço local deste corpo: origem = meio da borda na altura do
## asfalto, -Z = sentido da corrida, X = direita.
var lip := Transform3D.IDENTITY
## Comprimento da subida até a borda (m).
var ramp_length := 10.0
## Meia largura do topo (m), sem as saias laterais.
var half_width := 6.8
## Altura da borda acima do asfalto (m).
var height := 1.4
## Inclinação na borda (rad) = ângulo de saída do pulo.
var launch_angle := 0.38
## Rampa de asa-delta: o kart decola alto e plana (veja Kart._open_glider).
var glider := false


func _ready() -> void:
	add_to_group(&"jump_ramp")


## Posição no espaço da borda: x = lateral (direita +), y = altura acima do asfalto,
## z = distância até a borda no sentido da corrida (negativa = ainda antes da borda).
func to_lip_space(global_pos: Vector3) -> Vector3:
	var p := (global_transform * lip).affine_inverse() * global_pos
	return Vector3(p.x, p.y, -p.z)


## O ponto está em cima da rampa (topo ou saias), entre o começo e a borda?
func contains(global_pos: Vector3) -> bool:
	var p := to_lip_space(global_pos)
	return p.z > -ramp_length - 0.5 and p.z < 1.2 \
			and absf(p.x) < half_width + height * 1.3 + 0.3 \
			and p.y > -0.6 and p.y < height + 1.0


## Sentido da rampa (horizontal, no espaço global).
func get_forward() -> Vector3:
	var f := -(global_basis * lip.basis).z
	f.y = 0.0
	return f.normalized()
