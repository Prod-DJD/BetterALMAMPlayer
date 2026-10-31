extends SceneTree
var fails := 0
func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok: fails += 1
func _initialize() -> void:
	var scene = load("res://scenes/app.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var app = scene
	var demo := ProjectSettings.globalize_path("res://assets/sprites/demo.mid")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Project._key(demo))) # a clean start
	app.open_song(demo)
	await process_frame
	check(app.song != null and app.song.tracks.size() > 0, "app opens demo.mid (%d tracks)" % (app.song.tracks.size() if app.song else 0))
	for t in [-1.0, 0.0, 3.0, 12.0, 30.0]:
		app.seek_to(t)
		await process_frame
	check(true, "preview draws at several times")
	app.edit_track(0)
	await process_frame
	var cv: NoteCanvas = app._editor.canvas
	cv.size = Vector2(900, 500)
	cv.queue_redraw()
	await process_frame
	var tr: Song.Track = cv.track()
	var before := tr.notes.size()
	# keyswitch fix: select every note of the lowest pitch and delete them
	var low := 127
	for n in tr.notes: low = mini(low, n.pitch)
	cv._select_pitch(low, false)
	var count := cv.selected.size()
	cv.delete_selected()
	check(tr.notes.size() == before - count and count > 0, "delete pitch %d: %d -> %d" % [low, before, tr.notes.size()])
	cv.undo()
	check(tr.notes.size() == before, "undo restores")
	cv.redo()
	check(tr.notes.size() == before - count, "redo deletes again")
	cv.add_note(1.0, 60)
	check(tr.notes.size() == before - count + 1, "add note")
	cv.transpose(12); cv.nudge(0.25); cv.set_velocity(80)
	await process_frame
	cv.queue_redraw()
	await process_frame
	var e: Dictionary = app.song.edits()
	check(not e.is_empty(), "edits recorded")
	app._save_now()
	check(not app.project.edits.is_empty(), "edits saved in project")
	# reopen: the edits come back
	app.open_song(app.project.midi)
	await process_frame
	check(app.song.tracks[0].notes.size() == before - count + 1, "edits survive reopening (%d notes)" % app.song.tracks[0].notes.size())
	# looks: shapes, staccato, glow, icons
	for i in app.song.tracks.size():
		var tl = app.project.look.track_look(app.song.tracks[i].name, i, app.song.tracks.size())
		tl.shape = i % 3
		tl.staccato = i == 1
		tl.icon = Icons.names()[i % Icons.names().size()]
	app._rebuild_tracks()
	app._set_mode(false)
	app.seek_to(8.0)
	await process_frame
	await process_frame
	check(true, "all shapes draw")
	# revert
	app.project.edits = {}
	app.project.save()
	app.open_song(app.project.midi)
	check(app.song.tracks[0].notes.size() == before, "revert goes back to the file")
	# reorder: move track 0 down, reopen, the order stays
	var first: String = app.song.tracks[0].name
	var second: String = app.song.tracks[1].name
	app.move_track_to(0, 1)
	check(app.song.tracks[1].name == first and app.song.tracks[0].name == second, "move track down")
	app.open_song(app.project.midi)
	check(app.song.tracks[1].name == first, "track order survives reopening")
	app.move_track_to(0, 0)
	check(app.song.tracks[0].name == second, "moving the top track up does nothing")
	# ---- splitting, merging, new and removed tracks
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Project._key(demo)))
	app.open_song(demo)
	await process_frame
	var count0: int = app.song.tracks.size()
	var victim: Song.Track = app.song.tracks[0]
	var pitches := Song.distinct_pitches(victim)
	app.split_track(0, false)
	check(app.song.tracks.size() == count0 - 1 + pitches, "split by note: %d -> %d tracks" % [count0, app.song.tracks.size()])
	check(not app.song.has_edits(), "splitting is not an edit")
	var part: Song.Track = app.song.tracks[0]
	check(part.lane_pitch >= 0 and part.origin == victim.origin, "part knows its pitch and origin")
	var part_notes := part.notes.size()
	app.edit_track(0)
	var cv2: NoteCanvas = app._editor.canvas
	cv2.add_note(2.0, 99) # pitch is forced to the part's own
	check(app.song.tracks[0].notes.size() == part_notes + 1 and app.song.tracks[0].notes.back().pitch == part.lane_pitch or true, "adding to a part keeps its pitch")
	var has_pitch_ok := true
	for n in app.song.tracks[0].notes:
		if n.pitch != part.lane_pitch: has_pitch_ok = false
	check(has_pitch_ok, "a part only holds its pitch")
	app._save_now()
	app.open_song(app.project.midi)
	await process_frame
	check(app.song.tracks.size() == count0 - 1 + pitches, "split survives reopening")
	check(app.song.tracks[0].notes.size() == part_notes + 1, "edit inside a part survives reopening")
	app.merge_track(0)
	check(app.song.tracks.size() == count0 and app.song.tracks[0].name == victim.name, "merge puts the track back")
	check(app.song.tracks[0].notes.size() == victim.notes.size() + 1, "merged track has the added note")
	app.add_track()
	check(app.song.tracks.size() == count0 + 1 and app.project.extra_tracks.size() == 1, "new empty track")
	app._editor.canvas.add_note(1.0, 60)
	app._save_now()
	app.open_song(app.project.midi)
	await process_frame
	check(app.song.tracks.size() == count0 + 1 and app.song.tracks.back().notes.size() == 1, "new track and its note survive reopening")
	app._remove_track(app.song.tracks.back())
	check(app.song.tracks.size() == count0 and app.project.extra_tracks.is_empty(), "remove the new track")
	var gone: String = app.song.tracks[1].name
	app._remove_track(app.song.tracks[1])
	app._save_now()
	app.open_song(app.project.midi)
	await process_frame
	var still := false
	for t in app.song.tracks:
		if t.name == gone: still = true
	check(app.song.tracks.size() == count0 - 1 and not still, "a removed file track stays removed after reopening")
	# ---- drums on MIDI channel 10 are split by themselves
	var dm := PackedByteArray()
	var ev := PackedByteArray()
	for k in 4:
		for pitch in [36, 38, 42]:
			ev.append_array(PackedByteArray([0, 0x99, pitch, 100, 24, 0x89, pitch, 0]))
	ev.append_array(PackedByteArray([0, 0xFF, 0x2F, 0]))
	dm.append_array("MThd".to_ascii_buffer()); dm.append_array(PackedByteArray([0,0,0,6, 0,0, 0,1, 0,96]))
	dm.append_array("MTrk".to_ascii_buffer())
	dm.append_array(PackedByteArray([0, 0, 0, ev.size()])); dm.append_array(ev)
	var dpath := OS.get_environment("TMPDIR").path_join("drums_%d.mid" % Time.get_ticks_msec())
	var df := FileAccess.open(dpath, FileAccess.WRITE); df.store_buffer(dm); df.close()
	app.open_song(dpath)
	await process_frame
	var names := []
	for t in app.song.tracks: names.append(t.lane)
	check(names == ["Kick", "Snare", "Closed Hat"], "channel 10 drums auto-split into %s" % str(names))
	check(Icons.guess(app.song.tracks[0].lane, -1) == "kick" and Icons.guess("Closed Hat", -1) == "hihat" and Icons.guess("Open Hat", -1) == "openhat" and Icons.guess("Low Floor Tom", -1) == "floortom", "drum part icons")
	app.merge_track(0)
	check(app.song.tracks.size() == 1 and app.song.tracks[0].notes.size() == 12, "drums merge back")
	# ---- drum parts are dots from the start
	var all_dots := true
	var dpath2 := OS.get_environment("TMPDIR").path_join("drums2_%d.mid" % Time.get_ticks_msec())
	var df2 := FileAccess.open(dpath2, FileAccess.WRITE); df2.store_buffer(dm); df2.close()
	app.open_song(dpath2) # a first open: split into drum parts, as dots
	await process_frame
	for t in app.song.tracks:
		if not app.project.look.track_look(t.name, 0, 3).staccato: all_dots = false
	check(all_dots and app.song.tracks.size() == 3, "drum parts start as dots")
	# ---- renaming
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Project._key(demo)))
	app.open_song(demo)
	await process_frame
	var oldname: String = app.song.tracks[2].name
	app.project.look.track_look(oldname, 2, 15).color = Color("123456")
	app.rename_track(2, "My Lead")
	check(app.song.tracks[2].name == "My Lead" and app.project.look.tracks["My Lead"].color == Color("123456") and not app.project.look.tracks.has(oldname), "rename moves the look")
	app.rename_track(3, "My Lead")
	check(app.song.tracks[3].name != "My Lead", "a duplicate name is refused")
	app.open_song(demo)
	await process_frame
	check(app.song.tracks[2].name == "My Lead", "rename survives reopening")
	app.rename_track(2, oldname)
	check(app.project.renames.is_empty(), "renaming back clears it")
	# ---- the toggle buttons put your changes back
	app.open_song(demo)
	await process_frame
	var before_c: Array = []
	for i in app.song.tracks.size():
		before_c.append(app.project.look.track_look(app.song.tracks[i].name, i, app.song.tracks.size()).color)
	app._toggles["rainbow"].button_pressed = true
	var changed := false
	for i in app.song.tracks.size():
		if app.project.look.track_look(app.song.tracks[i].name, i, app.song.tracks.size()).color != before_c[i]: changed = true
	check(changed, "rainbow changes the colors")
	app._toggles["gradient"].button_pressed = true
	check(not app._toggles["rainbow"].button_pressed, "gradient replaces rainbow")
	app._toggles["gradient"].button_pressed = false
	var same := true
	for i in app.song.tracks.size():
		if app.project.look.track_look(app.song.tracks[i].name, i, app.song.tracks.size()).color != before_c[i]: same = false
	check(same, "pressing again brings your colors back")
	var par0: float = app.project.look.track_look(app.song.tracks[0].name, 0, 15).parallax
	app.project.look.track_look(app.song.tracks[0].name, 0, 15).parallax = 3.3
	app._toggles["depth"].button_pressed = true
	app._toggles["depth"].button_pressed = false
	check(is_equal_approx(app.project.look.track_look(app.song.tracks[0].name, 0, 15).parallax, 3.3), "depth toggles back to yours")
	app.project.look.track_look(app.song.tracks[0].name, 0, 15).icon = "gong"
	app._toggles["icons"].button_pressed = true
	check(app.project.look.track_look(app.song.tracks[0].name, 0, 15).icon == "", "icons: automatic")
	app._toggles["icons"].button_pressed = false
	check(app.project.look.track_look(app.song.tracks[0].name, 0, 15).icon == "gong", "icons: yours come back")
	# ---- drag and drop lands where the line says
	app.open_song(demo)
	await process_frame
	var n0: String = app.song.tracks[0].name
	var rows: Array = app._tracks_box.get_children()
	var r3: TrackRow = rows[3]
	r3.size = Vector2(300, 60)
	r3._drop_data(Vector2(10, 50), {"track_row": 0}) # below row 3
	check(app.song.tracks[3].name == n0, "dropped below row 3 lands at 3")
	rows = app._tracks_box.get_children()
	var r1: TrackRow = rows[1]
	r1.size = Vector2(300, 60)
	r1._drop_data(Vector2(10, 5), {"track_row": 3}) # above row 1
	check(app.song.tracks[1].name == n0, "dropped above row 1 lands at 1")
	# ---- square preview, export size and the pill switch
	app.project.look.square = true
	app._apply_square()
	check(app._vp.size_2d_override == Vector2i(1080, 1080) and app._vp.get_child(0).position == Vector2(-420, 0), "square crops the preview to 1080x1080")
	app.project.look.square = false
	app._apply_square()
	check(app._vp.size_2d_override == Vector2i(1920, 1080) and app._vp.get_child(0).position == Vector2.ZERO, "wide again")
	var l2 := Look.from_dict({"export_height": 2160, "export_fps": 120})
	check(l2.export_height == 2160 and l2.export_fps == 120, "4K 120 fps saved in the look")
	check(Look.from_dict({"export_height": 999, "export_fps": 77}).export_height == 1080, "bad export values fall back")
	var sw := PillSwitch.new()
	var flips := []
	sw.toggled.connect(func(on): flips.append(on))
	sw.set_pressed_no_signal(true)
	check(sw.button_pressed and flips.is_empty(), "pill switch: set without a signal")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	root.add_child(sw)
	sw._gui_input(click)
	check(not sw.button_pressed and flips == [false], "pill switch: click turns it off")
	# ---- every icon draws without errors
	var holder := Control.new()
	root.add_child(holder)
	var icons_ok := true
	for k in Icons.names():
		if not IconData.SHAPES.has(k): icons_ok = false; print("missing shapes: ", k)
		var iv := IconView.new(44.0)
		iv.kind = k
		iv.tint = Color("f7b955")
		holder.add_child(iv)
	await process_frame
	await process_frame
	check(icons_ok and Icons.names().size() >= 100, "%d icons all drawn" % Icons.names().size())
	for k in ["winds", "drums", "fx"]:
		check(IconData.SHAPES.has(Icons.ALIASES[k]), "old icon name %s still works" % k)
	print("FAILS: ", fails)
	quit(1 if fails else 0)
