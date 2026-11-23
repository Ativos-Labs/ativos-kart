class_name PickExtras
extends Node3D
## O que aparece junto com o gesto de escolha de um piloto (CharacterRig.play_pick_gesture):
##
## - o objeto na mão (CharacterData.pick_prop: a garrafa do Rafael). O osso, a posição na
##   mão e quando ele aparece vêm do metadado "prop" da animação do gesto (gravado por
##   tools/personagens/gestos_escolha.gd); ele cresce de uma vez com um pulinho;
## - o balão de fala (CharacterData.pick_shout, "SEXTOUU!"), em cima da cabeça, sempre de
##   frente para a câmera e por cima de tudo, com as letras pulando uma a uma a partir de
##   `pick_shout_time` (no ritmo da fala).
##
## O CharacterRig avança o tempo (advance) no mesmo relógio da animação, depois de pôr a
## pose do quadro; end() encolhe tudo e apaga o nó.

const BALLOON_SHADER := preload("res://shaders/balao_fala.gdshader")
const FONT := preload("res://assets/fonts/LilitaOne-Regular.woff2")
## Tempo para o objeto e o balão aparecerem e para sumirem (s).
const POP := 0.16
const GONE := 0.18
## Tempo entre uma letra e a próxima no balão (s) e quanto cada uma demora para crescer.
const LETTER_STEP := 0.1
const LETTER_POP := 0.12
## Altura das letras (no modelo, em metros; cresce com a escala do personagem), margem do
## balão (fração da altura da letra) e onde fica o meio dele (no modelo): ao lado dos olhos,
## do lado esquerdo do piloto, com o rabicho apontando para a boca (a garrafa sobe do lado
## direito; acima da cabeça ele ficava embaixo do aviso "está pronto!").
const LETTER_HEIGHT := 0.1
const FONT_SIZE := 96
const PADDING := Vector2(0.55, 0.45)
const BALLOON_AT := Vector3(0.5, 0.88, 0.1)

var _rig: CharacterRig
var _time := 0.0
var _ending := -1.0
# Objeto na mão.
var _prop: Node3D
var _prop_bone := -1
var _prop_xf := Transform3D.IDENTITY
var _prop_show := 0.0
# Balão.
var _balloon: Node3D
var _balloon_mat: ShaderMaterial
var _letters: Array[Label3D] = []
var _shout_at := 0.0


func setup(rig: CharacterRig, anim: Animation, data: CharacterData) -> void:
	_rig = rig
	name = "EscolhaExtras"
	var meta: Dictionary = anim.get_meta(&"prop", {})
	if data.pick_prop and not meta.is_empty() and rig.skeleton:
		_prop_bone = rig.skeleton.find_bone(String(meta.bone))
		_prop_xf = meta.transform
		_prop_show = float(meta.get("show", 0.0))
		if _prop_bone >= 0:
			_prop = data.pick_prop.instantiate() as Node3D
			_prop.name = "Objeto"
			_prop.visible = false
			add_child(_prop)
	if data.pick_shout != "":
		_shout_at = data.pick_shout_time
		_build_balloon(data)
	advance(0.0)


## Avança `delta` segundos (chamado pelo CharacterRig a cada quadro, depois da pose).
func advance(delta: float) -> void:
	_time += delta
	var fade := 1.0
	if _ending >= 0.0:
		fade = clampf(1.0 - (_time - _ending) / GONE, 0.0, 1.0)
		if fade <= 0.0:
			queue_free()
			return
	var scale_of := func(t: float, length: float) -> float:
		return 0.0 if t < 0.0 else _back_out(clampf(t / length, 0.0, 1.0)) * fade
	if _prop:
		var s: float = scale_of.call(_time - _prop_show, POP)
		_prop.visible = s > 0.001
		if _prop.visible:
			var bone := _rig.skeleton.global_transform * _rig.skeleton.get_bone_global_pose(_prop_bone) * _prop_xf
			_prop.global_transform = bone.scaled_local(Vector3.ONE * s)
	if _balloon:
		var s: float = scale_of.call(_time - _shout_at, POP)
		_balloon.visible = s > 0.001
		if _balloon.visible:
			var cam := get_viewport().get_camera_3d()
			var basis := cam.global_basis.orthonormalized() if cam else Basis.IDENTITY
			# Um balanço pequeno enquanto fala.
			var wobble := sin((_time - _shout_at) * 9.0) * 0.04 * maxf(0.0, 1.0 - (_time - _shout_at) / 1.5)
			_balloon.global_basis = basis * Basis(Vector3.BACK, wobble)
			_balloon.scale = Vector3.ONE * s * _rig.model.scale.x
			for i in _letters.size():
				var ls: float = scale_of.call(_time - _shout_at - LETTER_STEP * (i + 1), LETTER_POP)
				_letters[i].visible = ls > 0.001
				_letters[i].scale = Vector3.ONE * maxf(ls, 0.001)


## Encolhe tudo e apaga o nó (o gesto acabou ou foi desfeito).
func end() -> void:
	if _ending < 0.0:
		_ending = _time


## Sobe passando um pouco do tamanho final e volta (TRANS_BACK, EASE_OUT).
static func _back_out(x: float) -> float:
	var c := 1.70158
	var y := x - 1.0
	return 1.0 + (c + 1.0) * y * y * y + c * y * y


func _build_balloon(data: CharacterData) -> void:
	var text := data.pick_shout
	var px := LETTER_HEIGHT / FONT_SIZE
	var width := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x * px
	var size := Vector2(width + LETTER_HEIGHT * PADDING.x * 2.0, LETTER_HEIGHT * (1.0 + PADDING.y * 2.0))
	var tail_room := 0.3
	var quad_size := Vector2(size.x, size.y / (1.0 - tail_room))
	_balloon = Node3D.new()
	_balloon.name = "Balao"
	add_child(_balloon)
	_balloon.position = _rig.model.position + BALLOON_AT * _rig.model.scale.x
	var quad := MeshInstance3D.new()
	quad.name = "Fundo"
	var mesh := QuadMesh.new()
	mesh.size = quad_size
	# O quad desce um pouco: o meio da elipse fica na origem do nó (o meio do texto).
	mesh.center_offset = Vector3(0.0, -quad_size.y * tail_room * 0.5, 0.0)
	quad.mesh = mesh
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_balloon_mat = ShaderMaterial.new()
	_balloon_mat.shader = BALLOON_SHADER
	_balloon_mat.set_shader_parameter(&"quad_size", quad_size)
	_balloon_mat.set_shader_parameter(&"tail_room", tail_room)
	_balloon_mat.set_shader_parameter(&"tail_side", -1.0)
	_balloon_mat.render_priority = 10
	quad.material_override = _balloon_mat
	_balloon.add_child(quad)
	# Uma Label3D por letra, para cada uma pular sozinha.
	var x := -width * 0.5
	var ink := data.color.darkened(0.25)
	for ch in text:
		var w := FONT.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x * px
		var label := Label3D.new()
		label.text = ch
		label.font = FONT
		label.font_size = FONT_SIZE
		label.pixel_size = px
		label.modulate = ink
		label.outline_size = 0
		label.no_depth_test = true
		label.shaded = false
		label.double_sided = true
		label.render_priority = 11
		label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		label.position = Vector3(x + w * 0.5, 0.0, 0.001)
		label.visible = false
		_balloon.add_child(label)
		_letters.append(label)
		x += w
