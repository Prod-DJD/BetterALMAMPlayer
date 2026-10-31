## Opens a song from whatever the person has: a MIDI file, or a project from
## FL Studio (.flp) or Ableton Live (.als), with every track found by
## itself. Logic projects (.logicx) can't be read directly: see
## [member LOGIC_HELP].
class_name Importer
extends RefCounted

const EXTENSIONS := ["mid", "midi", "flp", "als"]
const LOGIC_HELP := "Logic projects can't be opened directly. In Logic: File ▸ Export ▸ All Tracks as MIDI Files…, then drop that .mid here."

## Why the last open failed, in words for the person.
static var last_error := ""

static func is_song_file(path: String) -> bool:
	return path.get_extension().to_lower() in EXTENSIONS or path.get_extension().to_lower() == "logicx"

static func load_song(path: String) -> Song:
	last_error = ""
	match path.get_extension().to_lower():
		"mid", "midi":
			var s := Song.load_file(path)
			if s == null:
				last_error = "That MIDI couldn't be read."
			else:
				unique_names(s)
			return s
		"flp":
			return FlpReader.read(path)
		"als":
			return AbletonReader.read(path)
		"logicx":
			last_error = LOGIC_HELP
			return null
	last_error = "That kind of file can't be opened."
	return null

## Two tracks with one name would share one look: number the later ones.
static func unique_names(song: Song) -> void:
	var seen := {}
	for t in song.tracks:
		var base := t.name
		var n := 2
		while seen.has(t.name):
			t.name = "%s %d" % [base, n]
			n += 1
		seen[t.name] = true
