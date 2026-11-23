class_name Caravan
extends Node3D
## Camelo de uma caravana andando devagar nas dunas, em volta de um caminho fechado
## (pontos já na altura do chão), com o balanço do passo. (Não roda no editor.)

## Caminho fechado (no espaço do pai).
var path := PackedVector3Array()
## Velocidade (m/s) e distância (m) do começo do caminho de onde ele sai.
var speed := 1.4
var offset := 0.0

var _cum := PackedFloat32Array()
var _d := 0.0
var _seg := 0


func _ready() -> void:
	var n := path.size()
	if n < 2:
		set_process(false)
		return
	_cum.resize(n + 1)
	_cum[0] = 0.0
	for i in n:
		_cum[i + 1] = _cum[i] + path[i].distance_to(path[(i + 1) % n])
	_d = fposmod(offset, _cum[n])
	_place()


func _process(delta: float) -> void:
	_d = fposmod(_d + speed * delta, _cum[_cum.size() - 1])
	_place()


func _place() -> void:
	var n := path.size()
	# Avança o segmento a partir do último (o camelo só anda para a frente).
	for _k in n:
		if _d >= _cum[_seg] and _d < _cum[_seg + 1]:
			break
		_seg = (_seg + 1) % n
	var a := path[_seg]
	var b := path[(_seg + 1) % n]
	var t := (_d - _cum[_seg]) / maxf(_cum[_seg + 1] - _cum[_seg], 0.001)
	var p := a.lerp(b, t)
	var dir := b - a
	dir.y = 0.0
	# Passo: sobe e desce duas vezes por passada e balança de lado.
	var step := _d * 1.9
	p.y += absf(sin(step)) * 0.12
	if dir.length_squared() > 0.0001:
		basis = Basis.looking_at(dir.normalized(), Vector3.UP, true) * Basis(Vector3.BACK, sin(step) * 0.035)
	position = p
