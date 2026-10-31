## ALMAMPlayer's window: the preview (or the note editor) in the middle with
## its transport, the tracks on the left, the scene on the right. Everything
## saves itself as you go; drop files anywhere (a .mid, or an FL Studio /
## Ableton project, opens the song; sound becomes its audio, a picture its
## background, an old config its look).
extends Control

const ACCENT := Color("f7b955")
const PANEL := Color("2a2622")
const GROUND := Color("1d1a17")
const TEXT_DIM := Color(1, 1, 1, 0.55)

var project: Project
var song: Song
var _stream: AudioStream

var vis: Visualizer
var player: AudioStreamPlayer
var playing := false
var _clock := 0.0 # song time when there's no audio playing
var _audio_started := false

var _save_timer: Timer
var _tracks_box: VBoxContainer
var _scene_box: VBoxContainer
var _title: Label
var _time_label: Label
var _seek: HSlider
var _play_btn: Button
var _empty: Control
var _frame: Control
var _editor: NoteEditor
var _preview_btn: Button
var _edit_btn: Button
var _status: Label
var _exporter: Exporter
var _export_bar: ProgressBar
var _export_row: Control
var _export_btn: Button
var _seeking := false

func _ready() -> void:
	get_window().min_size = Vector2i(1100, 640)
	get_window().files_dropped.connect(_on_files_dropped)
	theme = _make_theme()
	_build()
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = 0.6
	_save_timer.timeout.connect(_save_now)
	add_child(_save_timer)
	_exporter = Exporter.new()
	_exporter.progress.connect(func(p): _export_bar.value = p)
	_exporter.finished.connect(_on_export_finished)
	add_child(_exporter)
	# from the command line: ALMAMPlayer -- --render=song.mid --out=song.mp4
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv = a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else ""
	if args.has("render"):
		_render_and_quit(args["render"], args.get("out", args["render"].get_basename() + ".mp4"))
		return
	# the last song, as it was left
	var last := str(Project.state().get("last", ""))
	if last != "" and FileAccess.file_exists(last):
		open_song(last)
	else:
		_show_empty()

# ---------------------------------------------------------------- layout

func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 15
	var flat := func(c: Color, r := 8) -> StyleBoxFlat:
		var s := StyleBoxFlat.new()
		s.bg_color = c
		s.set_corner_radius_all(r)
		s.content_margin_left = 10
		s.content_margin_right = 10
		s.content_margin_top = 5
		s.content_margin_bottom = 5
		return s
	t.set_stylebox("normal", "Button", flat.call(Color("3a342e")))
	t.set_stylebox("hover", "Button", flat.call(Color("4a423a")))
	t.set_stylebox("pressed", "Button", flat.call(ACCENT.darkened(0.25)))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_stylebox("disabled", "Button", flat.call(Color("2f2a25")))
	t.set_color("font_pressed_color", "Button", Color.BLACK)
	t.set_stylebox("panel", "PanelContainer", flat.call(PANEL, 12))
	t.set_color("font_color", "Label", Color(1, 1, 1, 0.9))
	t.set_stylebox("normal", "LineEdit", flat.call(Color("3a342e")))
	t.set_stylebox("slider", "HSlider", flat.call(Color("4a423a"), 3))
	var grab: StyleBoxFlat = flat.call(ACCENT, 3)
	t.set_stylebox("grabber_area", "HSlider", grab)
	t.set_stylebox("grabber_area_highlight", "HSlider", grab)
	t.set_stylebox("background", "ProgressBar", flat.call(Color("3a342e"), 6))
	t.set_stylebox("fill", "ProgressBar", flat.call(ACCENT, 6))
	return t

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = GROUND
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	add_child(margin)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 10)
	margin.add_child(cols)

	# left: tracks
	var left := _panel("Tracks")
	left.custom_minimum_size.x = 380
	cols.add_child(left)
	var all_row := HBoxContainer.new()
	left.get_child(0).add_child(all_row)
	all_row.add_child(_button("Rainbow", _rainbow, "Colors around the color wheel"))
	all_row.add_child(_button("Gradient", _gradient, "Colors from the first track's to the last's"))
	all_row.add_child(_button("Depth", _reset_depth, "Back to the default speeds (the top tracks faster)"))
	all_row.add_child(_button("Icons", _auto_icons, "Pick every track's icon from its name and instrument again"))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.get_child(0).add_child(scroll)
	_tracks_box = VBoxContainer.new()
	_tracks_box.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(_tracks_box)

	# middle: title, preview, transport, export
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 8)
	cols.add_child(mid)
	var top := HBoxContainer.new()
	mid.add_child(top)
	top.add_child(_button("Open…", _open_dialog, "A MIDI or an FL Studio / Ableton project, its sound, a background, or a look (or drop them here)"))
	var recent := MenuButton.new()
	recent.text = "Recent ▾"
	recent.flat = false
	recent.about_to_popup.connect(func(): _fill_recent(recent.get_popup()))
	recent.get_popup().id_pressed.connect(func(i): open_song(Project.recent()[i]))
	top.add_child(recent)
	_title = Label.new()
	_title.size_flags_horizontal = SIZE_EXPAND_FILL
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_title.add_theme_font_size_override("font_size", 18)
	top.add_child(_title)
	_preview_btn = _button("Preview", func(): _set_mode(false), "See the video as it will export")
	_preview_btn.toggle_mode = true
	top.add_child(_preview_btn)
	_edit_btn = _button("Edit notes", func(): _set_mode(true), "Fix, add and delete notes (Tab)")
	_edit_btn.toggle_mode = true
	top.add_child(_edit_btn)
	_status = Label.new()
	_status.add_theme_color_override("font_color", TEXT_DIM)
	top.add_child(_status)

	var frame := AspectRatioContainer.new()
	frame.ratio = 16.0 / 9.0
	frame.size_flags_vertical = SIZE_EXPAND_FILL
	mid.add_child(frame)
	_frame = frame
	_editor = NoteEditor.new()
	_editor.size_flags_vertical = SIZE_EXPAND_FILL
	_editor.setup(self)
	_editor.edited.connect(func(): _changed())
	_editor.export_requested.connect(_save_midi_dialog)
	_editor.revert_requested.connect(_revert_edits)
	_editor.visible = false
	mid.add_child(_editor)
	var holder := SubViewportContainer.new()
	holder.stretch = true
	frame.add_child(holder)
	var vp := SubViewport.new()
	vp.size = Vector2i(1920, 1080)
	vp.size_2d_override = Vector2i(1920, 1080)
	vp.size_2d_override_stretch = true
	holder.add_child(vp)
	vis = Visualizer.new()
	vp.add_child(vis)
	holder.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT: toggle_play())
	_empty = _make_empty()
	frame.add_child(_empty)

	_set_mode(false)
	var transport := HBoxContainer.new()
	mid.add_child(transport)
	transport.add_child(_button("⏮", func(): seek_to(-Exporter.LEAD), "Back to the start"))
	_play_btn = _button("▶  Play", toggle_play, "Play / pause (space)")
	_play_btn.custom_minimum_size.x = 110
	transport.add_child(_play_btn)
	_time_label = Label.new()
	_time_label.custom_minimum_size.x = 110
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	transport.add_child(_time_label)
	_seek = HSlider.new()
	_seek.size_flags_horizontal = SIZE_EXPAND_FILL
	_seek.size_flags_vertical = SIZE_SHRINK_CENTER
	_seek.step = 0.01
	_seek.drag_started.connect(func(): _seeking = true)
	_seek.drag_ended.connect(func(_c): _seeking = false; seek_to(_seek.value))
	_seek.value_changed.connect(func(v): if _seeking: _preview_at(v))
	transport.add_child(_seek)

	_export_row = HBoxContainer.new()
	mid.add_child(_export_row)
	_export_btn = _button("Export video…", _export_dialog, "1080p, 60 fps, with the song's audio. .mov keeps a transparent background (no keying needed)")
	_export_row.add_child(_export_btn)
	_export_bar = ProgressBar.new()
	_export_bar.size_flags_horizontal = SIZE_EXPAND_FILL
	_export_bar.size_flags_vertical = SIZE_SHRINK_CENTER
	_export_bar.max_value = 1.0
	_export_bar.visible = false
	_export_row.add_child(_export_bar)

	# right: the scene
	var right := _panel("Scene")
	right.custom_minimum_size.x = 300
	cols.add_child(right)
	var rs := ScrollContainer.new()
	rs.size_flags_vertical = SIZE_EXPAND_FILL
	rs.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.get_child(0).add_child(rs)
	_scene_box = VBoxContainer.new()
	_scene_box.size_flags_horizontal = SIZE_EXPAND_FILL
	_scene_box.add_theme_constant_override("separation", 6)
	rs.add_child(_scene_box)

	player = AudioStreamPlayer.new()
	add_child(player)
	player.finished.connect(func(): pass)

func _panel(title: String) -> PanelContainer:
	var p := PanelContainer.new()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	var l := Label.new()
	l.text = title
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", ACCENT)
	v.add_child(l)
	return p

func _button(text: String, on: Callable, tip := "") -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.pressed.connect(on)
	return b

func _make_empty() -> Control:
	var c := CenterContainer.new()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	c.add_child(v)
	var l := Label.new()
	l.text = "Drop a MIDI file or a project (FL Studio .flp, Ableton .als) here."
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 20)
	v.add_child(l)
	var hint := Label.new()
	hint.text = "Every MIDI track is found by itself. A sound file named like the song (song.mid + song.mp3) is picked up too.\nLogic: File ▸ Export ▸ All Tracks as MIDI Files, then drop that."
	hint.add_theme_color_override("font_color", TEXT_DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hint)
	var b := _button("Open a song…", _open_dialog)
	b.size_flags_horizontal = SIZE_SHRINK_CENTER
	v.add_child(b)
	return c

func _show_empty() -> void:
	_empty.visible = true
	_title.text = "ALMAMPlayer"
	_export_btn.disabled = true

# ---------------------------------------------------------------- songs

func open_song(path: String) -> void:
	var s := Importer.load_song(path)
	if s == null:
		_flash(Importer.last_error)
		return
	_stop()
	song = s
	project = Project.open_for(path)
	song.apply_edits(project.edits)
	song.reorder(project.look.order)
	Project.remember(path)
	_apply_project()

func _apply_project() -> void:
	vis.song = song
	vis.look = project.look
	vis.refresh()
	_empty.visible = false
	_export_btn.disabled = false
	_load_audio(project.audio)
	_title.text = project.midi.get_file().get_basename()
	_rebuild_tracks()
	_rebuild_scene()
	_editor.open_song(song, project.look)
	seek_to(-Exporter.LEAD)
	_changed()

func _load_audio(path: String) -> void:
	_stream = null
	project.audio = path
	if path == "":
		player.stream = null
	else:
		var low := path.to_lower()
		if low.ends_with(".mp3"):
			_stream = AudioStreamMP3.load_from_file(path)
		elif low.ends_with(".ogg"):
			_stream = AudioStreamOggVorbis.load_from_file(path)
		elif low.ends_with(".wav"):
			_stream = AudioStreamWAV.load_from_file(path)
		if _stream == null:
			_flash("That sound file couldn't be read.")
			project.audio = ""
		player.stream = _stream
	_rebuild_scene()

func _length() -> float:
	var l := song.length if song else 0.0
	if _stream:
		l = max(l, _stream.get_length() + project.look.audio_offset)
	return l

# ---------------------------------------------------------------- playback

func toggle_play() -> void:
	if song == null:
		return
	if playing:
		_stop()
	else:
		_play_from(vis.time if vis.time < _length() else -Exporter.LEAD)

func _play_from(t: float) -> void:
	playing = true
	_clock = t
	_audio_started = false
	_start_audio_if_due(t)
	_play_btn.text = "❚❚  Pause"

func _start_audio_if_due(t: float) -> void:
	if _stream == null or _audio_started:
		return
	var at := t - project.look.audio_offset
	if at >= 0.0 and at < _stream.get_length():
		player.play(at)
		_audio_started = true

func _stop() -> void:
	playing = false
	player.stop()
	_audio_started = false
	if _play_btn:
		_play_btn.text = "▶  Play"

func seek_to(t: float) -> void:
	var was := playing
	_stop()
	_preview_at(t)
	if was:
		_play_from(t)

func _preview_at(t: float) -> void:
	vis.time = t
	_clock = t
	_update_transport()

func _process(delta: float) -> void:
	if not playing:
		return
	var t: float
	if _audio_started and player.playing:
		# the sound's own clock, corrected for what's still on its way out
		t = player.get_playback_position() + AudioServer.get_time_since_last_mix() \
				- AudioServer.get_output_latency() + project.look.audio_offset
	else:
		_clock += delta
		t = _clock
		_start_audio_if_due(t)
	_clock = t
	vis.time = t
	_update_transport()
	if t > _length() + Exporter.TAIL:
		_stop()

func _update_transport() -> void:
	if song == null:
		return
	_seek.min_value = -Exporter.LEAD
	_seek.max_value = _length() + Exporter.TAIL
	if not _seeking:
		_seek.set_value_no_signal(vis.time)
	var t: float = max(vis.time, 0.0)
	var l := _length()
	_time_label.text = "%d:%02d / %d:%02d" % [int(t) / 60, int(t) % 60, int(l) / 60, int(l) % 60]

## Space plays and pauses wherever the focus is, so a focused button can't
## take it (a button used to, so playback needed the key held down). Typing
## in a text box keeps its spaces.
func _input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_SPACE:
		var f := get_viewport().gui_get_focus_owner()
		if f is LineEdit or f is TextEdit:
			return
		toggle_play()
		get_viewport().set_input_as_handled()

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		match e.keycode:
			KEY_LEFT:
				seek_to(vis.time - 5.0)
			KEY_RIGHT:
				seek_to(vis.time + 5.0)
			KEY_HOME:
				seek_to(-Exporter.LEAD)
			KEY_O:
				if e.meta_pressed or e.ctrl_pressed:
					_open_dialog()
			KEY_TAB:
				_set_mode(not _editor.visible)
				accept_event()
			KEY_Z:
				if (e.meta_pressed or e.ctrl_pressed) and _editor.visible:
					if e.shift_pressed:
						_editor.canvas.redo()
					else:
						_editor.canvas.undo()
					accept_event()
			KEY_F11, KEY_F:
				if e.keycode == KEY_F11 or e.meta_pressed:
					var w := get_window()
					w.mode = Window.MODE_WINDOWED if w.mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN

# ---------------------------------------------------------------- saving

## Something changed: redraw now, save in a moment.
func _changed(textures := false) -> void:
	if textures:
		vis.refresh()
	vis.queue_redraw()
	if project:
		_status.text = "Saving…"
		_save_timer.start()

func _save_now() -> void:
	if project:
		if song:
			project.edits = song.edits()
		project.save()
		_status.text = "Saved"

func _flash(text: String) -> void:
	_status.text = text

# ---------------------------------------------------------------- files

func _open_dialog() -> void:
	var d := FileDialog.new()
	d.use_native_dialog = true
	d.file_mode = FileDialog.FILE_MODE_OPEN_FILES
	d.access = FileDialog.ACCESS_FILESYSTEM
	d.filters = PackedStringArray([
		"*.mid, *.midi, *.flp, *.als, *.logicx, *.mp3, *.wav, *.ogg, *.png, *.jpg, *.jpeg, *.webp, *.json ; Songs, projects, sound, pictures, looks",
	])
	d.files_selected.connect(_on_files_dropped)
	add_child(d)
	d.popup_centered()

func _pick_image(then: Callable) -> void:
	var d := FileDialog.new()
	d.use_native_dialog = true
	d.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	d.access = FileDialog.ACCESS_FILESYSTEM
	d.filters = PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp ; Pictures"])
	d.file_selected.connect(then)
	add_child(d)
	d.popup_centered()

func _on_files_dropped(files: PackedStringArray) -> void:
	# the song first, so sound and pictures dropped with it land on it
	var sorted := Array(files)
	sorted.sort_custom(func(a, b): return _is_midi(a) and not _is_midi(b))
	for f in sorted:
		var low: String = f.to_lower()
		if _is_midi(f):
			open_song(f)
		elif project == null:
			_flash("Open a song first.")
		elif low.ends_with(".mp3") or low.ends_with(".wav") or low.ends_with(".ogg"):
			_stop()
			_load_audio(f)
			_changed()
		elif low.ends_with(".png") or low.ends_with(".jpg") or low.ends_with(".jpeg") or low.ends_with(".webp"):
			project.look.background = f
			_rebuild_scene()
			_changed(true)
		elif low.ends_with(".json"):
			var l := Project.look_from_old_config(f, song)
			if l:
				project.look = l
				_apply_project()
				_flash("Look loaded")
			else:
				_flash("That file isn't a look.")

func _is_midi(f: String) -> bool:
	return Importer.is_song_file(f)

func _fill_recent(menu: PopupMenu) -> void:
	menu.clear()
	var r := Project.recent()
	for i in r.size():
		menu.add_item(str(r[i]).get_file(), i)
	if r.is_empty():
		menu.add_item("(nothing yet)", -1)
		menu.set_item_disabled(0, true)

# ---------------------------------------------------------------- tracks

func _rebuild_tracks() -> void:
	for c in _tracks_box.get_children():
		c.queue_free()
	var n := song.tracks.size()
	for i in n:
		var tr: Song.Track = song.tracks[i]
		var row := TrackRow.new()
		row.setup(self, tr, project.look.track_look(tr.name, i, n), i)
		_tracks_box.add_child(row)

## Moves track [i] up (-1) or down (+1) in the list.
func move_track(i: int, step: int) -> void:
	move_track_to(i, i + step)

## Moves track [from] to position [to] in the list, the song and the scene.
func move_track_to(from: int, to: int) -> void:
	if song == null or from == to or from < 0 or to < 0 or from >= song.tracks.size() or to >= song.tracks.size():
		return
	var t: Song.Track = song.tracks[from]
	song.tracks.remove_at(from)
	song.tracks.insert(to, t)
	project.look.order = []
	for tr in song.tracks:
		project.look.order.append(tr.name)
	_rebuild_tracks()
	_editor.open_song(song, project.look)
	_changed(true)
	_save_now() # not left to the timer: an order change must survive a quick reopen

func _each_track(f: Callable) -> void:
	var n := song.tracks.size()
	for i in n:
		f.call(project.look.track_look(song.tracks[i].name, i, n), i, n)
	_rebuild_tracks()
	_changed(true)

func _rainbow() -> void:
	_each_track(func(tl, i, n): tl.color = Look.default_track(i, n).color)

func _gradient() -> void:
	var n := song.tracks.size()
	if n < 2:
		return
	var a: Color = project.look.track_look(song.tracks[0].name, 0, n).color
	var b: Color = project.look.track_look(song.tracks[n - 1].name, n - 1, n).color
	_each_track(func(tl, i, cnt): tl.color = a.lerp(b, float(i) / (cnt - 1)))

func _reset_depth() -> void:
	_each_track(func(tl, i, n): tl.parallax = Look.default_track(i, n).parallax)

func _auto_icons() -> void:
	_each_track(func(tl, _i, _n): tl.icon = "")

# ---------------------------------------------------------------- scene

func _rebuild_scene() -> void:
	if _scene_box == null:
		return
	for c in _scene_box.get_children():
		c.queue_free()
	if project == null:
		return
	var l := project.look
	_slider("Speed", 80, 1200, 10, l.speed, func(v): l.speed = v, "px/s")
	_slider("Notes reach up to", 200, 1080, 1, l.top_margin, func(v): l.top_margin = v, "px")
	_slider("Lowest note sits at", 0, 700, 1, -l.vertical_offset, func(v): l.vertical_offset = -v, "px up")
	_slider("Velocity effect", 0, 1, 0.01, l.velocity_strength, func(v): l.velocity_strength = v)
	_slider("Pitch bend", 0, 2, 0.01, l.pitch_bend_strength, func(v): l.pitch_bend_strength = v)
	_slider("Glow", 0, 1.5, 0.01, l.glow, func(v): l.glow = v)
	_slider("Note thickness", 0.4, 2.0, 0.01, l.thickness, func(v): l.thickness = v, "×")
	_slider("Audio delay", -1000, 1000, 5, l.audio_offset * 1000.0, func(v): l.audio_offset = v / 1000.0, "ms")
	var sq := CheckButton.new()
	sq.text = "Square video (1080×1080)"
	sq.button_pressed = l.square
	sq.toggled.connect(func(on): l.square = on; _changed())
	_scene_box.add_child(sq)

	_scene_box.add_child(_section("Sound"))
	var snd := Label.new()
	snd.text = project.audio.get_file() if project.audio != "" else "None (drop a sound file)"
	snd.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	snd.add_theme_color_override("font_color", TEXT_DIM)
	_scene_box.add_child(snd)
	var srow := HBoxContainer.new()
	srow.add_child(_button("Choose…", func():
		var d := FileDialog.new()
		d.use_native_dialog = true
		d.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		d.access = FileDialog.ACCESS_FILESYSTEM
		d.filters = PackedStringArray(["*.mp3, *.wav, *.ogg ; Sound"])
		d.file_selected.connect(func(p): _stop(); _load_audio(p); _changed())
		add_child(d)
		d.popup_centered()))
	if project.audio != "":
		srow.add_child(_button("Remove", func(): _stop(); _load_audio(""); _changed()))
	_scene_box.add_child(srow)

	_scene_box.add_child(_section("Background"))
	var brow := HBoxContainer.new()
	brow.add_child(_button("Choose…", func(): _pick_image(func(p): l.background = p; _rebuild_scene(); _changed())))
	if l.background != "":
		brow.add_child(_button("Remove", func(): l.background = ""; _rebuild_scene(); _changed()))
	_scene_box.add_child(brow)

	_scene_box.add_child(_section("Looks"))
	var lrow := HBoxContainer.new()
	lrow.add_child(_button("Save this look…", _save_look_dialog, "Keep this look to use on other songs"))
	var use := MenuButton.new()
	use.text = "Use a look ▾"
	use.flat = false
	use.about_to_popup.connect(func():
		var m := use.get_popup()
		m.clear()
		var names := Project.looks()
		for i in names.size():
			m.add_item(names[i], i)
		if names.is_empty():
			m.add_item("(none saved yet)", -1)
			m.set_item_disabled(0, true))
	use.get_popup().id_pressed.connect(func(i):
		var lk := Project.load_look(Project.looks()[i])
		if lk:
			project.look = lk
			_apply_project())
	lrow.add_child(use)
	_scene_box.add_child(lrow)

	var keys := Label.new()
	keys.text = "\nSpace: play / pause · ← →: 5 s · Home: start · Tab: edit notes · ⌘F: full screen"
	keys.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	keys.add_theme_color_override("font_color", TEXT_DIM)
	keys.add_theme_font_size_override("font_size", 12)
	_scene_box.add_child(keys)

func _section(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_color_override("font_color", ACCENT)
	return l

func _slider(label: String, lo: float, hi: float, step: float, value: float, set_value: Callable, unit := "") -> void:
	var head := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.size_flags_horizontal = SIZE_EXPAND_FILL
	head.add_child(l)
	var num := SpinBox.new()
	num.min_value = lo
	num.max_value = hi
	num.step = step
	num.allow_greater = true
	num.allow_lesser = true
	num.suffix = unit
	num.custom_minimum_size.x = 120
	num.value = value
	head.add_child(num)
	_scene_box.add_child(head)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = value
	_scene_box.add_child(s)
	s.value_changed.connect(func(v): num.set_value_no_signal(v); set_value.call(v); _changed())
	num.value_changed.connect(func(v): s.set_value_no_signal(v); set_value.call(v); _changed())

func _save_look_dialog() -> void:
	var d := AcceptDialog.new()
	d.title = "Save this look"
	var e := LineEdit.new()
	e.text = _title.text
	e.select_all_on_focus = true
	d.add_child(e)
	d.confirmed.connect(func(): Project.save_look(e.text.strip_edges() if e.text.strip_edges() != "" else "Look", project.look); _flash("Look saved"))
	add_child(d)
	d.popup_centered(Vector2i(360, 100))
	e.grab_focus()

# ---------------------------------------------------------------- editing

func _set_mode(editing: bool) -> void:
	_frame.visible = not editing
	_editor.visible = editing
	_preview_btn.set_pressed_no_signal(not editing)
	_edit_btn.set_pressed_no_signal(editing)
	if editing and song:
		_editor.canvas.queue_redraw()

## The editor, on track [i] (the "Edit" button on a track).
func edit_track(i: int) -> void:
	_set_mode(true)
	_editor.show_track(i)

func _save_midi_dialog() -> void:
	if song == null:
		return
	var d := FileDialog.new()
	d.use_native_dialog = true
	d.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	d.access = FileDialog.ACCESS_FILESYSTEM
	d.filters = PackedStringArray(["*.mid ; MIDI file"])
	d.current_file = _title.text + " (edited).mid"
	d.current_dir = project.midi.get_base_dir()
	d.file_selected.connect(func(p):
		if not p.to_lower().ends_with(".mid"):
			p += ".mid"
		var err := song.save_midi(p)
		_flash("MIDI saved" if err == OK else "Couldn't save that MIDI."))
	add_child(d)
	d.popup_centered()

## Throws every edit away: the song is read from its file again.
func _revert_edits() -> void:
	if song == null or not song.has_edits():
		return
	var d := ConfirmationDialog.new()
	d.dialog_text = "Throw away every note edit in this song and go back to the file?"
	d.confirmed.connect(func():
		project.edits = {}
		project.save()
		open_song(project.midi)
		_flash("Edits reverted"))
	add_child(d)
	d.popup_centered()

# ---------------------------------------------------------------- export

func _export_dialog() -> void:
	if _exporter.running:
		_exporter.cancel()
		return
	var d := FileDialog.new()
	d.use_native_dialog = true
	d.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	d.access = FileDialog.ACCESS_FILESYSTEM
	d.filters = PackedStringArray(["*.mov ; QuickTime, transparent background (ProRes 4444 with alpha)", "*.mp4 ; MP4 video, black background"])
	d.current_file = _title.text + ".mov"
	d.current_dir = project.midi.get_base_dir()
	d.file_selected.connect(func(p):
		if not (p.to_lower().ends_with(".mov") or p.to_lower().ends_with(".mp4")):
			p += ".mov"
		_stop()
		_export_bar.value = 0
		_export_bar.visible = true
		_export_btn.text = "Stop exporting"
		_status.text = "Exporting…"
		_exporter.run(song, project.look, project.audio, p, Exporter.FPS_DEFAULT, _stream.get_length() if _stream else 0.0))
	add_child(d)
	d.popup_centered()

func _render_and_quit(midi: String, out: String) -> void:
	open_song(midi)
	if song == null:
		printerr("Couldn't read ", midi)
		get_tree().quit(1)
		return
	_exporter.progress.connect(func(p): print("%d%%" % int(p * 100)))
	_exporter.finished.connect(func(ok, msg):
		print("done: " if ok else "failed: ", msg)
		get_tree().quit(0 if ok else 1))
	_exporter.run(song, project.look, project.audio, out, Exporter.FPS_DEFAULT, _stream.get_length() if _stream else 0.0)

func _on_export_finished(ok: bool, message: String) -> void:
	_export_bar.visible = false
	_export_btn.text = "Export video…"
	if ok:
		_status.text = "Video saved"
		if not Array(OS.get_cmdline_user_args()).any(func(a): return a.begins_with("--render")):
			OS.shell_show_in_file_manager(message)
	else:
		_status.text = message

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_now()
