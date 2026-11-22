class_name BoostExhaustFx
extends Node3D
## Fogo do turbo saindo dos escapamentos/turbinas de cada kart (KartData.exhausts):
## - chamas presas às bocas (shaders/boost_flame.gdshader), uma malha só por kart;
## - faíscas e um pouco de fumaça (partículas soltas no mundo, ficam para trás);
## - no kart do jogador, uma luz que pisca no chão e na carroceria.
## A chama nasce com um estouro maior (ignição) e, quando o turbo acaba, o escapamento
## ainda dá um ou dois pipocos (como um carro de corrida tirando o pé).
## Fica dentro do KartVisual, então acompanha inclinação, manobras e race_scale.
## O Kart chama ignite() quando um turbo começa e update() a cada quadro de física.

const FLAME_SHADER := preload("res://shaders/boost_flame.gdshader")
## Sprites por chama: a externa (comprimento todo) e o núcleo (perto da boca).
const OUTER_SPRITES := 9
const CORE_SPRITES := 6
## Fração do comprimento ocupada pelo núcleo (igual a CORE_LEN no shader).
const CORE_LEN := 0.42
## Escala do raio guardado na cor do vértice (igual a RADIUS_MAX no shader).
const RADIUS_MAX := 0.3
## Tempo (s) para a chama acender e apagar.
const ATTACK := 0.05
const RELEASE := 0.14
## Ignição: a chama nasce maior e mais clara e assenta em IGNITION_TIME s.
const IGNITION_BOOST := 0.55
const IGNITION_TIME := 0.3
## Pipocos depois do turbo: força (fração da chama) e duração (s).
const POP_STRENGTH := 0.6
const POP_TIME := 0.07
## Chama mais longa em turbos mais fortes (nível 1, 2, 3 do mini-turbo).
const HEAT_PER_LEVEL := 0.12

const SPARK_COLORS := {
	KartExhaust.Style.FOGO: Color(1.8, 0.9, 0.3),
	KartExhaust.Style.JATO: Color(0.9, 1.5, 2.6),
	KartExhaust.Style.PLASMA: Color(0.8, 2.0, 2.6),
}
const LIGHT_COLORS := {
	KartExhaust.Style.FOGO: Color(1.0, 0.55, 0.2),
	KartExhaust.Style.JATO: Color(0.45, 0.65, 1.0),
	KartExhaust.Style.PLASMA: Color(0.4, 0.85, 1.0),
}
const SMOKE_COLORS := {
	KartExhaust.Style.FOGO: Color(0.3, 0.29, 0.28, 0.5),
	KartExhaust.Style.JATO: Color(0.75, 0.82, 0.9, 0.3),
	KartExhaust.Style.PLASMA: Color(0.7, 0.85, 0.95, 0.25),
}

var _flames: MeshInstance3D
var _material: ShaderMaterial
var _sparks: GPUParticles3D
var _smoke: GPUParticles3D
var _light: OmniLight3D
var _light_energy := 0.4
var _intensity := 0.0
var _ignition := 0.0
var _heat := 1.0
var _was_boosting := false
## Tempo até cada pipoco (negativo = acontecendo).
var _pops: Array[float] = []
var _smoke_time := 0.0
var _rng := RandomNumberGenerator.new()


## Monta chamas, partículas e (com `with_light`) a luz para as saídas do kart.
func setup(data: KartData, with_light: bool) -> void:
	var exhausts := data.get_exhausts()
	var main := exhausts[0]
	for ex in exhausts:
		if ex.radius > main.radius:
			main = ex

	_material = ShaderMaterial.new()
	_material.shader = FLAME_SHADER
	_flames = MeshInstance3D.new()
	_flames.name = "Chamas"
	_flames.mesh = _build_mesh(exhausts)
	_flames.material_override = _material
	_flames.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flames.visible = false
	add_child(_flames)

	var points := _emission_points(exhausts)
	var soft := _soft_texture()
	_sparks = _make_sparks(points, soft, SPARK_COLORS[main.style], exhausts.size())
	add_child(_sparks)
	_smoke = _make_smoke(points, soft, SMOKE_COLORS[main.style], main.radius, exhausts.size())
	add_child(_smoke)

	if with_light:
		var center := Vector3.ZERO
		var back := 0.0
		for ex in exhausts:
			center += ex.position
			back = maxf(back, ex.position.z)
		center /= exhausts.size()
		_light = OmniLight3D.new()
		_light.name = "LuzTurbo"
		# Baixa e atrás do kart: tinge o asfalto (e só um pouco a traseira) com o
		# brilho do fogo. Mais perto da carroceria ela pintava o kart todo.
		_light.position = Vector3(center.x, 0.25 * KartScale.ITEMS, back + 0.6 * KartScale.ITEMS)
		_light.light_color = LIGHT_COLORS[main.style]
		_light.omni_range = 2.6 * KartScale.ITEMS
		_light.light_specular = 0.2
		_light.omni_attenuation = 1.4
		_light.shadow_enabled = false
		_light.light_bake_mode = Light3D.BAKE_DISABLED
		_light.visible = false
		add_child(_light)
	_rng.randomize()


## Um turbo começou (`power` = nível do mini-turbo, 1 a 3).
func ignite(power := 1) -> void:
	_heat = 1.0 + HEAT_PER_LEVEL * clampi(power - 1, 0, 2)
	_ignition = 1.0
	_pops.clear()
	_smoke_time = 0.08


func update(delta: float, boosting: bool) -> void:
	if boosting:
		_intensity = move_toward(_intensity, 1.0, delta / ATTACK)
		_was_boosting = true
	else:
		if _was_boosting:
			_was_boosting = false
			_schedule_pops()
		_intensity = move_toward(_intensity, 0.0, delta / RELEASE)
	_ignition = maxf(_ignition - delta / IGNITION_TIME, 0.0)

	var pop := 0.0
	for i in range(_pops.size() - 1, -1, -1):
		var before := _pops[i]
		_pops[i] -= delta
		if _pops[i] <= -POP_TIME:
			_pops.remove_at(i)
		elif _pops[i] <= 0.0:
			pop = maxf(pop, POP_STRENGTH * (1.0 + _pops[i] / POP_TIME))
			if before > 0.0:
				_smoke_time = 0.1
	var shown := maxf(_intensity * (1.0 + IGNITION_BOOST * _ignition * _ignition), pop)

	var on := shown > 0.01
	if _flames.visible != on:
		_flames.visible = on
	if on:
		_material.set_shader_parameter(&"intensity", shown)
		_material.set_shader_parameter(&"heat", _heat)
	var sparks_on := boosting or pop > 0.0
	if _sparks.emitting != sparks_on:
		_sparks.emitting = sparks_on
	_smoke_time = maxf(_smoke_time - delta, 0.0)
	var smoke_on := _smoke_time > 0.0
	if _smoke.emitting != smoke_on:
		_smoke.emitting = smoke_on
	if _light:
		_light.visible = on
		if on:
			_light.light_energy = _light_energy * minf(shown, 1.5) * _rng.randf_range(0.8, 1.1)


## Liga (ou desliga) chamas, faíscas e fumaça por alguns quadros atrás da tela de
## carregamento, só para os shaders compilarem antes da corrida (veja Race.warm_up).
func prewarm(on: bool) -> void:
	_flames.visible = on
	if on:
		_material.set_shader_parameter(&"intensity", 1.0)
		_material.set_shader_parameter(&"heat", _heat)
	for p: GPUParticles3D in [_sparks, _smoke]:
		if on:
			p.emitting = true
		else:
			p.restart()
			p.emitting = false
	if _light:
		_light.visible = on


## Um ou dois pipocos logo depois que o turbo acaba.
func _schedule_pops() -> void:
	_pops.clear()
	var t := _rng.randf_range(0.06, 0.16)
	_pops.append(t)
	if _rng.randf() < 0.7:
		_pops.append(t + _rng.randf_range(0.12, 0.3))


# --- Montagem -------------------------------------------------------------------

## Uma malha com todas as chamas do kart: um quad por sprite (veja o shader).
static func _build_mesh(exhausts: Array[KartExhaust]) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	var aabb := AABB()
	var corners := [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
	for n in exhausts.size():
		var ex := exhausts[n]
		var dir := ex.direction.normalized()
		var length := ex.get_length()
		var radius := clampf(ex.radius / RADIUS_MAX, 0.0, 1.0)
		for layer in 2:
			var count := CORE_SPRITES if layer == 1 else OUTER_SPRITES
			for i in count:
				var k := float(i) / float(count - 1)
				var t := lerpf(0.02, CORE_LEN, k) if layer == 1 else lerpf(0.03, 1.0, pow(k, 1.25))
				var color := Color(float(layer), float(ex.style) * 0.5, radius, rng.randf())
				var base := verts.size()
				for corner: Vector2 in corners:
					verts.append(ex.position)
					normals.append(dir)
					uvs.append(corner)
					uv2s.append(Vector2(t, length))
					colors.append(color)
				indices.append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))
		# Caixa para o corte de visibilidade: a chama no máximo (turbo forte + ignição).
		var box := AABB(ex.position, Vector3.ZERO).expand(ex.position + dir * length * 2.2).grow(ex.radius * 4.0 + 0.15)
		aabb = box if n == 0 else aabb.merge(box)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uv2s
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.custom_aabb = aabb
	return mesh


## Pontos de saída das partículas (centro e um anel em cada boca) e a direção de
## cada um, como texturas para EMISSION_SHAPE_DIRECTED_POINTS.
static func _emission_points(exhausts: Array[KartExhaust]) -> Array[ImageTexture]:
	var pts: Array[Vector3] = []
	var dirs: Array[Vector3] = []
	for ex in exhausts:
		var dir := ex.direction.normalized()
		var side := dir.cross(Vector3.UP)
		if side.length_squared() < 0.01:
			side = Vector3.RIGHT
		side = side.normalized()
		var up := side.cross(dir).normalized()
		pts.append(ex.position)
		dirs.append(dir)
		for i in 4:
			var a := TAU * i / 4.0
			pts.append(ex.position + (side * cos(a) + up * sin(a)) * ex.radius * 0.6)
			dirs.append(dir)
	var img_p := Image.create(pts.size(), 1, false, Image.FORMAT_RGBF)
	var img_d := Image.create(pts.size(), 1, false, Image.FORMAT_RGBF)
	for i in pts.size():
		img_p.set_pixel(i, 0, Color(pts[i].x, pts[i].y, pts[i].z))
		img_d.set_pixel(i, 0, Color(dirs[i].x, dirs[i].y, dirs[i].z))
	return [ImageTexture.create_from_image(img_p), ImageTexture.create_from_image(img_d)]


static func _directed(points: Array[ImageTexture]) -> ParticleProcessMaterial:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_DIRECTED_POINTS
	pm.emission_point_texture = points[0]
	pm.emission_normal_texture = points[1]
	pm.emission_point_count = points[0].get_width()
	# Nos pontos dirigidos o +Z da partícula vira a direção do escapamento.
	pm.direction = Vector3(0, 0, 1)
	return pm


## Faíscas: riscos curtos e muito claros que voam para trás e caem.
static func _make_sparks(points: Array[ImageTexture], soft: Texture2D, color: Color, nozzles: int) -> GPUParticles3D:
	var pm := _directed(points)
	# Poucas e espalhadas (faíscas em fila contínua viravam um feixe de luz).
	pm.spread = 30.0
	pm.initial_velocity_min = 3.0 * KartScale.ITEMS
	pm.initial_velocity_max = 7.0 * KartScale.ITEMS
	pm.inherit_velocity_ratio = 0.95
	pm.gravity = Vector3(0, -7.0, 0)
	pm.damping_min = 1.0
	pm.damping_max = 3.0
	pm.scale_min = 0.5
	pm.scale_max = 1.0
	pm.color = color
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	var ct := CurveTexture.new()
	ct.curve = curve
	pm.scale_curve = ct

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = soft
	mat.disable_fog = true
	var quad := QuadMesh.new()
	quad.size = Vector2(0.025, 0.12) * KartScale.ITEMS
	quad.material = mat

	var p := GPUParticles3D.new()
	p.name = "FaiscasTurbo"
	p.process_material = pm
	p.draw_pass_1 = quad
	p.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY
	p.amount = clampi(nozzles * 3, 4, 10)
	p.lifetime = 0.22
	p.randomness = 0.4
	p.local_coords = false
	p.emitting = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-4, -3, -2), Vector3(8, 6, 12))
	return p


## Fumaça: baforadas que crescem e somem, só na ignição e nos pipocos.
static func _make_smoke(points: Array[ImageTexture], soft: Texture2D, color: Color, radius: float, nozzles: int) -> GPUParticles3D:
	var pm := _directed(points)
	pm.spread = 25.0
	pm.initial_velocity_min = 1.0 * KartScale.ITEMS
	pm.initial_velocity_max = 2.5 * KartScale.ITEMS
	pm.inherit_velocity_ratio = 0.75
	pm.gravity = Vector3(0, 0.8, 0) * KartScale.ITEMS
	pm.damping_min = 2.0
	pm.damping_max = 4.0
	pm.angle_min = -180.0
	pm.angle_max = 180.0
	# Raio da saída em relação a uma de 7 cm nos karts de antes do encaixe piloto × kart.
	var base := clampf(radius / (0.07 * KartScale.ITEMS), 0.6, 1.6)
	pm.scale_min = 0.7 * base
	pm.scale_max = 1.1 * base
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.45))
	curve.add_point(Vector2(1, 1.0))
	var ct := CurveTexture.new()
	ct.curve = curve
	pm.scale_curve = ct
	var grad := Gradient.new()
	grad.set_color(0, Color(color, 0.0))
	grad.set_color(1, Color(color, 0.0))
	grad.add_point(0.15, color)
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = soft
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.billboard_keep_scale = true
	# Some perto da câmera (a fumaça passa por ela quando fica para trás).
	mat.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	mat.distance_fade_min_distance = 0.6 * KartScale.CAMERA
	mat.distance_fade_max_distance = 2.2 * KartScale.CAMERA
	var quad := QuadMesh.new()
	quad.size = Vector2(0.45, 0.45) * KartScale.ITEMS
	quad.material = mat

	var p := GPUParticles3D.new()
	p.name = "FumacaTurbo"
	p.process_material = pm
	p.draw_pass_1 = quad
	p.amount = clampi(nozzles * 3, 4, 10)
	p.lifetime = 0.7
	p.local_coords = false
	p.emitting = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-4, -3, -2), Vector3(8, 6, 14))
	return p


## Textura redonda de borda suave (a mesma das faíscas do drift).
static func _soft_texture() -> Texture2D:
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 64
	tex.height = 64
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	return tex
