class_name Sfx
extends RefCounted
## Efeitos sonoros gerados por código (não precisa de arquivos de áudio).

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
		&"trick":
			stream = _tone([987.77, 1318.5, 1975.5], 0.06, 0.32)
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
