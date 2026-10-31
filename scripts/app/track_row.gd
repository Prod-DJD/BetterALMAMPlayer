## One track in the list: shown or hidden, its icon (picked from its name
## and instrument, or chosen), its color, its name, how fast it moves (depth),
## the note shape, and staccato. Its place in the list sets whether it is in
## front of the tracks below it. Changes show at once.
class_name TrackRow
extends PanelContainer

var app
var track: Song.Track
var tl: Look.TrackLook
var index := 0
var _icon: IconView
var _picker: PopupPanel
var _sb: StyleBoxFlat
var _name_label: Label

func setup(the_app, t: Song.Track, look: Look.TrackLook, i := 0) -> void:
	app = the_app
	track = t
	tl = look
	index = i
	var sb := StyleBoxFlat.new()
	_sb = sb
	sb.bg_color = Color("332e29")
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	sb.border_color = Color("f7b955")
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
	name.tooltip_text += "\nDouble-click to rename"
	_name_label = name
	row.add_child(name)
	var more := MenuButton.new()
	more.text = "⋯"
	more.flat = false
	more.tooltip_text = "Rename, split drums into parts, remove"
	more.about_to_popup.connect(func(): _fill_menu(more.get_popup()))
	more.get_popup().id_pressed.connect(_menu_chosen)
	row.add_child(more)
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
	depth.tooltip_text = "How fast this track moves. Who is in front follows the list: the top track is in front"
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

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.double_click and e.button_index == MOUSE_BUTTON_LEFT \
			and _name_label.get_global_rect().has_point(get_global_mouse_position()):
		app.ask_rename(index)

## Hold a track and drag it up or down the list: the whole row comes along.
func _get_drag_data(at: Vector2) -> Variant:
	set_drag_preview(_row_picture(at))
	return {"track_row": index}

## A picture of this row as it looks now, held at the spot it was grabbed.
func _row_picture(at: Vector2) -> Control:
	var holder := Control.new()
	var shown: Control = null
	var img := get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		var ratio := float(img.get_width()) / get_viewport().get_visible_rect().size.x
		var r := Rect2i(Vector2i(get_global_rect().position * ratio), Vector2i(size * ratio))
		r = r.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
		if r.size.x > 0 and r.size.y > 0:
			var pic := TextureRect.new()
			pic.texture = ImageTexture.create_from_image(img.get_region(r))
			pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			pic.stretch_mode = TextureRect.STRETCH_SCALE
			pic.size = size
			pic.modulate = Color(1, 1, 1, 0.92)
			shown = pic
	if shown == null: # no picture to take (nothing drawn yet): the name will do
		var panel := PanelContainer.new()
		var l := Label.new()
		l.text = "  " + track.name + "  "
		panel.add_child(l)
		shown = panel
	shown.position = -at
	holder.add_child(shown)
	return holder

func _can_drop_data(at: Vector2, data: Variant) -> bool:
	var ok: bool = data is Dictionary and data.has("track_row") and data["track_row"] != index
	if ok:
		app.show_drop_hint(self, -1 if at.y < size.y / 2.0 else 1)
	return ok

func _drop_data(at: Vector2, data: Variant) -> void:
	var from: int = data["track_row"]
	# the line shows where it lands: above this row or below it
	var to := index + (0 if at.y < size.y / 2.0 else 1)
	if from < to:
		to -= 1
	app.clear_drop_hint()
	app.move_track_to(from, to)

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		app.clear_drop_hint()

## A line above (-1) or below (+1) this row, or none (0).
func set_drop_hint(side: int) -> void:
	_sb.border_width_top = 3 if side < 0 else 0
	_sb.border_width_bottom = 3 if side > 0 else 0
	queue_redraw()

func _current_icon() -> String:
	return Icons.for_track(tl.icon, track)

func _fill_menu(menu: PopupMenu) -> void:
	menu.clear()
	if track.lane == "":
		var many := Song.distinct_pitches(track) > 1
		menu.add_item("Split into drum parts (kick, snare, hats…)", 0)
		menu.add_item("Split by note", 1)
		menu.set_item_disabled(0, not many)
		menu.set_item_disabled(1, not many)
	else:
		menu.add_item("Merge the parts back into one track", 2)
	menu.add_separator()
	menu.add_item("Rename…", 4)
	menu.add_item("Remove this track", 3)

func _menu_chosen(id: int) -> void:
	match id:
		0:
			app.split_track(index, true)
		1:
			app.split_track(index, false)
		2:
			app.merge_track(index)
		3:
			app.remove_track(index)
		4:
			app.ask_rename(index)

func _open_picker() -> void:
	if _picker:
		_picker.queue_free()
	_picker = PopupPanel.new()
	add_child(_picker)
	var holder := VBoxContainer.new()
	holder.add_theme_constant_override("separation", 6)
	_picker.add_child(holder)
	var search := LineEdit.new()
	search.placeholder_text = "Search icons…"
	search.clear_button_enabled = true
	holder.add_child(search)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(412, 360)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	holder.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)
	var auto := Button.new()
	auto.text = "Automatic (from the track's name and instrument)"
	auto.pressed.connect(func(): _choose(""))
	holder.add_child(auto)
	search.text_changed.connect(func(q): _fill_picker(list, q))
	_fill_picker(list, "")
	_picker.popup(Rect2i(Vector2i(_icon.get_screen_position()) + Vector2i(0, 36), Vector2i.ZERO))
	search.grab_focus()

## The icons by category, narrowed to those matching [query].
func _fill_picker(list: VBoxContainer, query: String) -> void:
	for c in list.get_children():
		c.queue_free()
	var q := query.strip_edges().to_lower()
	var current := _current_icon()
	for cat in IconData.CATEGORIES:
		var shown: Array = []
		for k in cat[1]:
			if q == "" or Icons.label(k).to_lower().contains(q) or k.contains(q) or str(cat[0]).to_lower().contains(q):
				shown.append(k)
		if shown.is_empty():
			continue
		var title := Label.new()
		title.text = cat[0]
		title.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
		title.add_theme_font_size_override("font_size", 12)
		list.add_child(title)
		var grid := GridContainer.new()
		grid.columns = 8
		grid.add_theme_constant_override("h_separation", 4)
		grid.add_theme_constant_override("v_separation", 4)
		list.add_child(grid)
		for k in shown:
			var iv := IconView.new(44.0)
			iv.kind = k
			iv.tint = tl.color
			iv.selected = k == current
			iv.tooltip_text = Icons.label(k)
			iv.clicked.connect(func(): _choose(k))
			grid.add_child(iv)

func _choose(kind: String) -> void:
	tl.icon = kind
	_icon.kind = _current_icon()
	_picker.hide()
	app._changed()

func refresh_color() -> void:
	_icon.tint = tl.color
