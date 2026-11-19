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
		&"rocket":
			stream = _rocket(1.0)
		&"briefcase":
			stream = _latches()
		&"cash":
			stream = _cloth(0.3, false)
		&"paper":
			stream = _cloth(0.5, true)
		&"stamp":
			stream = _stamp(0.32)
		&"boing":
			stream = _boing(0.3)
		&"alarm":
			stream = _tone([987.77, 739.99, 987.77, 739.99], 0.12, 0.34)
		&"calc_beep":
			stream = _tone([2793.83], 0.07, 0.3)
		&"boom":
			stream = _boom(1.3, 1.0)
		&"slam":
			stream = _boom(0.8, 0.45)
		&"parcela":
			stream = _tone([1567.98, 2093.0], 0.04, 0.24)
		&"senha":
			# "Plim-plom" do painel de senhas chamando.
			stream = _tone([1318.5, 1046.5], 0.32, 0.42)
		&"wrong":
			stream = _tone([392.0, 293.66, 233.08], 0.11, 0.42)
		&"julgado":
			stream = _tone([783.99, 1046.5, 1318.5, 1567.98, 2093.0, 2637.0], 0.065, 0.34)
		&"gavel":
			stream = _gavel(0.28)
		&"horn":
			stream = _horn(0.85)
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


## Foguete da RPV: ignição seca e o ronco de ar que sobe de tom, com estalinhos.
static func _rocket(length: float) -> AudioStreamWAV:
	var samples := PackedFloat32Array()
	var count := int(length * MIX_RATE)
	var low := 0.0
	var phase := 0.0
	for i in count:
		var t := float(i) / count
		var st := t * length
		var noise := randf_range(-1.0, 1.0)
		low = lerpf(low, noise, 0.12 + t * 0.2)
		phase += TAU * lerpf(110.0, 420.0, sqrt(t)) / MIX_RATE
		var env := minf(t * 30.0, 1.0) * pow(1.0 - t, 1.5)
		var crackle := noise * (1.0 if randf() < 0.004 else 0.0) * 0.8
		var ignition := noise * exp(-st * 30.0) * 0.6
		samples.append((low * 0.8 + sin(phase) * 0.3 + crackle) * env + ignition)
	return _make_stream(_normalized(samples, 0.85))


## Maleta da Antecipação abrindo: dois fechos ("clac, clac") e um brilho de moedas.
static func _latches() -> AudioStreamWAV:
	var samples := PackedFloat32Array()
	var count := int(0.5 * MIX_RATE)
	var phase := 0.0
	for i in count:
		var st := float(i) / MIX_RATE
		var s := 0.0
		for at: float in [0.0, 0.09]:
			var d := st - at
			if d >= 0.0:
				s += (randf_range(-1.0, 1.0) * 0.6 + sin(TAU * 1900.0 * d) * 0.5) * exp(-d * 160.0)
		if st > 0.17:
			var d := st - 0.17
			var f := 1568.0 if d < 0.07 else (2093.0 if d < 0.14 else 2637.0)
			phase += TAU * f / MIX_RATE
			s += (sin(phase) * 0.7 + signf(sin(phase)) * 0.15) * exp(-fmod(d, 0.07) * 18.0) * 0.35 * (1.0 - d / 0.33)
		samples.append(s)
	return _make_stream(_normalized(samples, 0.8))


## Carimbo batendo: um "tum" grave e seco com o estalo da madeira.
static func _stamp(length: float) -> AudioStreamWAV:
	var samples := PackedFloat32Array()
	var count := int(length * MIX_RATE)
	var phase := 0.0
	var low := 0.0
	for i in count:
		var t := float(i) / count
		var st := t * length
		phase += TAU * lerpf(150.0, 50.0, minf(st * 8.0, 1.0)) / MIX_RATE
		var noise := randf_range(-1.0, 1.0)
		low = lerpf(low, noise, 0.3)
		var body := sin(phase) * exp(-st * 14.0)
		var knock := (noise * 0.7 + sin(TAU * 900.0 * st) * 0.4) * exp(-st * 90.0)
		samples.append(body + knock + low * 0.15 * exp(-st * 20.0))
	return _make_stream(_normalized(samples, 0.95))


## Carimbo batendo na mureta: "boing" de mola (o tom treme e cai) com um toque seco.
static func _boing(length: float) -> AudioStreamWAV:
	var samples := PackedFloat32Array()
	var count := int(length * MIX_RATE)
	var phase := 0.0
	for i in count:
		var t := float(i) / count
		var st := t * length
		var f := 330.0 + 260.0 * exp(-st * 9.0) * sin(st * TAU * 14.0) - 80.0 * t
		phase += TAU * f / MIX_RATE
		var env := minf(t * 60.0, 1.0) * pow(1.0 - t, 1.6)
		var knock := randf_range(-1.0, 1.0) * exp(-st * 120.0) * 0.5
		samples.append((sin(phase) * 0.8 + signf(sin(phase)) * 0.12) * env + knock)
	return _make_stream(_normalized(samples, 0.8))


## Explosão (calculadora) ou baque enorme (a Constituição caindo): estalo, ronco grave e
## o chiado que some. `crack` = força do estalo e do chiado (o livro é mais abafado).
static func _boom(length: float, crack: float) -> AudioStreamWAV:
	var samples := PackedFloat32Array()
	var count := int(length * MIX_RATE)
	var low := 0.0
	var low2 := 0.0
	var phase := 0.0
	for i in count:
		var t := float(i) / count
		var st := t * length
		var noise := randf_range(-1.0, 1.0)
		low = lerpf(low, noise, 0.06)
		low2 = lerpf(low2, low, 0.12)
		phase += TAU * lerpf(90.0, 32.0, minf(st * 3.0, 1.0)) / MIX_RATE
		var body := sin(phase) * exp(-st * 5.0) * 1.2
		var rumble := low2 * 3.0 * pow(1.0 - t, 1.5)
		var hiss := noise * exp(-st * 7.0) * 0.35 * crack
		var snap := noise * exp(-st * 60.0) * 0.8 * crack
		samples.append(body + rumble + hiss + snap)
	return _make_stream(_normalized(samples, 0.95))


## Martelo de juiz: duas batidas secas de madeira ("toc-toc"), a segunda mais forte.
static func _gavel(length: float) -> AudioStreamWAV:
	var samples := PackedFloat32Array()
	var count := int(length * MIX_RATE)
	var hits := [0.0, 0.11]
	for i in count:
		var st := float(i) / MIX_RATE
		var s := 0.0
		for j in hits.size():
			var t: float = st - hits[j]
			if t < 0.0:
				continue
			var amp := 0.6 if j == 0 else 1.0
			# Corpo de madeira (tom que cai rápido) e o estalo.
			s += amp * (sin(TAU * lerpf(820.0, 520.0, minf(t * 30.0, 1.0)) * t) * exp(-t * 38.0)
					+ randf_range(-1.0, 1.0) * exp(-t * 160.0) * 0.6
					+ sin(TAU * 180.0 * t) * exp(-t * 22.0) * 0.5)
		samples.append(s)
	return _make_stream(_normalized(samples, 0.9))


## Buzina da Liminar: acorde de metais (dente de serra suave com vibrato) que entra forte
## e some, com um sopro de ar.
static func _horn(length: float) -> AudioStreamWAV:
	var samples := PackedFloat32Array()
	var count := int(length * MIX_RATE)
	var freqs := [233.08, 293.66, 349.23, 466.16]
	var phases := [0.0, 0.0, 0.0, 0.0]
	var low := 0.0
	for i in count:
		var t := float(i) / count
		var st := t * length
		var vib := 1.0 + 0.008 * sin(TAU * 6.0 * st)
		var s := 0.0
		for j in freqs.size():
			phases[j] = fmod(phases[j] + freqs[j] * vib / MIX_RATE, 1.0)
			var saw: float = phases[j] * 2.0 - 1.0
			s += (saw * 0.55 + sin(phases[j] * TAU) * 0.45) * (0.8 if j == 3 else 1.0)
		low = lerpf(low, randf_range(-1.0, 1.0), 0.15)
		var env := minf(st * 25.0, 1.0) * (1.0 - smoothstep(0.55, 1.0, t))
		samples.append(s * env * 0.3 + low * 0.25 * exp(-st * 6.0))
	return _make_stream(_normalized(samples, 0.85))


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
