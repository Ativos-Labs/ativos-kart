class_name Hud
extends CanvasLayer
## Interface da corrida: retrato do piloto, posição, volta, tempo, velocímetro,
## mini-mapa com todos os karts, semáforo de largada, mensagens e a tela de
## resultado com a classificação.
##
## Na tela dividida cada jogador tem um HUD compacto (Layout.PLAYER, dentro da tela
## dele) e um HUD por cima de tudo (Layout.OVERLAY) mostra o mapa da pista e o
## resultado.

## FULL = um jogador só; PLAYER = HUD de um jogador na tela dividida; OVERLAY = mapa e
## resultado por cima das telas divididas.
enum Layout { FULL, PLAYER, OVERLAY }

signal restart_requested
## Grand Prix: próxima corrida (ou, depois da última, uma copa nova).
signal next_requested
signal change_kart_requested
signal change_track_requested
signal change_character_requested
signal menu_requested

@onready var badge: PortraitBadge = %Badge
@onready var driver_name: Label = %DriverName
@onready var track_name: Label = %TrackName
@onready var lap_box: Control = %LapBox
@onready var place_badge: PlaceBadge = %PlaceBadge
@onready var result_laps: Label = %ResultLaps
@onready var lap_value: Label = %LapValue
@onready var time_value: Label = %TimeValue
@onready var lap_times_label: Label = %LapTimes
@onready var best_label: Label = %BestLabel
@onready var speed_gauge: SpeedGauge = %SpeedGauge
@onready var minimap: Minimap = %Minimap
@onready var start_lights: StartLights = %StartLights
@onready var center_label: Label = %CenterLabel
@onready var banner: RibbonLabel = %Banner
@onready var message_label: Label = %MessageLabel
@onready var hint_pill: Control = %HintPill
@onready var results: Control = %Results
@onready var results_checker: ColorRect = %ResultsChecker
@onready var result_title: RibbonLabel = %ResultTitle
@onready var result_rows: VBoxContainer = %ResultRows
@onready var result_record: Label = %ResultRecord
@onready var result_buttons: Control = %ResultButtons
@onready var again_button: Button = %AgainButton
@onready var change_character_button: Button = %ChangeCharacterButton
@onready var change_kart_button: Button = %ChangeKartButton
@onready var change_track_button: Button = %ChangeTrackButton
@onready var menu_button: Button = %MenuButton

@onready var map_panel: Control = $Root/MapPanel
@onready var time_panel: Control = $Root/TimePanel
@onready var lap_title: Label = $Root/LapBox/LapTitle

var kart: Kart
var layout := Layout.FULL
var _next_button: FancyButton
var _timeout_label: Label
var _center_tween: Tween
var _banner_tween: Tween
var _message_time := 0.0


func _ready() -> void:
	results.visible = false
	center_label.visible = false
	message_label.visible = false
	banner.visible = false
	again_button.pressed.connect(func(): restart_requested.emit())
	change_character_button.pressed.connect(func(): change_character_requested.emit())
	change_kart_button.pressed.connect(func(): change_kart_requested.emit())
	change_track_button.pressed.connect(func(): change_track_requested.emit())
	menu_button.pressed.connect(func(): menu_requested.emit())
	_next_button = FancyButton.new()
	_next_button.name = "NextButton"
	_next_button.text = "Próxima corrida"
	_next_button.icon_kind = "next"
	_next_button.align_left = true
	_next_button.primary = true
	_next_button.custom_minimum_size = Vector2(270, 46)
	_next_button.add_theme_font_size_override("font_size", 22)
	_next_button.visible = false
	_next_button.pressed.connect(func(): next_requested.emit())
	result_buttons.add_child(_next_button)
	result_buttons.move_child(_next_button, 0)


## `karts` = todos os karts da corrida (para o mini-mapa), incluindo `p_kart`.
## Na tela dividida, `slot` = o jogador dono deste HUD (Layout.PLAYER).
func setup(track: Track, p_kart: Kart, karts: Array[Kart], laps: int, best_total: float, best_lap: float,
		p_layout := Layout.FULL, slot: PlayerSlot = null) -> void:
	layout = p_layout
	if layout == Layout.OVERLAY:
		_setup_overlay(track, karts)
		return
	kart = p_kart
	track_name.text = track.track_name
	place_badge.visible = karts.size() > 1
	minimap.setup(track, karts, p_kart)
	if layout == Layout.PLAYER:
		_setup_compact(slot)
	else:
		if p_kart.character:
			badge.setup(p_kart.character)
			badge.follow(p_kart.driver)
			driver_name.text = p_kart.character.display_name.to_upper()
		else:
			badge.hide()
			driver_name.text = ""
	set_lap(1, laps)
	set_time(0.0)
	lap_times_label.text = ""
	best_label.text = "RECORDE  %s   •   VOLTA  %s" % [GameState.format_time(best_total), GameState.format_time(best_lap)]
	start_lights.step = 0


## HUD de um jogador na tela dividida: sem retrato (cada um custaria uma SubViewport),
## sem mapa (fica no HUD por cima de tudo), números menores e a etiqueta "J2" na cor
## do jogador no lugar do nome.
func _setup_compact(slot: PlayerSlot) -> void:
	badge.hide()
	track_name.hide()
	best_label.hide()
	lap_times_label.hide()
	hint_pill.hide()
	# Mapa pequeno no meio da direita, entre o tempo e o velocímetro (o do jogador fica
	# por cima dos outros).
	_set_offsets(map_panel, -184.0, -150.0, -18.0, 16.0)
	driver_name.text = slot.tag if slot else ""
	driver_name.add_theme_color_override("font_color", slot.color if slot else Color.WHITE)
	driver_name.add_theme_font_size_override("font_size", 40)
	driver_name.position = Vector2(24.0, 14.0)
	_set_offsets(place_badge, 22.0, -236.0, 212.0, -146.0)
	_set_offsets(lap_box, 26.0, -146.0, 280.0, -16.0)
	lap_box.add_theme_constant_override("separation", -16)
	lap_title.add_theme_font_size_override("font_size", 26)
	lap_value.add_theme_font_size_override("font_size", 70)
	_set_offsets(speed_gauge, -196.0, -170.0, -16.0, -8.0)
	_set_offsets(time_panel, -262.0, 14.0, -18.0, 84.0)
	time_value.add_theme_font_size_override("font_size", 38)
	center_label.add_theme_font_size_override("font_size", 130)
	message_label.add_theme_font_size_override("font_size", 52)
	banner.font_size = 46
	# Fim da corrida chegando (multijogador): contagem embaixo do tempo.
	_timeout_label = Label.new()
	_timeout_label.add_theme_font_override("font", UiKit.FONT_ITALIC)
	_timeout_label.add_theme_font_size_override("font_size", 26)
	_timeout_label.add_theme_color_override("font_color", UiKit.YELLOW)
	_timeout_label.add_theme_constant_override("outline_size", 10)
	_timeout_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timeout_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Root.add_child(_timeout_label)
	# No alto, no meio (onde fica o semáforo na largada).
	_timeout_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_set_offsets(_timeout_label, -200.0, 18.0, 200.0, 54.0)
	_timeout_label.hide()


## HUD por cima das telas divididas: só o mapa da pista (com todos os karts) e a tela
## de resultado.
func _setup_overlay(track: Track, karts: Array[Kart]) -> void:
	for child in $Root.get_children():
		if child != map_panel and child != results:
			child.hide()
	minimap.setup(track, karts)


## Lugar do mapa (unidades de interface) no HUD por cima das telas divididas, com o
## nome da pista em cima (`title`, opcional).
func place_map(rect: Rect2, title := "") -> void:
	map_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	map_panel.position = rect.position
	map_panel.size = rect.size
	if title != "":
		track_name.text = title.to_upper()
		track_name.add_theme_font_override("font", UiKit.FONT_ITALIC)
		track_name.add_theme_font_size_override("font_size", 30)
		track_name.add_theme_constant_override("outline_size", 12)
		track_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		track_name.position = Vector2(rect.position.x - 60.0, rect.position.y - 46.0)
		track_name.size = Vector2(rect.size.x + 120.0, 40.0)
		track_name.show()


static func _set_offsets(c: Control, left: float, top: float, right: float, bottom: float) -> void:
	c.offset_left = left
	c.offset_top = top
	c.offset_right = right
	c.offset_bottom = bottom


## Multijogador: segundos até a corrida acabar para quem ainda não chegou (-1 esconde).
func set_timeout(seconds: float) -> void:
	if _timeout_label == null:
		return
	_timeout_label.visible = seconds >= 0.0
	if seconds >= 0.0:
		_timeout_label.text = "FIM EM %d" % ceili(seconds)


func _process(delta: float) -> void:
	if kart and is_instance_valid(kart):
		speed_gauge.kmh = kart.get_speed_kmh()
		speed_gauge.ratio = absf(kart.speed) / maxf(kart.max_speed, 1.0)
		speed_gauge.boosting = kart.boost_time > 0.0
		speed_gauge.drift_level = kart.drift_level if kart.drifting else -1
	if _message_time > 0.0:
		_message_time -= delta
		message_label.modulate.a = 0.55 + 0.45 * absf(sin(Time.get_ticks_msec() * 0.008))


func set_lap(current: int, total: int) -> void:
	var text := "%d/%d" % [clampi(current, 1, total), total]
	if lap_value.text == text:
		return
	lap_value.text = text
	lap_value.pivot_offset = Vector2(0.0, lap_value.size.y)
	lap_value.scale = Vector2.ONE * 1.35
	var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(lap_value, "scale", Vector2.ONE, 0.35)


func set_time(t: float) -> void:
	time_value.text = GameState.format_time(t)


## Posição do jogador (chame a cada quadro; o selo só muda quando estabiliza).
func set_place(place: int, total: int) -> void:
	place_badge.set_place(place, total)


func set_lap_times(times: Array[float]) -> void:
	var lines := PackedStringArray()
	for i in times.size():
		lines.append("V%d   %s" % [i + 1, GameState.format_time(times[i])])
	lap_times_label.text = "\n".join(lines)


## Semáforo da largada: 1, 2, 3 = luzes vermelhas; 4 = verde (some logo depois).
func set_start_lights(step: int) -> void:
	start_lights.step = step
	if step == 1:
		start_lights.modulate.a = 1.0
	if step >= 4:
		var tw := create_tween()
		tw.tween_interval(0.9)
		tw.tween_property(start_lights, "modulate:a", 0.0, 0.35)


## Texto grande no centro da tela (contagem, "VAI!", "CHEGADA!").
func show_center(text: String, color := UiKit.YELLOW, hold := 0.8) -> void:
	center_label.text = text
	center_label.add_theme_color_override("font_color", color)
	center_label.visible = true
	center_label.pivot_offset = center_label.size * 0.5
	center_label.scale = Vector2.ONE * 2.2
	center_label.rotation = deg_to_rad(-8.0)
	center_label.modulate.a = 1.0
	if _center_tween:
		_center_tween.kill()
	_center_tween = create_tween().set_parallel()
	_center_tween.tween_property(center_label, "scale", Vector2.ONE, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_center_tween.tween_property(center_label, "rotation", 0.0, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_center_tween.chain().tween_interval(hold)
	_center_tween.chain().tween_property(center_label, "modulate:a", 0.0, 0.25)
	_center_tween.chain().tween_callback(func(): center_label.visible = false)


## Faixa que atravessa a tela ("VOLTA 2", "VOLTA FINAL!").
func show_banner(text: String, color := UiKit.NAVY, hold := 1.1) -> void:
	banner.text = text
	banner.color = color
	banner.visible = true
	banner.reset_size()
	var vp := banner.get_viewport_rect().size
	var center_x := (vp.x - banner.size.x) * 0.5
	banner.position.x = vp.x + 40.0
	if _banner_tween:
		_banner_tween.kill()
	_banner_tween = create_tween()
	_banner_tween.tween_property(banner, "position:x", center_x, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tween.tween_interval(hold)
	_banner_tween.tween_property(banner, "position:x", -banner.size.x - 40.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_banner_tween.tween_callback(func(): banner.visible = false)


## Aviso piscando (ex.: CONTRAMÃO). Texto vazio esconde.
func set_warning(text: String) -> void:
	message_label.visible = text != ""
	message_label.text = text
	_message_time = 1.0 if text != "" else 0.0


func show_hint(on: bool) -> void:
	var tw := create_tween()
	tw.tween_property(hint_pill, "modulate:a", 1.0 if on else 0.0, 0.4)


## Tela de resultado. Com adversários: a classificação (`standings`, uma entrada por
## kart: place, name, color, time, is_player e, opcionais, tag "J2", value (texto no
## lugar do tempo) e gain ("+15")) e as voltas do jogador numa linha.
## Correndo sozinho: as voltas e o tempo total, uma por linha.
## `options` (todas opcionais): title, title_color, laps_text (linha embaixo da
## tabela, "" esconde), record_text (no lugar dos avisos de recorde) e buttons:
## "race" (padrão), "gp_next" (próxima corrida da copa) ou "gp_final" (fim da copa).
func show_results(standings: Array[Dictionary], place: int, total: float, lap_times: Array[float],
		record_total: bool, record_lap: bool, options := {}) -> void:
	set_warning("")
	place_badge.visible = false
	var best := INF
	for t in lap_times:
		best = minf(best, t)
	for child in result_rows.get_children():
		child.queue_free()
	var rows: Array[Control] = []
	if standings.size() > 1:
		var titles := ["1º LUGAR!", "2º LUGAR!", "3º LUGAR!"]
		var colors := [Color(0.93, 0.6, 0.02), Color(0.45, 0.52, 0.66), Color(0.72, 0.38, 0.16)]
		result_title.text = titles[place - 1] if place <= 3 else "%dº LUGAR" % place
		result_title.color = colors[place - 1] if place <= 3 else UiKit.NAVY_LIGHT
		for s in standings:
			var row := StandingRow.new()
			var value: String = s.get("value", GameState.format_time(s.get("time", -1.0)))
			row.setup(s.place, s.name, value, s.color, s.is_player, s.get("tag", ""), s.get("gain", ""))
			result_rows.add_child(row)
			rows.append(row)
		var parts := PackedStringArray()
		for t in lap_times:
			parts.append(GameState.format_time(t))
		result_laps.text = "SUAS VOLTAS    %s" % "  •  ".join(parts)
		result_laps.visible = not lap_times.is_empty()
	else:
		result_laps.visible = false
		for i in lap_times.size():
			var is_best := is_equal_approx(lap_times[i], best) and lap_times.size() > 1
			var row := ResultRow.new()
			row.setup("VOLTA %d" % (i + 1), GameState.format_time(lap_times[i]), false, false,
					"MELHOR" if is_best else "")
			result_rows.add_child(row)
			rows.append(row)
		var total_row := ResultRow.new()
		total_row.setup("TEMPO TOTAL", GameState.format_time(total), true, true)
		result_rows.add_child(total_row)
		rows.append(total_row)

	var records := PackedStringArray()
	if record_total:
		records.append("NOVO RECORDE!")
	if record_lap:
		records.append("Melhor volta da pista!")
	result_record.text = "   ".join(records)
	if options.has("title"):
		result_title.text = options.title
	if options.has("title_color"):
		result_title.color = options.title_color
	if options.has("laps_text"):
		result_laps.text = options.laps_text
		result_laps.visible = options.laps_text != ""
	if options.has("record_text"):
		result_record.text = options.record_text
	result_record.visible = result_record.text != ""
	_set_result_buttons(options.get("buttons", "race"))
	# Muitas linhas (8 karts): a tabela fica mais baixa para caber tudo.
	result_rows.add_theme_constant_override("separation", 4 if rows.size() <= 8 else 2)

	results.visible = true
	results.modulate.a = 0.0
	result_buttons.modulate.a = 0.0
	result_record.modulate.a = 0.0
	result_laps.modulate.a = 0.0
	for row in rows:
		row.set("slide", 700.0)
	var mat := results_checker.material as ShaderMaterial
	var tw := create_tween()
	tw.tween_interval(1.5)
	tw.tween_property(results, "modulate:a", 1.0, 0.2)
	if mat:
		mat.set_shader_parameter("reveal", 0.0)
		tw.tween_method(func(v: float): mat.set_shader_parameter("reveal", v), 0.0, 1.0, 0.45) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var row_time := 0.28 if rows.size() <= 4 else 0.16
	for row in rows:
		tw.tween_property(row, "slide", 0.0, row_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_callback(Sfx.play.bind(self, &"ui_move", -14.0))
	tw.tween_property(result_laps, "modulate:a", 1.0, 0.2)
	tw.tween_property(result_record, "modulate:a", 1.0, 0.2)
	tw.tween_property(result_buttons, "modulate:a", 1.0, 0.25)
	tw.tween_callback(_focus_first_button)


## Botões da tela de resultado: corrida avulsa, meio da copa ou fim da copa.
func _set_result_buttons(kind: String) -> void:
	var in_cup := kind == "gp_next" or kind == "gp_final"
	_next_button.visible = in_cup
	_next_button.text = "Nova copa" if kind == "gp_final" else "Próxima corrida"
	_next_button.icon_kind = "retry" if kind == "gp_final" else "next"
	again_button.visible = not in_cup
	change_character_button.visible = not in_cup
	change_kart_button.visible = not in_cup
	change_track_button.visible = kind != "gp_next"
	change_track_button.text = "Trocar copa" if in_cup else "Trocar pista"


func _focus_first_button() -> void:
	for b in result_buttons.get_children():
		if b is Control and b.visible:
			(b as Control).grab_focus()
			return
