## Reads the MIDI tracks out of a Logic Pro project (.logicx): each track in
## the arrange, in its order, with the MIDI regions placed on it.
##
## The format is Logic's own binary "ProjectData" file inside the .logicx
## folder (Alternatives/000/ProjectData). Read by the FLP to Logic converter's
## LogicBridge (MIT, Jon Kubis): this is a port of its inspect_logicx tool and
## of the parser's record and placement rules, for the parts that read notes.
## Not read: tempo changes (the first tempo is used throughout), audio regions,
## plugin settings. Logic's offsets come from reverse engineering: the sample
## projects in the converter's tests are the check, and a project's own MIDI
## export (File > Export > All Tracks as MIDI File) is the ground truth: a
## 37-region project read here matches it note for note (apart from that upbeat).
##
## What decides where a note sounds (all found by comparing against that export):
##  - time zero is bar 1 (a fixed position in the file). A project can start
##    earlier, with an upbeat: its start position is kept in the song record,
##    and what lies before bar 1 is negative time here (a 2-beat upbeat puts
##    notes at -2 beats). Logic's own MIDI export counts from the project start
##    instead, so it is later than this by the length of the upbeat;
##  - each region starts at its position, begins [offset] ticks into its stored
##    notes, and ends [length] ticks after it (notes outside are not played);
##  - a note id can be stored twice, the first an empty placeholder: the last wins;
##  - the note's MIDI channel is in its status byte (0x90-0x9F), not always 0x90;
##  - a note flagged muted (bit 0x10 of its flag byte) is not played.
class_name LogicReader
extends RefCounted

const MAGIC := [0x23, 0x47, 0xc0, 0xab]
const ROOT_HEADER := 0x18
const REC_HEADER := 0x24
const REC_SIZE := 0x1c
const PPQ := 960.0 ## Logic's ticks per beat
const MIDI_NOTE_ORIGIN := 38400 ## note positions are offset by this
const AUDIO_REGION_ORIGIN := 34560 ## bar 1: placement positions are offset by this
const ARR_IDX := 0x040000 ## the arrange's index on its records
const ARR_MT_OFF := 0xa
const ARR_ROW_H := 0x3c
const IVNE_IDX := 0x08
const IVNE_NAME_LEN := 0xc2
const IVNE_NAME := 0xc4
const KART_CHAN := 0x2a
const KART_MASTER_CHAN := 0x500000
const PLACEMENT_SIZE := 0x50
const PLACEMENT_MIDI := 0x20
const SONG_START_A := 0x164 ## the project's start position, kept twice in the song record
const SONG_START_B := 0x1b4 ## (the upbeat starts here; bar 1 is AUDIO_REGION_ORIGIN)
const REGION_NAME_LEN := 0x34 ## in a region record: the name's length, then the name
const REGION_LENGTH := 60 ## from the end of the name (padded to even): the region's length in ticks
const REGION_OFFSET := 4 ## the same, from the end of the name: ticks into the notes where it begins
const NOTE_FLAGS := 0x0f ## in a note event
const NOTE_MUTED := 0x10 ## the note is muted in Logic: it doesn't sound

## Reads the .logicx folder at [bundle]; returns null (with
## [member Importer.last_error] set) if it can't.
static func read(bundle: String) -> Song:
	var path := bundle.path_join("Alternatives/000/ProjectData")
	if not FileAccess.file_exists(path):
		Importer.last_error = "That Logic project has no ProjectData (is it a .logicx folder?)."
		return null
	var data := FileAccess.get_file_as_bytes(path)
	var records := _parse(data)
	if records.is_empty():
		Importer.last_error = "That Logic project couldn't be read (its format changed, or it's damaged)."
		return null

	var bpm := _tempo(records)
	var ivne := {} # channel index → record
	for r in records:
		if r.tag == "ivnE":
			ivne[_u32(r.raw, IVNE_IDX)] = r

	# MIDI placements, by the arrange row they sit on
	var notes_by_row := _notes_by_row(records, AUDIO_REGION_ORIGIN)

	var song := Song.new()
	song.path = bundle
	song.bpm = bpm
	for r in records:
		if r.tag != "karT" or r.raw.size() != 93 or _u32(r.raw, IVNE_IDX) != ARR_IDX:
			continue
		var ch := _u32(r.raw, KART_CHAN)
		if ch == KART_MASTER_CHAN:
			continue
		var t := Song.Track.new()
		t.name = _name(ivne[ch]) if ivne.has(ch) else "Track %d" % (song.tracks.size() + 1)
		for ev in notes_by_row.get(ch, []):
			var start: float = ev[0] * 60.0 / (PPQ * bpm)
			var length: float = maxf(float(ev[3]), 1.0)
			var stop: float = start + length * 60.0 / (PPQ * bpm)
			t.notes.append(Song.make_note(clampi(ev[2], 0, 127), start, stop, clampi(ev[1], 1, 127)))
		song.add_track(t)
	Importer.unique_names(song)
	song.finish()
	if song.tracks.is_empty():
		Importer.last_error = "No MIDI notes found in that Logic project."
		return null
	return song

# ---------------------------------------------------------------- records

## The records of a ProjectData file: [{tag: String, raw: PackedByteArray}].
## Empty if the file isn't in the format (a wrong magic, or a size that
## doesn't walk to its end).
static func _parse(data: PackedByteArray) -> Array:
	var out := []
	if data.size() < ROOT_HEADER or data.slice(0, 4) != PackedByteArray(MAGIC):
		return []
	var end := ROOT_HEADER + _u32(data, 0x10)
	if end != data.size():
		return []
	var pos := ROOT_HEADER
	while pos < end:
		var tag := data.slice(pos, pos + 4)
		var size := 0
		if tag == PackedByteArray(MAGIC):
			size = ROOT_HEADER + _u32(data, pos + 0x10)
		else:
			for c in tag:
				if c < 0x20 or c >= 0x7f:
					return [] # lost our place: the next "tag" isn't a tag
			size = REC_HEADER + _u32(data, pos + REC_SIZE)
		if size < REC_HEADER or pos + size > end:
			return []
		out.append({"tag": tag.get_string_from_ascii() if tag != PackedByteArray(MAGIC) else "magic",
				"raw": data.slice(pos, pos + size)})
		pos += size
	return out

static func _u32(b: PackedByteArray, o: int) -> int:
	return b.decode_u32(o) if o + 4 <= b.size() else 0

static func _u16(b: PackedByteArray, o: int) -> int:
	return b.decode_u16(o) if o + 2 <= b.size() else 0

## The project tempo: the first record (the song) keeps it as BPM × 10000.
static func _tempo(records: Array) -> float:
	for r in records:
		if r.tag == "gnoS":
			var bpm := _u32(r.raw, 0x92) / 10000.0
			if bpm >= 20.0 and bpm <= 999.0:
				return bpm
	return 120.0

## A track's name: Logic stores it as Latin-1 (so "·" is one byte).
static func _name(r: Dictionary) -> String:
	var n := _u16(r.raw, IVNE_NAME_LEN)
	var s := ""
	for c in r.raw.slice(IVNE_NAME, mini(IVNE_NAME + n, r.raw.size())):
		s += char(c)
	return s.strip_edges()

# ---------------------------------------------------------------- notes

## Arrange row (channel) → [[tick, velocity, pitch, length]…], ticks counted
## from the start of the song (bar 1), so each region sits where Logic has it.
static func _notes_by_row(records: Array, origin: int) -> Dictionary:
	var out := {}
	var ev_index := _arrange_events(records)
	if ev_index < 0:
		return out
	var body := _body(records[ev_index].raw)
	var o := 0
	while o + PLACEMENT_SIZE <= body.size():
		if _u32(body, o) != PLACEMENT_MIDI:
			o += 4
			continue
		var row := (_u32(body, o + 0x10) & 0xffff) << 16
		var cluster := _u32(body, o + 0x20) << 16
		var region_start := _u32(body, o + 0x04) - origin
		var notes := _region_notes(records, cluster)
		if not out.has(row):
			out[row] = []
		for n in notes:
			out[row].append([region_start + n[0], n[1], n[2], n[3]])
		o += PLACEMENT_SIZE
	return out

## How many ticks the project's start lies before bar 1 (its upbeat), 0 if it
## starts at bar 1 or the record doesn't say. Notes in that stretch have
## negative times.
static func _upbeat_ticks(records: Array) -> int:
	for r in records:
		if r.tag == "gnoS":
			var a := _u32(r.raw, SONG_START_A)
			if a == _u32(r.raw, SONG_START_B) and a >= 0x4000 and a < AUDIO_REGION_ORIGIN:
				return AUDIO_REGION_ORIGIN - a
	return 0

## The last record with [param tag] and index [param idx]: an index can be stored
## more than once, and the first is an empty placeholder.
static func _last(records: Array, tag: String, idx: int) -> Variant:
	var found: Variant = null
	for r in records:
		if r.tag == tag and _u32(r.raw, IVNE_IDX) == idx:
			found = r
	return found

## A region's [length, offset] in ticks, from its record: it plays the notes from
## [offset] to [offset] + [length]. [-1, 0] if the record isn't there.
static func _region_window(records: Array, cluster: int) -> Array:
	var r: Variant = _last(records, "qeSM", cluster)
	if r == null:
		return [-1, 0]
	var nlen := _u16(r.raw, REGION_NAME_LEN)
	var base: int = REGION_NAME_LEN + 2 + nlen + (nlen & 1)
	if base + REGION_LENGTH + 4 > r.raw.size():
		return [-1, 0]
	var length := _u32(r.raw, base + REGION_LENGTH)
	return [length if length > 0 else -1, _u32(r.raw, base + REGION_OFFSET)]

## The notes the region whose note data is the record with index [param cluster]
## plays: [[tick, velocity, pitch, length]…], the tick counted from the region's
## start. Note events are 32 bytes (status 0x90-0x9F: the MIDI channel is in
## the low bits), with 16-byte controller events stepped over. Muted notes, and
## notes outside what the region plays, are left out.
static func _region_notes(records: Array, cluster: int) -> Array:
	var rec: Variant = _last(records, "qSvE", cluster)
	if rec == null:
		return []
	var window := _region_window(records, cluster)
	var body := _body(rec.raw)
	var out := []
	var i := 0
	while i + 16 < body.size():
		if (body[i] & 0xf0) == 0x90:
			var pos: int = _u32(body, i + 4) - MIDI_NOTE_ORIGIN - int(window[1])
			var muted := (body[i + NOTE_FLAGS] & NOTE_MUTED) != 0
			if not muted and pos >= 0 and (int(window[0]) < 0 or pos < int(window[0])):
				out.append([pos, body[i + 0x0b], body[i + 0x0c], _u32(body, i + 0x1c)])
			i += 32
		else:
			i += 16
	return out

static func _body(raw: PackedByteArray) -> PackedByteArray:
	return raw.slice(REC_HEADER, mini(REC_HEADER + _u32(raw, REC_SIZE), raw.size()))

## Index of the arrange's placement events (the record after the arrange's
## own container), or -1.
static func _arrange_events(records: Array) -> int:
	var arr := -1
	var best := -1
	var heights := []
	for i in records.size():
		var r = records[i]
		if r.tag != "qeSM" or _u32(r.raw, IVNE_IDX) != ARR_IDX:
			continue
		var h := _u16(r.raw, _arr_height_off(r.raw))
		heights.append([i, h])
	# the real arrange container: a height that is a whole number of rows
	for pair in heights:
		var h: int = pair[1]
		if h != 0 and h % ARR_ROW_H == 0 and records[pair[0]].raw.size() > best:
			best = records[pair[0]].raw.size()
			arr = pair[0]
	if arr < 0:
		for pair in heights:
			if records[pair[0]].raw.size() > best:
				best = records[pair[0]].raw.size()
				arr = pair[0]
	if arr < 0:
		return -1
	for i in range(arr + 1, records.size()):
		if records[i].tag == "qSvE" and _u32(records[i].raw, IVNE_IDX) == ARR_IDX:
			return i
	return -1

static func _arr_height_off(raw: PackedByteArray) -> int:
	var nlen := _u16(raw, 0x34)
	return 0x34 + 2 + nlen + (nlen & 1) + ARR_MT_OFF
