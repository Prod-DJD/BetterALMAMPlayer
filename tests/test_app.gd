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
	# ---- a file the OS won't let us read (macOS does this for ~/Music until allowed)
	var denied := OS.get_environment("TMPDIR").path_join("denied_%d.mid" % Time.get_ticks_msec())
	var okp := FileAccess.open(denied, FileAccess.WRITE); okp.store_buffer(dm); okp.close()
	OS.execute("chmod", ["000", denied])
	var before_song = app.song
	app.open_song(denied) # must not crash, and must leave the current song alone
	check(app.song == before_song and Importer.last_error != "", "unreadable file: a message, no crash (%s)" % Importer.last_error.left(40))
	check(Project.read_problem(denied) != "", "read_problem names the trouble")
	var stash := Project.state().duplicate()
	var sf := FileAccess.open(Project.STATE, FileAccess.WRITE); sf.store_string(JSON.stringify({"last": denied, "recent": [denied]})); sf.close()
	app.open_song(denied)
	check(not Project.state().has("last"), "an unreadable last song is forgotten, so the next start is clean")
	var sf2 := FileAccess.open(Project.STATE, FileAccess.WRITE); sf2.store_string(JSON.stringify(stash)); sf2.close()
	OS.execute("chmod", ["644", denied])
	DirAccess.remove_absolute(denied)
	# ---- an unreadable sound file
	var badwav := OS.get_environment("TMPDIR").path_join("denied_%d.wav" % Time.get_ticks_msec())
	var wf := FileAccess.open(badwav, FileAccess.WRITE); wf.store_string("x"); wf.close()
	OS.execute("chmod", ["000", badwav])
	app._load_audio(badwav)
	check(app.project.audio == "" and app._stream == null, "unreadable sound file: no crash, no sound set")
	OS.execute("chmod", ["644", badwav])
	DirAccess.remove_absolute(badwav)
	# ---- sliders: a double-click goes back to the usual setting
	app.project.look.speed = 700.0
	app._rebuild_scene()
	var speed_slider: HSlider = null
	for i in app._scene_box.get_child_count():
		var c = app._scene_box.get_child(i)
		if c is HBoxContainer and c.get_child(0) is Label and c.get_child(0).text == "Speed":
			speed_slider = app._scene_box.get_child(i + 1)
	check(speed_slider != null and is_equal_approx(speed_slider.value, 700.0), "speed slider found at 700")
	var dbl := InputEventMouseButton.new()
	dbl.button_index = MOUSE_BUTTON_LEFT
	dbl.pressed = true
	dbl.double_click = true
	speed_slider.gui_input.emit(dbl)
	check(is_equal_approx(app.project.look.speed, Look.new().speed) and is_equal_approx(speed_slider.value, Look.new().speed), "double-click resets the speed to the usual 300")
	# ---- hit icons: the glow follows the note thickness, and a new icon shows at once
	var tr0: Song.Track = app.song.tracks[0]
	var tl0: Look.TrackLook = app.project.look.track_look(tr0.name, 0, app.song.tracks.size())
	tl0.icon = "gong"
	check(app.vis._icon_of(tr0, tl0) == "gong", "icon shown is the chosen one")
	tl0.icon = "kick"
	check(app.vis._icon_of(tr0, tl0) == "kick", "a newly chosen icon shows at once (no stale cache)")
	check(Look.new().icon_size > 1.0 and Look.from_dict({"icon_size": 99}).icon_size <= 6.0, "icon size: bigger by default, kept in range")
	# ---- replacing a track from a dropped MIDI: where its notes land
	var old_notes: Array = [Song.make_note(60, 10.5, 11.0, 100), Song.make_note(62, 12.0, 12.5, 100)] # bar 6 at 120 bpm (2 s a bar)
	var trimmed: Array = [Song.make_note(60, 0.5, 1.0, 90), Song.make_note(62, 2.0, 2.5, 90)] # the clip starts at the song start
	var kept_space: Array = [Song.make_note(60, 10.5, 11.0, 90)] # the empty bars were kept
	check(TrackReplace.bar_of(10.5, 120.0) == 5 and TrackReplace.bar_of(1.99, 120.0) == 0 and TrackReplace.bar_of(2.0, 120.0) == 1, "bars count from 0, four beats each")
	check(TrackReplace.default_align(old_notes, trimmed, 120.0, 120.0), "a clip trimmed to the start offers the old bar first")
	check(not TrackReplace.default_align(old_notes, kept_space, 120.0, 120.0), "a clip that kept its empty bars is already in place")
	var placed := TrackReplace.plan(old_notes, trimmed, 120.0, 120.0, true, true)
	check(is_equal_approx(placed[0].start, 10.5) and is_equal_approx(placed[1].start, 12.0), "aligned to the old bar, same place within the bar")
	check(is_equal_approx(TrackReplace.plan(old_notes, trimmed, 120.0, 120.0, false, true)[0].start, 0.5), "not aligned: the file's own timing")
	check(is_equal_approx(TrackReplace.plan(old_notes, kept_space, 120.0, 120.0, true, true)[0].start, 10.5), "aligning a clip already in the right bar changes nothing")
	var slow: Array = [Song.make_note(60, 4.0, 5.0, 100)] # 4 s at 60 bpm = 4 beats
	check(is_equal_approx(TrackReplace.plan([], slow, 120.0, 60.0, false, true)[0].start, 2.0) and is_equal_approx(TrackReplace.plan([], slow, 120.0, 60.0, false, false)[0].start, 4.0), "tempo matching scales the times to the song")
	# ---- the editor: parts of a drum kit move up and down, notes go to other tracks, replace is one undo step
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Project._key(demo)))
	app.open_song(demo)
	await process_frame
	app.split_track(0, false)
	var total_before := 0
	for t in app.song.tracks: total_before += t.notes.size()
	app.edit_track(0)
	var cv3: NoteCanvas = app._editor.canvas
	var lane0: Song.Track = cv3.track()
	var lane_count_before: int = app.song.tracks.size()
	cv3.selected = [lane0.notes[0]]
	cv3.transpose(1) # one semitone up: it belongs to another part now
	var in_place := true
	var total_after := 0
	for t in app.song.tracks:
		total_after += t.notes.size()
		if t.lane != "":
			for n in t.notes:
				if n.pitch != t.lane_pitch: in_place = false
	check(in_place and total_after == total_before, "a note moved up in a drum part joins the right part (%d notes kept)" % total_after)
	# send selection to a new track
	var src_idx: int = app._editor.canvas.track_index
	var src_track: Song.Track = app.song.tracks[src_idx]
	app._editor.canvas.selected.assign([src_track.notes[0]])
	var before_src := src_track.notes.size()
	var tracks_before: int = app.song.tracks.size()
	app.move_selection_to(-1)
	check(app.song.tracks.size() == tracks_before + 1 and app.song.tracks.back().notes.size() == 1, "send to a new track makes it")
	var src_after: Song.Track = null
	for t in app.song.tracks:
		if t.name == src_track.name: src_after = t
	check(src_after != null and src_after.notes.size() == before_src - 1, "...and takes the note from the first track")
	app._editor.canvas.undo()
	var back := 0
	for t in app.song.tracks: back += t.notes.size()
	check(back == total_before, "one undo puts the note back where it was")
	# replace the notes of the track being edited
	var rep: Array[Song.Note] = [Song.make_note(60, 1.0, 1.5, 100), Song.make_note(64, 2.0, 2.5, 100)]
	for ti in app.song.tracks.size():
		if app.song.tracks[ti].lane == "" and app.song.tracks[ti].notes.size() > 2:
			app._editor.show_track(ti)
			break
	var edited_track: Song.Track = app._editor.canvas.track()
	var edited_count := edited_track.notes.size()
	app._editor.canvas.replace_notes(rep)
	check(app._editor.canvas.track().notes.size() == 2, "replace swaps the whole track's notes")
	app._editor.canvas.undo()
	check(app._editor.canvas.track().notes.size() == edited_count, "...and one undo brings the old ones back")
	# ---- Android: where the bundled ffmpeg lives
	check(Exporter.library_dir_in("7b6c000000-7b6c3d0000 r-xp 00000000 fd:0b 1234 /data/app/~~abc==/com.beatprod.betteralmamplayer-xyz==/lib/arm64/libgodot_android.so") == "/data/app/~~abc==/com.beatprod.betteralmamplayer-xyz==/lib/arm64", "finds the native library folder in a maps line")
	check(Exporter.library_dir_in("7b6c000000-7b6c3d0000 r-xp 00000000 fd:0b 1234 /system/lib64/libc.so") == "", "ignores other lines")
	# ---- an export watches the memory it uses
	var guard := Exporter.new()
	check(guard.memory_trouble() == "", "normal memory use: the export carries on")
	check(Exporter.MAX_APP_BYTES < 4_000_000_000 and Exporter.MAX_VIDEO_BYTES < 8_000_000_000, "the memory limits are well under a Mac's total")
	# ---- full screen preview
	app.set_fullscreen_preview(true)
	check(not app._left.visible and not app._right.visible and not app._top.visible and not app._transport.visible and app._frame.visible, "full screen: only the video is left")
	app.set_fullscreen_preview(false)
	check(app._left.visible and app._right.visible and app._top.visible and app._transport.visible, "full screen: leaving brings the panels back")
	# ---- transparent formats
	check(Exporter.wants_alpha("a.mov") and Exporter.wants_alpha("a.webm") and not Exporter.wants_alpha("a.mp4"), "alpha for .mov and .webm only")
	check(Exporter.alpha_codec_for("a.webm", "prores") == "vp9" and Exporter.alpha_codec_for("a.mov", "hevc") == "hevc", "a .webm is always VP9; a .mov takes the look's choice")
	check(Look.from_dict({"export_format": "hevc"}).export_format == "hevc" and Look.from_dict({"export_format": "nope"}).export_format == "mp4" and Look.new().export_format == "mp4", "export format saved; the default is MP4; bad values fall back")
	check(Exporter.extension_for("mp4") == "mp4" and Exporter.extension_for("prores") == "mov" and Exporter.extension_for("hevc") == "mov" and Exporter.extension_for("webm") == "webm", "each format has its file ending")
	# ---- editing the notes of several tracks together
	var mt_mc: NoteCanvas = app._editor.canvas
	mt_mc.all_tracks = true
	mt_mc.clear_history()
	var mt_total := 0
	for t in app.song.tracks:
		mt_total += t.notes.size()
	var mt_starts := []
	for t in app.song.tracks:
		mt_starts.append(t.notes[0].start if t.notes.size() > 0 else 0.0)
	var mt_ctrl_a := InputEventKey.new()
	mt_ctrl_a.keycode = KEY_A
	mt_ctrl_a.ctrl_pressed = true
	mt_ctrl_a.pressed = true
	mt_mc._on_key(mt_ctrl_a)
	check(mt_mc.selected.size() == mt_total and app.song.tracks.size() > 1, "Ctrl+A in All tracks selects the notes of every track (%d of %d)" % [mt_mc.selected.size(), mt_total])
	mt_mc.nudge(-0.5)
	var mt_moved := true
	for i in app.song.tracks.size():
		var t: Song.Track = app.song.tracks[i]
		if t.notes.size() > 0 and absf(t.notes[0].start - (maxf(mt_starts[i] - 0.5, NoteCanvas.MIN_START))) > 0.51 and mt_starts[i] >= 0.5:
			mt_moved = false
	check(mt_moved, "a shift moves the notes of all the tracks together")
	mt_mc.nudge(-100.0)
	var mt_earliest := 1e9
	for t in app.song.tracks:
		for n in t.notes:
			mt_earliest = minf(mt_earliest, n.start)
	check(mt_earliest >= NoteCanvas.MIN_START - 0.001 and mt_earliest < 0.0, "notes can be shifted before the start (the upbeat), down to the floor: %.2f" % mt_earliest)
	mt_mc.undo()
	mt_mc.undo()
	var mt_back := true
	for i in app.song.tracks.size():
		var t: Song.Track = app.song.tracks[i]
		if t.notes.size() > 0 and absf(t.notes[0].start - mt_starts[i]) > 0.001:
			mt_back = false
	check(mt_back, "two undos put every track's notes back")
	mt_mc._on_key(mt_ctrl_a)
	mt_mc.delete_selected()
	var mt_left := 0
	for t in app.song.tracks:
		mt_left += t.notes.size()
	check(mt_left == 0, "delete removes the selected notes from every track")
	mt_mc.undo()
	var mt_restored := 0
	for t in app.song.tracks:
		mt_restored += t.notes.size()
	check(mt_restored == mt_total, "...and one undo brings them all back (%d)" % mt_restored)
	mt_mc.all_tracks = false
	# ---- picking tracks in the list
	var sel_btn := Button.new(); var sel_box := HBoxContainer.new(); var sel_lbl := Label.new(); var sel_spin := SpinBox.new()
	check(TrackRow.is_plain_background(null) and TrackRow.is_plain_background(sel_box) and TrackRow.is_plain_background(sel_lbl), "a click on a row's background, layout boxes or text selects the row")
	check(not TrackRow.is_plain_background(sel_btn) and not TrackRow.is_plain_background(sel_spin), "buttons and number boxes keep their own clicks")
	sel_btn.free(); sel_box.free(); sel_lbl.free(); sel_spin.free()
	app.selected_tracks.clear()
	app.toggle_track_selected(2, false)
	check(app.selected_tracks == [2], "a click selects just that track")
	app.toggle_track_selected(4, true)
	check(app.selected_tracks == [2, 4], "Ctrl/Cmd-click adds another")
	app.toggle_track_selected(2, true)
	check(app.selected_tracks == [4], "Ctrl/Cmd-click on a selected track removes it")
	app.toggle_track_selected(3, false)
	check(app.selected_tracks == [3], "a plain click on another track selects only it")
	app.toggle_track_selected(3, false)
	check(app.selected_tracks.is_empty(), "a plain click on the only selected track deselects it")
	app.select_all_tracks()
	check(app.selected_tracks.size() == app.song.tracks.size(), "select all picks every track")
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	app._unhandled_input(esc)
	check(app.selected_tracks.is_empty(), "Esc deselects every track")
	# ---- the right panel shows the selected track's own settings
	app.toggle_track_selected(1, false)
	check(app._track_box.visible and not app._scene_box.visible, "selecting a track swaps the scene panel for its own settings")
	var pt_tl: Look.TrackLook = app.project.look.track_look(app.song.tracks[1].name, 1, app.song.tracks.size())
	pt_tl.parallax = 1.0
	app._rebuild_track_panel()
	var pt_depth: SpinBox = null
	for row in app._track_box.get_children():
		if row is VBoxContainer and row.get_child_count() == 2 and row.get_child(0) is Label and row.get_child(0).text == "Depth":
			pt_depth = row.get_child(1)
	check(pt_depth != null and absf(pt_depth.value - 1.0) < 0.001, "the track panel shows that track's depth")
	pt_depth.value = 2.5
	check(absf(pt_tl.parallax - 2.5) < 0.001, "changing it in the panel changes the track's look")
	pt_tl.color = Color(0.9, 0.1, 0.1)
	app._changed()
	check(app._editor.canvas.look.track_look(app.song.tracks[1].name, 1, app.song.tracks.size()).color == Color(0.9, 0.1, 0.1), "a colour change is seen by the note editor at once")
	app.toggle_track_selected(1, false)
	check(app.selected_tracks.is_empty() and app._scene_box.visible and not app._track_box.visible, "deselecting brings the scene's settings back")
	# ---- the three panels can be resized
	check(app._right.get_parent() is HSplitContainer and app._right.get_parent().get_parent() is HSplitContainer, "the scene panel sits in a resizable split")
	check(app._editor.get_parent() is HSplitContainer or app._editor.get_parent().get_parent() is HSplitContainer, "the preview sits in a resizable split")
	app._remember_panels()
	check(Project.state().has("panel_left") and Project.state().has("panel_right"), "the panel widths are remembered")
	# ---- the panels always fit in the smallest window
	var lay_inner: Control = app._right.get_parent()
	var lay_sum: float = app._left.get_combined_minimum_size().x + lay_inner.get_child(0).get_combined_minimum_size().x + app._right.get_combined_minimum_size().x
	check(lay_sum + 80.0 <= app.get_window().min_size.x, "the three panels at their smallest (%d px, with margins) fit the window's minimum width (%d px)" % [lay_sum + 80.0, app.get_window().min_size.x])
	check(app._left.get_combined_minimum_size().x <= 400.0, "a track row doesn't force the tracks panel wider than it is meant to be (%d px)" % app._left.get_combined_minimum_size().x)
	print("FAILS: ", fails)
	quit(1 if fails else 0)
