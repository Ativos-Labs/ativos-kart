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


## Cor das pedras soltas.
static func rock_color(scenery: int, rng: RandomNumberGenerator) -> Color:
	match scenery:
		Scenery.DESERTO:
			return Color.from_hsv(rng.randf_range(0.03, 0.07), rng.randf_range(0.45, 0.6), rng.randf_range(0.62, 0.82))
		Scenery.NEVE:
			return Color.from_hsv(0.6, rng.randf_range(0.05, 0.12), rng.randf_range(0.45, 0.6))
	return Color.from_hsv(0.08, rng.randf_range(0.08, 0.18), rng.randf_range(0.5, 0.68))
