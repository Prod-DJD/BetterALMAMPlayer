extends SceneTree

var fails := 0
func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok: fails += 1

func ev8(b: PackedByteArray, id: int, v: int) -> void:
	b.append(id); b.append(v)
func ev16(b: PackedByteArray, id: int, v: int) -> void:
	b.append(id); b.append(v & 255); b.append(v >> 8)
func ev32(b: PackedByteArray, id: int, v: int) -> void:
	b.append(id)
	for i in 4: b.append((v >> (8 * i)) & 255)
func evtext(b: PackedByteArray, id: int, data: PackedByteArray) -> void:
	b.append(id); b.append(data.size()); b.append_array(data)

func note24(pos: int, ch: int, length: int, key: int, vel: int) -> PackedByteArray:
	var n := PackedByteArray(); n.resize(24)
	n.encode_u32(0, pos); n.encode_u16(6, ch); n.encode_u32(8, length); n.encode_u16(12, key); n[21] = vel
	return n

func _initialize() -> void:
	# ---- a synthetic FL project: 2 channels, 1 pattern placed twice
	var d := PackedByteArray()
	evtext(d, 199, "20.8.4.2576".to_ascii_buffer() + PackedByteArray([0]))
	ev32(d, 156, 120000)
	ev16(d, 64, 0)
	evtext(d, 203, "Lead Synth".to_utf16_buffer())
	ev16(d, 64, 1)
	evtext(d, 203, "808 Bass".to_utf16_buffer())
	ev16(d, 65, 1)
	var notes := note24(0, 0, 96, 72, 100) + note24(96, 0, 96, 74, 90) + note24(0, 1, 192, 36, 120)
	evtext(d, 224, notes)
	# playlist: pattern 1 at tick 0 and at tick 768, length 192 each
	var pl := PackedByteArray(); pl.resize(64)
	for k in 2:
		var o := k * 32
		pl.encode_u32(o, 0 if k == 0 else 768); pl.encode_u16(o + 4, 20480); pl.encode_u16(o + 6, 20480 + 1)
		pl.encode_u32(o + 8, 192); pl.encode_float(o + 24, -1.0); pl.encode_float(o + 28, -1.0)
	evtext(d, 233, pl)
	var f := PackedByteArray()
	f.append_array("FLhd".to_ascii_buffer()); f.append_array(PackedByteArray([6,0,0,0, 0,0, 2,0, 96,0]))
	f.append_array("FLdt".to_ascii_buffer())
	var len := PackedByteArray(); len.resize(4); len.encode_u32(0, d.size())
	f.append_array(len); f.append_array(d)
	var tmp := OS.get_environment("TMPDIR") if OS.get_environment("TMPDIR") != "" else "/tmp"
	var p := tmp.path_join("t.flp")
	var fh := FileAccess.open(p, FileAccess.WRITE); fh.store_buffer(f); fh.close()
	var s := Importer.load_song(p)
	check(s != null, "flp loads: " + Importer.last_error)
	if s:
		check(s.tracks.size() == 2, "flp: 2 tracks, got %d" % s.tracks.size())
		check(s.tracks[0].name == "Lead Synth" and s.tracks[1].name == "808 Bass", "flp: channel names")
		check(s.tracks[0].notes.size() == 4, "flp: pattern placed twice -> 4 lead notes, got %d" % s.tracks[0].notes.size())
		check(absf(s.bpm - 120.0) < 0.01, "flp: bpm")
		# 96 ppq @120bpm: a quarter = 0.5 s; second pattern at tick 768 = 4 s
		check(absf(s.tracks[0].notes[2].start - 4.0) < 0.001, "flp: second copy at 4s, got %f" % s.tracks[0].notes[2].start)
		check(absf(s.tracks[0].notes[1].start - 0.5) < 0.001 and s.tracks[0].notes[1].pitch == 74, "flp: note 2 time/pitch")
		check(Icons.guess(s.tracks[1].name, s.tracks[1].program) == "subbass", "icon: 808 Bass -> subbass")
		# ---- edits: delete a note, add one, diff, apply on a fresh read, midi round trip
		s.tracks[0].notes.remove_at(0)
		s.tracks[0].notes.append(Song.make_note(40, 1.0, 1.5, 64))
		s.refresh()
		var e := s.edits()
		check(e.has("Lead Synth") and e["Lead Synth"]["added"].size() == 1 and e["Lead Synth"]["removed"].size() == 1, "edits: one added, one removed")
		var s2 := Importer.load_song(p)
		s2.apply_edits(JSON.parse_string(JSON.stringify(e)))
		check(s2.tracks[0].notes.size() == s.tracks[0].notes.size() and s2.edits() == e, "edits: reapplied from JSON gives the same song")
		var mp := tmp.path_join("t_out.mid")
		check(s.save_midi(mp) == OK, "midi: written")
		var back := Importer.load_song(mp)
		check(back != null and back.tracks.size() == 2, "midi: read back")
		if back:
			var a := s.tracks[0].notes.size(); var b := back.tracks[0].notes.size()
			check(a == b, "midi: lead notes %d == %d" % [a, b])
			var ok := true
			for i in mini(a, b):
				var x: Song.Note = s.tracks[0].notes[i]; var y: Song.Note = back.tracks[0].notes[i]
				if x.pitch != y.pitch or absf(x.start - y.start) > 0.003 or absf(x.end - y.end) > 0.003: ok = false
			check(ok, "midi: note timing round-trips within 3 ms")
	# ---- an Ableton set
	var xml := """<?xml version="1.0"?><Ableton><LiveSet><MasterTrack><DeviceChain><Mixer><Tempo><Manual Value="100"/></Tempo></Mixer></DeviceChain></MasterTrack><Tracks>
<MidiTrack Id="1"><Name><EffectiveName Value="Pluck Lead"/></Name><DeviceChain><MainSequencer><ClipTimeable><ArrangerAutomation><Events>
<MidiClip Id="0" Time="4"><CurrentStart Value="4"/><CurrentEnd Value="8"/><Loop><LoopStart Value="0"/><LoopEnd Value="2"/><StartRelative Value="0"/><LoopOn Value="true"/></Loop>
<Notes><KeyTracks><KeyTrack Id="0"><Notes><MidiNoteEvent Time="0" Duration="1" Velocity="100"/></Notes><MidiKey Value="60"/></KeyTrack></KeyTracks></Notes></MidiClip>
</Events></ArrangerAutomation></ClipTimeable></MainSequencer></DeviceChain></MidiTrack></Tracks></LiveSet></Ableton>"""
	var gz := xml.to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP)
	var ap := tmp.path_join("t.als")
	var ah := FileAccess.open(ap, FileAccess.WRITE); ah.store_buffer(gz); ah.close()
	var a := Importer.load_song(ap)
	check(a != null, "als loads: " + Importer.last_error)
	if a:
		# clip 4..8 beats, loop of 2 beats -> note at beats 4 and 6; 100 bpm -> 2.4 s and 3.6 s
		check(a.tracks[0].notes.size() == 2, "als: looped clip gives 2 notes, got %d" % a.tracks[0].notes.size())
		check(absf(a.tracks[0].notes[0].start - 2.4) < 0.001 and absf(a.tracks[0].notes[1].start - 3.6) < 0.001, "als: note times")
		check(a.tracks[0].name == "Pluck Lead" and absf(a.bpm - 100.0) < 0.01, "als: name and tempo")
	check(Importer.load_song("/x/y.logicx") == null and Importer.last_error.contains("Logic"), "logicx: explains the export route")
	check(Icons.guess("whatever", 33) == "bass" and Icons.guess("x", 0) == "grandpiano" and Icons.guess("zzz", -1) == "generic", "icons: program and fallback")
	# note-off velocity: read from the file, kept through a save and a re-read
	var ro := PackedByteArray()
	var rev := PackedByteArray([0, 0x90, 60, 100, 96, 0x80, 60, 20, 0, 0x90, 62, 90, 96, 0x80, 62, 0, 0, 0xFF, 0x2F, 0])
	ro.append_array("MThd".to_ascii_buffer()); ro.append_array(PackedByteArray([0,0,0,6, 0,0, 0,1, 1,224]))
	ro.append_array("MTrk".to_ascii_buffer()); ro.append_array(PackedByteArray([0, 0, 0, rev.size()])); ro.append_array(rev)
	var rp := tmp.path_join("rel.mid")
	var rf := FileAccess.open(rp, FileAccess.WRITE); rf.store_buffer(ro); rf.close()
	var rs := Importer.load_song(rp)
	check(rs != null and rs.tracks[0].notes[0].release == 20 and rs.tracks[0].notes[1].release == -1, "release velocity read from note-off (no note-off: -1)")
	var rw := tmp.path_join("rel_out.mid")
	rs.save_midi(rw)
	var rb := Importer.load_song(rw)
	check(rb != null and rb.tracks[0].notes[0].release == 20, "release velocity written and read back")
	print("FAILS: ", fails)
	quit(1 if fails else 0)
