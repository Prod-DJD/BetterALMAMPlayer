## A MIDI file read for drawing: every track's notes and pitch bends in
## seconds (the tempo map applied once, here), its name, and the range of
## notes used. Nothing about the look lives here.
class_name Song
extends RefCounted

class Note:
	var pitch: int
	var start: float
	var end: float
	var velocity: int

class Track:
	var name := ""
	## General MIDI program (0-127) the file selects, or -1: picks the icon.
	var program := -1
	## Which MIDI track it came from (tracks with no notes are skipped).
	var source := 0
	var notes: Array[Note] = []
	## [seconds, bend -1…1], in time order.
	var bends: Array[Vector2] = []
	## The longest note, for finding what's on screen quickly.
	var longest := 0.0

var path := ""
## Beats per minute at the start (for snapping in the editor; the timing
## itself is always in seconds).
var bpm := 120.0
var tracks: Array[Track] = []
var lowest := 127
var highest := 0
var length := 0.0

## Reads [midi_path]; returns null (and pushes an error) if it can't.
static func load_file(midi_path: String) -> Song:
	var reader := SMF.new()
	var result := reader.read_file(midi_path)
	if result.error != OK or result.data == null:
		push_error("Couldn't read MIDI %s (error %d)" % [midi_path, result.error])
		return null
	var song := Song.new()
	song.path = midi_path
	song._build(result.data)
	return song

func _build(data) -> void:
	var timebase: int = max(1, data.timebase)
	# the tempo map, from every track (type 1 files keep it in track 0)
	var tempos: Array = [] # [tick, microseconds per beat]
	for t in data.tracks:
		for e in t.events:
			if e.event.type == SMF.MIDIEventType.system_event and e.event.args.has("bpm"):
				tempos.append([e.time, e.event.args["bpm"]])
	tempos.sort_custom(func(a, b): return a[0] < b[0])
	if tempos.size() > 0 and tempos[0][1] > 0:
		bpm = 6e7 / float(tempos[0][1])
	# seconds at each tempo change, so any tick converts directly
	var marks: Array = [[0, 500000, 0.0]] # [tick, us/beat, seconds]
	for tp in tempos:
		var last = marks[-1]
		var secs: float = last[2] + float(tp[0] - last[0]) * last[1] / timebase / 1e6
		if tp[0] == last[0]:
			marks[-1] = [tp[0], tp[1], last[2]]
		else:
			marks.append([tp[0], tp[1], secs])
	var to_seconds := func(tick: int) -> float:
		var i := marks.size() - 1
		while i > 0 and marks[i][0] > tick:
			i -= 1
		return marks[i][2] + float(tick - marks[i][0]) * marks[i][1] / timebase / 1e6

	var index := 0
	for t in data.tracks:
		index += 1
		var track := Track.new()
		track.source = index - 1
		var open := {} # (channel, pitch) → [Note…] still sounding
		for e in t.events:
			var ev = e.event
			match ev.type:
				SMF.MIDIEventType.note_on:
					var n := Note.new()
					n.pitch = ev.note
					n.velocity = ev.velocity
					n.start = to_seconds.call(e.time)
					n.end = n.start
					var key = e.channel_number * 128 + ev.note
					if not open.has(key):
						open[key] = []
					open[key].append(n)
				SMF.MIDIEventType.note_off:
					var key = e.channel_number * 128 + ev.note
					if open.has(key) and open[key].size() > 0:
						var n: Note = open[key].pop_front()
						n.end = max(n.start, to_seconds.call(e.time))
						track.notes.append(n)
				SMF.MIDIEventType.program_change:
					if track.program < 0:
						track.program = ev.number
				SMF.MIDIEventType.pitch_bend:
					track.bends.append(Vector2(to_seconds.call(e.time), (ev.value - 8192) / 8192.0))
				SMF.MIDIEventType.system_event:
					if ev.args.get("meta", -1) == SMF.MIDISystemEventType.track_name and track.name == "":
						track.name = str(ev.args["text"]).strip_edges()
		# notes never let go: end at the track's last event
		var last_time: float = to_seconds.call(t.events[-1].time) if t.events.size() > 0 else 0.0
		for key in open:
			for n in open[key]:
				n.end = max(n.start + 0.1, last_time)
				track.notes.append(n)
		add_track(track)
	finish()

## Adds [track] (skipped if it has no notes), naming it if it has no name.
func add_track(track: Track) -> void:
	if track.notes.is_empty():
		return
	if track.name == "":
		track.name = "Track %d" % (tracks.size() + 1)
	tracks.append(track)

## After the tracks are in: sorts the notes, works out the note range and
## length, and remembers how the notes started (so edits can be saved as a
## difference from the file).
func finish() -> void:
	refresh()
	_pristine.clear()
	for tr in tracks:
		_pristine[tr.name] = _counts(tr)

## Re-works the note order, range and length after the notes changed.
func refresh() -> void:
	lowest = 127
	highest = 0
	length = 0.0
	for tr in tracks:
		tr.notes.sort_custom(func(a, b): return a.start < b.start)
		tr.longest = 0.0
		for n in tr.notes:
			tr.longest = max(tr.longest, n.end - n.start)
			lowest = min(lowest, n.pitch)
			highest = max(highest, n.pitch)
			length = max(length, n.end)
	if tracks.is_empty() or lowest > highest:
		lowest = 60
		highest = 72

static func make_note(pitch: int, start: float, end: float, velocity: int) -> Note:
	var n := Note.new()
	n.pitch = pitch
	n.start = start
	n.end = end
	n.velocity = velocity
	return n

# ---------------------------------------------------------------- edits

## Track name → {note key → how many}, as the file had them.
var _pristine := {}

static func note_key(n: Note) -> String:
	return "%d_%d_%d_%d" % [n.pitch, roundi(n.start * 1000.0), roundi(n.end * 1000.0), n.velocity]

func _counts(tr: Track) -> Dictionary:
	var c := {}
	for n in tr.notes:
		var k := note_key(n)
		c[k] = c.get(k, 0) + 1
	return c

## What differs from the file, per track name: {"added": [[pitch, start,
## end, velocity]…], "removed": [note key…]}. Empty if nothing was edited.
func edits() -> Dictionary:
	var out := {}
	for tr in tracks:
		var before: Dictionary = _pristine.get(tr.name, {})
		var now := {}
		var added := []
		for n in tr.notes:
			var k := note_key(n)
			now[k] = now.get(k, 0) + 1
			if now[k] > before.get(k, 0):
				added.append([n.pitch, snappedf(n.start, 0.001), snappedf(n.end, 0.001), n.velocity])
		var removed := []
		for k in before:
			for i in before[k] - now.get(k, 0):
				removed.append(k)
		if not added.is_empty() or not removed.is_empty():
			out[tr.name] = {"added": added, "removed": removed}
	return out

## Applies [edits] (as [method edits] made them) to the notes as read.
func apply_edits(saved: Dictionary) -> void:
	for tr in tracks:
		var e = saved.get(tr.name)
		if not e is Dictionary:
			continue
		var gone := {}
		for k in e.get("removed", []):
			gone[k] = gone.get(k, 0) + 1
		var kept: Array[Note] = []
		for n in tr.notes:
			var k := note_key(n)
			if gone.get(k, 0) > 0:
				gone[k] -= 1
			else:
				kept.append(n)
		tr.notes = kept
		for a in e.get("added", []):
			if a is Array and a.size() == 4:
				tr.notes.append(make_note(int(a[0]), float(a[1]), float(a[2]), int(a[3])))
	refresh()

func has_edits() -> bool:
	return not edits().is_empty()

## Writes the song (edits included) as a standard MIDI file: one track per
## track here, at the song's tempo. Note timing is exact in seconds.
func save_midi(out_path: String) -> Error:
	const PPQ := 480
	var ticks_per_s: float = PPQ * bpm / 60.0
	var out := StreamPeerBuffer.new()
	out.big_endian = true
	out.put_data("MThd".to_ascii_buffer())
	out.put_u32(6)
	out.put_u16(1)
	out.put_u16(tracks.size() + 1)
	out.put_u16(PPQ)
	# tempo track
	var meta := PackedByteArray()
	meta.append_array(_vlq(0))
	meta.append_array(PackedByteArray([0xFF, 0x51, 0x03]))
	var us := int(round(6e7 / bpm))
	meta.append_array(PackedByteArray([(us >> 16) & 255, (us >> 8) & 255, us & 255]))
	_put_track(out, meta)
	var index := 0
	for tr in tracks:
		var ch := index % 15
		if ch >= 9:
			ch += 1
		index += 1
		var ev := [] # [tick, order, bytes]
		var nm := tr.name.to_utf8_buffer()
		ev.append([0, -2, PackedByteArray([0xFF, 0x03]) + _vlq(nm.size()) + nm])
		if tr.program >= 0:
			ev.append([0, -1, PackedByteArray([0xC0 | ch, tr.program])])
		for n in tr.notes:
			var a := roundi(n.start * ticks_per_s)
			var b: int = max(a + 1, roundi(n.end * ticks_per_s))
			ev.append([a, 1, PackedByteArray([0x90 | ch, n.pitch, clampi(n.velocity, 1, 127)])])
			ev.append([b, 0, PackedByteArray([0x80 | ch, n.pitch, 0])])
		for bd in tr.bends:
			var v := clampi(8192 + roundi(bd.y * 8192.0), 0, 16383)
			ev.append([roundi(bd.x * ticks_per_s), 0, PackedByteArray([0xE0 | ch, v & 127, v >> 7])])
		ev.sort_custom(func(x, y): return x[0] < y[0] or (x[0] == y[0] and x[1] < y[1]))
		var body := PackedByteArray()
		var last := 0
		for e in ev:
			body.append_array(_vlq(max(0, e[0]) - last))
			last = max(0, e[0])
			body.append_array(e[2])
		_put_track(out, body)
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_buffer(out.data_array)
	return OK

static func _vlq(v: int) -> PackedByteArray:
	var b := PackedByteArray([v & 127])
	v >>= 7
	while v > 0:
		b.insert(0, (v & 127) | 128)
		v >>= 7
	return b

static func _put_track(out: StreamPeerBuffer, body: PackedByteArray) -> void:
	var end := PackedByteArray([0, 0xFF, 0x2F, 0])
	out.put_data("MTrk".to_ascii_buffer())
	out.put_u32(body.size() + end.size())
	out.put_data(body)
	out.put_data(end)

## The first note at or after [time] in [track] (binary search).
static func first_from(track: Track, time: float) -> int:
	var lo := 0
	var hi := track.notes.size()
	while lo < hi:
		var mid := (lo + hi) / 2
		if track.notes[mid].start < time:
			lo = mid + 1
		else:
			hi = mid
	return lo

## The pitch bend (-1…1) [track] is at, at [time], gliding between the
## file's bend events.
static func bend_at(track: Track, time: float) -> float:
	var bends := track.bends
	if bends.is_empty() or time < bends[0].x:
		return 0.0
	var lo := 0
	var hi := bends.size()
	while lo < hi:
		var mid := (lo + hi) / 2
		if bends[mid].x <= time:
			lo = mid + 1
		else:
			hi = mid
	var a: Vector2 = bends[lo - 1]
	if lo >= bends.size():
		return a.y
	var b: Vector2 = bends[lo]
	# a glide only between close events (a real bend); else a step
	if b.x - a.x > 0.12:
		return a.y
	return lerpf(a.y, b.y, (time - a.x) / max(b.x - a.x, 0.0001))
