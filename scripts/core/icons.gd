## The instrument icons: ~100 of them, drawn from lines, curves and fills
## (no picture files), so they are sharp at any size and take any color. The
## shapes live in [IconData] (made by assets/branding/make_icons.py);
## [method guess] picks one for a track from its name or General MIDI
## program, [method draw] paints it.
class_name Icons
extends RefCounted

## Icon names that older saved looks used.
const ALIASES := {"winds": "flute", "drums": "drumkit", "fx": "sfx"}

## What each General MIDI program (0-127) sounds like.
const GM := [
	"grandpiano", "piano", "grandpiano", "piano", "epiano", "epiano", "clav", "clav",
	"glockenspiel", "glockenspiel", "musicbox", "vibraphone", "marimba", "xylophone", "tubular", "kalimba",
	"organ", "organ", "organ", "organ", "accordion", "accordion", "harmonica", "accordion",
	"guitar", "guitar", "electricguitar", "electricguitar", "electricguitar", "electricguitar", "electricguitar", "guitar",
	"upright", "bass", "bass", "bass", "bass", "bass", "subbass", "acid",
	"violin", "violin", "cello", "upright", "strings", "pluck", "harp", "timpani",
	"strings", "strings", "strings", "strings", "choir", "choir", "vocoder", "stab",
	"trumpet", "trombone", "tuba", "trumpet", "horn", "brass", "brass", "brass",
	"sax", "sax", "sax", "sax", "oboe", "oboe", "bassoon", "clarinet",
	"flute", "flute", "recorder", "panflute", "ocarina", "flute", "whistle", "ocarina",
	"squarelead", "lead", "lead", "lead", "lead", "vocoder", "lead", "lead",
	"pad", "pad", "synth", "choir", "pad", "pad", "pad", "sweep",
	"rain", "pad", "glockenspiel", "ambience", "pad", "sfx", "ambience", "laser",
	"sitar", "banjo", "mandolin", "koto", "kalimba", "bagpipes", "violin", "oboe",
	"bell", "agogo", "steeldrum", "woodblock", "timpani", "tom", "drummachine", "reverse",
	"glitch", "noise", "ambience", "sfx", "sfx", "sweep", "clap", "impact",
]

## Words in a track's name that say what it is, most specific first. A short
## word (4 letters or fewer) must start a word of the name ("hat", not
## "whatever"); a longer one may appear anywhere.
const WORDS := [
	["kick", ["kick", "bd", "bass drum", "bassdrum"]],
	["sidestick", ["side stick", "sidestick", "rimshot", "rim shot", "rim"]],
	["snare", ["snare", "snr"]],
	["clap", ["clap", "snap"]],
	["openhat", ["open hat", "open hi", "openhat", "ohh", "open hh"]],
	["hihat", ["hihat", "hi-hat", "hi hat", "closed", "chh", "hat", "hh"]],
	["floortom", ["floor"]],
	["tom", ["tom"]],
	["crash", ["crash"]],
	["ride", ["ride"]],
	["cymbal", ["cymbal", "china", "splash", "cym"]],
	["cowbell", ["cowbell"]],
	["tambourine", ["tambourine", "tamb"]],
	["shaker", ["shaker", "maraca", "cabasa"]],
	["conga", ["conga", "perc"]],
	["bongo", ["bongo", "timbale"]],
	["triangle", ["triangle"]],
	["woodblock", ["wood block", "woodblock", "wood"]],
	["claves", ["clave"]],
	["guiro", ["guiro", "cuica", "vibraslap"]],
	["agogo", ["agogo"]],
	["whistle", ["whistle"]],
	["cajon", ["cajon", "cajón"]],
	["timpani", ["timpani", "timp", "taiko"]],
	["gong", ["gong"]],
	["steeldrum", ["steel drum", "steeldrum", "steelpan", "steel pan"]],
	["drummachine", ["drum machine", "drummachine", "909"]],
	["drumkit", ["drum", "kit"]],
	["bassoon", ["bassoon"]],
	["upright", ["upright", "double bass", "doublebass", "contrabass"]],
	["subbass", ["sub bass", "subbass", "sub", "808", "synth bass", "reese"]],
	["acid", ["acid", "303"]],
	["bass", ["bass"]],
	["electricguitar", ["electric guitar", "e-guitar", "eguitar", "egtr", "distort", "overdrive", "lead guitar"]],
	["guitar", ["guitar", "gtr", "nylon", "acoustic"]],
	["banjo", ["banjo"]],
	["mandolin", ["mandolin"]],
	["ukulele", ["ukulele", "uke"]],
	["sitar", ["sitar"]],
	["koto", ["koto", "shamisen"]],
	["clav", ["clav", "harpsichord"]],
	["harp", ["harp"]],
	["grandpiano", ["grand"]],
	["epiano", ["epiano", "e-piano", "e piano", "rhodes", "wurli", "electric piano"]],
	["organ", ["organ", "b3", "hammond"]],
	["accordion", ["accordion"]],
	["harmonica", ["harmonica", "mouth harp"]],
	["mellotron", ["mellotron", "tape"]],
	["piano", ["piano", "keys", "keyboard"]],
	["marimba", ["marimba"]],
	["xylophone", ["xylophone", "xylo"]],
	["vibraphone", ["vibraphone", "vibes", "vibra"]],
	["glockenspiel", ["glock", "celesta"]],
	["musicbox", ["music box", "musicbox"]],
	["tubular", ["tubular", "chime"]],
	["kalimba", ["kalimba"]],
	["bell", ["bell"]],
	["violin", ["violin", "fiddle", "viola"]],
	["cello", ["cello"]],
	["strings", ["string", "orch", "ensemble"]],
	["brass", ["brass", "horns"]],
	["horn", ["horn"]],
	["trumpet", ["trumpet"]],
	["trombone", ["trombone"]],
	["tuba", ["tuba"]],
	["sax", ["sax"]],
	["flute", ["flute", "piccolo"]],
	["clarinet", ["clarinet"]],
	["oboe", ["oboe", "english horn"]],
	["recorder", ["recorder"]],
	["panflute", ["pan flute", "panflute", "pan pipe"]],
	["bagpipes", ["bagpipe"]],
	["ocarina", ["ocarina"]],
	["choir", ["choir", "ooh", "aah", "voices"]],
	["vocoder", ["vocoder", "talkbox"]],
	["vocal", ["vox", "vocal", "voice", "sing", "adlib"]],
	["pad", ["pad", "drone"]],
	["pluck", ["pluck", "pizz"]],
	["arp", ["arp"]],
	["sequence", ["seq", "sequence"]],
	["stab", ["stab", "hit"]],
	["supersaw", ["supersaw"]],
	["wobble", ["wobble", "wub"]],
	["squarelead", ["square"]],
	["lead", ["lead", "saw", "melody", "solo"]],
	["noise", ["noise"]],
	["riser", ["riser", "rise", "build"]],
	["sweep", ["sweep", "whoosh"]],
	["impact", ["impact", "boom"]],
	["laser", ["laser", "zap"]],
	["glitch", ["glitch", "stutter"]],
	["reverse", ["reverse", "rev"]],
	["ambience", ["ambient", "ambience", "atmos", "texture"]],
	["vinyl", ["vinyl", "crackle"]],
	["rain", ["rain", "nature", "weather"]],
	["sfx", ["sfx", "fx", "effect"]],
	["metronome", ["metronome", "click"]],
	["turntable", ["turntable", "scratch"]],
	["sampler", ["sampler", "sample", "chop"]],
	["loop", ["loop"]],
	["speaker", ["speaker"]],
	["synth", ["synth", "chord"]],
]

## Every icon name, in the picker's order.
static func names() -> Array:
	var out := []
	for c in IconData.CATEGORIES:
		out.append_array(c[1])
	return out

static func label(kind: String) -> String:
	return IconData.LABELS.get(ALIASES.get(kind, kind), kind.capitalize())

## The icon for a track: its name first (what the person called it), then
## the General MIDI program the file selects.
static func guess(track_name: String, program: int) -> String:
	var n := track_name.to_lower()
	var tokens: Array = []
	var word := ""
	for ch in n:
		if ch == " " or ch == "_" or ch == "-" or ch == "." or ch == "/" or ch == "(" or ch == ")" or ch == "[" or ch == "]" or ch == "+" or ch == "·":
			if word != "":
				tokens.append(word)
			word = ""
		else:
			word += ch
	if word != "":
		tokens.append(word)
	for entry in WORDS:
		for w: String in entry[1]:
			if w.length() <= 4 and not w.contains(" "):
				for t: String in tokens:
					if t.begins_with(w):
						return entry[0]
			elif n.contains(w):
				return entry[0]
	if program >= 0 and program < GM.size():
		return GM[program]
	return "generic"

## The icon a track shows: the one the person chose, else one picked from
## its name (a drum part by its drum name) or its instrument.
static func for_track(chosen: String, track: Song.Track) -> String:
	if chosen != "":
		return chosen
	var g := guess(track.lane if track.lane != "" else track.name, -1 if track.drums else track.program)
	if g == "generic" and track.drums:
		return "drumkit"
	return g

## Draws [kind] in [rect] (centered, square) in [color].
static func draw(ci: CanvasItem, kind: String, rect: Rect2, color: Color) -> void:
	var id: String = ALIASES.get(kind, kind)
	var shapes: Array = IconData.SHAPES.get(id, IconData.SHAPES["generic"])
	var u := minf(rect.size.x, rect.size.y)
	var o := rect.position + (rect.size - Vector2(u, u)) / 2.0
	var w := maxf(1.3, u * 0.07)
	for s in shapes:
		match s[0]:
			"l":
				var lw: float = w * s[5]
				var a := o + Vector2(s[1], s[2]) * u
				var b := o + Vector2(s[3], s[4]) * u
				ci.draw_line(a, b, color, lw, true)
				if lw >= 2.4:
					ci.draw_circle(a, lw / 2.0, color)
					ci.draw_circle(b, lw / 2.0, color)
			"p":
				var flat: Array = s[1]
				var pts := PackedVector2Array()
				for i in range(0, flat.size(), 2):
					pts.append(o + Vector2(flat[i], flat[i + 1]) * u)
				var pw: float = w * s[2]
				ci.draw_polyline(pts, color, pw, true)
				if pw >= 2.4:
					ci.draw_circle(pts[0], pw / 2.0, color)
					ci.draw_circle(pts[pts.size() - 1], pw / 2.0, color)
			"f":
				# split into triangles once, at the icon's own scale (done again
				# at every size, it could fail on rounding and log an error on
				# every frame)
				var tri: Array = _fill_cache(s)
				if tri.is_empty():
					continue
				var pts := PackedVector2Array()
				for q: Vector2 in tri[0]:
					pts.append(o + q * u)
				var c := Color(color.r, color.g, color.b, color.a * s[2])
				RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), tri[1], pts,
						PackedColorArray([c]))
			"c":
				ci.draw_circle(o + Vector2(s[1], s[2]) * u, s[3] * u, Color(color.r, color.g, color.b, color.a * s[4]))
			"r":
				var rw: float = w * s[4]
				ci.draw_arc(o + Vector2(s[1], s[2]) * u, s[3] * u, 0.0, TAU, 32, color, rw, true)

static var _fills := {}

## A fill's points (at unit size) and its triangles, worked out once. Empty if
## the shape can't be split into triangles.
static func _fill_cache(s: Array) -> Array:
	var key: Array = s[1]
	var hit = _fills.get(key)
	if hit != null:
		return hit
	var pts := PackedVector2Array()
	for i in range(0, key.size(), 2):
		pts.append(Vector2(key[i], key[i + 1]))
	var idx := Geometry2D.triangulate_polygon(pts) if pts.size() >= 3 else PackedInt32Array()
	if idx.is_empty() and pts.size() >= 3:
		# a shape that touches itself: fill its outline's hull instead
		pts = Geometry2D.convex_hull(pts)
		pts.remove_at(pts.size() - 1)
		idx = Geometry2D.triangulate_polygon(pts)
	var out := [pts, idx] if not idx.is_empty() else []
	_fills[key] = out
	return out
