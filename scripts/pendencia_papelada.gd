class_name PendenciaPapelada
extends Node3D
## Pendência documental em 3D (ItemAttacks a larga atrás do kart): uma pilha de papel
## torta em cima de uma pasta de processo, com a lista do que falta (e o carimbo PENDENTE)
## na folha de cima, um clipe vermelho gigante prendendo o canto e um post-it amarelo em
## pé (para ser vista de longe no asfalto). Fica parada na pista até alguém bater nela.
## Malhas e materiais são os mesmos para todas.

const SHEET_TEX := preload("res://assets/textures/itens/pendencia_folha.png")
## Tamanho de uma folha (m, largura x comprimento) e quantas na pilha.
const SHEET := Vector2(1.05, 1.31)
const SHEETS := 8
const SHEET_THICK := 0.045
## Pasta de processo (parda) embaixo da pilha.
const FOLDER := Vector3(1.3, 0.05, 1.55)

static var _parts: Array = []

var _model: Node3D
var _tween: Tween


func build() -> void:
	name = "Pendencia"
	_model = Node3D.new()
	_model.name = "Modelo"
	add_child(_model)
	for part: Array in _get_parts():
		var mi := MeshInstance3D.new()
		mi.mesh = part[0]
		mi.material_override = part[1]
		mi.transform = part[2]
		_model.add_child(mi)
	visible = false


## Volta ao começo (antes de ser largada de novo).
func reset() -> void:
	if _tween:
		_tween.kill()
	_model.scale = Vector3.ONE
	_model.rotation = Vector3(0.0, randf() * TAU, 0.0)


## Caiu no chão: achata e volta.
func land() -> void:
	if _tween:
		_tween.kill()
	_model.scale = Vector3(1.15, 0.55, 1.15)
	_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_tween.tween_property(_model, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Peças: as folhas (caixinhas finas, tortas), a arte na de cima e o clipe.
static func _get_parts() -> Array:
	if not _parts.is_empty():
		return _parts
	var paper := StandardMaterial3D.new()
	paper.albedo_color = Color("f3ecd8")
	paper.roughness = 0.95
	var art := StandardMaterial3D.new()
	art.albedo_texture = SHEET_TEX
	art.roughness = 0.9
	art.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var sheet := BoxMesh.new()
	sheet.size = Vector3(SHEET.x, SHEET_THICK, SHEET.y)
	var face := PlaneMesh.new()
	face.size = SHEET
	var folder_mat := StandardMaterial3D.new()
	folder_mat.albedo_color = Color("c9944f")
	folder_mat.roughness = 0.85
	var folder := BoxMesh.new()
	folder.size = FOLDER
	_parts = [[folder, folder_mat, Transform3D(Basis(Vector3.UP, 0.12), Vector3(0.0, FOLDER.y * 0.5, 0.0))]]
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var top_xf := Transform3D.IDENTITY
	for i in SHEETS:
		var y := FOLDER.y + SHEET_THICK * (i + 0.5)
		var xf := Transform3D(Basis(Vector3.UP, rng.randf_range(-0.28, 0.28)),
				Vector3(rng.randf_range(-0.07, 0.07), y, rng.randf_range(-0.07, 0.07)))
		_parts.append([sheet, paper, xf])
		top_xf = xf
	# A arte em cima da última folha; o topo dela fica para a frente (-z).
	_parts.append([face, art, top_xf.translated_local(Vector3(0.0, SHEET_THICK * 0.5 + 0.004, 0.0))])
	# Clipe deitado no canto de cima da folha de cima, metade para fora dela.
	var clip_xf := top_xf.translated_local(Vector3(-SHEET.x * 0.3, SHEET_THICK * 0.5 + 0.03, -SHEET.y * 0.5 + 0.28))
	_parts.append([_clip_mesh(), _clip_material(), clip_xf])
	# Post-it amarelo colado na beirada, dobrado para cima.
	var note_mat := StandardMaterial3D.new()
	note_mat.albedo_color = Color("ffd21a")
	note_mat.roughness = 0.8
	note_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Brilho próprio: em pé, um lado fica na sombra e o amarelo puxava para o verde.
	note_mat.emission_enabled = true
	note_mat.emission = Color("ffc21a")
	note_mat.emission_energy_multiplier = 0.5
	var note := QuadMesh.new()
	note.size = Vector2(0.42, 0.42)
	var note_basis := Basis(Vector3.UP, 0.35) * Basis(Vector3.RIGHT, -0.35)
	_parts.append([note, note_mat, top_xf * Transform3D(note_basis, Vector3(SHEET.x * 0.22, 0.2, SHEET.y * 0.32))])
	return _parts


## Clipe de arame (tubo fino) no plano xz: o comprimento ao longo de z, deitado.
static func _clip_mesh() -> ArrayMesh:
	var path := PackedVector2Array()
	path.append(Vector2(-0.1, 0.37))
	_arc(path, Vector2(0.0, -0.28), 0.1, PI, TAU)
	_arc(path, Vector2(0.035, 0.28), 0.065, 0.0, PI)
	path.append(Vector2(-0.03, -0.11))
	var radius := 0.026
	var sides := 6
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array[PackedVector3Array] = []
	var normals: Array[PackedVector3Array] = []
	for i in path.size():
		var p := path[i]
		var prev := path[maxi(i - 1, 0)]
		var next := path[mini(i + 1, path.size() - 1)]
		var t := (next - prev).normalized()
		var side := Vector3(-t.y, 0.0, t.x)
		var ring := PackedVector3Array()
		var ns := PackedVector3Array()
		for k in sides:
			var a := TAU * k / sides
			var n := side * cos(a) + Vector3.UP * sin(a)
			ring.append(Vector3(p.x, 0.0, p.y) + n * radius)
			ns.append(n)
		rings.append(ring)
		normals.append(ns)
	for i in path.size() - 1:
		for k in sides:
			var k2 := (k + 1) % sides
			for v: Vector2i in [Vector2i(i, k), Vector2i(i + 1, k), Vector2i(i + 1, k2), Vector2i(i, k), Vector2i(i + 1, k2), Vector2i(i, k2)]:
				st.set_normal(normals[v.x][v.y])
				st.add_vertex(rings[v.x][v.y])
	return st.commit()


static func _arc(path: PackedVector2Array, center: Vector2, radius: float, from: float, to: float) -> void:
	for i in 9:
		var a := lerpf(from, to, i / 8.0)
		path.append(center + Vector2(cos(a), sin(a)) * radius)


static func _clip_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("e0262e")
	mat.metallic = 0.3
	mat.roughness = 0.35
	# O tubo é fino e visto de todo lado: sem se preocupar com o lado dos triângulos.
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat
