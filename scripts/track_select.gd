extends Node3D
## Tela de seleção de pista: a pista escolhida aparece ao fundo num sobrevoo de
## câmera, com as copas (a Copa Ativos traz o logo "at"), os cartões das pistas,
## o mapa do traçado, os recordes e o botão para correr. Vagas sem pista ainda
## aparecem como "?" (em breve).
## No Grand Prix a escolha é da copa: dá para olhar cada pista, e "Começar copa"
## corre todas em sequência, a partir da primeira.

const COLUMNS := 2
const CAPTIONS := {
	"length": "EXTENSÃO",
	"laps": "VOLTAS",
	"turns": "CURVAS",
	"difficulty": "DIFICULDADE",
	"record": "RECORDE",
	"lap": "MELHOR VOLTA",
}

@onready var camera: Camera3D = $Camera
@onready var cups_row: HBoxContainer = %Cups
@onready var cup_ribbon: RibbonLabel = %CupRibbon
@onready var grid: GridContainer = %Grid
@onready var info_panel: Control = %InfoPanel
@onready var track_name_label: Label = %TrackName
@onready var subtitle_label: Label = %TrackSubtitle
@onready var preview: TrackPreview = %Preview
@onready var stats_grid: GridContainer = %Stats
@onready var description_label: Label = %Description
@onready var back_button: FancyButton = %BackButton
@onready var race_button: FancyButton = %RaceButton
@onready var toast: Label = %Toast

var index := 0
var _slots: Array[TrackData] = []
var _cards: Array[TrackCard] = []
var _cups: Array[CupBadge] = []
## Pista que aparece ao fundo agora e a escolhida (que pode ainda estar sendo
## gerada; até lá a anterior continua no fundo).
var _track: Track
var _track_data: TrackData
var _wanted: TrackData
var _builder: TrackBuilder
## Foto do cartão sendo tirada (a câmera extra vê a pista que estiver ao fundo).
var _photo_vp: SubViewport
var _photo_data: TrackData
var _thumbs := {}
var _stat_values := {}
var _stars: StarRating
var _nav_cooldown := 0.0
var _confirming := false
var _toast_tween: Tween
var _fly := 0.0
var _time := 0.0
var _look := Vector3.ZERO
var _snap_camera := true


func _ready() -> void:
	_builder = GameState.track_builder
	_builder.track_built.connect(_on_track_built)
	_build_slots()
	_build_cups()
	_build_cards()
	_build_stats()
	back_button.pressed.connect(_back)
	race_button.pressed.connect(_confirm)
	toast.modulate.a = 0.0
	if _is_cup_mode():
		($UI/Root/Header as RibbonLabel).text = "ESCOLHA A COPA"
		race_button.text = "Começar copa"
	index = clampi(GameState.selected_track_index, 0, _slots.size() - 1)
	_select(index, true)
	race_button.grab_focus()
	_animate_intro()


func _is_cup_mode() -> bool:
	return GameState.mode == GameState.Mode.GRAND_PRIX


func _exit_tree() -> void:
	# As pistas guardadas fora da árvore não são liberadas junto com a tela.
	_builder.clear()


# --- Montagem ---------------------------------------------------------------------

func _build_slots() -> void:
	_slots.assign(GameState.tracks)
	while _slots.size() < GameState.track_slots:
		var placeholder := TrackData.new()
		placeholder.display_name = "???"
		placeholder.cup_name = _slots[0].cup_name if not _slots.is_empty() else "Copa Ativos"
		placeholder.locked = true
		_slots.append(placeholder)


func _build_cups() -> void:
	var names: Array[String] = []
	for t in GameState.tracks:
		if not names.has(t.cup_name):
			names.append(t.cup_name)
	for i in maxi(GameState.cup_slots, names.size()):
		var badge := CupBadge.new()
		var unlocked := i < names.size()
		badge.setup(names[i] if unlocked else "???", unlocked)
		badge.selected = i == 0
		badge.pressed.connect(_on_cup_pressed.bind(i))
		cups_row.add_child(badge)
		_cups.append(badge)
	cup_ribbon.text = (names[0] if not names.is_empty() else "Copa").to_upper()


func _build_cards() -> void:
	grid.columns = COLUMNS
	for i in _slots.size():
		var card := TrackCard.new()
		card.setup(_slots[i])
		# Fotos tiradas numa visita anterior a esta tela.
		var cached: Texture2D = GameState.track_thumbnails.get(_slots[i].id)
		if _slots[i].is_unlocked() and cached:
			_thumbs[_slots[i]] = cached
			card.thumbnail = cached
		card.pressed.connect(_on_card_pressed.bind(i))
		grid.add_child(card)
		_cards.append(card)


func _build_stats() -> void:
	for key: String in CAPTIONS:
		var cell := VBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_theme_constant_override("separation", -2)
		var caption := Label.new()
		caption.theme_type_variation = &"PanelSoft"
		caption.add_theme_font_size_override("font_size", 13)
		caption.text = CAPTIONS[key]
		cell.add_child(caption)
		if key == "difficulty":
			_stars = StarRating.new()
			_stars.custom_minimum_size = Vector2(124, 30)
			cell.add_child(_stars)
		else:
			var value := Label.new()
			value.theme_type_variation = &"PanelLabel"
			value.add_theme_font_override("font", UiKit.FONT_TITLE)
			value.add_theme_font_size_override("font_size", 25)
			cell.add_child(value)
			_stat_values[key] = value
		stats_grid.add_child(cell)


# --- Sobrevoo da pista ao fundo -------------------------------------------------------

func _process(delta: float) -> void:
	_nav_cooldown -= delta
	_time += delta
	if not is_instance_valid(_track) or _track.length <= 0.0:
		return
	_fly += delta * 22.0
	var t := _track.global_transform
	var p := t * _track.get_point_at(_fly)
	var ahead := t * _track.get_point_at(_fly + 55.0)
	var dir := (ahead - p).normalized()
	var right := dir.cross(Vector3.UP).normalized()
	var wanted := p + right * 24.0 - dir * 12.0 + Vector3.UP * (22.0 + sin(_time * 0.3) * 6.0)
	var look := ahead + Vector3.UP * 2.0
	if _snap_camera:
		_snap_camera = false
		camera.global_position = wanted
		_look = look
	else:
		camera.global_position = camera.global_position.lerp(wanted, 1.0 - exp(-1.6 * delta))
		_look = _look.lerp(look, 1.0 - exp(-2.2 * delta))
	camera.look_at(_look, Vector3.UP)


## Gerar uma pista trava o jogo por 0,2–0,6 s, então só a primeira é gerada aqui
## (a tela ainda está escura, no fade). As outras são geradas numa thread
## (TrackBuilder), começando pela escolhida e pelas vizinhas, e ficam guardadas:
## trocar de pista só tira uma da árvore e põe a outra.
func _show_track(data: TrackData, now := false) -> void:
	_wanted = data
	if now:
		_builder.build_now(data)
	if _builder.is_built(data):
		_put_track(data)
	var order: Array[TrackData] = [data]
	for k in range(1, _slots.size()):
		for i: int in [index + k, index - k]:
			var other := _slots[wrapi(i, 0, _slots.size())]
			if not order.has(other):
				order.append(other)
	_builder.request(order)


func _on_track_built(data: TrackData) -> void:
	if data == _wanted:
		_put_track(data)


func _put_track(data: TrackData) -> void:
	if data == _track_data and is_instance_valid(_track):
		return
	_cancel_photo()
	if is_instance_valid(_track):
		remove_child(_track)
	_track_data = data
	_track = _builder.get_track(data)
	_track.name = "Pista"
	add_child(_track)
	move_child(_track, 0)
	_fly = 0.0
	_snap_camera = true
	if not _thumbs.has(data):
		_make_thumbnail(data)


## "Foto" da pista para o cartão: uma câmera extra olha a largada uma vez só.
func _make_thumbnail(data: TrackData) -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(448, 300)
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var cam := Camera3D.new()
	cam.fov = 52.0
	vp.add_child(cam)
	var t := _track.global_transform
	cam.global_position = (t * _track.get_transform_at(-38.0, -4.5)).origin + Vector3.UP * 3.4
	cam.look_at(t * _track.get_point_at(6.0) + Vector3.UP * 3.6, Vector3.UP)
	cam.current = true
	_set_thumbnail(data, vp.get_texture())
	_photo_vp = vp
	_photo_data = data
	await get_tree().create_timer(0.8).timeout
	if not is_instance_valid(vp) or vp != _photo_vp:
		return
	_photo_vp = null
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	# Guarda uma cópia para a próxima vez que a tela abrir.
	var img := vp.get_texture().get_image()
	if img and not img.is_empty():
		GameState.track_thumbnails[data.id] = ImageTexture.create_from_image(img)


## Trocou de pista antes da foto ficar pronta: a câmera extra já veria a outra
## pista. A foto é tirada de novo na próxima vez que esta pista aparecer.
func _cancel_photo() -> void:
	if not is_instance_valid(_photo_vp):
		return
	_set_thumbnail(_photo_data, null)
	_photo_vp.queue_free()
	_photo_vp = null


func _set_thumbnail(data: TrackData, texture: Texture2D) -> void:
	if texture:
		_thumbs[data] = texture
	else:
		_thumbs.erase(data)
	for card in _cards:
		if card.data == data:
			card.thumbnail = texture


# --- Navegação --------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if _confirming:
		return
	var move := 0
	if event.is_action_pressed("ui_left") or event.is_action_pressed("esquerda"):
		move = -1
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("direita"):
		move = 1
	elif event.is_action_pressed("ui_up"):
		move = -COLUMNS
	elif event.is_action_pressed("ui_down"):
		move = COLUMNS
	if move != 0:
		_move(move)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept") and not back_button.has_focus():
		_confirm()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		_back()
		get_viewport().set_input_as_handled()


func _move(step: int) -> void:
	if _nav_cooldown > 0.0:
		return
	_nav_cooldown = 0.12
	var next := index + step
	if absi(step) == 1:
		next = wrapi(next, 0, _cards.size())
	elif next < 0 or next >= _cards.size():
		return
	Sfx.play(self, &"ui_move", -12.0)
	_select(next, false)


func _on_card_pressed(i: int) -> void:
	if i == index:
		_confirm()
	else:
		Sfx.play(self, &"ui_move", -12.0)
		_select(i, false)


func _on_cup_pressed(i: int) -> void:
	if _cups[i].unlocked:
		return
	_show_toast("Novas copas em breve!")
	Sfx.play(self, &"ui_back", -10.0)
	_shake(_cups[i])


func _select(i: int, first: bool) -> void:
	index = i
	for k in _cards.size():
		_cards[k].selected = k == index
	var data := _slots[index]
	var unlocked := data.is_unlocked()
	if unlocked:
		_show_track(data, first)
	_update_info(data, unlocked, first)
	race_button.disabled = not unlocked
	var card := _cards[index]
	card.pivot_offset = card.size * 0.5
	card.scale = Vector2.ONE * 1.08
	create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(card, "scale", Vector2.ONE, 0.25)


func _update_info(data: TrackData, unlocked: bool, first: bool) -> void:
	track_name_label.text = data.display_name if unlocked else "???"
	var where := "Corrida %d de %d da copa" if _is_cup_mode() else "Pista %d de %d"
	subtitle_label.text = ("%s  •  %s  •  %s" % [data.cup_name, where % [index + 1, _slots.size()],
			GameState.get_speed_class_name()]) if unlocked else "Em breve"
	# O traçado fica pronto na hora, mesmo com a pista ainda sendo gerada.
	var layout := _builder.get_track(data) if unlocked else null
	preview.show_track(layout, UiKit.YELLOW)
	if unlocked:
		_stat_values["length"].text = _format_meters(layout.length)
		_stat_values["laps"].text = str(data.laps)
		_stat_values["turns"].text = str(_count_turns(layout))
		_stat_values["record"].text = GameState.format_time(GameState.get_record(data.id, GameState.record_key("total")))
		_stat_values["lap"].text = GameState.format_time(GameState.get_record(data.id, GameState.record_key("lap")))
		_stars.value = data.difficulty
		description_label.text = data.description
	else:
		for key: String in _stat_values:
			_stat_values[key].text = "–"
		_stars.value = 0
		description_label.text = "Novas pistas chegam em breve. Por enquanto, o %s está pronto para correr!" % GameState.tracks[0].display_name
	if not first:
		info_panel.pivot_offset = info_panel.size * 0.5
		info_panel.scale = Vector2.ONE * 0.97
		create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(info_panel, "scale", Vector2.ONE, 0.22)


func _confirm() -> void:
	if _confirming:
		return
	var data := _slots[index]
	if not data.is_unlocked():
		_show_toast("Essa pista chega em breve!")
		Sfx.play(self, &"ui_back", -10.0)
		_shake(_cards[index])
		return
	_confirming = true
	GameState.selected_track_index = GameState.tracks.find(data)
	GameState.laps = data.laps
	Sfx.play(self, &"go", -10.0)
	if _is_cup_mode():
		GameState.start_grand_prix(data.cup_name)
		_show_toast("%s: %d corridas!" % [data.cup_name, GameState.grand_prix.race_count()])
	else:
		_show_toast("Rumo ao %s!" % data.display_name)
	var card := _cards[index]
	var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	card.scale = Vector2.ONE * 1.15
	tw.tween_property(card, "scale", Vector2.ONE, 0.35)
	await get_tree().create_timer(0.7).timeout
	GameState.goto_scene(GameState.SCENE_RACE)


func _back() -> void:
	if _confirming:
		return
	Sfx.play(self, &"ui_back", -10.0)
	GameState.picking_player = GameState.players.size() - 1
	GameState.goto_scene(GameState.SCENE_KART_SELECT)


# --- Utilidades ---------------------------------------------------------------------

## Quantas curvas a pista tem (trechos com raio menor que ~80 m). Num "S",
## cada lado conta como uma curva.
static func _count_turns(track: Track) -> int:
	var count := track.curvature.size()
	var step := track.length / maxi(count, 1)
	# Começa num trecho reto para não contar a mesma curva duas vezes na emenda.
	var offset := 0
	for i in count:
		if absf(track.curvature[i]) < 0.008:
			offset = i
			break
	var turns := 0
	var side := 0.0
	var run := 0.0
	for k in count:
		var c := track.curvature[(k + offset) % count]
		var s := signf(c) if absf(c) > 0.012 else (side if absf(c) > 0.008 else 0.0)
		if s != side:
			if side != 0.0 and run > 6.0:
				turns += 1
			side = s
			run = 0.0
		run += step
	if side != 0.0 and run > 6.0:
		turns += 1
	return turns


static func _format_meters(meters: float) -> String:
	var digits := str(int(round(meters)))
	var out := ""
	for i in digits.length():
		if i > 0 and (digits.length() - i) % 3 == 0:
			out += "."
		out += digits[i]
	return out + " m"


func _animate_intro() -> void:
	await get_tree().process_frame
	var delay := 0.05
	for card in _cards:
		card.pivot_offset = card.size * 0.5
		card.scale = Vector2.ONE * 0.5
		card.modulate.a = 0.0
		var tw := create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(card, "scale", Vector2.ONE, 0.35).set_delay(delay)
		tw.tween_property(card, "modulate:a", 1.0, 0.2).set_delay(delay)
		delay += 0.06
	for badge in _cups:
		badge.pivot_offset = badge.size * 0.5
		badge.scale = Vector2.ZERO
		create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(badge, "scale", Vector2.ONE, 0.3).set_delay(delay * 0.5)
		delay += 0.04
	var x := info_panel.position.x
	info_panel.position.x = x + 560.0
	create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(info_panel, "position:x", x, 0.45)


func _shake(control: Control) -> void:
	var x := control.position.x
	var tw := create_tween().set_trans(Tween.TRANS_SINE)
	for i in 3:
		tw.tween_property(control, "position:x", x + 7.0, 0.04)
		tw.tween_property(control, "position:x", x - 7.0, 0.04)
	tw.tween_property(control, "position:x", x, 0.04)


func _show_toast(text: String) -> void:
	toast.text = text
	if _toast_tween:
		_toast_tween.kill()
	toast.pivot_offset = toast.size * 0.5
	toast.scale = Vector2.ONE * 1.25
	_toast_tween = create_tween()
	_toast_tween.set_parallel()
	_toast_tween.tween_property(toast, "modulate:a", 1.0, 0.12)
	_toast_tween.tween_property(toast, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_toast_tween.chain().tween_interval(1.3)
	_toast_tween.chain().tween_property(toast, "modulate:a", 0.0, 0.4)
