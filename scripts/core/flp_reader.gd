## Reads the notes out of an FL Studio project (.flp): every channel that
## has notes becomes a track, named as in the channel rack, with the
## patterns placed where the playlist puts them. The file is a stream of
## events (an id byte, then 1, 2, 4 or a counted run of bytes). Not read:
## tempo changes and automation (the first tempo is used throughout), audio
## clips, plugin sounds.
class_name FlpReader
extends RefCounted

const PATTERN_BASE := 20480 # a playlist item's index is this + the pattern

## The song in [path], or null with [member Importer.last_error] set.
static func read(path: String) -> Song:
	var b := FileAccess.get_file_as_bytes(path)
	if b.size() < 22 or b.slice(0, 4).get_string_from_ascii() != "FLhd":
		Importer.last_error = "That isn't an FL Studio project."
		return null
	var ppq := maxi(1, b.decode_u16(12))
	var pos := 14
	if b.slice(pos, pos + 4).get_string_from_ascii() != "FLdt":
		Importer.last_error = "That FL Studio project is damaged."
		return null
	var end := mini(b.size(), pos + 8 + b.decode_u32(pos + 4))
	pos += 8

	var bpm := 130.0
	var utf16 := true
	var channel := -1
	var pattern := 0
	var names := {} # channel → name
	var default_names := {}
	var notes := {} # pattern → [[position, channel, length, key, velocity]…]
	var items: Array = [] # playlist: [position, pattern, length, start, end]
	while pos < end:
		var id := b[pos]
		pos += 1
		var size := 0
		var value := 0
		if id < 64:
			size = 1
		elif id < 128:
			size = 2
		elif id < 192:
			size = 4
		else:
			var shift := 0
			while pos < end:
				var c := b[pos]
				pos += 1
				size |= (c & 0x7F) << shift
				shift += 7
				if c & 0x80 == 0:
					break
		if pos + size > end:
			break
		if id < 64:
			value = b[pos]
		elif id < 128:
			value = b.decode_u16(pos)
		elif id < 192:
			value = b.decode_u32(pos)
		var data := b.slice(pos, pos + size) if id >= 192 else PackedByteArray()
		pos += size
		match id:
			64: # a new channel
				channel = value
			65: # a new pattern
				pattern = value
				channel = -1
			66: # old tempo
				bpm = float(value)
			156: # tempo × 1000
				bpm = value / 1000.0
			199: # the FL Studio version, as text
				var v := _text(data, false).split(".")
				if v.size() >= 2:
					utf16 = int(v[0]) > 11 or (int(v[0]) == 11 and int(v[1]) >= 5)
			192, 201, 203:
				if channel >= 0:
					var text := _text(data, utf16)
					if text != "":
						if id == 203:
							names[channel] = text
						elif id == 192:
							if not names.has(channel):
								names[channel] = text
						else:
							default_names[channel] = text
			224: # a pattern's notes
				if not notes.has(pattern):
					notes[pattern] = []
				var i := 0
				while i + 24 <= data.size():
					notes[pattern].append([
						data.decode_u32(i), data.decode_u16(i + 6), data.decode_u32(i + 8),
						data.decode_u16(i + 12), data[i + 21]])
					i += 24
			233: # playlist
				var i := 0
				while i + 32 <= data.size():
					var index := data.decode_u16(i + 6)
					if index > PATTERN_BASE:
						items.append([data.decode_u32(i), index - PATTERN_BASE, data.decode_u32(i + 8),
								data.decode_float(i + 24), data.decode_float(i + 28)])
					i += 32

	if notes.is_empty():
		Importer.last_error = "No notes found in that FL Studio project (empty patterns, or only audio)."
		return null
	var seconds_per_tick := 60.0 / (bpm * ppq)
	var by_channel := {} # channel → [[pitch, start, end, velocity]…]
	# the arrangement, or (nothing placed) the fullest pattern once
	if items.is_empty():
		var best := -1
		for p in notes:
			if best < 0 or notes[p].size() > notes[best].size():
				best = p
		items.append([0, best, 1 << 30, 0.0, -1.0])
	for it in items:
		if not notes.has(it[1]):
			continue
		var from_tick := float(it[3]) if is_finite(it[3]) and it[3] >= 0.0 and it[3] < 1e7 else 0.0
		var until_tick := from_tick + float(it[2])
		if is_finite(it[4]) and it[4] > from_tick and it[4] < 1e7:
			until_tick = minf(until_tick, float(it[4]))
		for n in notes[it[1]]:
			var local := float(n[0])
			if local < from_tick or local >= until_tick:
				continue
			var start := (float(it[0]) + local - from_tick) * seconds_per_tick
			var stop := start + maxf(float(n[2]), 1.0) * seconds_per_tick
			if not by_channel.has(n[1]):
				by_channel[n[1]] = []
			by_channel[n[1]].append([clampi(n[3], 0, 127), start, stop, maxi(1, n[4])])

	var song := Song.new()
	song.path = path
	song.bpm = bpm
	var order := by_channel.keys()
	order.sort()
	for c in order:
		var t := Song.Track.new()
		t.source = c
		t.name = str(names.get(c, default_names.get(c, "Channel %d" % (c + 1))))
		for n in by_channel[c]:
			t.notes.append(Song.make_note(n[0], n[1], n[2], n[3]))
		song.add_track(t)
	Importer.unique_names(song)
	song.finish()
	if song.tracks.is_empty():
		Importer.last_error = "No notes found in that FL Studio project."
		return null
	return song

static func _text(data: PackedByteArray, utf16: bool) -> String:
	# text fields end in a NUL (two bytes in UTF-16): leave it off
	var n := data.size()
	if utf16:
		n -= n % 2
		while n >= 2 and data[n - 1] == 0 and data[n - 2] == 0:
			n -= 2
	else:
		while n >= 1 and data[n - 1] == 0:
			n -= 1
	var text := data.slice(0, n)
	return (text.get_string_from_utf16() if utf16 else text.get_string_from_utf8()).strip_edges()
