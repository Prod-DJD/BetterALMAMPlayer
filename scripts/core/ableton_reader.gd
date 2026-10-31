## Reads the MIDI clips out of an Ableton Live set (.als, gzipped XML): each
## MIDI track becomes a track, with its arrangement clips placed (looped
## clips repeated). Not read: tempo changes (the set's tempo is used
## throughout), session-view clips, audio.
class_name AbletonReader
extends RefCounted

static func read(path: String) -> Song:
	var packed := FileAccess.get_file_as_bytes(path)
	var xml := packed.decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP)
	if xml.is_empty():
		xml = packed # saved uncompressed
	var p := XMLParser.new()
	if p.open_buffer(xml) != OK:
		Importer.last_error = "That Ableton set couldn't be read."
		return null
	var bpm := 120.0
	var stack: Array[String] = []
	var tracks: Array = [] # [name, clips]
	var track: Array = []
	var clip := {}
	var pending: Array = [] # notes of the key track being read: [time, duration, velocity]
	while p.read() == OK:
		var kind := p.get_node_type()
		if kind == XMLParser.NODE_ELEMENT_END:
			var done := p.get_node_name()
			if done == "MidiClip" and not clip.is_empty():
				if track.size() > 0 and clip.get("arrangement", false):
					track[1].append(clip)
				clip = {}
			elif done == "MidiTrack" and track.size() > 0:
				tracks.append(track)
				track = []
			stack.pop_back()
			continue
		if kind != XMLParser.NODE_ELEMENT:
			continue
		var name := p.get_node_name()
		var value := p.get_named_attribute_value_safe("Value")
		var up := stack[-1] if stack.size() > 0 else ""
		match name:
			"MidiTrack":
				track = ["", []]
			"EffectiveName":
				if track.size() > 0 and track[0] == "" and up == "Name":
					track[0] = value
			"MidiClip":
				if track.size() > 0:
					clip = {
						"arrangement": stack.has("ArrangerAutomation"),
						"start": 0.0, "end": 0.0, "loop_start": 0.0, "loop_end": 0.0,
						"relative": 0.0, "loop_on": false, "notes": [],
					}
			"CurrentStart":
				if not clip.is_empty() and up == "MidiClip":
					clip["start"] = float(value)
			"CurrentEnd":
				if not clip.is_empty() and up == "MidiClip":
					clip["end"] = float(value)
			"LoopStart":
				if not clip.is_empty() and up == "Loop":
					clip["loop_start"] = float(value)
			"LoopEnd":
				if not clip.is_empty() and up == "Loop":
					clip["loop_end"] = float(value)
			"StartRelative":
				if not clip.is_empty() and up == "Loop":
					clip["relative"] = float(value)
			"LoopOn":
				if not clip.is_empty() and up == "Loop":
					clip["loop_on"] = value == "true"
			"MidiNoteEvent":
				if not clip.is_empty() and p.get_named_attribute_value_safe("IsEnabled") != "false":
					pending.append([
						float(p.get_named_attribute_value_safe("Time")),
						float(p.get_named_attribute_value_safe("Duration")),
						float(p.get_named_attribute_value_safe("Velocity"))])
			"MidiKey":
				if not clip.is_empty():
					for n in pending:
						clip["notes"].append([int(value), n[0], n[1], n[2]])
					pending.clear()
			"Manual":
				if up == "Tempo":
					bpm = clampf(float(value), 20.0, 999.0)
		if p.is_empty():
			if name == "MidiClip" and not clip.is_empty():
				clip = {}
		else:
			stack.append(name)

	var song := Song.new()
	song.path = path
	song.bpm = bpm
	var seconds_per_beat := 60.0 / bpm
	for tr in tracks:
		var t := Song.Track.new()
		t.name = tr[0]
		for c in tr[1]:
			var span: float = c["loop_end"] - c["loop_start"]
			var length: float = c["end"] - c["start"]
			for n in c["notes"]:
				if n[1] < c["loop_start"] - 1e-6 or (n[1] >= c["loop_end"] and span > 0.0):
					continue
				var rel: float = n[1] - c["loop_start"] - c["relative"]
				var k := 0
				if c["loop_on"] and span > 0.0:
					rel = fposmod(rel, span)
				while rel + k * span < length and rel >= 0.0:
					var at: float = c["start"] + rel + k * span
					var dur: float = minf(n[2], c["end"] - at)
					if dur > 0.0:
						t.notes.append(Song.make_note(clampi(n[0], 0, 127), at * seconds_per_beat,
								(at + dur) * seconds_per_beat, clampi(int(n[3]), 1, 127)))
					k += 1
					if not c["loop_on"] or span <= 0.0:
						break
		song.add_track(t)
	if song.tracks.is_empty():
		Importer.last_error = "No MIDI notes found in that Ableton set's arrangement."
		return null
	Importer.unique_names(song)
	song.finish()
	return song
