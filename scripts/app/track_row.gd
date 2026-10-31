## One track in the list: shown or hidden, its icon (picked from its name
## and instrument, or chosen), its color, its name, how far in front it sits
## (depth), the note shape, and staccato. Changes show at once.
class_name TrackRow
extends PanelContainer

var app
var track: Song.Track
var tl: Look.TrackLook
var index := 0
var _icon: IconView
var _picker: PopupPanel

func setup(the_app, t: Song.Track, look: Look.TrackLook, i := 0) -> void:
	app = the_app
	track = t
	tl = look
	index = i
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
	row.add_theme_constant_override("separation", 6)
	v.add_child(row)
	var eye := CheckBox.new()
	eye.button_pressed = tl.visible
	eye.tooltip_text = "Show this track"
	eye.toggled.connect(func(on): tl.visible = on; app._changed())
	row.add_child(eye)
	_icon = IconView.new(30.0)
	_icon.kind = _current_icon()
	_icon.tint = tl.color
	_icon.tooltip_text = "Instrument icon (click to change)"
	_icon.clicked.connect(_open_picker)
	row.add_child(_icon)
	var color := ColorPickerButton.new()
	color.color = tl.color
	color.custom_minimum_size = Vector2(34, 26)
	color.edit_alpha = false
	color.color_changed.connect(func(c): tl.color = c; _icon.tint = c; app._changed())
	row.add_child(color)
	var name := Label.new()
	name.text = track.name
	name.tooltip_text = "%s · %d notes" % [track.name, track.notes.size()]
	name.size_flags_horizontal = SIZE_EXPAND_FILL
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name.clip_text = true
	row.add_child(name)
	var up := Button.new()
	up.text = "▲"
	up.tooltip_text = "Move this track up"
	up.disabled = i == 0
	up.pressed.connect(func(): app.move_track(index, -1))
	row.add_child(up)
	var down := Button.new()
	down.text = "▼"
	down.tooltip_text = "Move this track down"
	down.disabled = i == app.song.tracks.size() - 1
	down.pressed.connect(func(): app.move_track(index, 1))
	row.add_child(down)
	var edit := Button.new()
	edit.text = "Edit"
	edit.tooltip_text = "Edit this track's notes"
	edit.pressed.connect(func(): app.edit_track(index))
	row.add_child(edit)

	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 6)
	v.add_child(row2)
	var depth := SpinBox.new()
	depth.min_value = 0.1
	depth.max_value = 4.0
	depth.step = 0.02
	depth.value = tl.parallax
	depth.suffix = "× depth"
	depth.tooltip_text = "How fast this track moves (more: nearer, drawn in front)"
	depth.value_changed.connect(func(x): tl.parallax = x; app._changed())
	row2.add_child(depth)
	var shape := OptionButton.new()
	for s in ["Pill", "Soft", "Sharp"]:
		shape.add_item(s)
	shape.selected = tl.shape
	shape.tooltip_text = "Note shape"
	shape.item_selected.connect(func(s): tl.shape = s; app._changed())
	row2.add_child(shape)
	var stacc := CheckBox.new()
	stacc.text = "Dots"
	stacc.button_pressed = tl.staccato
	stacc.tooltip_text = "Short dots instead of long notes (staccato)"
	stacc.toggled.connect(func(on): tl.staccato = on; app._changed())
	row2.add_child(stacc)

func _current_icon() -> String:
	return tl.icon if tl.icon != "" else Icons.guess(track.name, track.program)

func _open_picker() -> void:
	if _picker:
		_picker.queue_free()
	_picker = PopupPanel.new()
	add_child(_picker)
	var holder := VBoxContainer.new()
	_picker.add_child(holder)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	holder.add_child(grid)
	for k in Icons.NAMES:
		var iv := IconView.new(40.0)
		iv.kind = k
		iv.tint = tl.color
		iv.selected = k == _current_icon()
		iv.tooltip_text = k.capitalize()
		iv.clicked.connect(func(): _choose(k))
		grid.add_child(iv)
	var auto := Button.new()
	auto.text = "Automatic"
	auto.tooltip_text = "Pick from the track's name and instrument"
	auto.pressed.connect(func(): _choose(""))
	holder.add_child(auto)
	_picker.popup(Rect2i(Vector2i(_icon.get_screen_position()) + Vector2i(0, 36), Vector2i.ZERO))

func _choose(kind: String) -> void:
	tl.icon = kind
	_icon.kind = _current_icon()
	_picker.hide()
	app._changed()

func refresh_color() -> void:
	_icon.tint = tl.color
