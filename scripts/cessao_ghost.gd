class_name CessaoGhost
extends Node3D
## Cessão de crédito em 3D: o Celerino, de fantasma (translúcido, o mesmo shader do
## fantasma do contra-relógio), aparece flutuando em cima do kart do rival, assina um
## contrato no ar (o braço direito rabisca enquanto a assinatura surge no papel), o
## carimbo bate, ele faz joinha e voa com o papel até quem usou o item, sumindo.
## Montado uma vez na carga da corrida (RaceItems), escondido e parado até ser usado.

const CELERINO := "res://data/personagens/celerino.tres"
const GHOST_SHADER := preload("res://shaders/ghost.gdshader")
const PAPER_SHADER := preload("res://shaders/item_contract.gdshader")
## Tamanho do fantasma (o Celerino tem 2 m) e altura dos pés acima do kart (m).
const GHOST_SCALE := 0.85
const HOVER := 1.3
## Opacidade do corpo e da borda (multiplicadas pelo aparecer/sumir).
const BASE_ALPHA := 0.52
const RIM_ALPHA := 0.7

var rig: CharacterRig
var paper: MeshInstance3D
var _mat: ShaderMaterial
var _paper_mat: ShaderMaterial
var _from: Kart
var _to: Kart
var _t := -1.0
var _len := 2.0
var _stage := 0
var _basis := Basis.IDENTITY


## Monta o Celerino-fantasma e o contrato (escondidos).
func build() -> void:
	name = "CelerinoFantasma"
	var data := load(CELERINO) as CharacterData
	if data == null:
		return
	rig = data.instantiate_rig()
	rig.setup_stand(GHOST_SCALE)
	# O modelo olha para +Z; este nó aponta -Z para quem ele encara.
	rig.rotation.y = PI
	add_child(rig)
	_mat = ShaderMaterial.new()
	_mat.shader = GHOST_SHADER
	_mat.set_shader_parameter("ghost_color", Color(0.72, 0.84, 1.0))
	_mat.set_shader_parameter("rim_color", Color(1.0, 1.0, 1.0))
	_apply_material()
	_apply_material.call_deferred()
	paper = MeshInstance3D.new()
	paper.name = "Contrato"
	var quad := QuadMesh.new()
	quad.size = Vector2(0.52, 0.66)
	paper.mesh = quad
	_paper_mat = ShaderMaterial.new()
	_paper_mat.shader = PAPER_SHADER
	_paper_mat.render_priority = 1
	paper.material_override = _paper_mat
	paper.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Na frente do peito, de frente para quem olha (o papel olha para +Z: meia volta),
	# com o topo um pouco para trás.
	paper.position = Vector3(0.08, 0.98, -0.44)
	paper.rotation = Vector3(-0.3, PI, 0.08)
	add_child(paper)
	_set_alpha(0.0)
	_park()


func _apply_material() -> void:
	if rig == null:
		return
	for node in rig.find_children("*", "GeometryInstance3D", true, false):
		var gi := node as GeometryInstance3D
		gi.material_override = _mat
		gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func is_busy() -> bool:
	return _t >= 0.0


## O fantasma aparece em cima de `from`, assina e voa até `to` em `duration` s.
## Devolve false se ele já está ocupado com outra cessão.
func play(from: Kart, to: Kart, duration: float) -> bool:
	if rig == null or is_busy():
		return false
	_from = from
	_to = to
	_len = maxf(duration, 0.5)
	_t = 0.0
	_stage = 0
	visible = true
	rig.process_mode = Node.PROCESS_MODE_INHERIT
	rig.set_face(&"face_happy")
	_paper_mat.set_shader_parameter("reveal", 0.0)
	_paper_mat.set_shader_parameter("stamp", 0.0)
	_set_alpha(0.0)
	set_physics_process(true)
	_update(0.0)
	reset_physics_interpolation()
	return true


## Mostra o fantasma parado na frente de `xf` (compila os shaders atrás da tela de carregamento).
func prewarm(on: bool, xf := Transform3D.IDENTITY) -> void:
	if rig == null or is_busy():
		return
	if on:
		visible = true
		global_transform = xf
		_set_alpha(1.0)
		_paper_mat.set_shader_parameter("reveal", 1.0)
		_paper_mat.set_shader_parameter("stamp", 1.0)
		reset_physics_interpolation()
	else:
		_park()


func _ready() -> void:
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	if _t < 0.0:
		set_physics_process(false)
		return
	_t += delta
	_update(delta)


func _update(_delta: float) -> void:
	if not is_instance_valid(_from) or not is_instance_valid(_to):
		_park()
		return
	var k := clampf(_t / _len, 0.0, 1.0)
	# Rabisca (braço direito) e depois faz joinha.
	if _stage == 0 and k >= 0.12:
		_stage = 1
		rig.play_gesture(&"gesture_wave", _len * 0.48, 2)
	elif _stage == 1 and k >= 0.62:
		_stage = 2
		rig.play_gesture(&"gesture_thumbs_up", _len * 0.3)
		rig.set_face(&"face_smiling")
	_set_alpha(smoothstep(0.0, 0.12, k) * (1.0 - smoothstep(0.86, 1.0, k)))
	_paper_mat.set_shader_parameter("reveal", clampf((k - 0.15) / 0.45, 0.0, 1.0))
	_paper_mat.set_shader_parameter("stamp", clampf((k - 0.6) / 0.06, 0.0, 1.0))
	var start := _from.global_position + Vector3.UP * (HOVER + sin(_t * 5.0) * 0.08)
	var goal := _to.global_position + Vector3.UP * 1.2
	var f := clampf((k - 0.68) / 0.32, 0.0, 1.0)
	var e := f * f * (3.0 - 2.0 * f)
	var pos := start.lerp(goal, e) + Vector3.UP * sin(e * PI) * 1.6
	# Encara quem usou o item; voando, olha para onde vai.
	var look := (_to.global_position - pos) if f <= 0.0 else (goal - start)
	look.y = 0.0
	if look.length_squared() > 0.01:
		_basis = Basis.looking_at(look.normalized(), Vector3.UP)
	var s := lerpf(1.0, 0.45, e) * lerpf(0.6, 1.0, smoothstep(0.0, 0.12, k))
	global_transform = Transform3D(_basis.scaled(Vector3.ONE * s), pos)
	if k >= 1.0:
		_park()


func _set_alpha(a: float) -> void:
	_mat.set_shader_parameter("base_alpha", BASE_ALPHA * a)
	_mat.set_shader_parameter("rim_alpha", RIM_ALPHA * a)
	if _paper_mat:
		_paper_mat.set_shader_parameter("alpha", a)


## Esconde e para (o personagem não gasta nada escondido).
func _park() -> void:
	_t = -1.0
	_from = null
	_to = null
	visible = false
	set_physics_process(false)
	if rig:
		rig.process_mode = Node.PROCESS_MODE_DISABLED
