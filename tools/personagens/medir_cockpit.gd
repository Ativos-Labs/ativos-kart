extends SceneTree
## Mede o cockpit de cada kart para o grupo "Cockpit" do KartData (pilotos que sentam
## de verdade no banco, como o Jarbas): grava um mapa de ocupação lateral por kart e
## imprime valores sugeridos. Confira os valores no mapa antes de copiar (peças soltas,
## volante e coluna podem enganar a medida automática).
##
##   Godot --headless --path . -s res://tools/personagens/medir_cockpit.gd -- <pasta> [x0 x1]
##
## Mapa: vista de lado da faixa x0..x1 (padrão 0,06..0,16 m, onde passam as pernas),
## frente do kart à esquerda, z de -1,1 a 0,9 e y de 0 a 1,4 m, células de 2 cm (cinza =
## tem superfície). Grade a cada 10 cm, amarela a cada 50 cm; vermelho = seat_position,
## azul = centro do volante.

const CELL := 0.02
const Z0 := -1.1
const Z1 := 0.9
const Y0 := 0.0
const Y1 := 1.4
const SCALE := 8

var _lane := Vector2(0.06, 0.16)
var _out := "/tmp"
var _f := 0
var _bodies := []
var _done := false


func _process(_d: float) -> bool:
	_f += 1
	if _f == 2:
		var args := OS.get_cmdline_user_args()
		_out = args[0] if args.size() > 0 else "/tmp"
		if args.size() > 2:
			_lane = Vector2(float(args[1]), float(args[2]))
		_build()
	return _done and _f > 12


func _physics_process(_d: float) -> bool:
	if _f >= 6 and not _done:
		_done = true
		_measure()
	return false


## Uma forma de colisão com as malhas de cada kart (espaço do KartVisual), lado a lado.
func _build() -> void:
	var gs: Node = root.get_node("GameState")
	for i in gs.karts.size():
		var k: KartData = gs.karts[i]
		var kv := KartVisual.new()
		root.add_child(kv)
		kv.setup(k, null)
		var off := Vector3(i * 20.0, 0, 0)
		var faces := PackedVector3Array()
		for n in kv.find_children("*", "MeshInstance3D", true, false):
			var mi := n as MeshInstance3D
			if mi.mesh == null:
				continue
			var xf := kv.global_transform.affine_inverse() * mi.global_transform
			for v in mi.mesh.get_faces():
				faces.append(xf * v + off)
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var shape := ConcavePolygonShape3D.new()
		shape.backface_collision = true
		shape.set_faces(faces)
		cs.shape = shape
		body.add_child(cs)
		root.add_child(body)
		_bodies.append([k, off])
		kv.queue_free()


func _measure() -> void:
	var space := root.get_world_3d().direct_space_state
	var box := BoxShape3D.new()
	# Um pouco maior que a célula: superfícies na borda entre duas células contam.
	box.size = Vector3(_lane.y - _lane.x, CELL * 1.3, CELL * 1.3)
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = box
	var nz := int((Z1 - Z0) / CELL)
	var ny := int((Y1 - Y0) / CELL)
	for b in _bodies:
		var k: KartData = b[0]
		var off: Vector3 = b[1]
		var occ := PackedByteArray()
		occ.resize(nz * ny)
		for iy in ny:
			for iz in nz:
				var c := Vector3((_lane.x + _lane.y) * 0.5, Y0 + (iy + 0.5) * CELL, Z0 + (iz + 0.5) * CELL)
				q.transform = Transform3D(Basis.IDENTITY, off + c)
				occ[iy * nz + iz] = 1 if space.intersect_shape(q, 1).size() > 0 else 0
		var slug := k.display_name.to_lower().replace(" ", "_").replace("ã", "a").replace("á", "a") \
				.replace("â", "a").replace("ó", "o").replace("é", "e")
		_save_png(occ, nz, ny, k, "%s/cockpit_%s.png" % [_out, slug])
		_suggest(occ, nz, ny, k)


func _occ(occ: PackedByteArray, nz: int, ny: int, z: float, y: float) -> bool:
	var iz := int(floor((z - Z0) / CELL + 1e-6))
	var iy := int(floor((y - Y0) / CELL + 1e-6))
	if iz < 0 or iz >= nz or iy < 0 or iy >= ny:
		return false
	return occ[iy * nz + iz] == 1


## Primeira superfície descendo a partir de `y` em `z` (topo da célula), ou -1.
func _down(occ: PackedByteArray, nz: int, ny: int, z: float, y: float) -> float:
	while y > Y0:
		if _occ(occ, nz, ny, z, y):
			return floor((y - Y0) / CELL + 1e-6) * CELL + CELL + Y0
		y -= CELL
	return -1.0


func _suggest(occ: PackedByteArray, nz: int, ny: int, k: KartData) -> void:
	var s := k.seat_position
	# Estofado: mediana embaixo do seat_position (de -5 a +5 cm).
	var heights: Array[float] = []
	for dz in [-0.04, -0.02, 0.0, 0.02, 0.04]:
		var h := _down(occ, nz, ny, s.z + dz, s.y + 0.08)
		if h > 0.0:
			heights.append(h)
	if heights.is_empty():
		print("%s: nada embaixo do seat_position" % k.display_name)
		return
	heights.sort()
	var cushion: float = heights[heights.size() / 2]
	# Encosto: andando para trás a 6 e 40 cm acima do estofado.
	var back := []
	for h in [0.06, 0.4]:
		var z := s.z
		while z < Z1 and not _occ(occ, nz, ny, z, cushion + h):
			z += CELL
		back.append(z)
	var angle := rad_to_deg(atan2(back[1] - back[0], 0.34))
	# Frente do estofado: andando para a frente logo abaixo da superfície.
	var front := s.z
	while front > Z0 and (_occ(occ, nz, ny, front, cushion - 0.01) or _occ(occ, nz, ny, front, cushion - 0.03)):
		front -= CELL
	# Assoalho logo à frente do banco e até onde os pés vão (8 cm acima dele).
	var floor_y := _down(occ, nz, ny, front - 0.08, cushion - 0.02)
	var limit := front - 0.04
	while limit > Z0 and not _occ(occ, nz, ny, limit, floor_y + 0.08):
		limit -= CELL
	print("%s (seat_position %s)" % [k.display_name, s])
	print("  seat_back_point = Vector3(0, %.2f, %.2f)" % [cushion, back[0]])
	print("  seat_back_angle = %.1f" % angle)
	print("  seat_front_z = %.2f" % front)
	print("  floor_height = %.2f" % floor_y)
	print("  foot_limit_z = %.2f" % limit)


func _save_png(occ: PackedByteArray, nz: int, ny: int, k: KartData, path: String) -> void:
	var img := Image.create(nz * SCALE, ny * SCALE, false, Image.FORMAT_RGB8)
	img.fill(Color(0.12, 0.13, 0.16))
	for iy in ny:
		for iz in nz:
			if occ[iy * nz + iz] == 1:
				img.fill_rect(Rect2i(iz * SCALE, (ny - 1 - iy) * SCALE, SCALE, SCALE), Color(0.85, 0.85, 0.85))
	for iz in nz + 1:
		var cm := int(round((Z0 + iz * CELL) * 100.0))
		if cm % 10 == 0:
			img.fill_rect(Rect2i(iz * SCALE, 0, 1, ny * SCALE),
					Color(0.8, 0.7, 0.2) if cm % 50 == 0 else Color(0.3, 0.32, 0.4))
	for iy in ny + 1:
		var cm := int(round((Y0 + iy * CELL) * 100.0))
		if cm % 10 == 0:
			img.fill_rect(Rect2i(0, (ny - iy) * SCALE, nz * SCALE, 1),
					Color(0.8, 0.7, 0.2) if cm % 50 == 0 else Color(0.3, 0.32, 0.4))
	for mark in [[k.seat_position, Color(1, 0.1, 0.1)], [k.steering_wheel_center, Color(0.2, 0.5, 1)]]:
		var p: Vector3 = mark[0]
		img.fill_rect(Rect2i(int((p.z - Z0) / CELL * SCALE) - 4, (ny - int((p.y - Y0) / CELL)) * SCALE - 4, 9, 9), mark[1])
	img.save_png(path)
