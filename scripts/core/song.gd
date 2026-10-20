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
	## Which MIDI track it came from (tracks with no notes are skipped).
	var source := 0
	var notes: Array[Note] = []
	## [seconds, bend -1…1], in time order.
	var bends: Array[Vector2] = []
	## The longest note, for finding what's on screen quickly.
	var longest := 0.0

var path := ""
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
		if track.notes.is_empty():
			continue
		track.notes.sort_custom(func(a, b): return a.start < b.start)
		for n in track.notes:
			track.longest = max(track.longest, n.end - n.start)
			lowest = min(lowest, n.pitch)
			highest = max(highest, n.pitch)
			length = max(length, n.end)
		if track.name == "":
			track.name = "Track %d" % (tracks.size() + 1)
		tracks.append(track)
	if tracks.is_empty():
		lowest = 60
		highest = 72

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
