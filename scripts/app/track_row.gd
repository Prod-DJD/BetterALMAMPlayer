## One track in the list: shown or hidden, its color, its name, how far in
## front it sits (depth), its note and "note on" images, staccato, and
## "own colors" (images drawn as they are). Changes show at once.
class_name TrackRow
extends PanelContainer

var app
var track: Song.Track
var tl: Look.TrackLook
var _note_btn: Button
var _effect_btn: Button

func setup(the_app, t: Song.Track, look: Look.TrackLook) -> void:
	app = the_app
	track = t
	tl = look
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("332e29")
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	add_child(v)

	var row := HBoxContainer.new()
	v.add_child(row)
	var eye := CheckBox.new()
	eye.button_pressed = tl.visible
	eye.tooltip_text = "Show this track"
	eye.toggled.connect(func(on): tl.visible = on; app._changed())
	row.add_child(eye)
	var color := ColorPickerButton.new()
	color.color = tl.color
	color.custom_minimum_size = Vector2(34, 26)
	color.edit_alpha = false
	color.color_changed.connect(func(c): tl.color = c; _refresh_pics(); app._changed())
	row.add_child(color)
	var name := Label.new()
	name.text = t.name
	name.tooltip_text = "%s · %d notes" % [t.name, t.notes.size()]
	name.size_flags_horizontal = SIZE_EXPAND_FILL
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name.clip_text = true
	row.add_child(name)
	var depth := SpinBox.new()
	depth.min_value = 0.1
	depth.max_value = 4.0
	depth.step = 0.02
	depth.value = tl.parallax
	depth.suffix = "×"
	depth.tooltip_text = "Depth: how fast this track moves (more: nearer, drawn in front)"
	depth.value_changed.connect(func(x): tl.parallax = x; app._changed())
	row.add_child(depth)

	var row2 := HBoxContainer.new()
	v.add_child(row2)
	_note_btn = _image_button("Note", "Note image (click to choose, right-click for the default; or drop a picture on this track)", "note_texture", Look.DEFAULT_NOTE)
	row2.add_child(_note_btn)
	_effect_btn = _image_button("Note on", "\"Note on\" image, shown as each note plays (right-click: default)", "effect_texture", Look.DEFAULT_EFFECT)
	row2.add_child(_effect_btn)
	var stacc := CheckBox.new()
	stacc.text = "Staccato"
	stacc.button_pressed = tl.staccato
	stacc.tooltip_text = "Short dots instead of long notes"
	stacc.toggled.connect(func(on): tl.staccato = on; app._changed())
	row2.add_child(stacc)
	var plain := CheckBox.new()
	plain.text = "Own colors"
	plain.button_pressed = tl.plain
	plain.tooltip_text = "Draw the images in their own colors"
	plain.toggled.connect(func(on): tl.plain = on; _refresh_pics(); app._changed())
	row2.add_child(plain)

func _image_button(label: String, tip: String, field: String, default: String) -> Button:
	var b := Button.new()
	b.tooltip_text = tip
	b.custom_minimum_size = Vector2(96, 30)
	var h := HBoxContainer.new()
	h.set_anchors_preset(PRESET_FULL_RECT)
	h.mouse_filter = MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", 6)
	b.add_child(h)
	var pic := TextureRect.new()
	pic.name = "Pic"
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.custom_minimum_size = Vector2(30, 22)
	pic.size_flags_vertical = SIZE_SHRINK_CENTER
	pic.mouse_filter = MOUSE_FILTER_IGNORE
	pic.texture = app.vis.texture(tl.get(field))
	pic.self_modulate = Color.WHITE if tl.plain else tl.color
	h.add_child(pic)
	var l := Label.new()
	l.text = label
	l.mouse_filter = MOUSE_FILTER_IGNORE
	h.add_child(l)
	b.pressed.connect(func(): app._pick_image(func(p): _set_image(field, p)))
	b.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_RIGHT:
			_set_image(field, default))
	return b

func _refresh_pics() -> void:
	for b in [_note_btn, _effect_btn]:
		var pic: TextureRect = b.find_child("Pic", true, false)
		pic.texture = app.vis.texture(tl.note_texture if b == _note_btn else tl.effect_texture)
		pic.self_modulate = Color.WHITE if tl.plain else tl.color

func _set_image(field: String, path: String) -> void:
	tl.set(field, path)
	_refresh_pics()
	app._changed(true)

## A picture dropped on this track: its note image (or "note on" image, if
## dropped over that button).
func drop_image(path: String) -> void:
	var over_effect := _effect_btn.get_global_rect().has_point(get_global_mouse_position())
	_set_image("effect_texture" if over_effect else "note_texture", path)
