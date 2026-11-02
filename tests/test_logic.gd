## Reads a Logic Pro project and checks it against the converter's own
## inspection tool. Set LOGIC_SAMPLE to a .logicx folder (not in the repo).
extends SceneTree

var fails := 0
func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok: fails += 1

## A record as LogicReader._parse gives it: the 0x24-byte header (index at 0x08,
## body size at 0x1c), then the body.
func record(tag: String, idx: int, body: PackedByteArray) -> Dictionary:
	var raw := PackedByteArray()
	raw.resize(LogicReader.REC_HEADER)
	raw.encode_u32(0x08, idx)
	raw.encode_u32(LogicReader.REC_SIZE, body.size())
	raw.append_array(body)
	return {"tag": tag, "raw": raw}

## A 32-byte note event: [channel] 0-15, tick counted from the region's stored start.
func note(channel: int, tick: int, pitch: int, flags := 0x01) -> PackedByteArray:
	var b := PackedByteArray()
	b.resize(32)
	b[0] = 0x90 | channel
	b.encode_u32(4, tick + LogicReader.MIDI_NOTE_ORIGIN)
	b[0x0b] = 100
	b[0x0c] = pitch
	b[LogicReader.NOTE_FLAGS] = flags
	b.encode_u32(0x1c, 480)
	return b

## A region record (tag qeSM) for the window: [length] and [offset] ticks.
func region(idx: int, length: int, offset: int) -> Dictionary:
	var raw := PackedByteArray()
	raw.resize(0x34 + 2 + 4 + 70) # a 4-letter name, then the fields
	raw.encode_u32(0x08, idx)
	raw.encode_u16(LogicReader.REGION_NAME_LEN, 4)
	var base := 0x34 + 2 + 4
	raw.encode_u32(base + LogicReader.REGION_LENGTH, length)
	raw.encode_u32(base + LogicReader.REGION_OFFSET, offset)
	return {"tag": "qeSM", "raw": raw}

func _initialize() -> void:
	# ---- the rules found by reading a real project against Logic's own MIDI export
	var cluster := 0x500000
	var ev := PackedByteArray()
	ev.append_array(note(0, 0, 60)); ev.append_array(note(1, 480, 64)); ev.append_array(note(2, 960, 67))
	check(LogicReader._region_notes([record("qSvE", cluster, ev)], cluster).size() == 3, "notes on every MIDI channel (0x90-0x92) are read")
	var muted := PackedByteArray()
	muted.append_array(note(0, 0, 60)); muted.append_array(note(0, 480, 62, 0x11)); muted.append_array(note(0, 960, 64, 0x91))
	check(LogicReader._region_notes([record("qSvE", cluster, muted)], cluster).size() == 1, "muted notes (flag 0x10) are left out")
	var many := PackedByteArray()
	for k in 6: many.append_array(note(0, k * 480, 60 + k))
	var win := LogicReader._region_notes([record("qSvE", cluster, many), region(cluster, 1440, 480)], cluster)
	check(win.size() == 3 and win[0][0] == 0 and win[0][2] == 61 and win[2][2] == 63, "a region plays [offset, offset + length) of its notes, counted from its start: %s" % str(win))
	var late := LogicReader._region_notes([record("qSvE", cluster, many)], cluster)
	check(late.size() == 6, "with no region record, every note is kept")
	var twice := LogicReader._region_notes([record("qSvE", cluster, PackedByteArray()), record("qSvE", cluster, many)], cluster)
	check(twice.size() == 6, "when an index is stored twice, the last record wins (the first is an empty placeholder)")
	check(LogicReader._region_window([region(cluster, 99, 7), region(cluster, 1440, 480)], cluster) == [1440, 480], "the last region record wins too")
	var song := PackedByteArray(); song.resize(0x200)
	song.encode_u32(LogicReader.SONG_START_A, 0x7f80); song.encode_u32(LogicReader.SONG_START_B, 0x7f80)
	check(LogicReader._upbeat_ticks([{"tag": "gnoS", "raw": song}]) == 1920, "a project that starts 2 beats before bar 1 has a 1920-tick upbeat")
	var odd := PackedByteArray(); odd.resize(0x200)
	odd.encode_u32(LogicReader.SONG_START_A, 0x7f80); odd.encode_u32(LogicReader.SONG_START_B, 0x1234)
	check(LogicReader._upbeat_ticks([{"tag": "gnoS", "raw": odd}]) == 0 and LogicReader._upbeat_ticks([]) == 0, "no usable start position: no upbeat")
	var sample := OS.get_environment("LOGIC_SAMPLE")
	if sample == "":
		print("sample project skipped: set LOGIC_SAMPLE to a .logicx folder")
		print("FAILS: ", fails)
		quit(1 if fails else 0)
		return
	var s := Importer.load_song(sample)
	check(s != null, "reads the project: " + Importer.last_error)
	if s != null:
		var counts := []
		for t in s.tracks:
			counts.append(t.notes.size())
			print("     %-36s %4d notes  bpm %.1f" % [t.name, t.notes.size(), s.bpm])
		var expect := [330, 286, 348, 181, 144, 49, 17, 604, 158]
		check(counts == expect, "note counts match the converter's tool: %s" % str(counts))
		check(absf(s.bpm - 160.0) < 0.01, "tempo 160")
	print("FAILS: ", fails)
	quit(1 if fails else 0)
