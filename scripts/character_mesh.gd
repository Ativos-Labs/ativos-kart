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
## Modelos com textura (o Jarbas) também juntam se todas as partes usarem a mesma
## textura (um atlas; as partes de cor lisa apontam para um ponto branco dele). Aí o
## material é `character_textured.gdshader`, com UV e recorte pela transparência.
## Nesses, os materiais com nome começando em `NO_SHADOW_PREFIX` (feitos pelo
## tools/personagens/build_personagem.py) ganham + 4 em CUSTOM0.a e não projetam sombra.
##
## Rosto por shape keys (o Rafael): as malhas com blend shapes viram uma segunda malha
## junta ("Rosto"), com os blend shapes de todas elas (a mesma textura e o mesmo
## material). Ficam separadas do corpo porque cada vértice de uma malha com blend shapes
## passa pela mistura deles a cada quadro em que o esqueleto mexe (no Compatibility, um
## passe de transform feedback por blend shape ligado): só os vértices do rosto pagam isso.
## O CharacterRig acha os blend shapes pelo nome, em qualquer MeshInstance3D do modelo.
##
## A malha junta é feita uma vez por modelo e fica guardada. Se o modelo não servir
## (texturas diferentes, transparência com mistura, esqueletos diferentes...), nada
## muda e o personagem usa as malhas originais.

const SHADER := preload("res://shaders/character.gdshader")
const SHADER_TEXTURED := preload("res://shaders/character_textured.gdshader")
## Ângulo para juntar normais ao simplificar (o mesmo do importador do Godot).
const LOD_NORMAL_MERGE_ANGLE := 60.0
const LOD_NORMAL_SPLIT_ANGLE := 25.0
## Materiais (com textura) que não projetam sombra: a aba do boné do Henrique.
const NO_SHADOW_PREFIX := "SemSombra_"

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
		_cache[key] = _build(meshes, data.tint_materials, data.tint_reference.a > 0.0)
	var entry: Dictionary = _cache[key]
	if entry.is_empty():
		return false

	var first := meshes[0]
	var tinted: ShaderMaterial = null
	if data.model_tint.a > 0.0:
		var ref: Color = data.tint_reference if data.tint_reference.a > 0.0 else entry.ref
		tinted = _tint_material(key, entry, data.model_tint, ref)
	for part in [["Corpo", entry.mesh], ["Rosto", entry.face]]:
		if part[1] == null:
			continue
		var merged := MeshInstance3D.new()
		merged.name = part[0]
		merged.mesh = part[1]
		merged.skin = first.skin
		first.get_parent().add_child(merged)
		merged.skeleton = first.skeleton
		merged.cast_shadow = first.cast_shadow
		merged.layers = first.layers
		if tinted:
			merged.material_override = tinted
	for mi in meshes:
		mi.get_parent().remove_child(mi)
		mi.free()
	return true


static func _tint_material(key: String, entry: Dictionary, tint: Color, ref: Color) -> ShaderMaterial:
	var tkey := "%s|%s|%s" % [key, tint.to_html(), ref.to_html()]
	if _tinted.has(tkey):
		return _tinted[tkey]
	# A mesma conta de CharacterRig._apply_tint: a cor de referência (a 1ª da lista, ou
	# CharacterData.tint_reference) vira a cor nova e as outras mantêm a proporção de
	# saturação e brilho em relação a ela.
	var mat := (entry.material as ShaderMaterial).duplicate() as ShaderMaterial
	mat.set_shader_parameter(&"tint_enabled", true)
	mat.set_shader_parameter(&"tint_reference_hue", ref.h)
	mat.set_shader_parameter(&"tint_hue", tint.h)
	mat.set_shader_parameter(&"tint_saturation_ratio", tint.s / maxf(ref.s, 0.01))
	mat.set_shader_parameter(&"tint_value_ratio", tint.v / maxf(ref.v, 0.01))
	_tinted[tkey] = mat
	return mat


## Material que dá para levar para os vértices: cor lisa, ou a mesma textura de todos
## (`like` = o primeiro material). Transparência só recortada (alpha scissor).
static func _plain(mat: Material, like: BaseMaterial3D) -> bool:
	var m := mat as StandardMaterial3D
	if m == null:
		return false
	if like and m.albedo_texture != like.albedo_texture:
		return false
	if m.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED and m.transparency != BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
		return false
	if m.next_pass \
			or m.emission_enabled or m.normal_enabled or m.rim_enabled or m.clearcoat_enabled \
			or m.ao_enabled or m.vertex_color_use_as_albedo or m.grow or m.billboard_mode != BaseMaterial3D.BILLBOARD_DISABLED:
		return false
	if like and (m.cull_mode != like.cull_mode or m.shading_mode != like.shading_mode \
			or m.diffuse_mode != like.diffuse_mode or m.specular_mode != like.specular_mode \
			or not is_equal_approx(m.metallic, like.metallic) or not is_equal_approx(m.metallic_specular, like.metallic_specular)):
		return false
	return m.cull_mode == BaseMaterial3D.CULL_DISABLED and m.shading_mode == BaseMaterial3D.SHADING_MODE_PER_PIXEL \
			and m.diffuse_mode == BaseMaterial3D.DIFFUSE_BURLEY and m.specular_mode == BaseMaterial3D.SPECULAR_SCHLICK_GGX


## `tint_all`: sem lista de materiais, todos podem ser recoloridos (o shader com
## textura escolhe pela matiz).
static func _build(meshes: Array[MeshInstance3D], tint_names: PackedStringArray, tint_all := false) -> Dictionary:
	var first := meshes[0]
	var parent := first.get_parent()
	var like: StandardMaterial3D = null
	# Confere se tudo pode virar uma superfície só.
	for mi in meshes:
		var mesh := mi.mesh as ArrayMesh
		if mesh == null or mi.get_parent() != parent or mi.skin != first.skin or mi.skeleton != first.skeleton \
				or not mi.transform.is_equal_approx(Transform3D.IDENTITY) or mi.material_override or mi.material_overlay:
			return {}
		# Blend shapes: só no modo que o importador de glTF usa (formas em posição absoluta).
		if mesh.get_blend_shape_count() > 0 and mesh.blend_shape_mode != Mesh.BLEND_SHAPE_MODE_NORMALIZED:
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
	var textured := like.albedo_texture != null
	var material := ShaderMaterial.new()
	material.shader = SHADER_TEXTURED if textured else SHADER
	if textured:
		material.set_shader_parameter(&"albedo_texture", like.albedo_texture)
	material.set_shader_parameter(&"metallic_value", like.metallic)
	material.set_shader_parameter(&"specular_value", like.metallic_specular)

	# O corpo (malhas sem blend shapes) e o rosto (com), cada um numa malha junta.
	var body: Array[MeshInstance3D] = []
	var face: Array[MeshInstance3D] = []
	var shape_names: Array[StringName] = []
	for mi in meshes:
		var count: int = (mi.mesh as ArrayMesh).get_blend_shape_count()
		if count > 0:
			face.append(mi)
		else:
			body.append(mi)
		for k in count:
			var shape := (mi.mesh as ArrayMesh).get_blend_shape_name(k)
			if not shape_names.has(shape):
				shape_names.append(shape)
	var no_shapes: Array[StringName] = []
	var out := {"mesh": null, "face": null, "material": material, "ref": Color.BLACK}
	for part in [[body, "mesh"], [face, "face"]]:
		var list: Array[MeshInstance3D] = part[0]
		if list.is_empty():
			continue
		var merged := _merge(list, textured, tint_names, tint_all, shape_names if part[1] == "face" else no_shapes)
		if merged.is_empty():
			return {}
		(merged.mesh as ArrayMesh).surface_set_material(0, material)
		out[part[1]] = merged.mesh
		if merged.has_ref:
			out.ref = merged.ref
	if out.mesh == null:
		# Só rosto (não acontece hoje): ele vira o "corpo".
		out.mesh = out.face
		out.face = null
	return out


## Junta as malhas de `meshes` numa superfície. `shapes`: blend shapes da malha junta (os
## que uma malha não tem ficam parados nela). Devolve {"mesh", "ref", "has_ref"} ou {}.
static func _merge(meshes: Array[MeshInstance3D], textured: bool, tint_names: PackedStringArray, tint_all: bool,
		shapes: Array[StringName]) -> Dictionary:
	# Uma superfície por material (de todas as malhas), cada uma com os seus LODs. Os LODs
	# são feitos por material: assim uma cor não vaza na outra quando a malha simplifica.
	var groups := {}  # material → {verts, normals, bones, weights, indices, shape_v, shape_n}
	var order: Array[StandardMaterial3D] = []
	for mi in meshes:
		var mesh := mi.mesh as ArrayMesh
		# Índice de cada blend shape da malha junta nesta malha (-1 = ela não tem).
		var own := PackedInt32Array()
		for shape in shapes:
			var found := -1
			for k in mesh.get_blend_shape_count():
				if mesh.get_blend_shape_name(k) == shape:
					found = k
					break
			own.append(found)
		for s in mesh.get_surface_count():
			var mat := mesh.surface_get_material(s) as StandardMaterial3D
			var arrays := mesh.surface_get_arrays(s)
			var src_v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var src_n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var src_b = arrays[Mesh.ARRAY_BONES]
			var src_w = arrays[Mesh.ARRAY_WEIGHTS]
			if src_b == null or src_w == null or (src_w as PackedFloat32Array).size() != src_v.size() * 4:
				return {}
			var src_uv = arrays[Mesh.ARRAY_TEX_UV]
			if textured and (src_uv == null or (src_uv as PackedVector2Array).size() != src_v.size()):
				return {}
			if not groups.has(mat):
				var shape_v: Array[PackedVector3Array] = []
				var shape_n: Array[PackedVector3Array] = []
				for k in shapes.size():
					shape_v.append(PackedVector3Array())
					shape_n.append(PackedVector3Array())
				groups[mat] = {"verts": PackedVector3Array(), "normals": PackedVector3Array(), "uvs": PackedVector2Array(),
						"bones": PackedInt32Array(), "weights": PackedFloat32Array(), "indices": PackedInt32Array(),
						"shape_v": shape_v, "shape_n": shape_n}
				order.append(mat)
			var g: Dictionary = groups[mat]
			var base: int = (g.verts as PackedVector3Array).size()
			g.verts.append_array(src_v)
			if textured:
				g.uvs.append_array(src_uv)
			g.normals.append_array(src_n)
			g.bones.append_array(src_b)
			g.weights.append_array(src_w)
			# Formas em posição absoluta (modo NORMALIZED): sem o blend shape, a própria base.
			var blend: Array = []
			if not shapes.is_empty() and mesh.get_blend_shape_count() > 0:
				blend = mesh.surface_get_blend_shape_arrays(s)
			# (Lido, somado e gravado de volta: append_array num elemento de Array, ou depois de
			# um `as`, muda uma cópia.)
			for k in shapes.size():
				var src_k := own[k]
				var sv: PackedVector3Array = g.shape_v[k]
				var sn: PackedVector3Array = g.shape_n[k]
				sv.append_array(src_v if src_k < 0 else blend[src_k][Mesh.ARRAY_VERTEX])
				sn.append_array(src_n if src_k < 0 else blend[src_k][Mesh.ARRAY_NORMAL])
				g.shape_v[k] = sv
				g.shape_n[k] = sn
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
		if textured:
			arr[Mesh.ARRAY_TEX_UV] = g.uvs
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
	var uvs := PackedVector2Array()
	var custom := PackedFloat32Array()
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	var indices := PackedInt32Array()
	var shape_v: Array[PackedVector3Array] = []
	var shape_n: Array[PackedVector3Array] = []
	for k in shapes.size():
		shape_v.append(PackedVector3Array())
		shape_n.append(PackedVector3Array())
	var lod_indices: Array[PackedInt32Array] = []
	var lod_sizes := PackedFloat32Array()
	for k in lod_count:
		lod_indices.append(PackedInt32Array())
		lod_sizes.append(0.0)
	var ref := Color.BLACK
	var has_ref := false
	for i in order.size():
		var mat := order[i]
		var g: Dictionary = groups[mat]
		var count: int = (g.verts as PackedVector3Array).size()
		var base := verts.size()
		verts.append_array(g.verts)
		normals.append_array(g.normals)
		uvs.append_array(g.uvs)
		bones.append_array(g.bones)
		weights.append_array(g.weights)
		for k in shapes.size():
			var sv := shape_v[k]
			var sn := shape_n[k]
			sv.append_array(g.shape_v[k])
			sn.append_array(g.shape_n[k])
			shape_v[k] = sv
			shape_n[k] = sn
		var tintable := tint_names.has(mat.resource_name) or (tint_all and tint_names.is_empty())
		if not tint_names.is_empty() and mat.resource_name == tint_names[0]:
			ref = mat.albedo_color
			has_ref = true
		var c := mat.albedo_color
		var rough := mat.roughness + (2.0 if tintable else 0.0)
		# Partes que não projetam sombra (a aba do boné do Henrique escurecia o rosto): + 4.
		# Só o shader com textura lê essa marca.
		if textured and mat.resource_name.begins_with(NO_SHADOW_PREFIX):
			rough += 4.0
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
	if textured:
		arrays[Mesh.ARRAY_TEX_UV] = uvs
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
	var blend_arrays := []
	if not shapes.is_empty():
		mesh.blend_shape_mode = Mesh.BLEND_SHAPE_MODE_NORMALIZED
		for k in shapes.size():
			mesh.add_blend_shape(shapes[k])
			var b := []
			b.resize(Mesh.ARRAY_MAX)
			b[Mesh.ARRAY_VERTEX] = shape_v[k]
			b[Mesh.ARRAY_NORMAL] = shape_n[k]
			blend_arrays.append(b)
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, blend_arrays, lods,
			Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	return {"mesh": mesh, "ref": ref, "has_ref": has_ref}


static func _offset(src: PackedInt32Array, base: int) -> PackedInt32Array:
	if base == 0:
		return src
	var out := src.duplicate()
	for i in out.size():
		out[i] += base
	return out
