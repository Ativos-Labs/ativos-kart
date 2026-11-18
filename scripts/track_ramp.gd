@tool
class_name TrackRamp
extends Resource
## Uma rampa de pulo na pista. O kart sobe a rampa, sai do chão na borda com a
## inclinação dela (velocidade × tangente do ângulo), faz um arco só com a
## gravidade e cai de volta no asfalto mais à frente (numa rampa de asa-delta, com
## `glider`, ele plana — veja abaixo). Quanto mais
## rápido o kart chega, mais longe vai. Coloque as rampas em retas: o pulo vai reto
## (no ar dá para corrigir só um pouco) e precisa de uns 45 m livres depois da borda.

## Posição da borda da rampa ao longo da volta (0 = largada, 0.5 = metade).
@export_range(0.0, 1.0, 0.001) var at := 0.5:
	set(value):
		at = value
		emit_changed()
## Comprimento da subida até a borda (m).
@export_range(4.0, 30.0, 0.5) var length := 10.0:
	set(value):
		length = value
		emit_changed()
## Altura da borda acima do asfalto (m).
@export_range(0.3, 3.0, 0.05) var height := 1.4:
	set(value):
		height = value
		emit_changed()
## Inclinação na borda (graus) = ângulo de saída do pulo. A rampa começa rente ao
## asfalto e vai curvando até esse ângulo (formato de "kicker").
@export_range(5.0, 35.0, 0.5) var angle := 22.0:
	set(value):
		angle = value
		emit_changed()
## Largura em fração do asfalto (1 = a pista toda).
@export_range(0.2, 1.0, 0.05) var width := 1.0:
	set(value):
		width = value
		emit_changed()
## Deslocamento lateral (-1 = encostada à esquerda, 0 = no meio, 1 = à direita).
## Só faz diferença com a rampa mais estreita que a pista.
@export_range(-1.0, 1.0, 0.05) var offset := 0.0:
	set(value):
		offset = value
		emit_changed()
## Placa de turbo em cima da rampa: o kart chega mais rápido e o pulo fica longo.
@export var turbo := false:
	set(value):
		turbo = value
		emit_changed()

@export_group("Asa-delta")
## Rampa de asa-delta (painel azul aceso com setas brancas e moldura amarela): o kart
## decola alto, a asa-delta abre em cima dele e ele plana uns 4 a 7 s, virando no ar
## (veja Kart, GLIDE_*). Ponha onde caibam uns 150 m de pista depois da borda sem
## outro trecho passando por cima — de preferência no alto de uma ponte, para o voo
## passar por cima do rio, do mar ou do vale. Paredes invisíveis altas seguram o kart
## dentro da pista até `glide_distance` m depois da borda.
@export var glider := false:
	set(value):
		glider = value
		emit_changed()
## Até onde (m depois da borda) vão as paredes invisíveis altas do voo.
@export_range(60.0, 400.0, 5.0) var glide_distance := 260.0:
	set(value):
		glide_distance = value
		emit_changed()


## Formato da subida: altura (0..1) na fração `t` do comprimento. Cúbica que sai
## rente ao asfalto (inclinação 0) e chega na borda com a inclinação pedida.
## O fator `k` fica entre 1,5 e 3 para a rampa só curvar para cima.
func profile(t: float) -> float:
	var k := shape_factor()
	return (3.0 - k) * t * t + (k - 2.0) * t * t * t


## Inclinação real na borda (rad) — com `k` limitado ela pode diferir de `angle`.
func lip_angle() -> float:
	return atan(shape_factor() * height / length)


func shape_factor() -> float:
	return clampf(length * tan(deg_to_rad(angle)) / maxf(height, 0.01), 1.5, 3.0)


## Altura (m, acima da borda) do kart planando `x` m depois da borda de uma rampa de
## asa-delta, chegando a `speed` m/s e sem frear no ar. Mesmas contas do Kart (sobe com
## GLIDE_LAUNCH_VY, a asa abre em GLIDE_OPEN_DELAY e desce até GLIDE_SINK).
static func glide_height(x: float, speed: float) -> float:
	var dt := 1.0 / 60.0
	var y := 0.0
	var vy := Kart.GLIDE_LAUNCH_VY
	var t := 0.0
	var dist := 0.0
	while dist < x and t < 20.0:
		if t < Kart.GLIDE_OPEN_DELAY:
			vy -= Kart.GRAVITY * dt
		else:
			var sink := Kart.GLIDE_SINK
			var open_t := t - Kart.GLIDE_OPEN_DELAY
			if open_t > Kart.GLIDE_TIRED_TIME:
				sink += (open_t - Kart.GLIDE_TIRED_TIME) * Kart.GLIDE_TIRED_SINK
			vy = move_toward(vy, -sink, Kart.GLIDE_GRAVITY * dt)
		y += vy * dt
		dist += speed * dt
		t += dt
	return y
