## Reads a Logic Pro project and checks it against the converter's own
## inspection tool. Set LOGIC_SAMPLE to a .logicx folder (not in the repo).
extends SceneTree

var fails := 0
func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok: fails += 1

func _initialize() -> void:
	var sample := OS.get_environment("LOGIC_SAMPLE")
	if sample == "":
		print("skipped: set LOGIC_SAMPLE to a .logicx folder")
		quit(0)
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
