@tool
class_name MeshMerge
extends RefCounted
## Junta malhas primitivas (com transformação) numa superfície só — como
## `SurfaceTool.append_from`, mas sem ler a malha de volta do RenderingServer. No
## Forward+ cada leitura espera a GPU (~0,6 ms na thread principal, mesmo quando a
## pista é gerada numa thread), e uma pista com pontes chegava a 220 leituras.
##
## Os arrays de cada formato ficam num cache: caixa, esfera e cilindro são guardados
## em tamanho unitário e escalados (dá a mesma malha: posições, normais, tangentes e
## UVs), então "caixa de 2 m" e "caixa de 3 m" usam a mesma leitura. As demais
## primitivas são guardadas por todos os parâmetros.
##
## Uso: append_from(malha, 0, transform)... set_material(m); commit([malha]).

## Chave do formato → arrays da malha (vértice, normal, tangente, UV, índices).
static var _cache := {}
static var _cache_lock := Mutex.new()

var _verts := PackedVector3Array()
var _normals := PackedVector3Array()
var _tangents := PackedFloat32Array()
var _uvs := PackedVector2Array()
var _indices := PackedInt32Array()
var _colors := PackedColorArray()
var _has_colors := false
var _material: Material


## `color` (opcional) vira a cor de vértice da peça (COLOR no shader): peças de cores
## diferentes na mesma superfície.
func append_from(mesh: PrimitiveMesh, _surface: int, xform: Transform3D, color := Color.WHITE) -> void:
	var scale := _unit_scale(mesh)
	var scalable := scale != Vector3.ZERO
	var key := _unit_key(mesh, scale) if scalable else _full_key(mesh)
	_cache_lock.lock()
	var arrays: Array = _cache.get(key, [])
	_cache_lock.unlock()
	if arrays.is_empty():
		# A leitura fica fora da trava: numa thread ela espera a thread principal,
		# que pode estar querendo a trava para gerar outra pista.
		arrays = (_unit_mesh(mesh, scale) if scalable else mesh).get_mesh_arrays()
		if scalable:
			_clean_directions(arrays)
		_cache_lock.lock()
		_cache[key] = arrays
		_cache_lock.unlock()
	if not scalable:
		scale = Vector3.ONE

	# A normal leva a inversa da escala (é o que a malha no tamanho certo tem) e
	# depois a transformação, como no SurfaceTool.
	var pos_basis := xform.basis * Basis.from_scale(scale)
	var normal_basis := xform.basis * Basis.from_scale(Vector3.ONE / scale)
	var flip := -1.0 if xform.basis.determinant() < 0.0 else 1.0
	var src_v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var src_n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var src_t: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
	var src_uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var src_i: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var base := _verts.size()
	for i in src_v.size():
		_verts.append(xform.origin + pos_basis * src_v[i])
		_normals.append((normal_basis * src_n[i]).normalized())
		var t := (pos_basis * Vector3(src_t[i * 4], src_t[i * 4 + 1], src_t[i * 4 + 2])).normalized()
		_tangents.append_array([t.x, t.y, t.z, src_t[i * 4 + 3] * flip])
	_uvs.append_array(src_uv)
	if color != Color.WHITE or _has_colors:
		if not _has_colors:
			_has_colors = true
			_colors.resize(base)
			_colors.fill(Color.WHITE)
		for i in src_v.size():
			_colors.append(color)
	for index in src_i:
		_indices.append(base + index)


func set_material(material: Material) -> void:
	_material = material


## Cria a superfície (numa malha nova ou acrescentada em `existing`). Com `with_lods`
## ela ganha versões simplificadas que o Godot usa de longe (LOD): para malhas
## repetidas centenas de vezes (as copas das árvores), que eram a maior parte dos
## triângulos do quadro.
func commit(existing: ArrayMesh = null, with_lods := false) -> ArrayMesh:
	var mesh := existing if existing else ArrayMesh.new()
	if _verts.is_empty():
		return mesh
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _verts
	arrays[Mesh.ARRAY_NORMAL] = _normals
	arrays[Mesh.ARRAY_TANGENT] = _tangents
	arrays[Mesh.ARRAY_TEX_UV] = _uvs
	arrays[Mesh.ARRAY_INDEX] = _indices
	if _has_colors:
		arrays[Mesh.ARRAY_COLOR] = _colors
	var lods := {}
	if with_lods:
		var importer := ImporterMesh.new()
		importer.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays)
		importer.generate_lods(60.0, 25.0, [])
		for k in importer.get_surface_lod_count(0):
			lods[importer.get_surface_lod_size(0, k)] = importer.get_surface_lod_indices(0, k)
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], lods)
	if _material:
		mesh.surface_set_material(mesh.get_surface_count() - 1, _material)
	return mesh


## Escala da malha em relação à versão unitária (caixa, esfera ou cilindro), ou
## ZERO se ela tiver de ser guardada como está.
static func _unit_scale(mesh: PrimitiveMesh) -> Vector3:
	if mesh.flip_faces or mesh.add_uv2:
		return Vector3.ZERO
	var s := Vector3.ZERO
	if mesh is BoxMesh:
		s = (mesh as BoxMesh).size
	elif mesh is SphereMesh and not (mesh as SphereMesh).is_hemisphere:
		var sphere := mesh as SphereMesh
		s = Vector3(sphere.radius, sphere.height * 0.5, sphere.radius)
	elif mesh is CylinderMesh:
		var cyl := mesh as CylinderMesh
		var r := maxf(cyl.top_radius, cyl.bottom_radius)
		s = Vector3(r, cyl.height, r)
	if s.x < 0.0001 or s.y < 0.0001 or s.z < 0.0001:
		return Vector3.ZERO
	return s


static func _unit_key(mesh: PrimitiveMesh, scale: Vector3) -> String:
	if mesh is BoxMesh:
		var box := mesh as BoxMesh
		return "box %d %d %d" % [box.subdivide_width, box.subdivide_height, box.subdivide_depth]
	if mesh is SphereMesh:
		var sphere := mesh as SphereMesh
		return "sphere %d %d" % [sphere.radial_segments, sphere.rings]
	var cyl := mesh as CylinderMesh
	return "cylinder %d %d %s %s %s %s" % [cyl.radial_segments, cyl.rings, cyl.cap_top, cyl.cap_bottom,
			cyl.top_radius / scale.x, cyl.bottom_radius / scale.x]


static func _unit_mesh(mesh: PrimitiveMesh, scale: Vector3) -> PrimitiveMesh:
	var unit: PrimitiveMesh = mesh.duplicate()
	if unit is BoxMesh:
		(unit as BoxMesh).size = Vector3.ONE
	elif unit is SphereMesh:
		(unit as SphereMesh).radius = 1.0
		(unit as SphereMesh).height = 2.0
	else:
		var cyl := unit as CylinderMesh
		cyl.top_radius /= scale.x
		cyl.bottom_radius /= scale.x
		cyl.height = 1.0
	return unit


## Normais e tangentes voltam do RenderingServer comprimidas: (0, 1, 0) vira
## (0, 1, -0.000015). Numa escala bem desigual (cabo de 5 cm × 31 m) esse resto
## cresce 600 vezes e entorta a normal da tampa em 0,5°; aqui ele é zerado.
static func _clean_directions(arrays: Array) -> void:
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for i in normals.size():
		normals[i] = _snap(normals[i])
	arrays[Mesh.ARRAY_NORMAL] = normals
	var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
	for i in tangents.size():
		if i % 4 != 3 and absf(tangents[i]) < 0.0001:
			tangents[i] = 0.0
	arrays[Mesh.ARRAY_TANGENT] = tangents


static func _snap(v: Vector3) -> Vector3:
	return Vector3(0.0 if absf(v.x) < 0.0001 else v.x, 0.0 if absf(v.y) < 0.0001 else v.y, 0.0 if absf(v.z) < 0.0001 else v.z)


## Chave com todos os parâmetros da malha (menos o material).
static func _full_key(mesh: PrimitiveMesh) -> String:
	var parts := [mesh.get_class()]
	for prop in mesh.get_property_list():
		var prop_name: String = prop.name
		if prop.usage & PROPERTY_USAGE_STORAGE and prop_name != "material" and not prop_name.begins_with("resource_"):
			parts.append(mesh.get(prop_name))
	return var_to_str(parts)
