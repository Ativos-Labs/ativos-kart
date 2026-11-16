class_name SkidMarks
extends MeshInstance3D
## Marcas de pneu no chão, de todos os karts da corrida, numa malha só (uma chamada
## de desenho). Cada roda que risca o chão é uma "trilha" (`new_trail`): o kart manda
## um ponto por quadro (`add_point`) e cada trecho novo vira dois triângulos ligando
## o ponto anterior ao novo. Os trechos ficam num anel de MAX_SEGMENTS posições: o
## mais antigo dá lugar ao novo. Só a parte nova da malha é enviada à placa de vídeo
## (`mesh_surface_update_*_region`), sem refazer a malha. As marcas somem sozinhas
## com a idade (shaders/skid_marks.gdshader).

const SHADER := preload("res://shaders/skid_marks.gdshader")
## Trechos no anel (8 karts derrapando juntos riscam ~16 trechos por quadro).
const MAX_SEGMENTS := 4096
const VERTS_PER_SEGMENT := 6
## Distância mínima (m) entre dois pontos de uma trilha.
const MIN_STEP := 0.45
## Pulo maior que isso (m) entre dois pontos quebra a trilha (kart reposicionado).
const MAX_STEP := 5.0
## Tempo (s) até a marca sumir.
const LIFE := 9.0

## Relógio das marcas (s).
var clock := 0.0

var _mesh: ArrayMesh
var _material: ShaderMaterial
var _ok := false
var _vertex_stride := 0
var _attr_stride := 0
var _color_offset := 0
var _uv_offset := 0
var _vertex_bytes := PackedByteArray()
var _attr_bytes := PackedByteArray()
var _next := 0
## Trechos escritos desde o último envio (podem dar a volta no anel).
var _dirty_count := 0
var _dirty_start := 0

# Estado de cada trilha (último ponto riscado).
var _has_last := PackedByteArray()
var _last_left := PackedVector3Array()
var _last_right := PackedVector3Array()
var _last_center := PackedVector3Array()
var _last_color := PackedColorArray()


func _ready() -> void:
	name = "MarcasDePneu"
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_build_mesh()


func _build_mesh() -> void:
	var count := MAX_SEGMENTS * VERTS_PER_SEGMENT
	var verts := PackedVector3Array()
	verts.resize(count)
	var colors := PackedColorArray()
	colors.resize(count)
	colors.fill(Color(0, 0, 0, 0))
	var uvs := PackedVector2Array()
	uvs.resize(count)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	_mesh = ArrayMesh.new()
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	# As marcas podem estar em qualquer lugar da pista: a caixa de corte cobre tudo.
	_mesh.custom_aabb = AABB(Vector3(-4000.0, -300.0, -4000.0), Vector3(8000.0, 600.0, 8000.0))
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("life", LIFE)
	mesh = _mesh
	material_override = _material
	# Formato do buffer como o servidor de renderização montou (posição no buffer de
	# vértices; cor e UV juntas no buffer de atributos).
	var format := _mesh.surface_get_format(0)
	_vertex_stride = RenderingServer.mesh_surface_get_format_vertex_stride(format, count)
	_attr_stride = RenderingServer.mesh_surface_get_format_attribute_stride(format, count)
	_color_offset = RenderingServer.mesh_surface_get_format_offset(format, count, Mesh.ARRAY_COLOR)
	_uv_offset = RenderingServer.mesh_surface_get_format_offset(format, count, Mesh.ARRAY_TEX_UV)
	_ok = _vertex_stride == 12 and _attr_stride >= 12
	if not _ok:
		push_warning("SkidMarks: formato de vértice inesperado (%d/%d); marcas de pneu desligadas." % [_vertex_stride, _attr_stride])
		return
	_vertex_bytes.resize(count * _vertex_stride)
	_attr_bytes.resize(count * _attr_stride)


## Cria uma trilha (uma roda) e devolve o número dela.
func new_trail() -> int:
	_has_last.append(0)
	_last_left.append(Vector3.ZERO)
	_last_right.append(Vector3.ZERO)
	_last_center.append(Vector3.ZERO)
	_last_color.append(Color.BLACK)
	return _has_last.size() - 1


## A roda saiu do chão (ou parou de derrapar): o próximo ponto começa uma marca nova.
func break_trail(trail: int) -> void:
	if trail >= 0 and trail < _has_last.size():
		_has_last[trail] = 0


## Ponto novo da trilha: `center` no chão, `side` = direção lateral (unitária),
## `width` = largura da marca e `color` = cor (alfa = força).
func add_point(trail: int, center: Vector3, side: Vector3, width: float, color: Color) -> void:
	if not _ok or trail < 0 or trail >= _has_last.size():
		return
	var half := side * width * 0.5
	var left := center - half
	var right := center + half
	if _has_last[trail] != 0:
		var step := center.distance_to(_last_center[trail])
		if step < MIN_STEP:
			return
		if step <= MAX_STEP:
			_write_segment(_last_left[trail], _last_right[trail], left, right, _last_color[trail], color)
	_has_last[trail] = 1
	_last_left[trail] = left
	_last_right[trail] = right
	_last_center[trail] = center
	_last_color[trail] = color


func _write_segment(l0: Vector3, r0: Vector3, l1: Vector3, r1: Vector3, c0: Color, c1: Color) -> void:
	var seg := _next
	_next = (_next + 1) % MAX_SEGMENTS
	if _dirty_count == 0:
		_dirty_start = seg
	_dirty_count = mini(_dirty_count + 1, MAX_SEGMENTS)
	var base := seg * VERTS_PER_SEGMENT
	# Dois triângulos: (l0, r0, l1) e (r0, r1, l1).
	_put(base + 0, l0, c0, 0.0)
	_put(base + 1, r0, c0, 1.0)
	_put(base + 2, l1, c1, 0.0)
	_put(base + 3, r0, c0, 1.0)
	_put(base + 4, r1, c1, 1.0)
	_put(base + 5, l1, c1, 0.0)


func _put(v: int, p: Vector3, c: Color, across: float) -> void:
	var o := v * _vertex_stride
	_vertex_bytes.encode_float(o, p.x)
	_vertex_bytes.encode_float(o + 4, p.y)
	_vertex_bytes.encode_float(o + 8, p.z)
	var a := v * _attr_stride
	_attr_bytes.encode_u8(a + _color_offset, int(clampf(c.r, 0.0, 1.0) * 255.0))
	_attr_bytes.encode_u8(a + _color_offset + 1, int(clampf(c.g, 0.0, 1.0) * 255.0))
	_attr_bytes.encode_u8(a + _color_offset + 2, int(clampf(c.b, 0.0, 1.0) * 255.0))
	_attr_bytes.encode_u8(a + _color_offset + 3, int(clampf(c.a, 0.0, 1.0) * 255.0))
	_attr_bytes.encode_float(a + _uv_offset, across)
	_attr_bytes.encode_float(a + _uv_offset + 4, clock)


func _physics_process(delta: float) -> void:
	clock += delta


func _process(_delta: float) -> void:
	_material.set_shader_parameter("now", clock)
	if _dirty_count == 0:
		return
	var first := _dirty_start
	var count := _dirty_count
	_dirty_count = 0
	if first + count <= MAX_SEGMENTS:
		_upload(first, count)
	else:
		_upload(first, MAX_SEGMENTS - first)
		_upload(0, first + count - MAX_SEGMENTS)


func _upload(first_segment: int, segments: int) -> void:
	var rid := _mesh.get_rid()
	var v0 := first_segment * VERTS_PER_SEGMENT
	var v1 := (first_segment + segments) * VERTS_PER_SEGMENT
	RenderingServer.mesh_surface_update_vertex_region(rid, 0, v0 * _vertex_stride,
			_vertex_bytes.slice(v0 * _vertex_stride, v1 * _vertex_stride))
	RenderingServer.mesh_surface_update_attribute_region(rid, 0, v0 * _attr_stride,
			_attr_bytes.slice(v0 * _attr_stride, v1 * _attr_stride))
