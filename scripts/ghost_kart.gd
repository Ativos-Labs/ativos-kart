class_name GhostKart
extends Node3D
## Kart transparente que refaz o percurso de um Ghost (o recorde da pista). Não bate
## em nada: é só o modelo, posto a cada quadro onde o kart gravado estava.

const GHOST_SHADER := preload("res://shaders/ghost.gdshader")

var ghost: Ghost
var _visual: Node3D
var _model: KartVisual
var _material: ShaderMaterial


## Monta o modelo do kart e do piloto do fantasma. Devolve false se não deu.
func setup(g: Ghost) -> bool:
	ghost = g
	var kart_data := load(g.kart_path) as KartData if ResourceLoader.exists(g.kart_path) else null
	if kart_data == null and not GameState.karts.is_empty():
		kart_data = GameState.karts[0]
	if kart_data == null:
		return false
	var character := load(g.character_path) as CharacterData if ResourceLoader.exists(g.character_path) else null
	name = "Fantasma"
	_visual = Node3D.new()
	add_child(_visual)
	_model = KartVisual.new()
	_visual.add_child(_model)
	_model.setup(kart_data, character)
	_model.scale = Vector3.ONE * kart_data.race_scale
	_material = ShaderMaterial.new()
	_material.shader = GHOST_SHADER
	# O piloto monta os materiais dele no _ready: a troca espera um quadro.
	_apply_material.call_deferred()
	show_at(0.0, 0.0)
	return true


func _apply_material() -> void:
	for node in find_children("*", "GeometryInstance3D", true, false):
		var gi := node as GeometryInstance3D
		gi.material_override = _material
		gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Põe o fantasma onde o kart gravado estava `time` segundos depois da largada.
## Depois do fim do percurso ele some.
func show_at(time: float, delta: float) -> void:
	if ghost == null:
		return
	var s := ghost.sample(time)
	visible = not s.is_empty()
	if s.is_empty():
		return
	global_transform = Transform3D(Basis(Vector3.UP, s.yaw), s.position)
	_visual.transform = Transform3D(Basis(s.visual as Quaternion), Vector3(0.0, s.squash, 0.0))
	_model.update_motion(delta, s.speed, s.steer, s.drift)
