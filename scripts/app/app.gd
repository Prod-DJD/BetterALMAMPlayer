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
var _vp: SubViewport
var _bg_rect: ColorRect
var _margin: MarginContainer
var _left: Control
var _right: Control
var _top: Control
var _transport: Control
var _fullscreen := false
var _prev_window_mode := Window.MODE_WINDOWED
var _fs_hint: Label
var _fs_btn: Button
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
	if OS.has_feature("mobile"):
		# the window is laid out for a desktop: show it scaled to fit a landscape screen
		var win := get_window()
		win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
		win.content_scale_size = Vector2i(1280, 720)
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
	# the last song, as it was left, unless the last start never finished (a
	# song that crashes the app must not trap it in a crash loop)
	_show_empty()
	_restore_last.call_deferred()

## The last song, as it was left. Done once the window is showing (a
## permission question from macOS can't freeze the start), and not at all if
## the last start never finished (a song that breaks the app must not trap it
## in a crash loop).
func _restore_last() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var last := str(Project.state().get("last", ""))
	var marker := "user://starting"
	if FileAccess.file_exists(marker):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(marker))
		Project.forget_last()
		_flash("The last start didn't finish, so the last song wasn't reopened.")
		return
	if last == "" or not FileAccess.file_exists(last):
		return
	var m := FileAccess.open(marker, FileAccess.WRITE)
	if m:
		m.store_string("1")
		m.close()
	open_song(last)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(marker))

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
	_bg_rect = bg
	bg.color = GROUND
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	_margin = margin
	margin.set_anchors_preset(PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	add_child(margin)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 10)
	margin.add_child(cols)

	# left: tracks
	var left := _panel("Tracks")
	_left = left
	left.custom_minimum_size.x = 380
	cols.add_child(left)
	var all_row := HFlowContainer.new()
	left.get_child(0).add_child(all_row)
	all_row.add_child(_toggle_button("rainbow", "Rainbow", "Colors around the color wheel", func(on): _color_toggle("rainbow", on)))
	all_row.add_child(_toggle_button("gradient", "Gradient", "Colors from the first track's to the last's", func(on): _color_toggle("gradient", on)))
	all_row.add_child(_toggle_button("depth", "Depth", "Default speeds (the top tracks faster)", _depth_toggle))
	all_row.add_child(_toggle_button("icons", "Icons", "Every icon picked again from the track's name and instrument", _icons_toggle))
	all_row.add_child(_button("＋ Track", add_track, "Add an empty track (add its notes in the editor)"))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.get_child(0).add_child(scroll)
	_tracks_box = VBoxContainer.new()
	_tracks_box.size_flags_horizontal = SIZE_EXPAND_FILL
	var tracks_pad := MarginContainer.new()
	tracks_pad.size_flags_horizontal = SIZE_EXPAND_FILL
	tracks_pad.add_theme_constant_override("margin_right", 12)
	tracks_pad.add_child(_tracks_box)
	scroll.add_child(tracks_pad)

	# middle: title, preview, transport, export
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 8)
	cols.add_child(mid)
	var top := HBoxContainer.new()
	_top = top
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
	_status.custom_minimum_size.x = 150 # a long message trims; it never widens the window
	_status.clip_text = true
	_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(_status)

	var frame := AspectRatioContainer.new()
	frame.ratio = 16.0 / 9.0
	frame.size_flags_vertical = SIZE_EXPAND_FILL
	mid.add_child(frame)
	_frame = frame
	_editor = NoteEditor.new()
	_editor.size_flags_vertical = SIZE_EXPAND_FILL
	_editor.setup(self)
	_editor.edited.connect(_on_editor_edited)
	_editor.send_requested.connect(move_selection_to)
	_editor.export_requested.connect(_save_midi_dialog)
	_editor.revert_requested.connect(_revert_edits)
	_editor.visible = false
	mid.add_child(_editor)
	var holder := SubViewportContainer.new()
	holder.stretch = true
	var stack := Control.new() # the video, with the full-screen button over its corner
	frame.add_child(stack)
	holder.set_anchors_preset(PRESET_FULL_RECT)
	stack.add_child(holder)
	_vp = SubViewport.new()
	_vp.size = Vector2i(1920, 1080)
	_vp.size_2d_override = Vector2i(1920, 1080)
	_vp.size_2d_override_stretch = true
	holder.add_child(_vp)
	vis = Visualizer.new()
	_vp.add_child(vis)
	holder.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT: toggle_play())
	_empty = _make_empty()
	_empty.set_anchors_preset(PRESET_FULL_RECT)
	stack.add_child(_empty)
	_fs_btn = Button.new()
	_fs_btn.text = "⛶"
	_fs_btn.tooltip_text = "Full screen: just the video (Esc to leave, F11 or ⌘F to toggle)"
	_fs_btn.focus_mode = Control.FOCUS_NONE
	_fs_btn.set_anchors_preset(PRESET_BOTTOM_RIGHT)
	_fs_btn.grow_horizontal = GROW_DIRECTION_BEGIN
	_fs_btn.grow_vertical = GROW_DIRECTION_BEGIN
	_fs_btn.offset_right = -10
	_fs_btn.offset_bottom = -10
	_fs_btn.modulate.a = 0.55
	_fs_btn.mouse_entered.connect(func(): _fs_btn.modulate.a = 1.0)
	_fs_btn.mouse_exited.connect(func(): _fs_btn.modulate.a = 0.55)
	_fs_btn.pressed.connect(func(): set_fullscreen_preview(not _fullscreen))
	stack.add_child(_fs_btn)

	_set_mode(false)
	var transport := HBoxContainer.new()
	_transport = transport
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
	_right = right
	right.custom_minimum_size.x = 300
	cols.add_child(right)
	var rs := ScrollContainer.new()
	rs.size_flags_vertical = SIZE_EXPAND_FILL
	rs.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.get_child(0).add_child(rs)
	_scene_box = VBoxContainer.new()
	_scene_box.size_flags_horizontal = SIZE_EXPAND_FILL
	_scene_box.add_theme_constant_override("separation", 6)
	var scene_pad := MarginContainer.new()
	scene_pad.size_flags_horizontal = SIZE_EXPAND_FILL
	scene_pad.add_theme_constant_override("margin_right", 12)
	scene_pad.add_child(_scene_box)
	rs.add_child(scene_pad)

	player = AudioStreamPlayer.new()
	add_child(player)
	player.finished.connect(func(): pass)

func _panel(title: String) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 14
	sb.content_margin_right = 18 # the scrollbar keeps off the edge
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	p.add_theme_stylebox_override("panel", sb)
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
	l.text = "Drop a MIDI file or a project (FL Studio, Ableton, Logic) here."
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 20)
	v.add_child(l)
	var hint := Label.new()
	hint.text = "Every MIDI track is found by itself. A sound file named like the song (song.mid + song.mp3) is picked up too."
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
		if str(Project.state().get("last", "")) == path:
			Project.forget_last() # don't try the same file on every start
		return
	_stop()
	song = s
	project = Project.open_for(path)
	for name in project.extra_tracks:
		song.add_empty_track(str(name))
	song.apply_edits(project.edits)
	song.drop_empty(project.extra_tracks)
	if project.fresh:
		# a drum track (MIDI channel 10) is one track of many parts: split it
		for t in song.tracks:
			if t.drums and Song.distinct_pitches(t) > 1:
				project.splits[t.origin] = "drums"
	song.apply_splits(project.splits)
	for t in song.tracks:
		if t.auto_name == "":
			t.auto_name = t.name
		if project.renames.has(t.auto_name) and str(project.renames[t.auto_name]) != "":
			t.name = str(project.renames[t.auto_name])
	Importer.unique_names(song)
	song.reorder(project.look.order)
	_default_part_looks()
	_reset_toggles()
	Project.remember(path)
	_apply_project()

## The preview shows the whole 16:9 picture, or just its middle square when
## "Square video" is on (the export crops the same part).
func _apply_square() -> void:
	var sq: bool = project != null and project.look.square
	# the container sets the viewport's pixel size; this sets what part of the
	# 1920x1080 picture it shows (stretched to fit)
	_vp.size_2d_override = Vector2i(1080, 1080) if sq else Vector2i(1920, 1080)
	vis.position = Vector2(-420, 0) if sq else Vector2.ZERO
	(_frame as AspectRatioContainer).ratio = 1.0 if sq else 16.0 / 9.0

func _apply_project() -> void:
	vis.song = song
	vis.look = project.look
	_apply_square()
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
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			_flash(Project.read_problem(path))
		else:
			var bytes := f.get_buffer(f.get_length())
			f.close()
			if low.ends_with(".mp3"):
				_stream = AudioStreamMP3.load_from_buffer(bytes)
			elif low.ends_with(".ogg"):
				_stream = AudioStreamOggVorbis.load_from_buffer(bytes)
			elif low.ends_with(".wav"):
				_stream = AudioStreamWAV.load_from_buffer(bytes)
			if _stream == null:
				_flash("That sound file couldn't be read.")
		if _stream == null:
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
					set_fullscreen_preview(not _fullscreen)
					accept_event()
			KEY_ESCAPE:
				if _fullscreen:
					set_fullscreen_preview(false)
					accept_event()

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
	_status.tooltip_text = text

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
	# a song dropped on the note editor replaces the track being edited
	if _editor.visible and song != null and _editor.get_global_rect().has_point(get_global_mouse_position()):
		for f in files:
			if Importer.is_song_file(f):
				_ask_replace_track(f)
				return
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

## Moves track [from] to position [to] in the list, the song and the scene.
func move_track_to(from: int, to: int) -> void:
	if song == null or from == to or from < 0 or to < 0 or from >= song.tracks.size() or to >= song.tracks.size():
		return
	var t: Song.Track = song.tracks[from]
	song.tracks.remove_at(from)
	song.tracks.insert(to, t)
	_tracks_changed()

## The tracks list changed (order, split, merge, added, removed): remember
## the order, redraw everything, and save now (not left to the timer, so a
## quick reopen still sees it).
func _tracks_changed(keep_history := false) -> void:
	# the track being edited stays the one being edited (by name)
	var editing := ""
	if _editor.canvas.track():
		editing = _editor.canvas.track().name
	project.look.order = []
	for tr in song.tracks:
		project.look.order.append(tr.name)
	_default_part_looks()
	_rebuild_tracks()
	for i in song.tracks.size():
		if song.tracks[i].name == editing:
			_editor.canvas.track_index = i
	_editor.open_song(song, project.look, keep_history)
	_changed(true)
	_save_now()

## After an edit in the editor: notes moved up or down in a part of a drum kit
## belong to another part now, so the parts are made again from the notes.
func _on_editor_edited() -> void:
	var resplit := []
	for t in song.tracks:
		if t.lane != "" and not resplit.has(t.origin):
			for n in t.notes:
				if n.pitch != t.lane_pitch:
					resplit.append(t.origin)
					break
	if not resplit.is_empty():
		for origin in resplit:
			var as_drums := str(project.splits.get(origin, "drums")) == "drums"
			var whole := song.merge_lanes(origin)
			if whole != null:
				song.split_by_pitch(whole, as_drums)
		_tracks_changed(true)
		return
	_changed()

## Moves the notes selected in the editor to track [param target] (its index),
## or to a new track (-1).
func move_selection_to(target: int) -> void:
	var cv := _editor.canvas
	var src := cv.track()
	if song == null or src == null or cv.selected.is_empty():
		return
	var notes: Array = cv.selected.duplicate()
	var dest: Song.Track
	if target < 0:
		dest = song.add_empty_track()
		project.extra_tracks.append(dest.origin)
	elif target < song.tracks.size() and song.tracks[target] != src:
		dest = song.tracks[target]
	else:
		return
	cv.push_multi_undo([song.tracks.find(src), song.tracks.find(dest)])
	var kept: Array[Song.Note] = []
	for n in src.notes:
		if not notes.has(n):
			kept.append(n)
	src.notes = kept
	for n in notes:
		dest.notes.append(n)
	cv.selected.clear()
	song.refresh()
	_tracks_changed(true)
	_flash("Moved %d notes to %s" % [notes.size(), dest.name])

## Parts split from one track start with the same speed, so a drum kit moves
## together (but each part has its own color and icon).
func _default_part_looks() -> void:
	var speed := {} # origin → parallax of its first part
	var n := song.tracks.size()
	for i in n:
		var t: Song.Track = song.tracks[i]
		if t.lane == "":
			continue
		var fresh := not project.look.tracks.has(t.name)
		var tl := project.look.track_look(t.name, i, n)
		if not speed.has(t.origin):
			speed[t.origin] = tl.parallax
		elif fresh:
			tl.parallax = speed[t.origin]
		# drum parts are hits, not held notes: dots (staccato) from the start
		if fresh and str(project.splits.get(t.origin, "")) == "drums":
			tl.staccato = true

## Splits track [i] into one track per pitch it uses: drum parts by name
## (kick, snare, hats…) or just by note.
func split_track(i: int, as_drums: bool) -> void:
	if song == null or i < 0 or i >= song.tracks.size():
		return
	var t: Song.Track = song.tracks[i]
	var made := song.split_by_pitch(t, as_drums)
	if made == 0:
		_flash("That track only has one note.")
		return
	# parts of a renamed track keep its new name as their start; remember it
	# so they come back the same when the song is opened again
	for p in song.tracks:
		if p.origin == t.origin and p.lane != "" and p.name != p.auto_name:
			project.renames[p.auto_name] = p.name
	project.splits[t.origin] = "drums" if as_drums else "notes"
	_tracks_changed()
	_flash("Split into %d tracks" % made)

## Puts the parts of track [i]'s split back into one track.
func merge_track(i: int) -> void:
	if song == null or i < 0 or i >= song.tracks.size():
		return
	var origin: String = song.tracks[i].origin
	if song.merge_lanes(origin) == null:
		return
	project.splits.erase(origin)
	for t in song.tracks:
		if t.origin == origin and project.renames.has(origin):
			t.name = str(project.renames[origin])
	_tracks_changed()
	_flash("Merged back into one track")

## A new empty track at the bottom; its notes are added in the editor.
func add_track() -> void:
	if song == null:
		_flash("Open a song first.")
		return
	var t := song.add_empty_track()
	project.extra_tracks.append(t.origin)
	_tracks_changed()
	edit_track(song.tracks.size() - 1)

## Removes track [i] (after asking, if it has notes).
func remove_track(i: int) -> void:
	if song == null or i < 0 or i >= song.tracks.size():
		return
	var t: Song.Track = song.tracks[i]
	if t.notes.is_empty():
		_remove_track(t)
		return
	var d := ConfirmationDialog.new()
	d.dialog_text = "Remove \"%s\" and its %d notes?" % [t.name, t.notes.size()]
	d.confirmed.connect(func(): _remove_track(t))
	add_child(d)
	d.popup_centered()

func _remove_track(t: Song.Track) -> void:
	song.tracks.erase(t)
	song.refresh()
	var parts_left := false
	for o in song.tracks:
		if o.origin == t.origin:
			parts_left = true
	if not parts_left:
		project.extra_tracks.erase(t.origin)
		project.splits.erase(t.origin)
	_tracks_changed()

func _each_track(f: Callable) -> void:
	var n := song.tracks.size()
	for i in n:
		f.call(project.look.track_look(song.tracks[i].name, i, n), i, n)
	_rebuild_tracks()
	_changed(true)

## The four buttons above the tracks switch on and off: press one and the
## change is made, press it again and your own colors, speeds or icons come
## straight back.
var _snap_colors := {} # track name → color, before Rainbow / Gradient
var _color_mode := ""
var _snap_depth := {}
var _snap_icons := {}
var _toggles := {} # "rainbow" … → its button

func _toggle_button(id: String, text: String, tip: String, on: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.tooltip_text = tip + " (press again to undo)"
	b.toggled.connect(on)
	_toggles[id] = b
	return b

func _reset_toggles() -> void:
	_snap_colors = {}
	_snap_depth = {}
	_snap_icons = {}
	_color_mode = ""
	for b in _toggles.values():
		b.set_pressed_no_signal(false)

func _color_toggle(mode: String, pressed: bool) -> void:
	if song == null:
		_toggles[mode].set_pressed_no_signal(false)
		return
	if not pressed:
		if _color_mode == mode:
			for i in song.tracks.size():
				var t: Song.Track = song.tracks[i]
				if _snap_colors.has(t.name):
					project.look.track_look(t.name, i, song.tracks.size()).color = _snap_colors[t.name]
			_color_mode = ""
			_rebuild_tracks()
			_changed(true)
		return
	if _color_mode == "":
		_snap_colors = {}
		for i in song.tracks.size():
			var t: Song.Track = song.tracks[i]
			_snap_colors[t.name] = project.look.track_look(t.name, i, song.tracks.size()).color
	_color_mode = mode
	for other in ["rainbow", "gradient"]:
		if other != mode:
			_toggles[other].set_pressed_no_signal(false)
	var n := song.tracks.size()
	if mode == "rainbow":
		_each_track(func(tl, i, cnt): tl.color = Look.default_track(i, cnt).color)
	elif n >= 2:
		var a: Color = _snap_colors[song.tracks[0].name]
		var b: Color = _snap_colors[song.tracks[n - 1].name]
		_each_track(func(tl, i, cnt): tl.color = a.lerp(b, float(i) / (cnt - 1)))

func _depth_toggle(pressed: bool) -> void:
	if song == null:
		_toggles["depth"].set_pressed_no_signal(false)
		return
	var n := song.tracks.size()
	if pressed:
		_snap_depth = {}
		for i in n:
			var t: Song.Track = song.tracks[i]
			_snap_depth[t.name] = project.look.track_look(t.name, i, n).parallax
		_each_track(func(tl, i, cnt): tl.parallax = Look.default_track(i, cnt).parallax)
	else:
		for i in n:
			var t: Song.Track = song.tracks[i]
			if _snap_depth.has(t.name):
				project.look.track_look(t.name, i, n).parallax = _snap_depth[t.name]
		_rebuild_tracks()
		_changed(true)

func _icons_toggle(pressed: bool) -> void:
	if song == null:
		_toggles["icons"].set_pressed_no_signal(false)
		return
	var n := song.tracks.size()
	if pressed:
		_snap_icons = {}
		for i in n:
			var t: Song.Track = song.tracks[i]
			_snap_icons[t.name] = project.look.track_look(t.name, i, n).icon
		_each_track(func(tl, _i, _n): tl.icon = "")
	else:
		for i in n:
			var t: Song.Track = song.tracks[i]
			if _snap_icons.has(t.name):
				project.look.track_look(t.name, i, n).icon = _snap_icons[t.name]
		_rebuild_tracks()
		_changed(true)

## Renames track [i]. Edits, looks and the order follow the new name.
func rename_track(i: int, new_name: String) -> void:
	if song == null or i < 0 or i >= song.tracks.size():
		return
	var t: Song.Track = song.tracks[i]
	new_name = new_name.strip_edges()
	if new_name == "" or new_name == t.name:
		return
	for o in song.tracks:
		if o != t and o.name == new_name:
			_flash("Another track already has that name.")
			return
	var old := t.name
	if project.look.tracks.has(old):
		project.look.tracks[new_name] = project.look.tracks[old]
		project.look.tracks.erase(old)
	if t.auto_name == "":
		t.auto_name = old
	t.name = new_name
	if new_name == t.auto_name:
		project.renames.erase(t.auto_name)
	else:
		project.renames[t.auto_name] = new_name
	_tracks_changed()

## Asks for a new name for track [i].
func ask_rename(i: int) -> void:
	if song == null or i < 0 or i >= song.tracks.size():
		return
	var d := ConfirmationDialog.new()
	d.title = "Rename track"
	var e := LineEdit.new()
	e.text = song.tracks[i].name
	e.select_all_on_focus = true
	e.custom_minimum_size.x = 280
	d.add_child(e)
	d.register_text_enter(e)
	d.confirmed.connect(func(): rename_track(i, e.text); d.queue_free())
	d.canceled.connect(func(): d.queue_free())
	add_child(d)
	d.popup_centered()
	e.grab_focus()

## Which row shows the "it will land here" line while a track is dragged.
var _hint_row: TrackRow

func show_drop_hint(row: TrackRow, side: int) -> void:
	if _hint_row and _hint_row != row:
		_hint_row.set_drop_hint(0)
	_hint_row = row
	row.set_drop_hint(side)

func clear_drop_hint() -> void:
	if _hint_row:
		_hint_row.set_drop_hint(0)
		_hint_row = null

# ---------------------------------------------------------------- scene

func _rebuild_scene() -> void:
	if _scene_box == null:
		return
	for c in _scene_box.get_children():
		c.queue_free()
	if project == null:
		return
	var l := project.look
	var dflt := Look.new() # the usual settings, for a double-click to come back to
	_slider("Speed", 80, 1200, 10, l.speed, func(v): l.speed = v, "px/s", dflt.speed)
	_slider("Notes reach up to", 200, 1080, 1, l.top_margin, func(v): l.top_margin = v, "px", dflt.top_margin)
	_slider("Lowest note sits at", 0, 700, 1, -l.vertical_offset, func(v): l.vertical_offset = -v, "px up", -dflt.vertical_offset)
	_slider("Velocity effect", 0, 1, 0.01, l.velocity_strength, func(v): l.velocity_strength = v, "note on & off", dflt.velocity_strength)
	_slider("Pitch bend", 0, 2, 0.01, l.pitch_bend_strength, func(v): l.pitch_bend_strength = v, "", dflt.pitch_bend_strength)
	_slider("Glow", 0, 1.5, 0.01, l.glow, func(v): l.glow = v, "×", dflt.glow)
	_slider("Note thickness", 0.4, 2.0, 0.01, l.thickness, func(v): l.thickness = v, "×", dflt.thickness)
	_slider("Icon size", 0.4, 4.0, 0.05, l.icon_size, func(v): l.icon_size = v, "×", dflt.icon_size)
	_slider("Audio delay", -1000, 1000, 5, l.audio_offset * 1000.0, func(v): l.audio_offset = v / 1000.0, "ms", dflt.audio_offset * 1000.0)
	var sq := CheckButton.new()
	sq.text = "Square video (1:1)"
	sq.button_pressed = l.square
	sq.toggled.connect(func(on): l.square = on; _apply_square(); _changed())
	_scene_box.add_child(sq)
	_scene_box.add_child(_section("Export"))
	var qrow := HBoxContainer.new()
	var res := _dropdown()
	for h in [[1080, "1080p"], [1440, "1440p"], [2160, "4K"]]:
		res.add_item(h[1], h[0])
	res.select(res.get_item_index(l.export_height))
	res.tooltip_text = "Video size. 4K takes much longer and makes big files."
	res.item_selected.connect(func(i): l.export_height = res.get_item_id(i); _changed())
	qrow.add_child(res)
	var fps := _dropdown()
	for f in [24, 30, 60, 120]:
		fps.add_item("%d fps" % f, f)
	fps.select(fps.get_item_index(l.export_fps))
	fps.tooltip_text = "Frame rate. 120 fps is for slow motion or high-refresh screens."
	fps.item_selected.connect(func(i): l.export_fps = fps.get_item_id(i); _changed())
	qrow.add_child(fps)
	_scene_box.add_child(qrow)
	var fmt := _dropdown()
	var formats := ["mp4", "prores", "hevc", "webm"]
	fmt.add_item("MP4 (plays anywhere)", 0)
	fmt.add_item("MOV transparent: ProRes 4444 (big)", 1)
	fmt.add_item("MOV transparent: HEVC (small, Apple)", 2)
	fmt.add_item("WebM transparent: VP9 (smallest)", 3)
	fmt.select(maxi(formats.find(l.export_format), 0))
	fmt.tooltip_text = "MP4 is on a black (or picture) background. The transparent ones drop the background so the notes sit straight on other footage, no keying."
	fmt.item_selected.connect(func(i): l.export_format = formats[i]; _changed())
	_scene_box.add_child(fmt)

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
	keys.text = "\nSpace: play / pause · ← →: 5 s · Home: start · Tab: edit notes · F11 or ⌘F: full screen (Esc leaves)"
	keys.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	keys.add_theme_color_override("font_color", TEXT_DIM)
	keys.add_theme_font_size_override("font_size", 12)
	_scene_box.add_child(keys)

## A dropdown that shows as much as fits (a long choice never widens the
## panel past the window).
func _dropdown() -> OptionButton:
	var o := OptionButton.new()
	o.fit_to_longest_item = false
	o.clip_text = true
	o.size_flags_horizontal = SIZE_EXPAND_FILL
	o.custom_minimum_size.x = 60
	return o

func _section(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_color_override("font_color", ACCENT)
	return l

func _slider(label: String, lo: float, hi: float, step: float, value: float, set_value: Callable, unit := "", default_value := NAN) -> void:
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
	if not is_nan(default_value):
		s.tooltip_text = "Double-click to go back to the usual setting"
		l.tooltip_text = s.tooltip_text
		l.mouse_filter = MOUSE_FILTER_STOP
		var reset := func():
			s.value = default_value # the slider's own change brings the number and the picture with it
		s.gui_input.connect(func(e): if e is InputEventMouseButton and e.double_click and e.button_index == MOUSE_BUTTON_LEFT: reset.call())
		l.gui_input.connect(func(e): if e is InputEventMouseButton and e.double_click and e.button_index == MOUSE_BUTTON_LEFT: reset.call())

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

# ---------------------------------------------------------------- replace a track

## A MIDI (or project) dropped on the note editor: ask which of its tracks to
## take and where to place it, then replace the notes of the track being
## edited with them.
func _ask_replace_track(path: String) -> void:
	var cv := _editor.canvas
	var target := cv.track()
	var incoming := Importer.load_song(path)
	if target == null or incoming == null:
		_flash(Importer.last_error if incoming == null else "Pick a track to replace first.")
		return
	var d := ConfirmationDialog.new()
	d.title = "Replace the notes of \"%s\"" % target.name
	d.ok_button_text = "Replace"
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.custom_minimum_size.x = 420
	d.add_child(box)
	var head := Label.new()
	head.text = "with the notes from %s" % path.get_file()
	box.add_child(head)
	var which := OptionButton.new()
	for t in incoming.tracks:
		which.add_item("%s (%d notes)" % [t.name, t.notes.size()])
	# the file's track with the same name, else the one with the most notes
	var pick := 0
	for i in incoming.tracks.size():
		if incoming.tracks[i].name.to_lower() == target.name.to_lower():
			pick = i
			break
		if incoming.tracks[i].notes.size() > incoming.tracks[pick].notes.size():
			pick = i
	which.select(pick)
	if incoming.tracks.size() > 1:
		var l := Label.new()
		l.text = "Take this track from the file:"
		box.add_child(l)
		box.add_child(which)
	var place := OptionButton.new()
	place.add_item("Where the file puts them", 0)
	place.add_item("In the bar this track's notes started in", 1)
	var match_tempo := CheckBox.new()
	match_tempo.button_pressed = true
	match_tempo.visible = absf(incoming.bpm - song.bpm) > 0.5
	match_tempo.text = "Match the song's tempo (%.0f BPM in the file, %.0f in the song)" % [incoming.bpm, song.bpm]
	var info := Label.new()
	info.add_theme_color_override("font_color", TEXT_DIM)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size.x = 400
	var refresh := func():
		var src: Song.Track = incoming.tracks[which.selected]
		var scale: float = incoming.bpm / song.bpm if match_tempo.button_pressed else 1.0
		if target.notes.is_empty() or src.notes.is_empty():
			info.text = "The track has no notes now, so the file's timing is used."
			place.disabled = true
			return
		place.disabled = false
		var new_first := INF
		for n in src.notes:
			new_first = minf(new_first, n.start)
		var old_first := INF
		for n in target.notes:
			old_first = minf(old_first, n.start)
		info.text = "The file's first note is in bar %d; this track's first note was in bar %d." % [
				TrackReplace.bar_of(new_first * scale, song.bpm) + 1, TrackReplace.bar_of(old_first, song.bpm) + 1]
	var first_src: Song.Track = incoming.tracks[pick]
	if TrackReplace.default_align(target.notes, first_src.notes, song.bpm, incoming.bpm):
		place.select(1)
	var pl := Label.new()
	pl.text = "Place the notes:"
	box.add_child(pl)
	box.add_child(place)
	box.add_child(match_tempo)
	box.add_child(info)
	refresh.call()
	which.item_selected.connect(func(_i): refresh.call())
	match_tempo.toggled.connect(func(_on): refresh.call())
	d.confirmed.connect(func():
		var src: Song.Track = incoming.tracks[which.selected]
		var notes := TrackReplace.plan(target.notes, src.notes, song.bpm, incoming.bpm,
				place.selected == 1 and not place.disabled, match_tempo.button_pressed)
		cv.replace_notes(notes)
		_flash("Replaced with %d notes from %s" % [notes.size(), path.get_file()])
		d.queue_free())
	d.canceled.connect(func(): d.queue_free())
	add_child(d)
	d.popup_centered()

# ---------------------------------------------------------------- full screen

## Just the video, filling the screen: the panels, the title bar and the
## transport go away (Esc or F11 brings them back). Space, the arrow keys and
## a click still play, pause and move.
func set_fullscreen_preview(on: bool) -> void:
	if on == _fullscreen or _frame == null:
		return
	_fullscreen = on
	var w := get_window()
	if on:
		_prev_window_mode = w.mode
		_set_mode(false)
		w.mode = Window.MODE_FULLSCREEN
	else:
		w.mode = _prev_window_mode
	for c in [_left, _right, _top, _transport, _export_row]:
		c.visible = not on
	for side in ["left", "right", "top", "bottom"]:
		_margin.add_theme_constant_override("margin_" + side, 0 if on else 10)
	_bg_rect.color = Color.BLACK if on else GROUND
	if on:
		_show_fs_hint()

func _show_fs_hint() -> void:
	if _fs_hint == null:
		_fs_hint = Label.new()
		_fs_hint.text = "Esc to leave · Space plays and pauses · ← → move"
		_fs_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
		_fs_hint.add_theme_font_size_override("font_size", 16)
		_fs_hint.set_anchors_preset(PRESET_CENTER_BOTTOM)
		_fs_hint.grow_horizontal = GROW_DIRECTION_BOTH
		_fs_hint.offset_top = -56
		_fs_hint.mouse_filter = MOUSE_FILTER_IGNORE
		add_child(_fs_hint)
	_fs_hint.modulate.a = 1.0
	_fs_hint.visible = true
	var tw := create_tween()
	tw.tween_interval(2.0)
	tw.tween_property(_fs_hint, "modulate:a", 0.0, 0.6)
	tw.tween_callback(func(): _fs_hint.visible = false)

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
	var ext := Exporter.extension_for(project.look.export_format)
	var names := {"mp4": "MP4 video", "mov": "QuickTime video, transparent background", "webm": "WebM video, transparent background"}
	d.filters = PackedStringArray(["*.%s ; %s" % [ext, names[ext]]])
	d.current_file = _title.text + "." + ext
	d.current_dir = project.midi.get_base_dir()
	d.file_selected.connect(func(p):
		var low: String = p.to_lower()
		if not (low.ends_with(".mov") or low.ends_with(".mp4") or low.ends_with(".webm")):
			p += "." + ext
		_stop()
		_export_bar.value = 0
		_export_bar.visible = true
		_export_btn.text = "Stop exporting"
		_status.text = "Exporting…"
		_exporter.run(song, project.look, project.audio, p, project.look.export_fps, _stream.get_length() if _stream else 0.0))
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
	_exporter.run(song, project.look, project.audio, out, project.look.export_fps, _stream.get_length() if _stream else 0.0)

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
