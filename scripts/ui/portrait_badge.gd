class_name PortraitBadge
extends Control
## Retrato redondo do piloto (HUD). O rosto imita as expressões do piloto na corrida.
## O desenho não precisa ser refeito a cada quadro: o polígono usa a textura da
## SubViewport do retrato, que se atualiza sozinha.

var portrait: CharacterPortrait
var label := ""


func setup(data: CharacterData) -> void:
	if data == null or data.model_scene == null:
		return
	label = data.display_name.to_upper()
	portrait = CharacterPortrait.new()
	add_child(portrait)
	# 24 quadros por segundo bastam para as piscadas e expressões do selo.
	portrait.setup(data, 192, 24.0)
	queue_redraw()


## Liga o retrato às expressões do piloto.
func follow(driver: CharacterRig) -> void:
	if driver and portrait and portrait.rig:
		driver.face_changed.connect(func(face: StringName): portrait.rig.set_face(face, 0.0))


func _draw() -> void:
	var r := minf(size.x, size.y) * 0.5
	var c := Vector2(size.x * 0.5, r)
	draw_circle(c + Vector2(0, 5), r, Color(0, 0, 0, 0.3))
	draw_circle(c, r, Color.WHITE)
	draw_circle(c, r - 5.0, UiKit.BLUE.lightened(0.15))
	draw_circle(c + Vector2(0, -r * 0.3), r * 0.55, Color(1, 1, 1, 0.12))
	if portrait:
		var pts := PackedVector2Array()
		var uvs := PackedVector2Array()
		var inner := r - 5.0
		for i in 48:
			var a := TAU * i / 48.0
			var d := Vector2.from_angle(a)
			pts.append(c + d * inner)
			uvs.append(Vector2(0.5, 0.5) + d * 0.5 * (inner / r) * 1.04)
		draw_polygon(pts, PackedColorArray([Color.WHITE]), uvs, portrait.get_texture())
	draw_arc(c, r - 2.5, 0.0, TAU, 48, Color.WHITE, 5.0, true)
