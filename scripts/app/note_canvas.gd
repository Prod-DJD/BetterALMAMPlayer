## The piano roll: the song's notes over time (across) and pitch (up), one
## track at a time to edit (the others shown dim behind it).
##
##   click a note: select (shift: add) · drag it: move · drag its right
##   edge: resize · drag empty space: box-select · double-click empty
##   space: add a note · right-click a note: delete · click a piano key:
##   select every note of that pitch (to clear a keyswitch in one go) ·
##   Delete: delete the selection · ↑↓ ←→: move the selection · ⌘A / ⌘Z /
##   ⇧⌘Z: select all / undo / redo · scroll: pan · ⌘-scroll or pinch: zoom ·
##   click the ruler: jump there
##
## All edits go through [Song] (so the preview and the export see them) and
## each can be undone.
class_name NoteCanvas
extends Control

signal edited
signal selection_changed
signal seek_requested(time: float)

const KEYS_W := 64.0
const RULER_H := 26.0
const ACCENT := Color("f7b955")
const BLACK_KEYS := [1, 3, 6, 8, 10]

var app
var song: Song
var look: Look
var track_index := 0
var px_per_s := 140.0
var scroll_t := -0.5
var row_h := 16.0
## The pitch of the grid's top row.
var top_pitch := 90.0
## Grid and snap, in beats (0: no snapping).
var snap_beats := 0.25
## Show the other tracks' notes behind the one being edited.
var show_others := true
var selected: Array[Song.Note] = []
## Edit notes from several tracks at once: the tracks selected in the list,
## else every track. Off: only the track being edited.
var all_tracks := false
## How far before the start a note can be moved (the upbeat; the preview starts here).
const MIN_START := -1.0

## The positions of the tracks whose notes can be picked and edited together.
func edit_indices() -> Array:
	if song == null:
		return []
	if not all_tracks:
		return [track_index]
	var picked: Array = []
	if app and app.get("selected_tracks") != null:
		picked = app.selected_tracks.filter(func(i): return i >= 0 and i < song.tracks.size())
	if not picked.is_empty():
		return picked
	var every := []
	for i in song.tracks.size():
		every.append(i)
	return every

## Every note of the tracks being edited.
func edit_notes() -> Array[Song.Note]:
	var out: Array[Song.Note] = []
	for i in edit_indices():
		out.append_array(song.tracks[i].notes)
	return out

## What to save before a change, as one undo step: the tracks being edited.
func _snapshot() -> Dictionary:
	if not all_tracks:
		return {"track": track_index, "notes": _dump(track())}
	var entries := []
	for i in edit_indices():
		entries.append({"track": i, "notes": _dump(song.tracks[i])})
	return {"multi": entries}

var _undo: Array = []
var _redo: Array = []
var _mode := "" # move, resize, box, scrub
var _press := Vector2.ZERO
var _origin := {} # Note → [start, end, pitch]
var _pending_undo := {}
var _dragged := false
var _box := Rect2()
var _box_add := false
var _hover := ""

func _init() -> void:
	focus_mode = Control.FOCUS_CLICK
	clip_contents = true
	custom_minimum_size = Vector2(120, 200)

func _process(_d: float) -> void:
	if is_visible_in_tree() and app and app.playing:
		var x := t_to_x(app.vis.time)
		var w := size.x - KEYS_W
		if x > size.x - w * 0.1 or x < KEYS_W:
			scroll_t = app.vis.time - w * 0.15 / px_per_s
		queue_redraw()

# ---------------------------------------------------------------- view

func track() -> Song.Track:
	if song and track_index >= 0 and track_index < song.tracks.size():
		return song.tracks[track_index]
	return null

func snap_seconds() -> float:
	if snap_beats <= 0.0 or song == null:
		return 0.0
	return snap_beats * 60.0 / song.bpm

func t_to_x(t: float) -> float:
	return KEYS_W + (t - scroll_t) * px_per_s

func x_to_t(x: float) -> float:
	return scroll_t + (x - KEYS_W) / px_per_s

func p_to_y(p: float) -> float:
	return RULER_H + (top_pitch - p) * row_h

func y_to_p(y: float) -> int:
	return ceili(top_pitch - (y - RULER_H) / row_h)

func _rows() -> float:
	return (size.y - RULER_H) / row_h

func _clamp_view() -> void:
	top_pitch = clampf(top_pitch, _rows() - 1.0, 128.0)
	var end: float = song.length + 4.0 if song else 10.0
	scroll_t = clampf(scroll_t, -1.0, maxf(end - 1.0, 0.0))

## Shows the active track's notes: scrolled to its start, centered on its
## pitches.
func fit_track() -> void:
	var tr := track()
	if tr == null or tr.notes.is_empty():
		return
	var lo := 127
	var hi := 0
	for n in tr.notes:
		lo = mini(lo, n.pitch)
		hi = maxi(hi, n.pitch)
	# a lone keyswitch far below shouldn't pull the view down: center on the
	# bulk of the notes
	var pitches: Array = []
	for n in tr.notes:
		pitches.append(n.pitch)
	pitches.sort()
	var mid: float = (pitches[int(pitches.size() * 0.1)] + pitches[int(pitches.size() * 0.9)]) / 2.0
	top_pitch = mid + _rows() / 2.0
	scroll_t = tr.notes[0].start - 0.5
	_clamp_view()
	queue_redraw()

func set_track(i: int) -> void:
	track_index = i
	selected.clear()
	selection_changed.emit()
	fit_track()

# ---------------------------------------------------------------- drawing

func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, size), Color("1b1815"))
	if song == null:
		return
	_clamp_view()
	var grid := Rect2(KEYS_W, RULER_H, size.x - KEYS_W, size.y - RULER_H)
	# pitch rows
	var p_hi := mini(127, int(ceil(top_pitch)))
	var p_lo := maxi(0, int(floor(top_pitch - _rows())) - 1)
	for p in range(p_lo, p_hi + 1):
		var y := p_to_y(p)
		var black: bool = (p % 12) in BLACK_KEYS
		draw_rect(Rect2(KEYS_W, y, grid.size.x, row_h), Color(0, 0, 0, 0.22) if black else Color(1, 1, 1, 0.025))
		if p % 12 == 0:
			draw_line(Vector2(KEYS_W, y + row_h), Vector2(size.x, y + row_h), Color(1, 1, 1, 0.16))
	# beat grid
	var beat := 60.0 / song.bpm
	var first := floori(scroll_t / beat)
	var last := ceili(x_to_t(size.x) / beat)
	var px_beat := beat * px_per_s
	for b in range(maxi(first, 0), last + 1):
		var x := t_to_x(b * beat)
		if x < KEYS_W:
			continue
		var bar := b % 4 == 0
		if px_beat < 8.0 and not bar:
			continue
		draw_line(Vector2(x, RULER_H), Vector2(x, size.y), Color(1, 1, 1, 0.2 if bar else 0.08))
		if px_beat > 70.0:
			for q in range(1, 4):
				var qx := x + px_beat * q / 4.0
				draw_line(Vector2(qx, RULER_H), Vector2(qx, size.y), Color(1, 1, 1, 0.035))
	# the other tracks: faint outlines with a hint of fill, never solid, so
	# notes stacked on top of each other (several tracks playing the same
	# thing) can't pile up into something that looks like a note you can pick
	var count := song.tracks.size()
	var editing := edit_indices()
	for i in count:
		if i in editing or not show_others:
			continue
		var tr: Song.Track = song.tracks[i]
		var col: Color = look.track_look(tr.name, i, count).color
		var edge := Color(col.r, col.g, col.b, 0.55)
		var wash := Color(col.r, col.g, col.b, 0.05)
		for n in tr.notes:
			var r := _note_rect(n)
			if r.end.x < KEYS_W or r.position.x > size.x:
				continue
			draw_rect(r, wash)
			draw_rect(r, edge, false, 1.0)
	# the active track
	var active := track()
	for ti in editing:
		var tr: Song.Track = song.tracks[ti]
		var base: Color = look.track_look(tr.name, ti, count).color
		for n in tr.notes:
			var r := _note_rect(n)
			if r.end.x < KEYS_W or r.position.x > size.x or r.end.y < RULER_H or r.position.y > size.y:
				continue
			var c := base.lerp(Color.BLACK, 0.5 * (1.0 - n.velocity / 127.0))
			var sel := selected.has(n)
			if sel:
				c = c.lightened(0.25)
			draw_rect(r, c)
			draw_rect(r, Color.WHITE if sel else Color(0, 0, 0, 0.45), false, 1.5 if sel else 1.0)
	# box selection
	if _mode == "box":
		draw_rect(_box, Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.15))
		draw_rect(_box, ACCENT, false, 1.0)
	# playhead
	if app:
		var px := t_to_x(app.vis.time)
		if px >= KEYS_W and px <= size.x:
			draw_line(Vector2(px, RULER_H), Vector2(px, size.y), ACCENT, 1.5)
	# piano keys
	draw_rect(Rect2(0, RULER_H, KEYS_W, size.y - RULER_H), Color("26221e"))
	var lit := {}
	for n in selected:
		lit[n.pitch] = true
	for p in range(p_lo, p_hi + 1):
		var y := p_to_y(p)
		var black: bool = (p % 12) in BLACK_KEYS
		var kr := Rect2(0, y + 0.5, KEYS_W * (0.62 if black else 1.0) - 1.0, row_h - 1.0)
		var kc := Color("141210") if black else Color("d8d2c8")
		if lit.has(p):
			kc = ACCENT
		draw_rect(kr, kc)
		if p % 12 == 0 or (row_h >= 18.0 and not black):
			var label := "%s%d" % [["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"][p % 12], p / 12 - 1]
			draw_string(font, Vector2(KEYS_W - 30.0, y + row_h - 4.0), label, HORIZONTAL_ALIGNMENT_LEFT, 28.0, 11, Color(0, 0, 0, 0.7) if not black or lit.has(p) else Color(1, 1, 1, 0.6))
	# ruler
	draw_rect(Rect2(0, 0, size.x, RULER_H), Color("2a2622"))
	var step: float = 1.0
	for s in [0.25, 0.5, 1.0, 2.0, 5.0, 10.0, 30.0, 60.0]:
		step = s
		if s * px_per_s >= 70.0:
			break
	var t0 := floorf(scroll_t / step) * step
	var t := t0
	while t_to_x(t) < size.x:
		var x := t_to_x(t)
		if x >= KEYS_W and t >= 0.0:
			draw_line(Vector2(x, RULER_H - 8.0), Vector2(x, RULER_H), Color(1, 1, 1, 0.5))
			var m := int(t) / 60
			var sec := fmod(t, 60.0)
			var text := "%d:%02d" % [m, int(sec)] if step >= 1.0 else "%d:%04.1f" % [m, sec]
			draw_string(font, Vector2(x + 4.0, 14.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.6))
		t += step
	draw_rect(Rect2(0, 0, KEYS_W, RULER_H), Color("2a2622"))
	if app:
		var px := t_to_x(app.vis.time)
		if px >= KEYS_W and px <= size.x:
			draw_colored_polygon(PackedVector2Array([Vector2(px - 6, 0), Vector2(px + 6, 0), Vector2(px, 10)]), ACCENT)
	if active == null or active.notes.is_empty():
		draw_string(font, Vector2(KEYS_W + 20.0, size.y / 2.0), "No notes here. Double-click to add one.", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 1, 1, 0.5))

func _note_rect(n: Song.Note) -> Rect2:
	var x := t_to_x(n.start)
	return Rect2(x, p_to_y(n.pitch) + 1.0, maxf((n.end - n.start) * px_per_s, 3.0), row_h - 2.0)

# ---------------------------------------------------------------- picking

func _note_at(pos: Vector2) -> Song.Note:
	var indices := edit_indices()
	for k in range(indices.size() - 1, -1, -1):
		var tr: Song.Track = song.tracks[indices[k]]
		for i in range(tr.notes.size() - 1, -1, -1):
			var n := tr.notes[i]
			if _note_rect(n).grow(1.0).has_point(pos):
				return n
	return null

func _on_edge(n: Song.Note, pos: Vector2) -> bool:
	var r := _note_rect(n)
	return r.size.x > 14.0 and pos.x > r.end.x - 7.0

func _snap(t: float) -> float:
	var s := snap_seconds()
	return roundf(t / s) * s if s > 0.0 else t

# ---------------------------------------------------------------- input

func _gui_input(e: InputEvent) -> void:
	if song == null:
		return
	if e is InputEventMouseButton:
		_on_button(e)
	elif e is InputEventMouseMotion:
		_on_motion(e)
	elif e is InputEventPanGesture:
		scroll_t += e.delta.x * 12.0 / px_per_s
		top_pitch -= e.delta.y * 0.35
		_clamp_view()
		queue_redraw()
	elif e is InputEventMagnifyGesture:
		_zoom(e.factor, e.position.x)
	elif e is InputEventKey and e.pressed:
		_on_key(e)

func _zoom(factor: float, at_x: float) -> void:
	var t := x_to_t(at_x)
	px_per_s = clampf(px_per_s * factor, 12.0, 1600.0)
	scroll_t = t - (at_x - KEYS_W) / px_per_s
	_clamp_view()
	queue_redraw()

func _on_button(e: InputEventMouseButton) -> void:
	if e.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]:
		var up: bool = e.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_LEFT]
		var dir := 1.0 if up else -1.0
		if e.ctrl_pressed or e.meta_pressed:
			_zoom(1.15 if up else 1.0 / 1.15, e.position.x)
		elif e.shift_pressed or e.button_index in [MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]:
			scroll_t -= dir * 80.0 / px_per_s
		else:
			top_pitch += dir * 3.0
		_clamp_view()
		queue_redraw()
		accept_event()
		return
	if e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			grab_focus()
			_press_left(e)
		else:
			_release_left()
	elif e.button_index == MOUSE_BUTTON_RIGHT and e.pressed:
		var n := _note_at(e.position)
		if n:
			if not selected.has(n):
				selected = [n]
			delete_selected()

func _press_left(e: InputEventMouseButton) -> void:
	var pos := e.position
	_dragged = false
	if pos.y < RULER_H and pos.x >= KEYS_W:
		_mode = "scrub"
		seek_requested.emit(maxf(x_to_t(pos.x), -1.0))
		return
	if pos.x < KEYS_W and pos.y >= RULER_H:
		_select_pitch(y_to_p(pos.y), e.shift_pressed)
		return
	var n := _note_at(pos)
	if e.double_click and n == null and pos.x >= KEYS_W and pos.y >= RULER_H:
		add_note(_snap(x_to_t(pos.x)), y_to_p(pos.y))
		return
	if n:
		if e.shift_pressed:
			if selected.has(n):
				selected.erase(n)
			else:
				selected.append(n)
			selection_changed.emit()
			queue_redraw()
			if not selected.has(n):
				return
		elif not selected.has(n):
			selected = [n]
			selection_changed.emit()
		_mode = "resize" if _on_edge(n, pos) else "move"
		_press = pos
		_origin.clear()
		for s in selected:
			_origin[s] = [s.start, s.end, s.pitch]
		_pending_undo = _snapshot()
		queue_redraw()
		return
	_mode = "box"
	_press = pos
	_box = Rect2(pos, Vector2.ZERO)
	_box_add = e.shift_pressed
	if not _box_add and not selected.is_empty():
		selected.clear()
		selection_changed.emit()
	queue_redraw()

func _on_motion(e: InputEventMouseMotion) -> void:
	var pos := e.position
	match _mode:
		"scrub":
			seek_requested.emit(maxf(x_to_t(pos.x), -1.0))
		"move", "resize":
			if not _dragged and pos.distance_to(_press) < 3.0:
				return
			if not _dragged:
				_dragged = true
				_push_pending_undo()
			_drag(pos)
			queue_redraw()
		"box":
			_box = Rect2(_press, pos - _press).abs()
			_box_select()
			queue_redraw()
		_:
			var n := _note_at(pos)
			var want := Control.CURSOR_ARROW
			if n:
				want = Control.CURSOR_HSIZE if _on_edge(n, pos) else Control.CURSOR_MOVE
			elif pos.x < KEYS_W and pos.y > RULER_H:
				want = Control.CURSOR_POINTING_HAND
			mouse_default_cursor_shape = want

func _drag(pos: Vector2) -> void:
	var dt := (pos.x - _press.x) / px_per_s
	var lead: Song.Note = selected[0]
	var o: Array = _origin[lead]
	if _mode == "move":
		var min_start := 1e9
		var lo := 127
		var hi := 0
		for s in selected:
			min_start = minf(min_start, _origin[s][0])
			lo = mini(lo, _origin[s][2])
			hi = maxi(hi, _origin[s][2])
		var delta: float = _snap(o[0] + dt) - o[0]
		delta = maxf(delta, MIN_START - min_start)
		var dp := roundi(-(pos.y - _press.y) / row_h)
		dp = clampi(dp, -lo, 127 - hi)
		for s in selected:
			var og: Array = _origin[s]
			s.start = og[0] + delta
			s.end = og[1] + delta
			s.pitch = og[2] + dp
	else:
		var delta: float = _snap(o[1] + dt) - o[1]
		var min_len := maxf(snap_seconds(), 0.02)
		for s in selected:
			var og: Array = _origin[s]
			s.end = maxf(og[1] + delta, s.start + min_len if snap_seconds() > 0.0 else s.start + 0.02)

func _release_left() -> void:
	if _mode in ["move", "resize"] and _dragged:
		song.refresh()
		edited.emit()
	_mode = ""
	_pending_undo = {}
	queue_redraw()

func _box_select() -> void:
	if song == null:
		return
	var before: Array = selected.duplicate() if _box_add else []
	var fresh: Array[Song.Note] = []
	for n in edit_notes():
		if _box.intersects(_note_rect(n)) or before.has(n):
			fresh.append(n)
	if fresh != selected:
		selected = fresh
		selection_changed.emit()

func _select_pitch(p: int, add: bool) -> void:
	if song == null:
		return
	var fresh: Array[Song.Note] = []
	if add:
		fresh.append_array(selected)
	for n in edit_notes():
		if n.pitch == p and not fresh.has(n):
			fresh.append(n)
	selected = fresh
	selection_changed.emit()
	queue_redraw()

func _on_key(e: InputEventKey) -> void:
	var cmd := e.meta_pressed or e.ctrl_pressed
	match e.keycode:
		KEY_DELETE, KEY_BACKSPACE:
			if not selected.is_empty():
				delete_selected()
				accept_event()
		KEY_A:
			if cmd and song != null:
				selected.assign(edit_notes())
				selection_changed.emit()
				queue_redraw()
				accept_event()
		KEY_Z:
			if cmd:
				if e.shift_pressed:
					redo()
				else:
					undo()
				accept_event()
		KEY_Y:
			if cmd:
				redo()
				accept_event()
		KEY_UP, KEY_DOWN:
			if not selected.is_empty():
				transpose((12 if e.shift_pressed else 1) * (1 if e.keycode == KEY_UP else -1))
				accept_event()
		KEY_LEFT, KEY_RIGHT:
			if not selected.is_empty():
				var step := snap_seconds() if snap_seconds() > 0.0 else 0.01
				nudge(step * (1.0 if e.keycode == KEY_RIGHT else -1.0))
				accept_event()
		KEY_ESCAPE:
			if not selected.is_empty():
				selected.clear()
				selection_changed.emit()
				queue_redraw()
				accept_event()

# ---------------------------------------------------------------- editing

func _dump(tr: Song.Track) -> Array:
	var out := []
	if tr:
		for n in tr.notes:
			out.append([n.pitch, n.start, n.end, n.velocity, n.release])
	return out

func _push_undo() -> void:
	_pending_undo = _snapshot()
	_push_pending_undo()

func _push_pending_undo() -> void:
	if _pending_undo.is_empty():
		return
	_undo.append(_pending_undo)
	if _undo.size() > 200:
		_undo.pop_front()
	_redo.clear()
	_pending_undo = {}

## Puts one track's notes back as the entry saved them; returns what they
## were just before (for redo).
func _restore_one(entry: Dictionary) -> Dictionary:
	var idx: int = entry["track"]
	if idx < 0 or idx >= song.tracks.size():
		return {"track": idx, "notes": []}
	var tr: Song.Track = song.tracks[idx]
	var now := {"track": idx, "notes": _dump(tr)}
	var notes: Array[Song.Note] = []
	for d in entry["notes"]:
		notes.append(Song.make_note(d[0], d[1], d[2], d[3], d[4] if d.size() > 4 else -1))
	tr.notes = notes
	return now

func _restore(entry: Dictionary) -> Dictionary:
	var now := {}
	if entry.has("multi"): # notes moved between tracks: every track involved goes back
		now = {"multi": []}
		for e in entry["multi"]:
			now["multi"].append(_restore_one(e))
	else:
		now = _restore_one(entry)
	selected.clear()
	song.refresh()
	selection_changed.emit()
	edited.emit()
	queue_redraw()
	return now

## Saves the notes of several tracks as one undo step (for moving notes
## from one track to another).
func push_multi_undo(indices: Array) -> void:
	var entries := []
	for i in indices:
		if i >= 0 and i < song.tracks.size():
			entries.append({"track": i, "notes": _dump(song.tracks[i])})
	_undo.append({"multi": entries})
	if _undo.size() > 200:
		_undo.pop_front()
	_redo.clear()

## Replaces every note of the track being edited with [param new_notes] (one
## undo step).
func replace_notes(new_notes: Array[Song.Note]) -> void:
	var tr := track()
	if tr == null:
		return
	_push_undo()
	tr.notes = new_notes
	selected.clear()
	song.refresh()
	selection_changed.emit()
	edited.emit()
	queue_redraw()

func undo() -> void:
	if _undo.is_empty():
		return
	_redo.append(_restore(_undo.pop_back()))

func redo() -> void:
	if _redo.is_empty():
		return
	_undo.append(_restore(_redo.pop_back()))

func can_undo() -> bool:
	return not _undo.is_empty()

func can_redo() -> bool:
	return not _redo.is_empty()

func clear_history() -> void:
	_undo.clear()
	_redo.clear()
	selected.clear()

func delete_selected() -> void:
	if song == null or selected.is_empty():
		return
	_push_undo()
	for ti in edit_indices():
		var tr: Song.Track = song.tracks[ti]
		var kept: Array[Song.Note] = []
		for n in tr.notes:
			if not selected.has(n):
				kept.append(n)
		tr.notes = kept
	selected.clear()
	song.refresh()
	selection_changed.emit()
	edited.emit()
	queue_redraw()

func add_note(start: float, pitch: int) -> void:
	var tr := track()
	if tr == null:
		return
	_push_undo()
	var length := snap_seconds() if snap_seconds() > 0.0 else 0.25
	# a note added to a part of a drum kit starts on that part's pitch
	if tr.lane_pitch >= 0:
		pitch = tr.lane_pitch
	var n := Song.make_note(clampi(pitch, 0, 127), maxf(start, 0.0), maxf(start, 0.0) + length, 100)
	tr.notes.append(n)
	selected = [n]
	song.refresh()
	selection_changed.emit()
	edited.emit()
	queue_redraw()

func transpose(semitones: int) -> void:
	if selected.is_empty():
		return
	_push_undo()
	for n in selected:
		n.pitch = clampi(n.pitch + semitones, 0, 127)
	song.refresh()
	edited.emit()
	queue_redraw()

func nudge(seconds: float) -> void:
	if selected.is_empty():
		return
	var first := 1e9
	for n in selected:
		first = minf(first, n.start)
	seconds = maxf(seconds, MIN_START - first)
	_push_undo()
	for n in selected:
		n.start += seconds
		n.end += seconds
	song.refresh()
	edited.emit()
	queue_redraw()

func set_velocity(v: int) -> void:
	if selected.is_empty():
		return
	_push_undo()
	for n in selected:
		n.velocity = clampi(v, 1, 127)
	edited.emit()
	queue_redraw()
