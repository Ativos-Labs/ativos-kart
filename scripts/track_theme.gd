@tool
class_name TrackTheme
extends RefCounted
## Cores e vegetação de cada cenário da pista. O cenário é escolhido no nó raiz da
## pista ("Cenário"); o céu, o sol e a névoa ficam nos nós WorldEnvironment e Sol.

enum Scenery { CAMPO, PRAIA, DESERTO, NEVE }


## Parâmetros do shaders/terrain.gdshader (o que não aparece fica no padrão).
static func terrain_params(scenery: int) -> Dictionary:
	match scenery:
		Scenery.PRAIA:
			return {
				"grass_a": Color(0.3, 0.66, 0.17), "grass_b": Color(0.52, 0.76, 0.2), "grass_dark": Color(0.17, 0.48, 0.13),
				"mowed_light": Color(0.42, 0.78, 0.2), "mowed_dark": Color(0.33, 0.67, 0.16),
				"sand": Color(1.0, 0.91, 0.68), "rock": Color(0.5, 0.45, 0.4), "rock_dark": Color(0.3, 0.27, 0.26),
				"snow_height": 9999.0, "sand_band": 2.6, "stripe_strength": 0.7,
			}
		Scenery.DESERTO:
			return {
				"grass_a": Color(0.88, 0.6, 0.35), "grass_b": Color(0.95, 0.72, 0.45), "grass_dark": Color(0.74, 0.45, 0.25),
				"mowed_light": Color(0.86, 0.6, 0.38), "mowed_dark": Color(0.79, 0.52, 0.32),
				"sand": Color(0.95, 0.8, 0.56), "rock": Color(0.82, 0.44, 0.25), "rock_dark": Color(0.56, 0.26, 0.16),
				"rock_band": Color(0.95, 0.68, 0.45), "band_mix": 0.45, "strata": 0.16, "strata_freq": 0.55,
				"rock_slope": 0.24, "snow_height": 9999.0, "sand_band": 1.4, "stripe_strength": 0.3,
			}
		Scenery.NEVE:
			return {
				"grass_a": Color(0.78, 0.85, 0.96), "grass_b": Color(0.95, 0.97, 1.0), "grass_dark": Color(0.6, 0.7, 0.9),
				"mowed_light": Color(0.88, 0.92, 0.98), "mowed_dark": Color(0.72, 0.79, 0.92),
				"sand": Color(0.78, 0.85, 0.95), "rock": Color(0.52, 0.53, 0.58), "rock_dark": Color(0.3, 0.31, 0.36),
				"snow": Color(0.95, 0.97, 1.0), "snow_height": 30.0, "sand_band": 1.2, "stripe_strength": 0.45,
				"rock_slope": 0.42,
			}
	return {}


## Parâmetros do shaders/water.gdshader (lagos, rios e mar).
static func water_params(scenery: int) -> Dictionary:
	match scenery:
		Scenery.PRAIA:
			return {"shallow_color": Color(0.24, 0.93, 0.86), "deep_color": Color(0.0, 0.42, 0.78), "depth_range": 7.0}
		Scenery.DESERTO:
			return {"shallow_color": Color(0.36, 0.78, 0.68), "deep_color": Color(0.05, 0.36, 0.5), "depth_range": 4.0}
		Scenery.NEVE:
			return {"ice": 1.0, "shallow_color": Color(0.86, 0.95, 1.0), "deep_color": Color(0.5, 0.74, 0.93), "depth_range": 5.0}
	return {}


## Cor da base e da ponta dos tufos de grama.
static func grass_colors(scenery: int) -> Array[Color]:
	match scenery:
		Scenery.PRAIA:
			return [Color(0.12, 0.42, 0.08), Color(0.55, 0.88, 0.25)]
		Scenery.DESERTO:
			return [Color(0.42, 0.34, 0.14), Color(0.9, 0.78, 0.42)]
		Scenery.NEVE:
			return [Color(0.16, 0.3, 0.16), Color(0.86, 0.92, 0.98)]
	return [Color(0.12, 0.36, 0.08), Color(0.5, 0.8, 0.22)]


## Cores das flores (vazio = sem flores).
static func flower_palette(scenery: int) -> Array[Color]:
	match scenery:
		Scenery.PRAIA:
			return [Color(0.95, 0.15, 0.25), Color(1.0, 0.45, 0.7), Color(1.0, 0.82, 0.1), Color(1.0, 0.55, 0.15), Color(1, 1, 1)]
		Scenery.DESERTO:
			return [Color(0.75, 0.4, 1.0), Color(1.0, 0.82, 0.1), Color(1.0, 0.45, 0.6)]
		Scenery.NEVE:
			return []
	return [Color(1, 1, 1), Color(1.0, 0.82, 0.1), Color(1.0, 0.45, 0.7), Color(0.95, 0.2, 0.25), Color(0.65, 0.4, 1.0), Color(0.45, 0.75, 1.0)]


## Quanto de neve cobre o alto das copas e arbustos (0 a 1).
static func snow_cover(scenery: int) -> float:
	return 1.0 if scenery == Scenery.NEVE else 0.0


## Cor de um arbusto.
static func bush_color(scenery: int, rng: RandomNumberGenerator) -> Color:
	match scenery:
		Scenery.PRAIA:
			if rng.randf() < 0.25:
				return Color.from_hsv(rng.randf_range(0.95, 1.02), rng.randf_range(0.5, 0.75), 1.0)
			return Color.from_hsv(rng.randf_range(0.26, 0.36), rng.randf_range(0.7, 0.9), rng.randf_range(0.55, 0.8))
		Scenery.DESERTO:
			return Color.from_hsv(rng.randf_range(0.14, 0.24), rng.randf_range(0.3, 0.5), rng.randf_range(0.5, 0.7))
		Scenery.NEVE:
			return Color.from_hsv(rng.randf_range(0.36, 0.42), rng.randf_range(0.55, 0.75), rng.randf_range(0.32, 0.46))
	if rng.randf() < 0.18:
		return Color.from_hsv(rng.randf_range(0.9, 1.0), 0.45, 1.0)
	return Color.from_hsv(rng.randf_range(0.25, 0.33), rng.randf_range(0.65, 0.85), rng.randf_range(0.5, 0.75))


## --- Efeitos do kart no chão (veja Kart.set_ground_theme) ------------------------------

## Cor das marcas de pneu fora do asfalto (no asfalto elas são de borracha escura).
## O alfa é a força da marca.
static func offroad_mark_color(scenery: int) -> Color:
	match scenery:
		Scenery.PRAIA:
			return Color(0.62, 0.5, 0.32, 0.55)
		Scenery.DESERTO:
			return Color(0.5, 0.27, 0.14, 0.5)
		Scenery.NEVE:
			return Color(0.5, 0.58, 0.74, 0.5)
	return Color(0.2, 0.24, 0.08, 0.5)


static var _dust_cache := {}


## Poeira (ou neve) que sai das rodas de trás no drift e fora do asfalto: terra no
## Campo, areia na Praia, nuvens de poeira vermelha no Deserto e neve fofa na Neve.
## Um material por cenário, compartilhado pelos karts.
static func dust_material(scenery: int) -> ParticleProcessMaterial:
	if _dust_cache.has(scenery):
		return _dust_cache[scenery]
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(0.18, 0.04, 0.12)
	m.direction = Vector3(0.0, 1.0, 1.0)
	m.spread = 35.0
	m.damping_min = 1.5
	m.damping_max = 2.5
	var color := Color(0.62, 0.55, 0.42, 0.5)
	var grow := 2.2
	match scenery:
		Scenery.PRAIA:
			# Areia: grãos pesados que sobem e caem rápido.
			color = Color(0.97, 0.87, 0.62, 0.7)
			m.initial_velocity_min = 2.0
			m.initial_velocity_max = 4.2
			m.gravity = Vector3(0.0, -7.0, 0.0)
			m.scale_min = 0.45
			m.scale_max = 0.9
			grow = 1.4
		Scenery.DESERTO:
			# Poeira fina: nuvens grandes que ficam no ar.
			color = Color(0.86, 0.58, 0.36, 0.5)
			m.initial_velocity_min = 0.8
			m.initial_velocity_max = 2.2
			m.gravity = Vector3(0.0, 0.4, 0.0)
			m.scale_min = 0.9
			m.scale_max = 1.5
			grow = 3.0
		Scenery.NEVE:
			# Neve fofa: um leque branco que sobe alto e cai.
			color = Color(0.97, 0.98, 1.0, 0.9)
			m.direction = Vector3(0.0, 1.3, 1.0)
			m.initial_velocity_min = 2.4
			m.initial_velocity_max = 4.6
			m.gravity = Vector3(0.0, -6.0, 0.0)
			m.scale_min = 0.5
			m.scale_max = 1.1
			grow = 1.8
		_:
			m.initial_velocity_min = 1.0
			m.initial_velocity_max = 2.6
			m.gravity = Vector3(0.0, -1.0, 0.0)
			m.scale_min = 0.7
			m.scale_max = 1.3
	m.color = color
	# Medidas feitas para os karts de antes do encaixe piloto × kart: a poeira encolhe com
	# eles (a malha da partícula é a do kart, já menor).
	m.emission_box_extents *= KartScale.ITEMS
	m.initial_velocity_min *= KartScale.ITEMS
	m.initial_velocity_max *= KartScale.ITEMS
	m.gravity *= KartScale.ITEMS
	# Cresce e some aos poucos (sem estalar no fim da vida).
	var size := Curve.new()
	size.add_point(Vector2(0.0, 1.0 / grow))
	size.add_point(Vector2(1.0, 1.0))
	var size_tex := CurveTexture.new()
	size_tex.curve = size
	m.scale_curve = size_tex
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	fade.add_point(0.6, Color(1, 1, 1, 0.7))
	var fade_tex := GradientTexture1D.new()
	fade_tex.gradient = fade
	m.color_ramp = fade_tex
	_dust_cache[scenery] = m
	return m


## Solta os materiais guardados (fim do jogo).
static func clear_cache() -> void:
	_dust_cache.clear()


## Duração (s) de cada partícula de poeira.
static func dust_lifetime(scenery: int) -> float:
	match scenery:
		Scenery.PRAIA:
			return 0.55
		Scenery.DESERTO:
			return 1.2
		Scenery.NEVE:
			return 0.8
	return 0.8


## Cor das pedras soltas.
static func rock_color(scenery: int, rng: RandomNumberGenerator) -> Color:
	match scenery:
		Scenery.DESERTO:
			return Color.from_hsv(rng.randf_range(0.03, 0.07), rng.randf_range(0.45, 0.6), rng.randf_range(0.62, 0.82))
		Scenery.NEVE:
			return Color.from_hsv(0.6, rng.randf_range(0.05, 0.12), rng.randf_range(0.45, 0.6))
	return Color.from_hsv(0.08, rng.randf_range(0.08, 0.18), rng.randf_range(0.5, 0.68))
