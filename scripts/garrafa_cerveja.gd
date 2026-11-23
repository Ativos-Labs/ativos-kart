class_name GarrafaCerveja
extends Node3D
## A long neck de vidro verde que o Rafael segura no gesto de escolha ("SEXTOUU!";
## CharacterData.pick_prop = res://scenes/props/garrafa_cerveja.tscn).
##
## Malha de revolução feita aqui pelo perfil abaixo (corpo, ombro, gargalo e o anel da
## boca), a tampinha verde de metal com a saia ondulada e o rótulo oval num pedaço do corpo
## virado para +Z (textura de tools/personagens/build_garrafa.py). A origem é o ponto em que
## a mão fechada segura o gargalo (o metadado "prop" do gesto põe a origem no bolso entre a
## palma, os dedos e o polegar) e +Y aponta para a tampa. Medidas pela mão do Rafael (luva
## deformada na CPU, cortes do punho): o punho fechado cobre 9,1 cm do gargalo (de 4,4 cm
## abaixo a 4,7 cm acima da pegada) e o bolso tem ~1,2 cm de raio. Por isso o gargalo é reto
## e fino (Ø 2,4 cm) por 9 cm: o ombro da garrafa alarga abaixo do mindinho e o anel e a
## tampinha saem acima do polegar, sem atravessar a mão; o rótulo fica todo à mostra.

const LABEL_TEXTURE := preload("res://assets/textures/personagens/garrafa_rotulo.png")
const GLASS_SHADER := preload("res://shaders/garrafa_vidro.gdshader")
## Altura da garrafa e da pegada a partir do fundo (m).
const HEIGHT := 0.27
const GRIP := 0.2025
const SEGMENTS := 36
## Perfil do vidro: (raio, altura a partir do fundo) em metros, de baixo para cima.
const GLASS := [
	Vector2(0.0, 0.0015), Vector2(0.024, 0.0), Vector2(0.0275, 0.0015), Vector2(0.029, 0.006),
	Vector2(0.029, 0.112), Vector2(0.0284, 0.121), Vector2(0.0255, 0.131), Vector2(0.0205, 0.141),
	Vector2(0.0162, 0.149), Vector2(0.0133, 0.155), Vector2(0.0124, 0.159), Vector2(0.0118, 0.249),
	Vector2(0.0133, 0.2505), Vector2(0.0135, 0.2555), Vector2(0.0124, 0.257),
]
## Tampinha: saia ondulada (`CAP_CRIMPS` dobras) e o topo.
const CAP := [
	Vector2(0.0122, 0.2555), Vector2(0.0143, 0.2565), Vector2(0.0144, 0.2665), Vector2(0.0137, 0.2685),
	Vector2(0.011, 0.2697), Vector2(0.0, 0.27),
]
const CAP_CRIMPS := 21
## Rótulo: de onde até onde (altura a partir do fundo, m) e quanto do corpo ele cobre (graus).
const LABEL_FROM := 0.016
const LABEL_TO := 0.104
const LABEL_ARC := 160.0

static var _meshes := {}


func _ready() -> void:
	if _meshes.is_empty():
		_meshes = {"vidro": _lathe(GLASS, 0), "tampa": _lathe(CAP, CAP_CRIMPS), "rotulo": _label()}
		var glass := ShaderMaterial.new()
		glass.shader = GLASS_SHADER
		(_meshes.vidro as ArrayMesh).surface_set_material(0, glass)
		var cap := StandardMaterial3D.new()
		cap.albedo_color = Color(0.09, 0.42, 0.16)
		cap.metallic = 0.75
		cap.roughness = 0.32
		(_meshes.tampa as ArrayMesh).surface_set_material(0, cap)
		var label := StandardMaterial3D.new()
		label.albedo_texture = LABEL_TEXTURE
		label.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		label.alpha_scissor_threshold = 0.5
		label.roughness = 0.45
		label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		(_meshes.rotulo as ArrayMesh).surface_set_material(0, label)
	for part in ["vidro", "rotulo", "tampa"]:
		var mi := MeshInstance3D.new()
		mi.name = part.capitalize()
		mi.mesh = _meshes[part]
		add_child(mi)


## Superfície de revolução de um perfil (raio, altura em frações). `crimps` > 0 ondula a
## parte de raio maior (a saia da tampinha).
static func _lathe(profile: Array, crimps: int) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var rings := profile.size()
	for i in rings:
		var p: Vector2 = profile[i]
		var prev: Vector2 = profile[maxi(i - 1, 0)]
		var next: Vector2 = profile[mini(i + 1, rings - 1)]
		var tangent := (next - prev).normalized()
		var n2 := Vector2(tangent.y, -tangent.x)
		for k in SEGMENTS + 1:
			var a := TAU * k / SEGMENTS
			var r := p.x
			if crimps > 0 and p.x > 0.014:
				r *= 1.0 + 0.045 * cos(a * crimps)
			verts.append(Vector3(sin(a) * r, p.y - GRIP, cos(a) * r))
			normals.append(Vector3(sin(a) * n2.x, n2.y, cos(a) * n2.x).normalized())
			uvs.append(Vector2(float(k) / SEGMENTS, p.y / HEIGHT))
	for i in rings - 1:
		for k in SEGMENTS:
			var a := i * (SEGMENTS + 1) + k
			var b := a + 1
			var d := a + SEGMENTS + 1
			var c := d + 1
			indices.append_array([a, d, c, a, c, b])
	return _mesh(verts, normals, uvs, indices)


## Pedaço do corpo com o rótulo, virado para +Z, um pouco por fora do vidro.
static func _label() -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var steps := 30
	var r := 0.029 + 0.0006
	for k in steps + 1:
		var a := deg_to_rad(LABEL_ARC) * (float(k) / steps - 0.5)
		var n := Vector3(sin(a), 0.0, cos(a))
		for row in 2:
			var y: float = LABEL_FROM if row == 0 else LABEL_TO
			verts.append(Vector3(n.x * r, y - GRIP, n.z * r))
			normals.append(n)
			uvs.append(Vector2(float(k) / steps, 1.0 - row))
	for k in steps:
		var a := k * 2
		indices.append_array([a, a + 1, a + 3, a, a + 3, a + 2])
	return _mesh(verts, normals, uvs, indices)


static func _mesh(verts: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array,
		indices: PackedInt32Array) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
