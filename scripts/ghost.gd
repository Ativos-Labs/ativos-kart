class_name Ghost
extends RefCounted
## Fantasma do contra-relógio: o percurso de um kart gravado 30 vezes por segundo
## (posição, giro, inclinação do modelo, rodas, volante e a asa-delta), salvo junto com o recorde
## de cada pista e classe de velocidade em user://fantasmas/. O GhostKart refaz o
## percurso com um kart transparente.

const DIR := "user://fantasmas"
## Versão 2 = com a abertura da asa-delta em cada quadro. A versão 1 (sem asa) ainda
## é lida.
const VERSION := 2
## Quadros gravados por segundo.
const RATE := 30.0
## Números por quadro: posição (3), giro (1), rotação do modelo (4), afundamento da
## suspensão (1), velocidade (1), volante (1), lado do drift (1) e abertura da asa (1).
const STRIDE := 13
## Números por quadro na versão 1 (sem a asa).
const STRIDE_V1 := 12

var track_id := ""
var speed_class := ""
## Tempo total da corrida gravada (s) e de cada volta.
var total_time := -1.0
var lap_times := PackedFloat32Array()
## Recursos do kart e do piloto (para montar o modelo).
var kart_path := ""
var character_path := ""
var glider_path := ""
var frames := PackedFloat32Array()
## Números por quadro deste fantasma (STRIDE, ou STRIDE_V1 num arquivo antigo).
var stride := STRIDE


static func path_for(p_track_id: String, p_class: String) -> String:
	return "%s/%s_%s.fantasma" % [DIR, p_track_id, p_class]


## Começa uma gravação para o kart `kart` (de um jogador).
static func start_recording(p_track_id: String, p_class: String, kart: Kart) -> Ghost:
	var g := Ghost.new()
	g.track_id = p_track_id
	g.speed_class = p_class
	if kart.data:
		g.kart_path = kart.data.resource_path
	if kart.character:
		# Personagem recolorido (outro jogador já tinha esse) não tem arquivo: vale o
		# original, o fantasma é todo de uma cor só mesmo.
		g.character_path = kart.character.resource_path
		if g.character_path.is_empty() and GameState.characters.size() > 0:
			g.character_path = GameState.characters[0].resource_path
	if kart.glider:
		g.glider_path = kart.glider.resource_path
	return g


func frame_count() -> int:
	return frames.size() / stride


## Grava o quadro do momento `time` (s desde a largada). Chame a cada quadro de física:
## só grava quando chega a hora do próximo quadro.
func capture(kart: Kart, time: float) -> void:
	if time < frame_count() / RATE:
		return
	var p := kart.global_position
	var q := kart.visual.transform.basis.get_rotation_quaternion()
	var glide := kart.glider_visual.openness if kart.glider_visual else (1.0 if kart.gliding else 0.0)
	frames.append_array(PackedFloat32Array([
		p.x, p.y, p.z, kart.global_rotation.y,
		q.x, q.y, q.z, q.w, kart.visual.position.y,
		kart.speed, kart.steer_input, float(kart.drift_dir), glide,
	]))


## Estado do kart no momento `time` (interpolado entre os quadros gravados).
## Devolve {} se o percurso já acabou.
func sample(time: float) -> Dictionary:
	var count := frame_count()
	if count == 0:
		return {}
	var f := maxf(time, 0.0) * RATE
	var i := floori(f)
	if i >= count - 1:
		return {}
	var t := f - i
	var a := i * stride
	var b := a + stride
	var qa := Quaternion(frames[a + 4], frames[a + 5], frames[a + 6], frames[a + 7])
	var qb := Quaternion(frames[b + 4], frames[b + 5], frames[b + 6], frames[b + 7])
	return {
		"position": Vector3(frames[a], frames[a + 1], frames[a + 2]).lerp(Vector3(frames[b], frames[b + 1], frames[b + 2]), t),
		"yaw": lerp_angle(frames[a + 3], frames[b + 3], t),
		"visual": qa.slerp(qb, t),
		"squash": lerpf(frames[a + 8], frames[b + 8], t),
		"speed": lerpf(frames[a + 9], frames[b + 9], t),
		"steer": lerpf(frames[a + 10], frames[b + 10], t),
		"drift": int(frames[a + 11]),
		"glide": lerpf(frames[a + 12], frames[b + 12], t) if stride > 12 else 0.0,
	}


## Tempo do fantasma ao completar `laps` voltas (-1 se não tem).
func split_time(laps: int) -> float:
	if laps <= 0 or laps > lap_times.size():
		return -1.0
	var sum := 0.0
	for i in laps:
		sum += lap_times[i]
	return sum


func save() -> bool:
	DirAccess.make_dir_recursive_absolute(DIR)
	var file := FileAccess.open_compressed(path_for(track_id, speed_class), FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
	if file == null:
		push_warning("Não deu para salvar o fantasma: %s" % error_string(FileAccess.get_open_error()))
		return false
	file.store_var({
		"version": VERSION,
		"track_id": track_id,
		"speed_class": speed_class,
		"total_time": total_time,
		"lap_times": lap_times,
		"kart": kart_path,
		"character": character_path,
		"glider": glider_path,
		"frames": frames,
	})
	file.close()
	return true


## O fantasma salvo desta pista e classe (null se não tem).
static func load_for(p_track_id: String, p_class: String) -> Ghost:
	var path := path_for(p_track_id, p_class)
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open_compressed(path, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	if file == null:
		return null
	var d = file.get_var()
	file.close()
	if not (d is Dictionary):
		return null
	var version := int(d.get("version", 0))
	if version != 1 and version != VERSION:
		return null
	var g := Ghost.new()
	g.stride = STRIDE_V1 if version == 1 else STRIDE
	g.track_id = d.get("track_id", p_track_id)
	g.speed_class = d.get("speed_class", p_class)
	g.total_time = float(d.get("total_time", -1.0))
	g.lap_times = d.get("lap_times", PackedFloat32Array())
	g.kart_path = d.get("kart", "")
	g.character_path = d.get("character", "")
	g.glider_path = d.get("glider", "")
	g.frames = d.get("frames", PackedFloat32Array())
	return g if g.frame_count() > 1 else null
