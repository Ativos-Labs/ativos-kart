class_name CharacterMesh
extends RefCounted
## Junta as malhas de um personagem numa malha só, com uma superfície e um material.
##
## O Celerino vem do Blender com 10 malhas e 35 superfícies (uma por material em cada
## malha). No renderer Compatibility (a versão web) cada superfície com esqueleto custa,
## a cada quadro em que os ossos mexem, um passe de deformação na GPU (transform
## feedback), além do desenho e das sombras. Com 8 pilotos + o retrato do HUD eram ~315
## passes por quadro, o maior custo da corrida no navegador (medido: congelar os pilotos
## economizava 3 a 9 ms por quadro num M4).
##
## Os 13 materiais do Celerino são cores lisas com o mesmo sombreamento, então a cor e a
## rugosidade de cada um vão para os vértices e tudo vira uma superfície com
## `character.gdshader`, que imita o StandardMaterial3D e faz a recoloração dos
## adversários. Os dados vão em CUSTOM0 (float: rgb = cor sRGB, a = rugosidade, + 2 nas
## partes recoloríveis). Os níveis de detalhe (LOD) são refeitos por material e
## juntados, para uma cor não vazar na outra de longe.
##
## A malha junta é feita uma vez por modelo e fica guardada. Se o modelo não servir
## (texturas, transparência, esqueletos diferentes...), nada muda e o personagem usa
## as malhas originais.

const SHADER := preload("res://shaders/character.gdshader")
## Ângulo para juntar normais ao simplificar (o mesmo do importador do Godot).
const LOD_NORMAL_MERGE_ANGLE := 60.0
const LOD_NORMAL_SPLIT_ANGLE := 25.0

## Desligado, os personagens usam as malhas originais (para comparar ou depurar).
static var enabled := true
## "modelo|materiais recoloríveis" → {"mesh", "material", "ref"} (vazio = não serve).
static var _cache := {}
## "modelo|materiais|cor" → ShaderMaterial recolorido.
static var _tinted := {}


## Solta as malhas e materiais guardados (no fim do jogo; senão o Godot acusa vazamento).
static func clear_cache() -> void:
	_cache.clear()
	_tinted.clear()


## Troca as malhas de `model` (instância do `data.model_scene`) pela malha junta.
## Devolve false (e não mexe em nada) se o modelo não puder ser juntado.
static func apply(model: Node3D, data: CharacterData) -> bool:
	if not enabled or data == null or data.model_scene == null:
		return false
	var meshes: Array[MeshInstance3D] = []
	for node in model.find_children("*", "MeshInstance3D", true, false):
		meshes.append(node as MeshInstance3D)
	if meshes.is_empty():
		return false
	var key := "%s|%s" % [data.model_scene.resource_path, ",".join(data.tint_materials)]
	if not _cache.has(key):
		_cache[key] = _build(meshes, data.tint_materials)
	var entry: Dictionary = _cache[key]
	if entry.is_empty():
		return false

	var first := meshes[0]
	var merged := MeshInstance3D.new()
	merged.name = "Corpo"
	merged.mesh = entry.mesh
	merged.skin = first.skin
	first.get_parent().add_child(merged)
	merged.skeleton = first.skeleton
	merged.cast_shadow = first.cast_shadow
	merged.layers = first.layers
	if data.model_tint.a > 0.0:
		merged.material_override = _tint_material(key, entry, data.model_tint)
	for mi in meshes:
		mi.get_parent().remove_child(mi)
		mi.free()
	return true


static func _tint_material(key: String, entry: Dictionary, tint: Color) -> ShaderMaterial:
	var tkey := "%s|%s" % [key, tint.to_html()]
	if _tinted.has(tkey):
		return _tinted[tkey]
	# A mesma conta de CharacterRig._apply_tint: a 1ª cor da lista vira a cor nova e as
	# outras mantêm a proporção de saturação e brilho em relação a ela.
	var ref: Color = entry.ref
	var mat := (entry.material as ShaderMaterial).duplicate() as ShaderMaterial
	mat.set_shader_parameter(&"tint_enabled", true)
	mat.set_shader_parameter(&"tint_hue", tint.h)
	mat.set_shader_parameter(&"tint_saturation_ratio", tint.s / maxf(ref.s, 0.01))
	mat.set_shader_parameter(&"tint_value_ratio", tint.v / maxf(ref.v, 0.01))
	_tinted[tkey] = mat
	return mat


## Material de cor lisa que dá para levar para os vértices.
static func _plain(mat: Material, like: BaseMaterial3D) -> bool:
	var m := mat as StandardMaterial3D
	if m == null:
		return false
	if m.albedo_texture or m.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or m.next_pass \
			or m.emission_enabled or m.normal_enabled or m.rim_enabled or m.clearcoat_enabled \
			or m.ao_enabled or m.vertex_color_use_as_albedo or m.grow or m.billboard_mode != BaseMaterial3D.BILLBOARD_DISABLED:
		return false
	if like and (m.cull_mode != like.cull_mode or m.shading_mode != like.shading_mode \
			or m.diffuse_mode != like.diffuse_mode or m.specular_mode != like.specular_mode \
			or not is_equal_approx(m.metallic, like.metallic) or not is_equal_approx(m.metallic_specular, like.metallic_specular)):
		return false
	return m.cull_mode == BaseMaterial3D.CULL_DISABLED and m.shading_mode == BaseMaterial3D.SHADING_MODE_PER_PIXEL \
			and m.diffuse_mode == BaseMaterial3D.DIFFUSE_BURLEY and m.specular_mode == BaseMaterial3D.SPECULAR_SCHLICK_GGX


static func _build(meshes: Array[MeshInstance3D], tint_names: PackedStringArray) -> Dictionary:
	var first := meshes[0]
	var parent := first.get_parent()
	var like: StandardMaterial3D = null
	# Confere se tudo pode virar uma superfície só.
	for mi in meshes:
		var mesh := mi.mesh as ArrayMesh
		if mesh == null or mi.get_parent() != parent or mi.skin != first.skin or mi.skeleton != first.skeleton \
				or not mi.transform.is_equal_approx(Transform3D.IDENTITY) or mesh.get_blend_shape_count() > 0 \
				or mi.material_override or mi.material_overlay:
			return {}
		for s in mesh.get_surface_count():
			if mesh.surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES or mi.get_surface_override_material(s):
				return {}
			var mat := mesh.surface_get_material(s)
			if not _plain(mat, like):
				return {}
			if like == null:
				like = mat as StandardMaterial3D
	if like == null or first.skin == null:
		return {}

	# Uma superfície por material (de todas as malhas), cada uma com os seus LODs. Os LODs
	# são feitos por material: assim uma cor não vaza na outra quando a malha simplifica.
	var groups := {}  # material → {verts, normals, bones, weights, indices}
	var order: Array[StandardMaterial3D] = []
	for mi in meshes:
		var mesh := mi.mesh as ArrayMesh
		for s in mesh.get_surface_count():
			var mat := mesh.surface_get_material(s) as StandardMaterial3D
			var arrays := mesh.surface_get_arrays(s)
			var src_v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var src_b = arrays[Mesh.ARRAY_BONES]
			var src_w = arrays[Mesh.ARRAY_WEIGHTS]
			if src_b == null or src_w == null or (src_w as PackedFloat32Array).size() != src_v.size() * 4:
				return {}
			if not groups.has(mat):
				groups[mat] = {"verts": PackedVector3Array(), "normals": PackedVector3Array(),
						"bones": PackedInt32Array(), "weights": PackedFloat32Array(), "indices": PackedInt32Array()}
				order.append(mat)
			var g: Dictionary = groups[mat]
			var base: int = (g.verts as PackedVector3Array).size()
			g.verts.append_array(src_v)
			g.normals.append_array(arrays[Mesh.ARRAY_NORMAL])
			g.bones.append_array(src_b)
			g.weights.append_array(src_w)
			var idx = arrays[Mesh.ARRAY_INDEX]
			if idx == null:
				g.indices.append_array(PackedInt32Array(range(base, base + src_v.size())))
			else:
				g.indices.append_array(_offset(idx, base))

	var importer := ImporterMesh.new()
	for mat in order:
		var g: Dictionary = groups[mat]
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = g.verts
		arr[Mesh.ARRAY_NORMAL] = g.normals
		arr[Mesh.ARRAY_BONES] = g.bones
		arr[Mesh.ARRAY_WEIGHTS] = g.weights
		arr[Mesh.ARRAY_INDEX] = g.indices
		importer.add_surface(Mesh.PRIMITIVE_TRIANGLES, arr)
	importer.generate_lods(LOD_NORMAL_MERGE_ANGLE, LOD_NORMAL_SPLIT_ANGLE, [])
	var lod_count := 0
	for i in order.size():
		# Os LODs só servem se a simplificação não mexeu nos vértices.
		var count: int = (groups[order[i]].verts as PackedVector3Array).size()
		if (importer.get_surface_arrays(i)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() != count:
			lod_count = 0
			break
		lod_count = maxi(lod_count, importer.get_surface_lod_count(i))

	# Junta tudo: os vértices de cada material em sequência, com a cor e a rugosidade.
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var custom := PackedFloat32Array()
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	var indices := PackedInt32Array()
	var lod_indices: Array[PackedInt32Array] = []
	var lod_sizes := PackedFloat32Array()
	for k in lod_count:
		lod_indices.append(PackedInt32Array())
		lod_sizes.append(0.0)
	var ref := Color.BLACK
	for i in order.size():
		var mat := order[i]
		var g: Dictionary = groups[mat]
		var count: int = (g.verts as PackedVector3Array).size()
		var base := verts.size()
		verts.append_array(g.verts)
		normals.append_array(g.normals)
		bones.append_array(g.bones)
		weights.append_array(g.weights)
		var tintable := tint_names.has(mat.resource_name)
		if not tint_names.is_empty() and mat.resource_name == tint_names[0]:
			ref = mat.albedo_color
		var c := mat.albedo_color
		var rough := mat.roughness + (2.0 if tintable else 0.0)
		var c_arr := PackedFloat32Array()
		c_arr.resize(count * 4)
		for v in count:
			c_arr[v * 4] = c.r
			c_arr[v * 4 + 1] = c.g
			c_arr[v * 4 + 2] = c.b
			c_arr[v * 4 + 3] = rough
		custom.append_array(c_arr)
		indices.append_array(_offset(g.indices, base))
		# LOD k de cada material (o último que ele tiver, se tiver menos níveis).
		var own := importer.get_surface_lod_count(i)
		for k in lod_count:
			var src: PackedInt32Array = g.indices if own == 0 else importer.get_surface_lod_indices(i, mini(k, own - 1))
			lod_indices[k].append_array(_offset(src, base))
			if own > 0:
				lod_sizes[k] = maxf(lod_sizes[k], importer.get_surface_lod_size(i, mini(k, own - 1)))

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_CUSTOM0] = custom
	arrays[Mesh.ARRAY_BONES] = bones
	arrays[Mesh.ARRAY_WEIGHTS] = weights
	arrays[Mesh.ARRAY_INDEX] = indices
	var lods := {}
	for k in lod_count:
		# Níveis que quase não simplificam não ajudam.
		if lod_sizes[k] > 0.0 and lod_indices[k].size() < indices.size() * 0.9 and not lods.has(lod_sizes[k]):
			lods[lod_sizes[k]] = lod_indices[k]
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], lods,
			Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter(&"metallic_value", like.metallic)
	material.set_shader_parameter(&"specular_value", like.metallic_specular)
	mesh.surface_set_material(0, material)
	return {"mesh": mesh, "material": material, "ref": ref}


static func _offset(src: PackedInt32Array, base: int) -> PackedInt32Array:
	if base == 0:
		return src
	var out := src.duplicate()
	for i in out.size():
		out[i] += base
	return out
