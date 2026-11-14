class_name KartVisual
extends Node3D
## Modelo do kart com o piloto: rodas girando, volante virando e o personagem sentado
## no banco segurando o volante. Usado na corrida, no menu e nas telas de seleção.
##
## Rodas e volante podem ser nós do modelo ou ossos de um Skeleton3D (karts com
## esqueleto): o nome em KartData é procurado primeiro entre os nós e depois entre os
## ossos. Os giros são calculados no espaço deste nó (frente = -Z, direita = +X).

## Uma peça móvel do modelo (roda ou volante): um nó ou um osso.
class Part:
	var node: Node3D
	var skeleton: Skeleton3D
	var bone := -1
	## Transformação da peça em repouso, relativa ao KartVisual.
	var rest: Transform3D
	## Inversa da transformação do pai da peça (nó pai ou osso pai) relativa ao KartVisual.
	var parent_inv: Transform3D

	## Aplica `pivot` (espaço do KartVisual) sobre a pose de repouso.
	func apply(pivot: Transform3D) -> void:
		var local := parent_inv * pivot * rest
		if node:
			node.transform = local
		else:
			skeleton.set_bone_pose_position(bone, local.origin)
			skeleton.set_bone_pose_rotation(bone, local.basis.get_rotation_quaternion())


var kart_data: KartData
var character: CharacterData
var model: Node3D
var driver: CharacterRig

## Ângulo atual do volante (rad, positivo = esquerda).
var wheel_turn := 0.0

var _spin_front := 0.0
var _spin_rear := 0.0
var _wheel_steer := 0.0
var _front_wheels: Array[Part] = []
var _rear_wheels: Array[Part] = []
var _steering: Array[Part] = []


func setup(p_kart: KartData, p_character: CharacterData) -> void:
	kart_data = p_kart
	character = p_character
	for child in get_children():
		child.queue_free()
	model = p_kart.instantiate_model()
	add_child(model)
	_front_wheels = _find_parts(p_kart.front_wheels)
	_rear_wheels = _find_parts(p_kart.rear_wheels)
	_steering = _find_parts(p_kart.steering_wheel_nodes)
	driver = null
	if p_character and p_character.model_scene:
		driver = p_character.instantiate_rig()
		driver.setup_drive(p_character.kart_scale, p_character.seat_height)
		driver.position = p_kart.seat_position
		driver.rotation = Vector3(0.0, PI, 0.0)
		add_child(driver)
	_update_steering(0.0)


## Atualiza rodas, volante e piloto. `steer` positivo = esquerda.
func update_motion(delta: float, speed: float, steer: float, drift_dir := 0) -> void:
	if kart_data == null:
		return
	var dist := speed * delta
	_spin_front = wrapf(_spin_front + dist / kart_data.front_wheel_radius, 0.0, TAU)
	_spin_rear = wrapf(_spin_rear + dist / kart_data.rear_wheel_radius, 0.0, TAU)
	var steer_target := steer * 0.45
	if drift_dir != 0:
		steer_target = drift_dir * 0.2 + steer * 0.2
	_wheel_steer = lerpf(_wheel_steer, steer_target, 1.0 - exp(-14.0 * delta))
	# Rodar para a frente (-Z) = girar em volta de +X com ângulo negativo.
	for part in _front_wheels:
		part.apply(_pivot(part.rest.origin, Basis(Vector3.UP, _wheel_steer) * Basis(Vector3.RIGHT, -_spin_front)))
	for part in _rear_wheels:
		part.apply(_pivot(part.rest.origin, Basis(Vector3.RIGHT, -_spin_rear)))

	# Volante: no drift ele fica virado para o lado da derrapagem.
	var turn_target := steer * 0.85
	if drift_dir != 0:
		turn_target = drift_dir * 0.55 + steer * 0.4
	wheel_turn = lerpf(wheel_turn, turn_target, 1.0 - exp(-10.0 * delta))
	_update_steering(wheel_turn)
	if driver:
		driver.steer = steer
		driver.drift_dir = drift_dir


func _update_steering(angle: float) -> void:
	var axis := kart_data.steering_wheel_axis.normalized()
	var pivot := _pivot(kart_data.steering_wheel_center, Basis(axis, angle))
	for part in _steering:
		part.apply(pivot)
	if driver:
		# Se o volante faz parte da carroceria (não gira), as mãos ficam paradas nele.
		var hand_turn := angle if not _steering.is_empty() else 0.0
		driver.hand_target_l = _rim_point(-kart_data.hand_angle, hand_turn)
		driver.hand_target_r = _rim_point(kart_data.hand_angle, hand_turn)
		driver.has_hand_targets = true


## Rotação `basis` em volta do ponto `center` (espaço deste nó).
static func _pivot(center: Vector3, basis: Basis) -> Transform3D:
	return Transform3D(basis, center) * Transform3D(Basis.IDENTITY, -center)


## Ponto do aro do volante (espaço deste nó). `degrees` a partir do topo, positivo = direita.
func _rim_point(degrees: float, turn: float) -> Vector3:
	var axis := kart_data.steering_wheel_axis.normalized()
	var up := (Vector3.UP - axis * axis.dot(Vector3.UP)).normalized()
	var right := up.cross(axis)
	var a := deg_to_rad(degrees) - turn
	return kart_data.steering_wheel_center + (right * sin(a) + up * cos(a)) * kart_data.steering_wheel_radius \
			+ axis * 0.015


## Procura cada nome entre os nós do modelo e, se não achar, entre os ossos.
func _find_parts(names: PackedStringArray) -> Array[Part]:
	var parts: Array[Part] = []
	if names.is_empty():
		return parts
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	for part_name in names:
		var part := Part.new()
		var node := model.find_child(part_name, true, false) as Node3D
		if node:
			part.node = node
			var parent_rel := _relative_to_self(node.get_parent())
			part.rest = parent_rel * node.transform
			part.parent_inv = parent_rel.affine_inverse()
			parts.append(part)
			continue
		for s in skeletons:
			var skeleton := s as Skeleton3D
			var bone := skeleton.find_bone(part_name)
			if bone < 0:
				continue
			var skel_rel := _relative_to_self(skeleton)
			var parent_bone := skeleton.get_bone_parent(bone)
			var parent_global := skeleton.get_bone_global_rest(parent_bone) if parent_bone >= 0 else Transform3D.IDENTITY
			part.skeleton = skeleton
			part.bone = bone
			part.rest = skel_rel * skeleton.get_bone_global_rest(bone)
			part.parent_inv = (skel_rel * parent_global).affine_inverse()
			parts.append(part)
			break
		if part.node == null and part.skeleton == null:
			push_warning("Peça '%s' não encontrada no kart '%s'." % [part_name, kart_data.display_name])
	return parts


## Transformação de `node` relativa a este nó (funciona mesmo fora da árvore).
func _relative_to_self(node: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	while node != null and node != self:
		if node is Node3D:
			t = (node as Node3D).transform * t
		node = node.get_parent()
	return t
