## How a song looks: the scene settings and each track's settings. Saved
## as plain JSON; anything missing (an older file, a new track) gets a
## default instead of breaking. Tracks are matched by name, so reordering
## or adding tracks in the MIDI keeps everyone's colors.
class_name Look
extends RefCounted

## How a note is shaped (all drawn, never from pictures).
enum Shape { PILL, SOFT, SHARP }

class TrackLook:
	## The settings a track can have of its own, over the scene's.
	const OWN := ["top_margin", "vertical_offset", "thickness", "glow", "icon_size", "velocity_strength", "pitch_bend_strength"]

	var color := Color.WHITE
	## How fast this track's notes move, relative to the scene speed
	## (the depth effect). Who is in front is the track list's order.
	var parallax := 1.0
	var shape := Shape.PILL
	## An icon name from [Icons], or "" to pick one from the track itself.
	var icon := ""
	## Short dots instead of long notes.
	var staccato := false
	var visible := true
	## Only the notes between these pitches are shown (the track's range).
	var low := 0
	var high := 127
	## The settings the scene has for every track, when this track wants its own
	## (NAN: follow the scene). Where its notes sit, how thick they are and how
	## they react.
	var top_margin := NAN
	var vertical_offset := NAN
	var thickness := NAN
	var glow := NAN
	var icon_size := NAN
	var velocity_strength := NAN
	var pitch_bend_strength := NAN

	func to_dict() -> Dictionary:
		var d := {
			"color": color.to_html(), "parallax": parallax, "shape": shape,
			"icon": icon, "staccato": staccato, "visible": visible, "low": low, "high": high,
		}
		for k in OWN:
			if not is_nan(get(k)):
				d[k] = get(k)
		return d

	static func from_dict(d: Dictionary, fallback: TrackLook) -> TrackLook:
		var t := TrackLook.new()
		t.color = Color.from_string(str(d.get("color", "")), fallback.color)
		t.parallax = float(d.get("parallax", fallback.parallax))
		t.shape = clampi(int(d.get("shape", fallback.shape)), 0, 2)
		t.icon = str(d.get("icon", ""))
		t.staccato = bool(d.get("staccato", false))
		t.visible = bool(d.get("visible", true))
		t.low = clampi(int(d.get("low", 0)), 0, 127)
		t.high = clampi(int(d.get("high", 127)), t.low, 127)
		for k in OWN:
			if d.has(k):
				t.set(k, float(d[k]))
		return t

## Pixels a second at parallax 1.
var speed := 300.0
## Where the lowest note sits, from the bottom (negative: up), px.
var vertical_offset := -192.0
## How far up the highest note reaches, px.
var top_margin := 880.0
var velocity_strength := 0.2
var pitch_bend_strength := 0.5
## How much notes glow while they play, and how thick they are (× the
## default, which follows the note spacing).
var glow := 0.6
var thickness := 1.0
## How big the track icon is when a note hits (× a size that follows the
## note thickness).
var icon_size := 1.6
## Seconds the notes are shifted against the audio (+: notes later).
var audio_offset := 0.0
var square := false
## The exported video: its height in pixels (1080, 1440 or 2160 for 4K; the
## width follows at 16:9, or the same as the height for a square video) and
## its frame rate.
var export_height := 1080
var export_fps := 60
## The video format: "mp4" (H.264, on black, plays anywhere), or one that
## keeps a transparent background: "prores" (.mov, the best for editing, the
## biggest), "hevc" (.mov, much smaller, Apple apps) or "webm" (VP9, the
## smallest; browsers and some editors).
var export_format := "mp4"
## "fast" or "best": how hard the encoder works (best is slower, same format).
var export_quality := "fast"
## Compress harder for a smaller file at the same picture quality (slower to
## render). Not offered for ProRes and HEVC, which have no such setting.
var export_smaller := false
var background := ""
## Track name → TrackLook
var tracks := {}
## Track names in the order the person put them (empty: the file's order).
var order: Array = []

## The look for [track] number [i] of [count]: saved, or a default
## (colors around the wheel, the top tracks faster).
func track_look(name: String, i: int, count: int) -> TrackLook:
	if tracks.has(name):
		return tracks[name]
	var t := default_track(i, count)
	tracks[name] = t
	return t

## The value that applies to [param tl]: its own if it has one, else the scene's.
func top_margin_of(tl: TrackLook) -> float:
	return top_margin if is_nan(tl.top_margin) else tl.top_margin
func offset_of(tl: TrackLook) -> float:
	return vertical_offset if is_nan(tl.vertical_offset) else tl.vertical_offset
func thickness_of(tl: TrackLook) -> float:
	return thickness if is_nan(tl.thickness) else tl.thickness
func glow_of(tl: TrackLook) -> float:
	return glow if is_nan(tl.glow) else tl.glow
func icon_size_of(tl: TrackLook) -> float:
	return icon_size if is_nan(tl.icon_size) else tl.icon_size
func velocity_of(tl: TrackLook) -> float:
	return velocity_strength if is_nan(tl.velocity_strength) else tl.velocity_strength
func bend_of(tl: TrackLook) -> float:
	return pitch_bend_strength if is_nan(tl.pitch_bend_strength) else tl.pitch_bend_strength

static func default_track(i: int, count: int) -> TrackLook:
	var t := TrackLook.new()
	var n: int = max(count, 1)
	# the hues spread evenly around the wheel, and neighbours in the list get
	# hues far apart: step through them by a stride that shares no factor with n
	var stride := 1
	for k in range(maxi(int(n * 0.618), 1), 0, -1):
		if _gcd(k, n) == 1:
			stride = k
			break
	var slot := (i * stride) % n
	t.color = Color.from_hsv(float(slot) / n, 0.85, 0.95)
	t.parallax = (1.2 / float(n) * (n - i)) + 0.6
	return t

static func _gcd(a: int, b: int) -> int:
	return a if b == 0 else _gcd(b, a % b)

func to_dict() -> Dictionary:
	var tr := {}
	for k in tracks:
		tr[k] = tracks[k].to_dict()
	return {
		"version": 3, "speed": speed, "vertical_offset": vertical_offset,
		"top_margin": top_margin, "velocity_strength": velocity_strength,
		"pitch_bend_strength": pitch_bend_strength, "audio_offset": audio_offset,
			"glow": glow, "thickness": thickness, "icon_size": icon_size,
		"square": square, "export_height": export_height, "export_fps": export_fps, "export_format": export_format, "export_quality": export_quality, "export_smaller": export_smaller, "background": background, "tracks": tr, "order": order,
	}

static func from_dict(d: Dictionary) -> Look:
	var l := Look.new()
	l.speed = float(d.get("speed", l.speed))
	l.vertical_offset = float(d.get("vertical_offset", l.vertical_offset))
	l.top_margin = float(d.get("top_margin", l.top_margin))
	l.velocity_strength = float(d.get("velocity_strength", l.velocity_strength))
	l.pitch_bend_strength = float(d.get("pitch_bend_strength", l.pitch_bend_strength))
	l.audio_offset = float(d.get("audio_offset", l.audio_offset))
	l.glow = float(d.get("glow", l.glow))
	l.thickness = float(d.get("thickness", l.thickness))
	l.icon_size = clampf(float(d.get("icon_size", l.icon_size)), 0.3, 6.0)
	l.square = bool(d.get("square", false))
	l.export_height = int(d.get("export_height", 1080)) if int(d.get("export_height", 1080)) in [1080, 1440, 2160] else 1080
	l.export_fps = int(d.get("export_fps", 60)) if int(d.get("export_fps", 60)) in [24, 30, 60, 120] else 60
	l.export_format = str(d.get("export_format", "mp4")) if str(d.get("export_format", "mp4")) in ["mp4", "prores", "hevc", "webm"] else "mp4"
	l.export_quality = "best" if str(d.get("export_quality", "fast")) == "best" else "fast"
	l.export_smaller = bool(d.get("export_smaller", false))
	l.background = str(d.get("background", ""))
	var o = d.get("order", [])
	if o is Array:
		for name in o:
			l.order.append(str(name))
	var tr = d.get("tracks", {})
	if tr is Dictionary:
		var i := 0
		for k in tr:
			if tr[k] is Dictionary:
				l.tracks[str(k)] = TrackLook.from_dict(tr[k], default_track(i, tr.size()))
			i += 1
	return l

## A copy, for presets (the same look on another song).
func duplicate_look() -> Look:
	return Look.from_dict(to_dict())
