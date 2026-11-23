@tool
class_name TrackObstacles
extends Node3D
## Obstáculos que se mexem na pista, um tipo por cenário (TrackTheme.Scenery):
##   Campo  → pneus gigantes atravessando a pista aos pulos (dá para passar por baixo
##            no alto do pulo);
##   Praia  → ondas do mar que passam por cima da mureta e varrem a pista;
##   Deserto → tambores de coluna de templo (arenito pintado) rolando aos trancos;
##   Neve   → bolas de neve enormes descendo do lado do morro.
## Cada trecho (Track.obstacle_zones) tem alguns obstáculos. O movimento de cada um é
## uma função do relógio (`clock`), sem física: o padrão se repete igual a cada
## corrida (a corrida acerta o relógio pela largada), o piloto do computador consegue
## prever onde o obstáculo vai estar (`lane_danger`) e a prévia da tela de pistas
## anima sozinha. Quem é atingido roda e perde moedas (Kart.hit_by_obstacle); a onda
## empurra e balança o kart.

enum Kind { PNEU, ONDA, TAMBOR, NEVE }

const SHADER := preload("res://shaders/obstacle.gdshader")
const WAVE_SHADER := preload("res://shaders/obstacle_wave.gdshader")
const LOGO_ICON := preload("res://assets/logos/ativos_icone.png")
## Meio do kart acima do chão e "raio" do kart nas contas de batida (m), para a caixa
## padrão da cena (res://scenes/kart.tscn); cada veículo desconta Kart.hitbox_shrink, a
## diferença da caixa dele para essa (veja _hits). Na altura vale o tamanho dos karts do
## encaixe piloto × kart (KartScale.ITEMS).
const KART_CENTER := 0.55 * KartScale.ITEMS
const KART_RADIUS := 0.8
const KART_HALF_LENGTH := 1.0
const KART_HALF_HEIGHT := 0.8 * KartScale.ITEMS
## Onda: comprimento do trecho (m), altura máxima (m) e fases (s): chegando pelo mar,
## atravessando a pista e sumindo. Depois um tempo de calmaria.
const WAVE_LENGTH := 26.0
const WAVE_HEIGHT := 2.1
const WAVE_START := 44.0
const WAVE_APPROACH := 2.6
const WAVE_CROSS := 2.8
const WAVE_FADE := 0.7
const WAVE_CALM := 1.6
## Faixa perigosa em volta da crista (m): atrás e na frente dela.
const WAVE_BAND_BACK := 1.6
const WAVE_BAND_FRONT := 1.4

## Ajustes de cada tipo de obstáculo que rola.
const ROLLERS := {
	Kind.PNEU: {"radius": 1.05, "half_len": 0.42, "speed": 8.5, "reach": 30.0, "rest": 1.6,
			"along": [-7.0, 0.0, 7.0], "sides": [1.0, -1.0, 1.0], "push": 6.0, "slow": 0.35},
	Kind.TAMBOR: {"radius": 0.9, "half_len": 0.95, "speed": 7.0, "reach": 28.0, "rest": 1.4,
			"along": [-9.0, -3.0, 3.0, 9.0], "sides": [-1.0, 1.0, -1.0, 1.0], "push": 5.5, "slow": 0.4},
	Kind.NEVE: {"radius": 1.35, "half_len": 1.35, "speed": 6.5, "reach": 32.0, "rest": 1.6,
			"along": [-8.0, 0.0, 8.0], "sides": [0.0, 0.0, 0.0], "push": 7.0, "slow": 0.3},
}


## Um obstáculo (rolando ou onda).
class Mover:
	var kind := 0
	var zone := 0
	## Lado de onde vem (+1 = direita da pista, -1 = esquerda); vai para o outro lado.
	var side := 1.0
	## Posição ao longo do trecho (m, + = sentido da corrida).
	var along := 0.0
	var phase := 0.0
	var period := 8.0
	var duration := 7.0
	var reach := 30.0
	var speed := 8.0
	var radius := 1.0
	var half_len := 0.5
	var push := 6.0
	var slow := 0.35
	## Altura do chão (m, relativa ao meio do trecho) de -reach a +reach, de metro em metro.
	var ground := PackedFloat32Array()
	var node: Node3D
	var material: ShaderMaterial
	## Estado no último quadro: lateral, altura, escala (0 = fora) e distância rolada.
	var state := Vector4.ZERO


## Um trecho com obstáculos.
class Zone:
	var along := 0.0
	var xform := Transform3D.IDENTITY
	var inverse := Transform3D.IDENTITY


## Relógio dos obstáculos (s). Com `external_clock` a corrida acerta o relógio.
var clock := 0.0
var external_clock := false
var kind := Kind.PNEU
## Comprimento de uma volta da pista (para a distância até os trechos).
var track_length := 1.0

var _zones: Array[Zone] = []
var _movers: Array[Mover] = []
var _live := false
var _karts: Array[Node] = []
var _karts_frame := -1
var _wall_in := 12.5
var _wall_out := 13.3
var _wall_height := 1.1
var _road_half := 7.5
var _prewarming := false


## O tipo de obstáculo de cada cenário.
static func kind_for(scenery: int) -> int:
	match scenery:
		TrackTheme.Scenery.PRAIA:
			return Kind.ONDA
		TrackTheme.Scenery.DESERTO:
			return Kind.TAMBOR
		TrackTheme.Scenery.NEVE:
			return Kind.NEVE
	return Kind.PNEU


## Monta os obstáculos dos trechos da pista (`zones` = frações da volta).
func setup(track: Track, terrain: TrackTerrain, zones: PackedFloat32Array, with_collision: bool) -> void:
	kind = kind_for(track.scenery)
	track_length = track.length
	_road_half = track.road_width * 0.5
	_wall_in = _road_half + track.shoulder_width
	_wall_out = _wall_in + track.wall_thickness
	_wall_height = track.wall_height
	var shared := _shared_parts()
	for zi in zones.size():
		var z := Zone.new()
		z.along = wrapf(zones[zi], 0.0, 1.0) * track.length
		var xf := track.get_transform_at(z.along)
		z.xform = Transform3D(Basis.looking_at(Vector3(-xf.basis.z.x, 0.0, -xf.basis.z.z).normalized(), Vector3.UP), xf.origin)
		z.inverse = z.xform.affine_inverse()
		_zones.append(z)
		if kind == Kind.ONDA:
			_add_wave(zi, z, track, terrain)
		else:
			_add_rollers(zi, z, track, terrain, shared)
	_live = with_collision and not Engine.is_editor_hint()
	set_physics_process(not Engine.is_editor_hint())
	# Pose inicial (no editor fica parado nela).
	_update_movers(3.0)


func _ready() -> void:
	if _movers.is_empty():
		set_physics_process(false)


# --- Montagem -------------------------------------------------------------------------

## Malhas e materiais compartilhados pelos obstáculos do mesmo tipo.
func _shared_parts() -> Dictionary:
	var parts := {}
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	match kind:
		Kind.TAMBOR:
			mat.set_shader_parameter("mode", 3)
			var cyl := CylinderMesh.new()
			cyl.top_radius = 1.0
			cyl.bottom_radius = 1.0
			cyl.height = 2.0
			cyl.radial_segments = 22
			cyl.rings = 1
			cyl.material = mat
			parts.mesh = cyl
		Kind.NEVE:
			mat.set_shader_parameter("mode", 1)
			var sphere := SphereMesh.new()
			sphere.radius = 1.0
			sphere.height = 2.0
			sphere.radial_segments = 28
			sphere.rings = 14
			sphere.material = mat
			parts.mesh = sphere
		Kind.PNEU:
			mat.set_shader_parameter("mode", 2)
			var torus := TorusMesh.new()
			torus.inner_radius = 0.52
			torus.outer_radius = 1.0
			torus.rings = 28
			torus.ring_segments = 12
			torus.material = mat
			parts.mesh = torus
			var hub := CylinderMesh.new()
			hub.top_radius = 0.58
			hub.bottom_radius = 0.58
			hub.height = 0.42
			hub.radial_segments = 20
			hub.rings = 1
			hub.material = TrackScenery.color_material(TrackScenery.BRAND_BLUE, 0.35, 0.3)
			parts.hub = hub
			var logo := QuadMesh.new()
			logo.size = Vector2(0.78, 0.78)
			logo.material = TrackScenery.brand_material(LOGO_ICON, TrackScenery.BRAND_BLUE, 1.0,
					{"logo_fill": 0.86, "recolor": true, "recolor_main": Color.WHITE, "recolor_accent": TrackScenery.YELLOW})
			parts.logo = logo
	return parts


func _add_rollers(zi: int, z: Zone, track: Track, terrain: TrackTerrain, shared: Dictionary) -> void:
	var cfg: Dictionary = ROLLERS[kind]
	var alongs: Array = cfg.along
	var sides: Array = cfg.sides
	# Bolas de neve descem do lado do morro (o mais alto).
	var uphill := _higher_side(z, terrain) if kind == Kind.NEVE else 1.0
	var count := alongs.size()
	for i in count:
		var m := Mover.new()
		m.kind = kind
		m.zone = zi
		m.side = uphill if float(sides[i]) == 0.0 else float(sides[i])
		m.along = alongs[i]
		m.radius = cfg.radius
		m.half_len = cfg.half_len
		m.speed = cfg.speed
		m.reach = cfg.reach
		m.duration = 2.0 * m.reach / m.speed
		m.period = m.duration + float(cfg.rest)
		# Espalhados no tempo; cada trecho começa num ponto diferente do ciclo.
		m.phase = m.period * (float(i) / count + zi * 0.37)
		m.push = cfg.push
		m.slow = cfg.slow
		m.ground = _sample_ground(z, m.along, m.reach, track, terrain)
		m.node = _make_roller_node(shared)
		_movers.append(m)


func _make_roller_node(shared: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = {Kind.PNEU: "Pneu", Kind.TAMBOR: "TamborDeColuna", Kind.NEVE: "BolaDeNeve"}[kind]
	var body := MeshInstance3D.new()
	body.mesh = shared.mesh
	# Tambor e pneu deitados com o eixo ao longo da pista (rolam atravessando-a).
	if kind != Kind.NEVE:
		body.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	root.add_child(body)
	if kind == Kind.PNEU:
		var hub := MeshInstance3D.new()
		hub.mesh = shared.hub
		hub.rotation = Vector3(PI * 0.5, 0.0, 0.0)
		root.add_child(hub)
		for face: float in [1.0, -1.0]:
			var logo := MeshInstance3D.new()
			logo.mesh = shared.logo
			logo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			logo.transform = Transform3D(Basis(Vector3.UP, 0.0 if face > 0.0 else PI), Vector3(0.0, 0.0, 0.215 * face))
			root.add_child(logo)
	add_child(root)
	return root


func _add_wave(zi: int, z: Zone, track: Track, terrain: TrackTerrain) -> void:
	var m := Mover.new()
	m.kind = Kind.ONDA
	m.zone = zi
	# A onda vem do mar: o lado mais baixo.
	m.side = -_higher_side(z, terrain)
	m.along = 0.0
	m.reach = WAVE_START
	m.half_len = WAVE_LENGTH * 0.5
	m.duration = WAVE_APPROACH + WAVE_CROSS + WAVE_FADE
	m.period = m.duration + WAVE_CALM
	m.phase = m.period * zi * 0.45
	m.push = 8.5
	m.slow = 0.6
	m.ground = _sample_ground(z, 0.0, m.reach, track, terrain)
	var mi := MeshInstance3D.new()
	mi.name = "Onda"
	mi.mesh = _wave_mesh()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.material = ShaderMaterial.new()
	m.material.shader = WAVE_SHADER
	var water := TrackTheme.water_params(track.scenery)
	if water.has("shallow_color"):
		m.material.set_shader_parameter("shallow_color", water.shallow_color)
		m.material.set_shader_parameter("deep_color", water.deep_color)
	mi.material_override = m.material
	add_child(mi)
	m.node = mi
	_movers.append(m)


## Lado (+1 direita / -1 esquerda) com o chão mais alto perto do trecho.
func _higher_side(z: Zone, terrain: TrackTerrain) -> float:
	var sums := [0.0, 0.0]
	for k in 2:
		var side := -1.0 if k == 0 else 1.0
		for lat: float in [30.0, 45.0, 60.0, 80.0]:
			for along: float in [-10.0, 0.0, 10.0]:
				var p := z.xform * Vector3(side * lat, 0.0, -along)
				sums[k] += terrain.height_at(p.x, p.z) if terrain else 0.0
	return 1.0 if sums[1] > sums[0] else -1.0


## Altura do chão (relativa ao meio do trecho) ao longo da linha que o obstáculo
## percorre: asfalto e acostamento entre as muretas, o terreno fora delas.
func _sample_ground(z: Zone, along: float, reach: float, track: Track, terrain: TrackTerrain) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var steps := int(ceil(reach)) * 2
	for i in steps + 1:
		var lat := -reach + float(i) * (2.0 * reach / steps)
		var h := 0.0
		if absf(lat) > _wall_out + 0.6 and terrain:
			var p := z.xform * Vector3(lat, 0.0, -along)
			h = maxf(terrain.height_at(p.x, p.z), track.water_level - 0.4) - z.xform.origin.y
		out.append(h)
	return out


## Faixa ao longo do trecho com o perfil de uma onda (UV.x = perfil, UV.y = ao longo).
## +X = sentido em que a onda anda; a crista fica em x = 0.
func _wave_mesh() -> ArrayMesh:
	var profile: Array[Vector2] = [
		Vector2(-7.0, 0.0), Vector2(-5.6, 0.06), Vector2(-4.2, 0.18), Vector2(-3.0, 0.36),
		Vector2(-2.0, 0.58), Vector2(-1.1, 0.8), Vector2(-0.45, 0.94), Vector2(0.1, 1.0),
		Vector2(0.55, 0.95), Vector2(0.9, 0.8), Vector2(1.15, 0.56), Vector2(1.3, 0.3),
		Vector2(1.38, 0.0), Vector2(1.38, -0.5),
	]
	var segs := 28
	var md := Track.MeshData.new()
	for j in segs + 1:
		var v := float(j) / segs
		var z := (v - 0.5) * WAVE_LENGTH
		# Mais baixa nas pontas do trecho (vira espuma rasa).
		var taper := smoothstep(0.0, 0.32, 1.0 - absf(v - 0.5) * 2.0)
		for k in profile.size():
			var p := profile[k]
			var u := clampf(remap(p.x, -7.0, 1.38, 0.0, 1.0), 0.0, 1.0)
			var y := p.y * lerpf(0.25, 1.0, taper) if p.y > 0.0 else p.y
			md.add_vertex(Vector3(p.x, y, z), Vector3.UP, Vector2(u, v))
	var cols := profile.size()
	for j in segs:
		for k in cols - 1:
			var a := j * cols + k
			var b := a + 1
			var c := a + cols
			var d := c + 1
			md.indices.append_array([a, b, c, b, d, c])
	# Normais suaves a partir dos triângulos.
	var normals := PackedVector3Array()
	normals.resize(md.verts.size())
	for t in range(0, md.indices.size(), 3):
		var ia := md.indices[t]
		var ib := md.indices[t + 1]
		var ic := md.indices[t + 2]
		var n := (md.verts[ib] - md.verts[ia]).cross(md.verts[ic] - md.verts[ia])
		normals[ia] += n
		normals[ib] += n
		normals[ic] += n
	for i in normals.size():
		var n := normals[i].normalized()
		md.normals[i] = n if n.y >= 0.0 else -n
	var mesh := md.to_mesh(null)
	mesh.custom_aabb = AABB(Vector3(-8.0, -1.0, -WAVE_LENGTH * 0.5 - 1.0), Vector3(10.0, 3.5, WAVE_LENGTH + 2.0))
	return mesh


# --- Movimento ------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if not external_clock:
		clock += delta
	if _prewarming:
		return
	_update_movers(clock)
	if _live:
		_check_hits()


func _update_movers(t: float) -> void:
	for m in _movers:
		var z := _zones[m.zone]
		if m.kind == Kind.ONDA:
			_place_wave(m, z, t)
		else:
			_place_roller(m, z, t)


## Estado de um obstáculo que rola no instante `t`: (lateral, altura, escala, distância
## rolada). Escala 0 = fora da pista (esperando a vez).
func _roller_state(m: Mover, t: float) -> Vector4:
	var u := fposmod(t + m.phase, m.period)
	if u >= m.duration:
		return Vector4.ZERO
	var k := u / m.duration
	var lat := m.side * m.reach * (1.0 - 2.0 * k)
	var dist := m.speed * u
	# Aparece e some longe da pista (crescendo/encolhendo).
	var s := smoothstep(0.0, 0.1, k) * smoothstep(1.0, 0.9, k)
	if m.kind == Kind.NEVE:
		s *= lerpf(0.75, 1.12, k)
	var hop := 0.0
	match m.kind:
		Kind.PNEU:
			# Quica alto: no topo do pulo o kart passa por baixo (~1/3 do tempo).
			var b := sin(PI * dist / 9.0)
			hop = b * b * 2.0
		Kind.TAMBOR:
			# Pedra pesada: pula pouco a cada pedra do chão.
			hop = absf(sin(PI * dist / 2.9)) * (0.12 + 0.25 * absf(sin(dist * 0.31 + m.phase)))
	# Pulo por cima das muretas.
	var x := (absf(lat) - (_wall_in + _wall_out) * 0.5) / (m.radius * s + 1.7)
	var wall := (_wall_height + 0.25) * (0.5 + 0.5 * cos(PI * x)) if absf(x) < 1.0 else 0.0
	var y := _ground_at(m, lat) + m.radius * s + maxf(hop, wall)
	return Vector4(lat, y, s, dist)


func _place_roller(m: Mover, z: Zone, t: float) -> void:
	m.state = _roller_state(m, t)
	var s := m.state.z
	if s <= 0.001:
		if m.node.visible:
			m.node.visible = false
		return
	if not m.node.visible:
		m.node.visible = true
		if m.node.is_inside_tree():
			m.node.reset_physics_interpolation()
	# Rola em volta do eixo ao longo da pista, para o lado em que anda.
	var roll := Basis(Vector3(0.0, 0.0, m.side), m.state.w / maxf(m.radius, 0.1))
	var local := Transform3D(roll.scaled(Vector3.ONE * m.radius * s), Vector3(m.state.x, m.state.y, -m.along))
	m.node.transform = z.xform * local


## Onda no instante `t`: (lateral da crista, altura da base, força 0..1, -).
func _wave_state(m: Mover, t: float) -> Vector4:
	var u := fposmod(t + m.phase, m.period)
	if u >= m.duration:
		return Vector4.ZERO
	var lat := 0.0
	var h := 0.0
	var mid := (_wall_in + _wall_out) * 0.5
	if u < WAVE_APPROACH:
		var k := u / WAVE_APPROACH
		lat = lerpf(m.side * m.reach, m.side * mid, k)
		h = lerpf(0.3, 1.0, smoothstep(0.0, 1.0, k))
	elif u < WAVE_APPROACH + WAVE_CROSS:
		var k := (u - WAVE_APPROACH) / WAVE_CROSS
		lat = lerpf(m.side * mid, -m.side * _wall_in, k)
		h = lerpf(1.0, 0.42, k)
	else:
		var k := (u - WAVE_APPROACH - WAVE_CROSS) / WAVE_FADE
		lat = -m.side * (_wall_in - 0.4 * k)
		h = 0.42 * (1.0 - k)
	return Vector4(lat, _ground_at(m, lat) - 0.25, h, 0.0)


func _place_wave(m: Mover, z: Zone, t: float) -> void:
	m.state = _wave_state(m, t)
	var h := m.state.z
	if h <= 0.001:
		if m.node.visible:
			m.node.visible = false
		return
	if not m.node.visible:
		m.node.visible = true
		if m.node.is_inside_tree():
			m.node.reset_physics_interpolation()
	# A malha anda para +X: virada quando a onda vem da direita.
	var basis := Basis(Vector3.UP, PI if m.side > 0.0 else 0.0).scaled(Vector3(1.0, WAVE_HEIGHT * h, 1.0))
	m.node.transform = z.xform * Transform3D(basis, Vector3(m.state.x, m.state.y, 0.0))
	m.material.set_shader_parameter("strength", clampf(h * 1.6, 0.0, 1.0))


func _ground_at(m: Mover, lat: float) -> float:
	var n := m.ground.size()
	if n < 2:
		return 0.0
	var f := clampf((lat + m.reach) / (2.0 * m.reach) * (n - 1), 0.0, n - 1.001)
	var i := int(f)
	return lerpf(m.ground[i], m.ground[i + 1], f - i)


# --- Batidas --------------------------------------------------------------------------

func _check_hits() -> void:
	var frame := Engine.get_physics_frames()
	if _karts_frame < 0 or frame - _karts_frame >= 60:
		_karts = get_tree().get_nodes_in_group(&"kart")
		_karts_frame = frame
	var inv := global_transform.affine_inverse()
	for node in _karts:
		if not is_instance_valid(node):
			continue
		var kart := node as Kart
		if kart == null or kart.is_spinning():
			continue
		var local := inv * kart.global_position
		for zi in _zones.size():
			var z := _zones[zi]
			var q := z.inverse * local
			var k_along := -q.z
			if absf(k_along) > 20.0 or absf(q.x) > _wall_in + 1.0:
				continue
			for m in _movers:
				if m.zone == zi and _hits(m, q.x, q.y + KART_CENTER, k_along, kart.hitbox_shrink):
					var dir := z.xform.basis * Vector3(-m.side, 0.0, 0.0)
					kart.hit_by_obstacle((global_basis * dir).normalized() * m.push, m.slow, m.kind != Kind.ONDA)
					break


## O kart (lateral `kx`, altura do meio `ky`, posição ao longo `kz` no trecho) encosta
## no obstáculo agora? `shrink` = quanto a caixa dele é menor que a de um kart comum, de
## cada lado (Kart.hitbox_shrink): a moto, mais estreita, tem menos alcance na lateral.
func _hits(m: Mover, kx: float, ky: float, kz: float, shrink := Vector2.ZERO) -> bool:
	var st := m.state
	if st.z <= 0.05:
		return false
	var dz := kz - m.along
	if m.kind == Kind.ONDA:
		if st.z < 0.35 or absf(dz) > m.half_len * 0.82:
			return false
		# Distância à crista no sentido em que a onda anda (+ = à frente dela).
		var ahead := (kx - st.x) * -m.side
		return ahead > -WAVE_BAND_BACK and ahead < WAVE_BAND_FRONT
	var r := m.radius * st.z
	if absf(dz) > m.half_len * st.z + KART_HALF_LENGTH - shrink.y:
		return false
	# Alcance do obstáculo + kart em cada eixo (elipse; num kart comum é um círculo).
	var dx := (kx - st.x) / maxf(r + KART_RADIUS - shrink.x, 0.1)
	var dy := (ky - st.y) / (r + KART_HALF_HEIGHT)
	if m.kind == Kind.NEVE:
		dx = (kx - st.x) / maxf(r + KART_RADIUS + 0.1 - shrink.x, 0.1)
		dy = (ky - st.y) / (r + KART_HALF_HEIGHT + 0.1)
		var dzn := dz / maxf(r + KART_RADIUS + 0.1 - shrink.y, 0.1)
		return Vector3(dx, dy, dzn).length() < 1.0
	return Vector2(dx, dy).length() < 1.0


# --- Piloto do computador -----------------------------------------------------------

## Perigo (0 = livre, 1 = vai bater) de cada lateral de `lanes` (m) para um kart em
## `along` (m desde a largada) a `speed` m/s: onde cada obstáculo à frente vai estar
## quando o kart chegar nele. Trechos longe (mais de 70 m) não contam.
func lane_danger(along: float, speed: float, lanes: PackedFloat32Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(lanes.size())
	var v := maxf(speed, 6.0)
	for zi in _zones.size():
		var to_zone := wrapf(_zones[zi].along - along, -track_length * 0.5, track_length * 0.5)
		if to_zone < -14.0 or to_zone > 70.0:
			continue
		for m in _movers:
			if m.zone != zi:
				continue
			var arrive := maxf((to_zone + m.along) / v, 0.0)
			for dt: float in [-0.25, 0.0, 0.3]:
				var t := clock + arrive + dt
				var st := _wave_state(m, t) if m.kind == Kind.ONDA else _roller_state(m, t)
				if st.z <= 0.05:
					continue
				var reach := 0.0
				var center := st.x
				if m.kind == Kind.ONDA:
					if st.z < 0.35:
						continue
					reach = 2.2
					center = st.x - m.side * 0.2
				else:
					# Pneu no alto do pulo: passa por baixo.
					if st.y - m.radius * st.z > KART_CENTER + KART_HALF_HEIGHT:
						continue
					reach = m.radius * st.z + 1.3
				if absf(center) > _road_half + reach:
					continue
				for i in lanes.size():
					if absf(lanes[i] - center) < reach:
						out[i] = 1.0
	return out


## Algum trecho com obstáculos nos próximos `ahead` metros?
func has_zone_ahead(along: float, ahead := 70.0) -> bool:
	for z in _zones:
		var to_zone := wrapf(z.along - along, -track_length * 0.5, track_length * 0.5)
		if to_zone > -14.0 and to_zone < ahead:
			return true
	return false


# --- Compilação dos shaders (web) ---------------------------------------------------

## Põe todos os obstáculos à vista em cima da pista (para os shaders compilarem atrás
## da tela de carregamento, veja Race.warm_up). `false` volta ao normal.
func prewarm(on: bool) -> void:
	_prewarming = on
	if not on:
		_update_movers(clock)
		return
	for i in _movers.size():
		var m := _movers[i]
		var z := _zones[m.zone]
		m.node.visible = true
		if m.kind == Kind.ONDA:
			m.node.transform = z.xform * Transform3D(Basis().scaled(Vector3(1.0, WAVE_HEIGHT, 1.0)), Vector3(-4.0, -0.25, 0.0))
			m.material.set_shader_parameter("strength", 1.0)
		else:
			m.node.transform = z.xform * Transform3D(Basis().scaled(Vector3.ONE * m.radius), Vector3((i % 3 - 1) * 4.0, m.radius, -m.along))
		if m.node.is_inside_tree():
			m.node.reset_physics_interpolation()


## Pontos para a câmera olhar ao compilar (um por trecho, no espaço global).
func zone_points() -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	for z in _zones:
		out.append(global_transform * z.xform)
	return out
