## Where the notes of a MIDI dropped on the editor go when they replace a
## track: the timing rules, apart from the window so they can be tested.
##
## A re-exported track can come two ways: with the empty bars before it kept
## (its first note is in the same bar as the old one: it fits as it is) or
## trimmed to start at the song's very start (it must be moved to the bar the
## old track's notes began in). Either way the notes keep their place within
## their bar; only whole bars are added.
class_name TrackReplace
extends RefCounted

const BEATS_PER_BAR := 4.0

static func _first(notes: Array) -> float:
	var t := INF
	for n in notes:
		t = minf(t, n.start)
	return t

## The bar (counting from 0) a time falls in, with [param bpm] and four beats
## to the bar.
static func bar_of(seconds: float, bpm: float) -> int:
	return int(floor(seconds * bpm / 60.0 / BEATS_PER_BAR + 1e-6))

## Whether to offer "start where the old notes started" as the first choice:
## true when the dropped notes begin in the first bar but the old ones didn't.
static func default_align(old_notes: Array, new_notes: Array, song_bpm: float, file_bpm: float, match_tempo := true) -> bool:
	if old_notes.is_empty() or new_notes.is_empty():
		return false
	var scale := file_bpm / song_bpm if match_tempo else 1.0
	return bar_of(_first(new_notes) * scale, song_bpm) == 0 and bar_of(_first(old_notes), song_bpm) > 0

## The dropped notes (copies) placed for the track: their times scaled to the
## song's tempo if [param match_tempo], and, if [param align_bar] and the track
## had notes, moved by whole bars so the first one is in the bar the old
## track's first note was in.
static func plan(old_notes: Array, new_notes: Array, song_bpm: float, file_bpm: float, align_bar: bool, match_tempo: bool) -> Array[Song.Note]:
	var scale := file_bpm / song_bpm if match_tempo else 1.0
	var shift := 0.0
	if align_bar and not old_notes.is_empty() and not new_notes.is_empty():
		var bar_len := BEATS_PER_BAR * 60.0 / song_bpm
		shift = float(bar_of(_first(old_notes), song_bpm) - bar_of(_first(new_notes) * scale, song_bpm)) * bar_len
	var out: Array[Song.Note] = []
	for n in new_notes:
		var start := maxf(n.start * scale + shift, 0.0)
		var stop := maxf(n.end * scale + shift, start + 0.01)
		out.append(Song.make_note(n.pitch, start, stop, n.velocity, n.release))
	return out
