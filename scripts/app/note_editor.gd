## The note editor: the piano roll ([NoteCanvas]) with its toolbar: which
## track, snapping, undo, delete, the velocity of the selection, saving the
## fixed MIDI, and undoing every edit.
class_name NoteEditor
extends VBoxContainer

signal edited
signal export_requested
signal revert_requested

var app
var canvas: NoteCanvas
var _track_pick: OptionButton
var _snap: OptionButton
var _undo_btn: Button
var _redo_btn: Button
var _delete_btn: Button
var _vel: SpinBox
var _info: Label

const SNAPS := [["Off", 0.0], ["1 beat", 1.0], ["1/2", 0.5], ["1/4", 0.25], ["1/8", 0.125], ["1/16", 0.0625]]

func setup(the_app) -> void:
	app = the_app
	add_theme_constant_override("separation", 6)
	size_flags_horizontal = SIZE_EXPAND_FILL
	clip_contents = true
	custom_minimum_size.x = 0
	var bar := HFlowContainer.new()
	bar.add_theme_constant_override("h_separation", 6)
	bar.add_theme_constant_override("v_separation", 6)
	add_child(bar)
	_track_pick = OptionButton.new()
	_track_pick.custom_minimum_size.x = 170
	_track_pick.tooltip_text = "The track you're editing"
	_track_pick.item_selected.connect(func(i): canvas.set_track(i))
	bar.add_child(_track_pick)
	_snap = OptionButton.new()
	for s in SNAPS:
		_snap.add_item("Snap: " + s[0])
	_snap.selected = 3
	_snap.tooltip_text = "Snap moves, resizes and new notes to the beat grid"
	_snap.item_selected.connect(func(i): canvas.snap_beats = SNAPS[i][1])
	bar.add_child(_snap)
	_undo_btn = _button(bar, "Undo", "⌘Z", func(): canvas.undo())
	_redo_btn = _button(bar, "Redo", "⇧⌘Z", func(): canvas.redo())
	_delete_btn = _button(bar, "Delete", "Delete the selected notes (Delete key; or right-click a note)", func(): canvas.delete_selected())
	_vel = SpinBox.new()
	_vel.min_value = 1
	_vel.max_value = 127
	_vel.prefix = "Velocity "
	_vel.value = 100
	_vel.tooltip_text = "Velocity of the selected notes"
	_vel.value_changed.connect(func(v): canvas.set_velocity(int(v)))
	bar.add_child(_vel)
	_info = Label.new()
	_info.custom_minimum_size.x = 90
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_info.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	bar.add_child(_info)
	_button(bar, "Save MIDI…", "Write the song, with your edits, as a MIDI file", func(): export_requested.emit())
	_button(bar, "Revert all", "Throw away every edit and go back to the file", func(): revert_requested.emit())

	canvas = NoteCanvas.new()
	canvas.app = app
	canvas.size_flags_vertical = SIZE_EXPAND_FILL
	canvas.edited.connect(func(): _sync(); edited.emit())
	canvas.selection_changed.connect(_sync)
	canvas.seek_requested.connect(func(t): app.seek_to(t))
	add_child(canvas)
	var hint := Label.new()
	hint.text = "Drag: move · drag a note's right edge: resize · double-click: add · right-click: delete · click a piano key: select that pitch (keyswitches) · scroll: pan · ⌘-scroll: zoom"
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size.x = 1 # wraps to the room there is, never widens the window
	add_child(hint)

func _button(bar: Control, text: String, tip: String, on: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.pressed.connect(on)
	bar.add_child(b)
	return b

## The song to edit (null: nothing).
func open_song(song: Song, look: Look) -> void:
	canvas.song = song
	canvas.look = look
	canvas.clear_history()
	_track_pick.clear()
	if song:
		for t in song.tracks:
			_track_pick.add_item(t.name)
	var i := clampi(canvas.track_index, 0, maxi((song.tracks.size() if song else 1) - 1, 0))
	_track_pick.selected = i
	canvas.set_track(i)
	_sync()

func show_track(i: int) -> void:
	if canvas.song == null or i < 0 or i >= canvas.song.tracks.size():
		return
	_track_pick.selected = i
	canvas.set_track(i)
	_sync()

func _sync() -> void:
	_undo_btn.disabled = not canvas.can_undo()
	_redo_btn.disabled = not canvas.can_redo()
	var n := canvas.selected.size()
	_delete_btn.disabled = n == 0
	_vel.editable = n > 0
	_info.text = "%d selected" % n if n > 0 else "%d notes" % (canvas.track().notes.size() if canvas.track() else 0)
	if n > 0:
		_vel.set_value_no_signal(canvas.selected[0].velocity)
	canvas.queue_redraw()
