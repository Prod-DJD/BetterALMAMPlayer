## A song as you work on it: its MIDI, its audio, and its look. Saved by
## itself (no "save config" step) in the app's data folder, one file per
## song file, and opened again the next time that MIDI is opened.
class_name Project
extends RefCounted

const DIR := "user://projects"
const STATE := "user://state.json"
const LOOKS := "user://looks"

var midi := ""
var audio := ""
var look := Look.new()
## Note edits, as [method Song.edits] makes them.
var edits := {}
## Tracks split into parts by pitch: track origin → "drums" or "notes".
var splits := {}
## Empty tracks the person made (their notes are in [member edits]).
var extra_tracks: Array = []
## Names the person gave tracks: the name it started with → their name.
var renames := {}
## Opened for the first time (no saved project yet).
var fresh := false

static func _key(midi_path: String) -> String:
	return "%s/%s.json" % [DIR, midi_path.md5_text()]

## The saved project for [midi_path], or a fresh one (finding a sound file
## with the same name beside the MIDI, if there is one).
static func open_for(midi_path: String) -> Project:
	var p := Project.new()
	p.midi = midi_path
	var f := _key(midi_path)
	p.fresh = not FileAccess.file_exists(f)
	if FileAccess.file_exists(f):
		var d = JSON.parse_string(FileAccess.get_file_as_string(f))
		if d is Dictionary:
			p.audio = str(d.get("audio", ""))
			if d.get("edits") is Dictionary:
				p.edits = d["edits"]
			if d.get("splits") is Dictionary:
				p.splits = d["splits"]
			if d.get("renames") is Dictionary:
				p.renames = d["renames"]
			if d.get("extra_tracks") is Array:
				p.extra_tracks = d["extra_tracks"]
			if d.get("look") is Dictionary:
				p.look = Look.from_dict(d["look"])
	if p.audio == "" or not FileAccess.file_exists(p.audio):
		p.audio = find_audio_beside(midi_path)
	return p

## song.mid → song.mp3 / .wav / .ogg next to it, if there is one.
static func find_audio_beside(midi_path: String) -> String:
	var stem := midi_path.get_basename()
	for ext in ["mp3", "wav", "ogg", "MP3", "WAV", "OGG"]:
		if FileAccess.file_exists(stem + "." + ext):
			return stem + "." + ext
	return ""

func save() -> void:
	if midi == "":
		return
	DirAccess.make_dir_recursive_absolute(DIR)
	var f := FileAccess.open(_key(midi), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"midi": midi, "audio": audio, "edits": edits, "splits": splits, "extra_tracks": extra_tracks, "renames": renames, "look": look.to_dict()}, "\t"))

# ----- the app's own memory: last song, recent songs -----

static func state() -> Dictionary:
	if FileAccess.file_exists(STATE):
		var d = JSON.parse_string(FileAccess.get_file_as_string(STATE))
		if d is Dictionary:
			return d
	return {}

static func remember(midi_path: String) -> void:
	var s := state()
	var recent: Array = s.get("recent", [])
	recent.erase(midi_path)
	recent.push_front(midi_path)
	s["recent"] = recent.slice(0, 12)
	s["last"] = midi_path
	var f := FileAccess.open(STATE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(s, "\t"))

## Why [param path] can't be read, in words for the person, or "" if it can.
## [method FileAccess.file_exists] isn't enough: a file in a protected folder
## (macOS asks before apps read the Music folder, for one) exists but the
## open is refused.
static func read_problem(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f != null:
		f.close()
		return ""
	var err := FileAccess.get_open_error()
	if err == ERR_FILE_NOT_FOUND or not FileAccess.file_exists(path):
		return "That file isn't there any more."
	# it exists but won't open: usually the OS saying no
	return "That file exists but couldn't be read (%s). If it's in your Music folder, macOS may have blocked it: allow it in System Settings ▸ Privacy & Security (Files and Folders, or Media & Apple Music), or move the project out of that folder." % error_string(err)

## Stops the next start from reopening the last song.
static func forget_last() -> void:
	var s := state()
	if s.has("last"):
		s.erase("last")
		var f := FileAccess.open(STATE, FileAccess.WRITE)
		if f:
			f.store_string(JSON.stringify(s, "\t"))

static func recent() -> Array:
	return state().get("recent", []).filter(func(p): return FileAccess.file_exists(p))

# ----- looks: the same look on another song -----

static func save_look(name: String, look: Look) -> void:
	DirAccess.make_dir_recursive_absolute(LOOKS)
	var f := FileAccess.open("%s/%s.json" % [LOOKS, name.validate_filename()], FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(look.to_dict(), "\t"))

static func looks() -> Array:
	var out := []
	var d := DirAccess.open(LOOKS)
	if d:
		for f in d.get_files():
			if f.ends_with(".json"):
				out.append(f.get_basename())
	out.sort()
	return out

static func load_look(name: String) -> Look:
	var f := "%s/%s.json" % [LOOKS, name]
	var d = JSON.parse_string(FileAccess.get_file_as_string(f)) if FileAccess.file_exists(f) else null
	return Look.from_dict(d) if d is Dictionary else null

## An old ALMAMPlayer config (settings by track number) as a look, with
## its tracks matched to [song]'s by order.
static func look_from_old_config(path: String, song: Song) -> Look:
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not d is Dictionary:
		return null
	if d.has("version") and d.has("tracks"):
		return Look.from_dict(d) # one of ours
	var l := Look.new()
	l.speed = float(d.get("speed", l.speed))
	l.vertical_offset = float(d.get("vertical_offset", l.vertical_offset))
	l.top_margin = float(d.get("top_margin", l.top_margin))
	l.velocity_strength = float(d.get("velocity_strength", l.velocity_strength))
	l.pitch_bend_strength = float(d.get("pitch_bend_strength", l.pitch_bend_strength))
	l.audio_offset = float(d.get("audio_offset", 0.0))
	l.square = bool(d.get("square_ratio", false))
	var bg := str(d.get("background_path", ""))
	l.background = "" if bg.begins_with("res://") else bg
	var n := song.tracks.size() if song else 0
	for i in n:
		var k := str(i)
		var t := Look.default_track(i, n)
		var colors: Dictionary = d.get("colors_json", {}) if d.get("colors_json") is Dictionary else {}
		if colors.has(k):
			t.color = Color.from_string(str(colors[k]), t.color)
		for field in [["parallax", "parallax"], ["staccato", "staccato"]]:
			var src = d.get(field[0])
			if src is Dictionary and src.get(k) != null:
				t.set(field[1], src[k])
		l.tracks[song.tracks[i].name] = t
	return l
