## The instrument icons, drawn from lines, arcs and polygons (no picture
## files): sharp at any size and in any color. [method guess] picks one for
## a track from its General MIDI program or its name.
class_name Icons
extends RefCounted

const NAMES := [
	"piano", "synth", "lead", "bass", "guitar", "pluck", "strings", "brass",
	"winds", "vocal", "pad", "bell", "drums", "fx", "generic",
]

## The icon for a track: its name first (what the person called it), then
## the General MIDI program the file selects.
static func guess(track_name: String, program: int) -> String:
	var n := track_name.to_lower()
	var tokens := n.split(" ", false)
	for sep in ["_", "-", ".", "/", "(", ")", "[", "]", "+"]:
		var more := []
		for t in tokens:
			more.append_array(t.split(sep, false))
		tokens = PackedStringArray(more)
	var words := {
		"drums": ["kick", "snare", "hat", "drum", "perc", "clap", "tom", "cymbal", "808s", "rim"],
		"bass": ["bass", "808", "sub"],
		"piano": ["piano", "keys", "rhodes", "wurli", "organ", "clav", "epiano"],
		"guitar": ["guitar", "gtr", "strum"],
		"strings": ["violin", "cello", "string", "viola", "orch", "fiddle"],
		"brass": ["brass", "trumpet", "horn", "trombone", "sax", "tuba"],
		"winds": ["flute", "clarinet", "oboe", "wind", "bassoon", "piccolo", "recorder"],
		"vocal": ["vox", "vocal", "voice", "choir", "sing", "adlib", "ooh", "aah"],
		"pad": ["pad", "atmos", "ambient", "drone", "texture"],
		"pluck": ["pluck", "harp", "kalimba", "marimba", "koto", "banjo", "pizz"],
		"bell": ["bell", "chime", "glock", "celesta", "music box", "vibes", "xylo"],
		"lead": ["lead", "saw", "arp", "square", "melody"],
		"fx": ["fx", "riser", "sweep", "noise", "impact", "whoosh", "effect"],
		"synth": ["synth", "keysynth", "chord"],
	}
	for kind in words:
		for w in words[kind]:
			# short words only at the start of a word ("hat", not "whatever")
			if w.length() <= 4:
				for t in tokens:
					if t.begins_with(w):
						return kind
			elif n.contains(w):
				return kind
	if program >= 0:
		var groups := [
			"piano", "bell", "piano", "guitar", "bass", "strings", "strings",
			"brass", "winds", "winds", "lead", "pad", "fx", "pluck", "drums", "fx",
		]
		var g: String = groups[clampi(program / 8, 0, 15)]
		if program >= 52 and program <= 54:
			return "vocal"
		return g
	return "generic"

## Draws [kind] in [rect] (centered, square) in [color].
static func draw(ci: CanvasItem, kind: String, rect: Rect2, color: Color) -> void:
	var u := minf(rect.size.x, rect.size.y)
	var o := rect.position + (rect.size - Vector2(u, u)) / 2.0
	var w := maxf(1.5, u * 0.085)
	var P := func(x: float, y: float) -> Vector2: return o + Vector2(x, y) * u
	match kind:
		"piano":
			ci.draw_rect(Rect2(P.call(0.1, 0.2), Vector2(0.8, 0.6) * u), color, false, w)
			for x in [0.26, 0.42, 0.58, 0.74]:
				ci.draw_line(P.call(x, 0.55), P.call(x, 0.8), color, w * 0.7)
			for x in [0.26, 0.42, 0.74]:
				ci.draw_rect(Rect2(P.call(x - 0.045, 0.2), Vector2(0.09, 0.35) * u), color)
		"synth":
			var pts := PackedVector2Array()
			for i in 25:
				var x := i / 24.0
				pts.append(P.call(0.1 + x * 0.8, 0.5 - 0.27 * sin(x * TAU * 1.5)))
			ci.draw_polyline(pts, color, w, true)
		"lead":
			ci.draw_polyline(PackedVector2Array([
				P.call(0.08, 0.72), P.call(0.4, 0.28), P.call(0.4, 0.72),
				P.call(0.72, 0.28), P.call(0.72, 0.72), P.call(0.92, 0.5)]), color, w, true)
		"bass":
			ci.draw_colored_polygon(PackedVector2Array([
				P.call(0.12, 0.38), P.call(0.32, 0.38), P.call(0.52, 0.2),
				P.call(0.52, 0.8), P.call(0.32, 0.62), P.call(0.12, 0.62)]), color)
			ci.draw_arc(P.call(0.52, 0.5), 0.2 * u, -0.9, 0.9, 12, color, w, true)
			ci.draw_arc(P.call(0.52, 0.5), 0.34 * u, -0.9, 0.9, 14, color, w, true)
		"guitar":
			ci.draw_arc(P.call(0.36, 0.66), 0.22 * u, 0, TAU, 28, color, w, true)
			ci.draw_circle(P.call(0.36, 0.66), 0.06 * u, color)
			ci.draw_line(P.call(0.5, 0.52), P.call(0.86, 0.16), color, w * 1.3)
			ci.draw_line(P.call(0.82, 0.2), P.call(0.92, 0.1), color, w * 1.8)
		"pluck":
			ci.draw_polyline(PackedVector2Array([
				P.call(0.2, 0.15), P.call(0.2, 0.85), P.call(0.8, 0.85), P.call(0.2, 0.15)]), color, w, true)
			for x in [0.35, 0.5, 0.65]:
				ci.draw_line(P.call(x, 0.15 + (x - 0.2) / 0.6 * 0.7), P.call(x, 0.85), color, w * 0.55)
		"strings":
			ci.draw_arc(P.call(0.5, 0.64), 0.2 * u, 0, TAU, 24, color, w, true)
			ci.draw_arc(P.call(0.5, 0.42), 0.15 * u, 0, TAU, 20, color, w, true)
			ci.draw_line(P.call(0.5, 0.27), P.call(0.5, 0.06), color, w)
			ci.draw_line(P.call(0.12, 0.88), P.call(0.88, 0.3), color, w * 0.7)
		"brass":
			ci.draw_polyline(PackedVector2Array([
				P.call(0.55, 0.4), P.call(0.9, 0.2), P.call(0.9, 0.8), P.call(0.55, 0.6)]), color, w, true)
			ci.draw_line(P.call(0.08, 0.5), P.call(0.55, 0.5), color, w * 1.4)
			for x in [0.22, 0.32, 0.42]:
				ci.draw_line(P.call(x, 0.5), P.call(x, 0.3), color, w * 0.9)
		"winds":
			var a: Vector2 = P.call(0.1, 0.84)
			var b: Vector2 = P.call(0.9, 0.16)
			var side: Vector2 = (b - a).orthogonal().normalized() * 0.065 * u
			ci.draw_line(a + side, b + side, color, w * 0.8)
			ci.draw_line(a - side, b - side, color, w * 0.8)
			ci.draw_line(a + side, a - side, color, w * 0.8)
			ci.draw_line(b + side, b - side, color, w * 0.8)
			for t in [0.4, 0.55, 0.7]:
				ci.draw_circle(a.lerp(b, t), 0.03 * u + 0.5, color)
		"vocal":
			ci.draw_arc(P.call(0.5, 0.26), 0.14 * u, PI, TAU, 12, color, w, true)
			ci.draw_line(P.call(0.36, 0.26), P.call(0.36, 0.44), color, w)
			ci.draw_line(P.call(0.64, 0.26), P.call(0.64, 0.44), color, w)
			ci.draw_arc(P.call(0.5, 0.44), 0.14 * u, 0, PI, 12, color, w, true)
			ci.draw_arc(P.call(0.5, 0.44), 0.27 * u, 0.1, PI - 0.1, 16, color, w * 0.8, true)
			ci.draw_line(P.call(0.5, 0.71), P.call(0.5, 0.88), color, w * 0.8)
			ci.draw_line(P.call(0.34, 0.88), P.call(0.66, 0.88), color, w)
		"pad":
			ci.draw_line(P.call(0.14, 0.3), P.call(0.7, 0.3), color, w * 1.5)
			ci.draw_line(P.call(0.3, 0.5), P.call(0.86, 0.5), color, w * 1.5)
			ci.draw_line(P.call(0.2, 0.7), P.call(0.62, 0.7), color, w * 1.5)
		"bell":
			var pts := PackedVector2Array([P.call(0.14, 0.74), P.call(0.26, 0.62), P.call(0.26, 0.42)])
			for i in 13:
				var ang := PI + PI * i / 12.0
				pts.append(P.call(0.5, 0.42) + Vector2(cos(ang), sin(ang)) * 0.24 * u)
			pts.append_array(PackedVector2Array([P.call(0.74, 0.62), P.call(0.86, 0.74), P.call(0.14, 0.74)]))
			ci.draw_polyline(pts, color, w, true)
			ci.draw_circle(P.call(0.5, 0.86), 0.06 * u, color)
		"drums":
			var top := PackedVector2Array()
			var bottom := PackedVector2Array()
			for i in 25:
				var ang := TAU * i / 24.0
				top.append(P.call(0.5 + 0.34 * cos(ang), 0.46 + 0.11 * sin(ang)))
			for i in 13:
				var ang := PI * i / 12.0
				bottom.append(P.call(0.5 + 0.34 * cos(ang), 0.72 + 0.11 * sin(ang)))
			ci.draw_polyline(top, color, w, true)
			ci.draw_polyline(bottom, color, w, true)
			ci.draw_line(P.call(0.16, 0.46), P.call(0.16, 0.72), color, w)
			ci.draw_line(P.call(0.84, 0.46), P.call(0.84, 0.72), color, w)
			ci.draw_line(P.call(0.22, 0.08), P.call(0.55, 0.4), color, w)
			ci.draw_line(P.call(0.78, 0.08), P.call(0.45, 0.4), color, w)
		"fx":
			ci.draw_colored_polygon(PackedVector2Array([
				P.call(0.5, 0.08), P.call(0.6, 0.4), P.call(0.92, 0.5), P.call(0.6, 0.6),
				P.call(0.5, 0.92), P.call(0.4, 0.6), P.call(0.08, 0.5), P.call(0.4, 0.4)]), color)
		_:
			ci.draw_circle(P.call(0.36, 0.74), 0.15 * u, color)
			ci.draw_line(P.call(0.5, 0.72), P.call(0.5, 0.14), color, w)
			ci.draw_polyline(PackedVector2Array([
				P.call(0.5, 0.14), P.call(0.68, 0.24), P.call(0.74, 0.42)]), color, w, true)
