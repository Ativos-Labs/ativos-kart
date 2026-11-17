class_name GraphicsQuality
extends Node
## Qualidade gráfica (aba "Gráficos" das opções, filho do GameSettings): tira ou
## simplifica o que mais pesa, para o jogo rodar liso num PC fraco.
##
## - Sombras: Desligadas / Simples (2 divisões, até 100 m, sem a sombra suave que
##   varia com a distância, mapa de sombras menor) / Completas (como a pista foi
##   feita; na web e com 3 ou 4 telas já usam 2 divisões e vão menos longe).
## - Luz e efeitos: oclusão de ambiente (SSAO) e brilho (glow). Simples (sem os dois)
##   / Médios (SSAO em qualidade baixa) / Completos.
## - Antisserrilhado: Desligado / Leve (FXAA, só no desktop: o renderizador da web
##   não tem) / MSAA 2x / MSAA 4x.
## - Resolução 3D: fração fixa da resolução da tela, ou Automática (RenderScale baixa
##   sozinha quando o jogo fica lento).
## - Cenário: Reduzido (sem grama e flores, menos neve, os modelos simplificam mais
##   perto da câmera) / Completo.
## Os níveis Baixa / Média / Alta mudam tudo de uma vez. Na primeira vez que o jogo
## abre (nada salvo) o nível vem da placa de vídeo (suggested_preset).
##
## Quando vale: o que é de cada tela (luz, ambiente, grama, neve) é ajustado quando os
## nós entram na árvore (node_added), antes do primeiro quadro. No desktop uma troca
## nas opções vale na hora. Na web ligar/desligar sombras recompila todos os shaders
## (o jogo trava 4-5 s), então lá a troca vale a partir da próxima tela (atrás do
## fade, onde o warm_up já compila tudo).

## Algum valor mudou (a tela de opções atualiza o nível).
signal changed

enum { LOW, MEDIUM, HIGH, CUSTOM }
const PRESET_NAMES := ["Baixa", "Média", "Alta", "Personalizada"]

const SECTION := "graficos"
const SHADOWS := &"sombras"
const EFFECTS := &"efeitos"
const ANTIALIAS := &"antisserrilhado"
const SCALE := &"resolucao_3d"
const SCENERY := &"cenario"
const KEYS: Array[StringName] = [SHADOWS, EFFECTS, ANTIALIAS, SCALE, SCENERY]
const CAPTIONS := {
	SHADOWS: "Sombras",
	EFFECTS: "Luz e efeitos",
	ANTIALIAS: "Antisserrilhado",
	SCALE: "Resolução 3D",
	SCENERY: "Cenário",
}

enum Aa { OFF, FXAA, MSAA_2X, MSAA_4X }
const SHADOW_NAMES := ["Desligadas", "Simples", "Completas"]
const EFFECT_NAMES := ["Simples", "Médios", "Completos"]
const AA_NAMES := ["Desligado", "Leve (FXAA)", "2x (MSAA)", "4x (MSAA)"]
## Fração da resolução da tela no 3D (0 = automática).
const SCALES := [0.5, 0.6, 0.75, 0.85, 1.0, 0.0]
const SCENERY_NAMES := ["Reduzido", "Completo"]

## Cenário reduzido: os modelos com LOD simplificam com este erro na tela (pixels,
## o padrão do projeto é 1) e a neve cai com esta fração dos flocos.
const REDUCED_LOD_PIXELS := 4.0
const REDUCED_SNOW := 0.35
## Sombras simples: alcance (m) e tamanho do mapa de sombras do sol.
const SIMPLE_SHADOW_DISTANCE := 100.0
const SIMPLE_SHADOW_ATLAS := 2048

## Valores como a tela/luz vieram, antes de qualquer ajuste (fica no recurso/nó).
const META := &"graficos_original"

var show_fps := false

var _cfg: ConfigFile
var _save := Callable()
var _values := {}
## Web: a troca espera a próxima tela.
var _pending := false
## Últimos valores mandados ao RenderingServer (só manda o que mudou).
var _last := {}
var _fps_label: Label
var _fps_time := 0.0
var _fps_shown := -1


## Lê o que está salvo (antes de entrar na árvore). `save` grava o arquivo de opções.
func setup(cfg: ConfigFile, save: Callable) -> void:
	_cfg = cfg
	_save = save
	var defaults := preset_values(suggested_preset())
	for key in KEYS:
		var v = _cfg.get_value(SECTION, key, defaults[key])
		v = float(v) if key == SCALE else int(v)
		_values[key] = v if _index_of(key, v) >= 0 else defaults[key]
	show_fps = bool(_cfg.get_value(SECTION, "mostrar_fps", false))


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Como o RenderingServer começa (as opções do projeto): "Alta" não muda nada.
	_last[&"atlas"] = [_project("rendering/lights_and_shadows/directional_shadow/size"),
			_project("rendering/lights_and_shadows/directional_shadow/16_bits")]
	_last[&"filter"] = _project("rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality")
	_last[&"ssao"] = [_project("rendering/environment/ssao/quality"), _project("rendering/environment/ssao/half_size")]
	_last[&"glow"] = int(_project("rendering/environment/glow/upscale_mode")) == 1
	_build_fps_label()
	get_tree().node_added.connect(_on_node_added)
	# Depois do GameState montar o RenderScale (é criado depois das opções).
	_apply_globals.call_deferred()


# --- Valores -------------------------------------------------------------------------

## Valores possíveis da opção, na ordem da tela.
func values(key: StringName) -> Array:
	match key:
		SHADOWS, EFFECTS:
			return [0, 1, 2]
		ANTIALIAS:
			return [Aa.OFF, Aa.FXAA, Aa.MSAA_2X, Aa.MSAA_4X] if has_fxaa() else [Aa.OFF, Aa.MSAA_2X, Aa.MSAA_4X]
		SCALE:
			return SCALES.duplicate()
		SCENERY:
			return [0, 1]
	return []


func option_names(key: StringName) -> PackedStringArray:
	var out := PackedStringArray()
	for v in values(key):
		out.append(value_name(key, v))
	return out


static func value_name(key: StringName, v) -> String:
	match key:
		SHADOWS:
			return SHADOW_NAMES[v]
		EFFECTS:
			return EFFECT_NAMES[v]
		ANTIALIAS:
			return AA_NAMES[v]
		SCALE:
			return "Automática" if v <= 0.0 else "%d%%" % roundi(v * 100.0)
		SCENERY:
			return SCENERY_NAMES[v]
	return str(v)


func get_value(key: StringName):
	return _values[key]


## Posição do valor atual em `values(key)`.
func index_of(key: StringName) -> int:
	return maxi(_index_of(key, _values[key]), 0)


func set_value(key: StringName, v) -> void:
	_values[key] = v
	_cfg.set_value(SECTION, key, v)
	_after_change()


## Nível atual (CUSTOM quando os valores não batem com nenhum).
func get_preset() -> int:
	for p in [LOW, MEDIUM, HIGH]:
		var want := preset_values(p)
		if KEYS.all(func(k: StringName) -> bool: return _same(_values[k], want[k])):
			return p
	return CUSTOM


func set_preset(p: int) -> void:
	var want := preset_values(p)
	for key in KEYS:
		_values[key] = want[key]
		_cfg.set_value(SECTION, key, want[key])
	_after_change()


func preset_values(p: int) -> Dictionary:
	match p:
		LOW:
			return {SHADOWS: 0, EFFECTS: 0, ANTIALIAS: Aa.FXAA if has_fxaa() else Aa.OFF, SCALE: 0.75, SCENERY: 0}
		MEDIUM:
			return {SHADOWS: 1, EFFECTS: 1, ANTIALIAS: Aa.MSAA_2X, SCALE: 0.0, SCENERY: 1}
	return {SHADOWS: 2, EFFECTS: 2, ANTIALIAS: Aa.MSAA_4X, SCALE: 0.0, SCENERY: 1}


func set_show_fps(on: bool) -> void:
	show_fps = on
	_cfg.set_value(SECTION, "mostrar_fps", on)
	_save.call()
	_update_fps_label()


## A troca vale na hora (desktop) ou só na próxima tela (web).
static func applies_live() -> bool:
	return not OS.has_feature("web")


## FXAA só existe nos renderizadores Forward+/Mobile (não no da web).
static func has_fxaa() -> bool:
	return RenderingServer.get_current_rendering_method() != "gl_compatibility"


## Nível para a primeira vez, pela placa de vídeo: renderização por software → Baixa;
## placa integrada (Intel, AMD APU) → Média; o resto (dedicada, Apple) → Alta.
static func suggested_preset() -> int:
	var adapter := RenderingServer.get_video_adapter_name().to_lower()
	var vendor := RenderingServer.get_video_adapter_vendor().to_lower()
	if adapter == "":
		return HIGH # sem tela (--headless)
	for software in ["llvmpipe", "softpipe", "swiftshader", "basic render"]:
		if adapter.contains(software):
			return LOW
	var type := RenderingServer.get_video_adapter_type()
	if type == RenderingDevice.DEVICE_TYPE_CPU:
		return LOW
	if adapter.contains("apple") or vendor.contains("apple"):
		return HIGH # Apple Silicon: integrada, mas dá conta
	if type == RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU:
		return MEDIUM
	# Web (Compatibility) não diz o tipo da placa: Intel que não é Arc é integrada.
	if adapter.contains("intel") and not adapter.contains(" arc"):
		return MEDIUM
	return HIGH


func _index_of(key: StringName, v) -> int:
	var list := values(key)
	for i in list.size():
		if _same(list[i], v):
			return i
	return -1


static func _same(a, b) -> bool:
	if typeof(a) == TYPE_FLOAT or typeof(b) == TYPE_FLOAT:
		return is_equal_approx(float(a), float(b))
	return a == b


func _after_change() -> void:
	_save.call()
	if applies_live():
		_apply_globals()
		_apply_tree()
	else:
		_pending = true
	changed.emit()


static func _project(setting: String) -> Variant:
	return ProjectSettings.get_setting_with_override(setting)


# --- Aplicar -------------------------------------------------------------------------

## O que vale para o jogo todo: antisserrilhado e LOD das telas, mapa e filtro das
## sombras, qualidade do SSAO e do brilho, resolução do 3D.
func _apply_globals() -> void:
	_pending = false
	var aa: int = _values[ANTIALIAS]
	var msaa := Viewport.MSAA_DISABLED
	if aa == Aa.MSAA_2X:
		msaa = Viewport.MSAA_2X
	elif aa == Aa.MSAA_4X:
		msaa = Viewport.MSAA_4X
	var ssaa := Viewport.SCREEN_SPACE_AA_FXAA if aa == Aa.FXAA else Viewport.SCREEN_SPACE_AA_DISABLED
	var lod := float(_project("rendering/mesh_lod/lod_change/threshold_pixels"))
	if _values[SCENERY] == 0:
		lod = maxf(lod, REDUCED_LOD_PIXELS)
	var viewports: Array[Viewport] = [get_tree().root]
	for node in get_tree().get_nodes_in_group(RenderScale.GROUP):
		if node is Viewport:
			viewports.append(node)
	for vp in viewports:
		if vp.msaa_3d != msaa:
			vp.msaa_3d = msaa
		if vp.screen_space_aa != ssaa:
			vp.screen_space_aa = ssaa
		if not is_equal_approx(vp.mesh_lod_threshold, lod):
			vp.mesh_lod_threshold = lod

	var atlas: int = _project("rendering/lights_and_shadows/directional_shadow/size")
	var bits16: bool = _project("rendering/lights_and_shadows/directional_shadow/16_bits")
	var filter: int = _project("rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality")
	if _values[SHADOWS] == 1:
		atlas = mini(atlas, SIMPLE_SHADOW_ATLAS)
		filter = mini(filter, RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW)
	_send(&"atlas", [atlas, bits16], func(): RenderingServer.directional_shadow_atlas_set_size(atlas, bits16))
	_send(&"filter", filter, func(): RenderingServer.directional_soft_shadow_filter_set_quality(
			filter as RenderingServer.ShadowQuality))

	var ssao_quality: int = _project("rendering/environment/ssao/quality")
	var half: bool = _project("rendering/environment/ssao/half_size")
	var bicubic := int(_project("rendering/environment/glow/upscale_mode")) == 1
	if _values[EFFECTS] == 1:
		ssao_quality = mini(ssao_quality, RenderingServer.ENV_SSAO_QUALITY_LOW)
		half = true
		bicubic = false
	_send(&"ssao", [ssao_quality, half], func(): RenderingServer.environment_set_ssao_quality(
			ssao_quality as RenderingServer.EnvironmentSSAOQuality, half,
			_project("rendering/environment/ssao/adaptive_target"),
			_project("rendering/environment/ssao/blur_passes"),
			_project("rendering/environment/ssao/fadeout_from"),
			_project("rendering/environment/ssao/fadeout_to")))
	_send(&"glow", bicubic, func(): RenderingServer.environment_glow_set_use_bicubic_upscale(bicubic))

	if GameState.render_scale:
		GameState.render_scale.fixed = float(_values[SCALE])


func _send(what: StringName, value, call: Callable) -> void:
	if _last.get(what) == value:
		return
	_last[what] = value
	call.call()


## Reaplica em tudo o que já está na tela (troca na hora, desktop).
func _apply_tree() -> void:
	var root := get_tree().root
	for type in ["WorldEnvironment", "DirectionalLight3D", "GPUParticles3D"]:
		for node in root.find_children("*", type, true, false):
			if _handles(node):
				_apply_node(node)
	for node in get_tree().get_nodes_in_group(TrackScenery.DETAIL_GROUP):
		_apply_node(node)


func _on_node_added(node: Node) -> void:
	if _pending and node.get_parent() == get_tree().root:
		# Web: uma tela nova está entrando (atrás do fade).
		_apply_globals()
	if not _handles(node):
		return
	# No `ready`: a luz e a neve terminam de se montar no _ready delas.
	if node.is_node_ready():
		_apply_node(node)
	else:
		var apply := _apply_node.bind(node)
		if not node.ready.is_connected(apply):
			node.ready.connect(apply, CONNECT_ONE_SHOT)


func _handles(node: Node) -> bool:
	return node is WorldEnvironment or node is DirectionalLight3D or node is Snowfall \
			or node.is_in_group(TrackScenery.DETAIL_GROUP)


func _apply_node(node: Node) -> void:
	if not is_instance_valid(node):
		return
	var full_scenery: bool = _values[SCENERY] == 1
	if node is WorldEnvironment:
		_apply_environment((node as WorldEnvironment).environment)
	elif node is DirectionalLight3D:
		_apply_light(node as DirectionalLight3D)
	elif node is Snowfall:
		(node as Snowfall).amount_ratio = 1.0 if full_scenery else REDUCED_SNOW
	elif node is Node3D:
		(node as Node3D).visible = full_scenery


func _apply_environment(env: Environment) -> void:
	if env == null:
		return
	# O recurso pode ser o mesmo em várias telas (vem da cena da pista): o original fica
	# guardado nele para dar para voltar ao "Completos".
	if not env.has_meta(META):
		env.set_meta(META, {"ssao": env.ssao_enabled, "glow": env.glow_enabled})
	var original: Dictionary = env.get_meta(META)
	var on: bool = _values[EFFECTS] > 0
	env.ssao_enabled = original.ssao and on
	env.glow_enabled = original.glow and on


func _apply_light(light: DirectionalLight3D) -> void:
	if not light.has_meta(META):
		light.set_meta(META, {
			"shadow_enabled": light.shadow_enabled,
			"directional_shadow_mode": light.directional_shadow_mode,
			"directional_shadow_split_1": light.directional_shadow_split_1,
			"directional_shadow_max_distance": light.directional_shadow_max_distance,
			"directional_shadow_blend_splits": light.directional_shadow_blend_splits,
			"light_angular_distance": light.light_angular_distance,
		})
	var original: Dictionary = light.get_meta(META)
	for property in original:
		if light.get(property) != original[property]:
			light.set(property, original[property])
	var level: int = _values[SHADOWS]
	if not light.shadow_enabled:
		return
	if level == 0:
		light.shadow_enabled = false
		return
	# Cada divisão (cascata) redesenha tudo o que faz sombra. Na web elas eram ~40% do
	# quadro (4 → 2 divisões economizava 0,6 a 3,9 ms num M4); com 3 ou 4 telas as
	# sombras são desenhadas uma vez por tela.
	var distance := light.directional_shadow_max_distance
	var two_splits := false
	var players := GameState.players.size()
	if players >= 3:
		distance = minf(distance, 110.0)
		two_splits = true
	elif OS.has_feature("web"):
		distance = minf(distance, 140.0)
		two_splits = true
	if level == 1:
		distance = minf(distance, SIMPLE_SHADOW_DISTANCE)
		two_splits = true
		light.directional_shadow_blend_splits = false
		# Sem a penumbra que cresce com a distância (procura de bloqueador, cara).
		light.light_angular_distance = 0.0
	if two_splits and light.directional_shadow_mode != DirectionalLight3D.SHADOW_ORTHOGONAL:
		light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		# A 1ª divisão (a nítida) cobre os primeiros ~20 m: o kart e quem está perto.
		light.directional_shadow_split_1 = 0.18
	light.directional_shadow_max_distance = distance


# --- Contador de FPS -----------------------------------------------------------------

func _build_fps_label() -> void:
	var layer := CanvasLayer.new()
	layer.name = "FPS"
	# Abaixo do fade de troca de tela (128).
	layer.layer = 127
	add_child(layer)
	_fps_label = Label.new()
	_fps_label.add_theme_font_size_override("font_size", 16)
	_fps_label.add_theme_color_override("font_color", Color.WHITE)
	_fps_label.add_theme_color_override("font_outline_color", Color(0.04, 0.05, 0.12))
	_fps_label.add_theme_constant_override("outline_size", 6)
	_fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# No meio do topo (o HUD usa os cantos).
	_fps_label.anchor_left = 0.5
	_fps_label.anchor_right = 0.5
	_fps_label.offset_left = -70.0
	_fps_label.offset_right = 70.0
	_fps_label.offset_top = 4.0
	_fps_label.offset_bottom = 28.0
	layer.add_child(_fps_label)
	_update_fps_label()


func _update_fps_label() -> void:
	if _fps_label == null:
		return
	_fps_label.visible = show_fps
	_fps_shown = -1
	_fps_time = 1.0
	set_process(show_fps)


func _process(delta: float) -> void:
	# Texto muda só duas vezes por segundo (e só se o número mudou).
	_fps_time += delta
	if _fps_time < 0.5:
		return
	_fps_time = 0.0
	var fps := roundi(Engine.get_frames_per_second())
	if fps != _fps_shown:
		_fps_shown = fps
		_fps_label.text = "%d FPS" % fps
