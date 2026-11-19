class_name Hud
extends CanvasLayer
## Interface da corrida: mini-mapa com todos os karts, moedas e volta (pílulas no canto
## inferior esquerdo), posição (canto inferior direito), semáforo de largada, mensagens e
## a tela de resultado com a classificação.
##
## A tela do piloto fica limpa: o canto superior esquerdo só mostra o slot do item
## (ItemSlot, com a roleta) enquanto há item — vazio, some — e o tempo (canto superior
## direito) só aparece quando ele cruza a chegada, menos no contra-relógio, em que o
## relógio é o objetivo. Na tela dividida fica a etiqueta "J2" no alto, com o slot ao lado.
## Os itens também mostram aqui a tinta do Juridiquês (InkOverlay, embaixo do resto do
## HUD), o contrato da Cessão de crédito (ContractCard) e o clarão do raio do Deságio.
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

@onready var driver_name: Label = %DriverName
@onready var track_name: Label = %TrackName
@onready var place_badge: PlaceBadge = %PlaceBadge
@onready var result_laps: Label = %ResultLaps
@onready var time_value: Label = %TimeValue
@onready var lap_times_label: Label = %LapTimes
@onready var best_label: Label = %BestLabel
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

var kart: Kart
var layout := Layout.FULL
## Canto inferior esquerdo: moedas Ativos e volta, cada uma numa pílula escura.
var status_box: HBoxContainer
var coin_pill: HudPill
var lap_pill: HudPill
## Canto superior esquerdo: o item guardado (roleta ao pegar uma caixa).
var item_slot: ItemSlot
var contract_card: ContractCard
var ink_overlay: InkOverlay
## Aviso de item vindo atrás do jogador (PEC dos Precatórios, Intimação).
var alert: ItemAlert
var _flash: ColorRect
var _flash_tween: Tween
var _coins := -1
var _max_coins := 10
## O relógio aparece durante a corrida (contra-relógio) ou só na chegada.
var _clock_always := false
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
	status_box = HBoxContainer.new()
	status_box.name = "StatusBox"
	status_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_box.add_theme_constant_override("separation", 12)
	coin_pill = HudPill.new(HudPill.Icon.COIN)
	lap_pill = HudPill.new(HudPill.Icon.FLAG)
	status_box.add_child(coin_pill)
	status_box.add_child(lap_pill)
	$Root.add_child(status_box)
	$Root.move_child(status_box, place_badge.get_index())
	status_box.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	status_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_set_offsets(status_box, 28.0, -82.0, 28.0, -24.0)
	# Posição no canto inferior direito.
	place_badge.align_right = true
	place_badge.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	place_badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_set_offsets(place_badge, -300.0, -146.0, -28.0, -24.0)
	_build_item_widgets(100.0, Vector2(26.0, 22.0))


## Itens: a tinta (embaixo de tudo), o clarão do raio, o slot e o contrato.
func _build_item_widgets(slot_size: float, slot_pos: Vector2) -> void:
	var root := $Root as Control
	ink_overlay = InkOverlay.new()
	ink_overlay.name = "Tinta"
	root.add_child(ink_overlay)
	root.move_child(ink_overlay, 0)
	ink_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash = ColorRect.new()
	_flash.name = "Clarao"
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.color = Color(1, 1, 1, 0)
	_flash.visible = false
	root.add_child(_flash)
	root.move_child(_flash, 1)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	item_slot = ItemSlot.new(slot_size)
	item_slot.name = "SlotItem"
	item_slot.position = slot_pos
	root.add_child(item_slot)
	root.move_child(item_slot, results.get_index())
	contract_card = ContractCard.new()
	contract_card.name = "Contrato"
	root.add_child(contract_card)
	root.move_child(contract_card, results.get_index())
	contract_card.set_home(slot_pos + Vector2(slot_size + 16.0, 0.0))
	alert = ItemAlert.new()
	alert.name = "AvisoItem"
	root.add_child(alert)
	root.move_child(alert, results.get_index())
	_place_alert(22.0)


## Aviso de item no alto, no meio da tela, a `top` px da borda.
func _place_alert(top: float) -> void:
	alert.set_anchors_preset(Control.PRESET_CENTER_TOP)
	var w := alert.custom_minimum_size.x
	_set_offsets(alert, -w * 0.5, top, w * 0.5, top + alert.custom_minimum_size.y)


## `karts` = todos os karts da corrida (para o mini-mapa), incluindo `p_kart`.
## Na tela dividida, `slot` = o jogador dono deste HUD (Layout.PLAYER).
func setup(track: Track, p_kart: Kart, karts: Array[Kart], laps: int, best_total: float, best_lap: float,
		p_layout := Layout.FULL, slot: PlayerSlot = null) -> void:
	layout = p_layout
	if layout == Layout.OVERLAY:
		_setup_overlay(track, karts)
		return
	kart = p_kart
	_max_coins = Kart.MAX_COINS
	_coins = -1
	set_coins(p_kart.coins, false)
	_clock_always = GameState.mode == GameState.Mode.TIME_TRIAL
	time_panel.visible = _clock_always
	best_label.visible = _clock_always and layout == Layout.FULL
	track_name.text = track.track_name
	place_badge.visible = karts.size() > 1
	minimap.setup(track, karts, p_kart)
	if layout == Layout.PLAYER:
		_setup_compact(slot)
	else:
		# Canto superior esquerdo vazio: sem nome do piloto nem da pista.
		driver_name.hide()
		track_name.hide()
		# A dica da largada mostra a tecla de drift atual (dá para trocar nas opções).
		var drift_keys := GameState.settings.key_labels(&"drift")
		var hint_label := hint_pill.get_node_or_null("HintLabel") as Label
		if hint_label and not drift_keys.is_empty():
			hint_label.text = "Dica: segure %s + direção nas curvas para derrapar e soltar um turbo!" % drift_keys[0].to_upper()
	set_lap(1, laps, false)
	set_time(0.0)
	lap_times_label.text = ""
	best_label.text = "RECORDE  %s   •   VOLTA  %s" % [GameState.format_time(best_total), GameState.format_time(best_lap)]
	start_lights.step = 0


## HUD de um jogador na tela dividida: mapa pequeno, números menores e a etiqueta "J2"
## na cor do jogador no lugar do nome.
func _setup_compact(slot: PlayerSlot) -> void:
	track_name.hide()
	best_label.hide()
	lap_times_label.hide()
	hint_pill.hide()
	# Mapa pequeno no meio da direita (o do jogador fica por cima dos outros).
	_set_offsets(map_panel, -184.0, -150.0, -18.0, 16.0)
	driver_name.text = slot.tag if slot else ""
	driver_name.add_theme_color_override("font_color", slot.color if slot else Color.WHITE)
	driver_name.add_theme_font_size_override("font_size", 40)
	driver_name.position = Vector2(24.0, 14.0)
	# Slot do item menor, ao lado da etiqueta "J2"; contrato e tinta menores também.
	_rebuild_item_slot(78.0, Vector2(88.0, 12.0))
	ink_overlay.text_size = 9
	# Aviso menor, abaixo da contagem do fim da corrida.
	alert.radius = 34.0
	_place_alert(58.0)
	_set_offsets(place_badge, -230.0, -110.0, -20.0, -14.0)
	coin_pill.height = 46.0
	lap_pill.height = 46.0
	status_box.add_theme_constant_override("separation", 10)
	_set_offsets(status_box, 20.0, -62.0, 20.0, -16.0)
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


## Troca o slot do item por um do tamanho `slot_size` em `slot_pos` (HUD compacto).
func _rebuild_item_slot(slot_size: float, slot_pos: Vector2) -> void:
	var root := $Root as Control
	var index := item_slot.get_index()
	var key := item_slot.key_text
	root.remove_child(item_slot)
	item_slot.queue_free()
	item_slot = ItemSlot.new(slot_size)
	item_slot.name = "SlotItem"
	item_slot.position = slot_pos
	item_slot.key_text = key
	root.add_child(item_slot)
	root.move_child(item_slot, index)
	contract_card.card_scale = 0.8
	contract_card.set_home(slot_pos + Vector2(slot_size + 10.0, -8.0))


# --- Itens --------------------------------------------------------------------------

## A roleta do slot gira e para em `kind` depois de `duration` s.
func roll_item(kind: int, duration: float) -> void:
	item_slot.roll(kind, duration)


## O jogador usou o item guardado.
func use_item() -> void:
	item_slot.use()


## Antecipação Celer: o slot fica com a maleta e um anel de tempo de `duration` s.
func item_timer(kind: int, duration: float) -> void:
	item_slot.start_timer(kind, duration)


## Um toque no item que está em uso (jato da Antecipação Celer).
func item_pulse() -> void:
	item_slot.pulse()


## Um rival levou o item do jogador (Cessão de crédito).
func item_stolen() -> void:
	item_slot.stolen()


## Cessão de crédito do jogador: o contrato é assinado e o item cai no slot.
func receive_item(kind: int, from_name: String, to_name: String, duration: float) -> void:
	item_slot.receive(kind, duration)
	var target := contract_card.get_parent_control().get_global_transform().affine_inverse() * item_slot.get_box_center()
	contract_card.play(kind, from_name, to_name, duration, target)


## Tecla (ou botão) de usar o item, no canto do slot.
func set_item_key(text: String) -> void:
	item_slot.key_text = text


## O perigo de `kind` passou (a Liminar suspendeu a PEC): o aviso do alto fica verde
## com `text` um instante.
func item_resolved(kind: int, text: String) -> void:
	if alert:
		alert.show_resolved(kind, text)


## Um item vem atrás do jogador (`kind`: PEC dos Precatórios ou Intimação;
## RaceItem.NONE esconde o aviso).
func item_alert(kind: int) -> void:
	if alert:
		alert.show_alert(kind)


## Juridiquês: tinta na tela por `duration` s.
func show_ink(duration: float) -> void:
	ink_overlay.splat(duration)


## Clarão na tela (raio do Deságio): pisca duas vezes e some.
func flash(color: Color, strength := 0.6) -> void:
	if _flash == null:
		return
	if _flash_tween:
		_flash_tween.kill()
	_flash.visible = true
	_flash.color = Color(color, strength)
	_flash_tween = create_tween()
	_flash_tween.tween_property(_flash, "color:a", strength * 0.15, 0.08)
	_flash_tween.tween_property(_flash, "color:a", strength * 0.7, 0.05)
	_flash_tween.tween_property(_flash, "color:a", 0.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_flash_tween.tween_callback(_flash.hide)


## Tira tudo dos itens da tela (fim da corrida).
func clear_items() -> void:
	if item_slot:
		item_slot.clear()
	if contract_card:
		contract_card.clear()
	if ink_overlay:
		ink_overlay.clear()
	if alert:
		alert.show_alert(RaceItem.NONE)


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
	if _message_time > 0.0:
		_message_time -= delta
		message_label.modulate.a = 0.55 + 0.45 * absf(sin(Time.get_ticks_msec() * 0.008))


func set_lap(current: int, total: int, animate := true) -> void:
	if lap_pill.set_text("%d/%d" % [clampi(current, 1, total), total]) and animate:
		lap_pill.bump(1.3)


func set_time(t: float) -> void:
	time_value.text = GameState.format_time(t)


## Chegada: o painel do tempo (com as voltas) entra no canto superior direito.
func show_final_time() -> void:
	if layout == Layout.OVERLAY or (time_panel.visible and time_panel.modulate.a >= 1.0):
		return
	time_panel.visible = true
	best_label.visible = layout == Layout.FULL
	for c: Control in [time_panel, best_label]:
		c.modulate.a = 0.0
	var x := time_panel.position.x
	time_panel.position.x = x + 80.0
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(time_panel, "position:x", x, 0.4)
	tw.tween_property(time_panel, "modulate:a", 1.0, 0.25)
	tw.tween_property(best_label, "modulate:a", 1.0, 0.25).set_delay(0.15)


## Posição do jogador (chame a cada quadro; o selo só muda quando estabiliza).
func set_place(place: int, total: int) -> void:
	place_badge.set_place(place, total)


## Moedas do jogador (pula ao ganhar, pisca ao perder; no máximo o número fica laranja).
func set_coins(value: int, animate := true) -> void:
	if value == _coins:
		return
	var gained := value > _coins
	_coins = value
	var full := value >= _max_coins
	coin_pill.set_text(str(value), UiKit.ORANGE if full else UiKit.YELLOW, Color(0.32, 0.16, 0.0, 0.85))
	if animate:
		if gained:
			coin_pill.bump()
		else:
			coin_pill.flash()


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
	status_box.visible = false
	clear_items()
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
