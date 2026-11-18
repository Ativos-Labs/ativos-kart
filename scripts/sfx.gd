class_name Sfx
extends RefCounted
## Efeitos sonoros gerados por código (não precisa de arquivos de áudio). Tocam no
## canal "Efeitos" (volume na tela de opções), como o motor dos karts.

const MIX_RATE := 22050
## Frequência do loop de motor (Hz): o tom muda com `pitch_scale` = frequência / esta.
const ENGINE_BASE_FREQ := 60.0

static var _cache := {}


## Toca um som curto. Cria um AudioStreamPlayer temporário dentro de `owner_node`.
static func play(owner_node: Node, sound: StringName, volume_db := -8.0, pitch := 1.0) -> void:
	if owner_node == null or not owner_node.is_inside_tree():
		return
	var player := AudioStreamPlayer.new()
	player.stream = get_stream(sound)
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.bus = GameSettings.BUS_SFX
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	owner_node.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


static func get_stream(sound: StringName) -> AudioStreamWAV:
	if _cache.has(sound):
		return _cache[sound]
	var stream: AudioStreamWAV
	match sound:
		&"beep":
			stream = _tone([523.25], 0.18, 0.5)
		&"go":
			stream = _tone([1046.5], 0.55, 0.5)
		&"lap":
			stream = _tone([659.25, 880.0], 0.14, 0.45)
		&"final_lap":
			stream = _tone([523.25, 659.25, 783.99, 1046.5], 0.11, 0.45)
		&"finish":
			stream = _tone([523.25, 659.25, 783.99, 1046.5, 783.99, 1046.5], 0.13, 0.45)
		&"finish_low":
			stream = _tone([659.25, 587.33, 523.25, 392.0, 523.25], 0.14, 0.4)
		&"place_up":
			stream = _tone([880.0, 1174.66], 0.05, 0.25)
		&"boost":
			stream = _whoosh(0.55)
		&"bump":
			stream = _thud(0.18)
		&"drift_level":
			stream = _tone([1318.5], 0.07, 0.3)
		&"item_box":
			stream = _tone([1046.5, 1318.5, 1568.0, 2093.0], 0.045, 0.3)
		&"item_tick":
			stream = _tone([1760.0], 0.025, 0.25)
		&"item_get":
			stream = _tone([1318.5, 1760.0, 2637.0], 0.06, 0.32)
		&"item_use":
			stream = _whoosh(0.35)
		&"thunder":
			stream = _thunder(1.7)
		&"shrink":
			stream = _tone([1568.0, 1318.5, 1046.5, 783.99, 587.33], 0.045, 0.3)
		&"grow":
			stream = _tone([587.33, 783.99, 1046.5, 1318.5, 1568.0], 0.045, 0.3)
		&"squish":
			stream = _tone([523.25, 349.23, 261.63], 0.06, 0.35)
		&"ink":
			stream = _ink(0.5)
		&"ghost":
			stream = _ghost(1.2)
		&"trick":
			stream = _tone([987.77, 1318.5, 1975.5], 0.06, 0.32)
		&"coin":
			stream = _tone([1318.5, 1975.5], 0.055, 0.3)
		&"coin_lost":
			stream = _tone([1318.5, 987.77, 739.99, 587.33], 0.05, 0.28)
		&"spin":
			stream = _tone([880.0, 698.46, 587.33, 440.0, 349.23], 0.055, 0.3)
		&"splash":
			stream = _splash(0.7)
		&"glider_open":
			stream = _cloth(0.6, true)
		&"glider_close":
			stream = _cloth(0.28, false)
		&"ui_move":
			stream = _tone([880.0], 0.045, 0.25)
		&"ui_accept":
			stream = _tone([783.99, 1174.66], 0.07, 0.35)
		&"ui_back":
			stream = _tone([587.33, 392.0], 0.07, 0.3)
		_:
			stream = _tone([440.0], 0.1, 0.4)
	_cache[sound] = stream
	return stream


## Ronco de motor em loop (mesma onda do motor do jogador), para os adversários.
static func get_engine_loop() -> AudioStreamWAV:
	if _cache.has(&"engine_loop"):
		return _cache[&"engine_loop"]
	# A onda tem um sub-harmônico (meia frequência): um ciclo dela = 2 / frequência.
	# 735 amostras a 22050 Hz fecham um ciclo exato, então o loop não estala.
	var cycle := int(round(MIX_RATE * 2.0 / ENGINE_BASE_FREQ))
	var count := cycle * 6
	var samples := PackedFloat32Array()
	samples.resize(count)
	for i in count:
		var p := TAU * ENGINE_BASE_FREQ * i / MIX_RATE
		var s := sin(p) * 0.55 + sin(p * 2.0) * 0.3 + sin(p * 3.0 + 0.4) * 0.12 + sin(p * 0.5) * 0.3
		samples[i] = clampf(s * 1.3, -1.0, 1.0) * 0.5
	var stream := _make_stream(samples)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = count
	_cache[&"engine_loop"] = stream
	return stream


static func _make_stream(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	return stream


## Sequência de notas (onda quadrada suave) — estilo videogame.
static func _tone(freqs: Array, note_length: float, volume: float) -> AudioStreamWAV:
	var samples := PackedFloat32Array()
	var per_note := int(note_length * MIX_RATE)
	for f in freqs:
		var phase := 0.0
		for i in per_note:
			var t := float(i) / per_note
			phase += TAU * float(f) / MIX_RATE
			var wave := sin(phase) * 0.7 + signf(sin(phase)) * 0.3
			var env := minf(t * 30.0, 1.0) * pow(1.0 - t, 1.5)
			samples.append(wave * env * volume)
	return _make_stream(samples)


static func _whoosh(length: float) -> AudioStreamWAV:
	var samples := PackedFloat32Array()
	var count := int(length * MIX_RATE)
	var low := 0.0
	var phase := 0.0
	for i in count:
		var t := float(i) / count
		var noise := randf_range(-1.0, 1.0)
		low = lerpf(low, noise, 0.08 + t * 0.25)
		phase += TAU * (180.0 + t * 520.0) / MIX_RATE
		var env := minf(t * 12.0, 1.0) * pow(1.0 - t, 2.0)
		samples.append((low * 0.7 + sin(phase) * 0.25) * env * 0.8)
	return _make_stream(samples)


## Água batendo: ruído que começa forte e vai abafando (chiado de espuma no fim).
static func _splash(length: float) -> AudioStreamWAV:
	var samples := PackedFloat32Array()
	var count := int(length * MIX_RATE)
	var low := 0.0
	var mid := 0.0
	for i in count:
		var t := float(i) / count
		var noise := randf_range(-1.0, 1.0)
		low = lerpf(low, noise, 0.05)
		mid = lerpf(mid, noise, lerpf(0.5, 0.12, t))
		var env := minf(t * 40.0, 1.0) * pow(1.0 - t, 1.6)
		samples.append((low * 1.4 + mid * 0.6) * env * 0.75)
	return _make_stream(samples)


## Tecido da asa-delta: abrindo, um "fuump" de vento que enche e termina num estalo
## (a vela esticando); fechando, um farfalhar curto que some.
static func _cloth(length: float, opening: bool) -> AudioStreamWAV:
	var samples := PackedFloat32Array()
	var count := int(length * MIX_RATE)
	var low := 0.0
	var mid := 0.0
	var snap_at := 0.32 if opening else -1.0
	for i in count:
		var t := float(i) / count
		var noise := randf_range(-1.0, 1.0)
		low = lerpf(low, noise, 0.04 + t * 0.06)
		# O farfalhar do pano: ruído mais agudo que treme.
		mid = lerpf(mid, noise, 0.35)
		var flutter := 0.55 + 0.45 * sin(t * length * TAU * (22.0 if opening else 30.0))
		var env: float
		if opening:
			env = smoothstep(0.0, 0.3, t) * pow(1.0 - t, 1.4)
		else:
			env = minf(t * 25.0, 1.0) * pow(1.0 - t, 2.2)
		var s := (low * 1.3 + mid * 0.35 * flutter) * env
		if snap_at > 0.0 and t >= snap_at:
			# Estalo: um baque grave e curtinho com um "tac" agudo.
			var st := (t - snap_at) * length
			s += (sin(TAU * 95.0 * st) * 0.9 + noise * 0.5) * exp(-st * 38.0)
		samples.append(clampf(s * 0.85, -1.0, 1.0))
	return _make_stream(samples)


## Trovão do Deságio: um estalo seco e o ronco grave que rola e some.
static func _thunder(length: float) -> AudioStreamWAV:
	var samples := PackedFloat32Array()
	var count := int(length * MIX_RATE)
	var low := 0.0
	var low2 := 0.0
	for i in count:
		var t := float(i) / count
		var st := t * length
		var noise := randf_range(-1.0, 1.0)
		low = lerpf(low, noise, 0.04)
		low2 = lerpf(low2, low, 0.1)
		var crack := noise * exp(-st * 16.0) * 0.12
		var roll := 0.65 + 0.35 * sin(st * 8.0 + sin(st * 2.7) * 2.0)
		var rumble := low2 * roll * smoothstep(0.0, 0.06, t) * pow(1.0 - t, 1.2)
		samples.append(crack + rumble)
	return _make_stream(_normalized(samples, 0.9))


## Tinta do Juridiquês espirrando: "splosh" molhado com um baque grave.
static func _ink(length: float) -> AudioStreamWAV:
	var samples := PackedFloat32Array()
	var count := int(length * MIX_RATE)
	var mid := 0.0
	var phase := 0.0
	for i in count:
		var t := float(i) / count
		var st := t * length
		var noise := randf_range(-1.0, 1.0)
		mid = lerpf(mid, noise, lerpf(0.55, 0.06, t))
		phase += TAU * lerpf(120.0, 48.0, t) / MIX_RATE
		var env := minf(t * 60.0, 1.0) * pow(1.0 - t, 2.2)
		samples.append(mid * env + sin(phase) * exp(-st * 22.0))
	return _make_stream(_normalized(samples, 0.8))


## Fantasma da Cessão: "uuuuh" que sobe e desce, com vibrato e um sopro.
static func _ghost(length: float) -> AudioStreamWAV:
	var samples := PackedFloat32Array()
	var count := int(length * MIX_RATE)
	var phase := 0.0
	var air := 0.0
	for i in count:
		var t := float(i) / count
		var st := t * length
		var f := 420.0 + 230.0 * sin(t * PI) - 90.0 * t + 16.0 * sin(st * TAU * 6.0)
		phase += TAU * f / MIX_RATE
		air = lerpf(air, randf_range(-1.0, 1.0), 0.2)
		var env := smoothstep(0.0, 0.18, t) * (1.0 - smoothstep(0.6, 1.0, t))
		samples.append((sin(phase) * 0.7 + sin(phase * 2.0) * 0.12 + air * 0.25) * env)
	return _make_stream(_normalized(samples, 0.7))


## Ajusta o pico das amostras para `peak` (ruído filtrado sai baixo demais).
static func _normalized(samples: PackedFloat32Array, peak: float) -> PackedFloat32Array:
	var top := 0.0
	for s in samples:
		top = maxf(top, absf(s))
	if top > 0.0:
		var k := peak / top
		for i in samples.size():
			samples[i] *= k
	return samples


static func _thud(length: float) -> AudioStreamWAV:
	var samples := PackedFloat32Array()
	var count := int(length * MIX_RATE)
	var phase := 0.0
	var low := 0.0
	for i in count:
		var t := float(i) / count
		phase += TAU * lerpf(140.0, 45.0, t) / MIX_RATE
		low = lerpf(low, randf_range(-1.0, 1.0), 0.2)
		var env := pow(1.0 - t, 3.0)
		samples.append((sin(phase) * 0.8 + low * 0.4) * env)
	return _make_stream(samples)
