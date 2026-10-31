## How a song looks: the scene settings and each track's settings. Saved
## as plain JSON; anything missing (an older file, a new track) gets a
## default instead of breaking. Tracks are matched by name, so reordering
## or adding tracks in the MIDI keeps everyone's colors.
class_name Look
extends RefCounted

## How a note is shaped (all drawn, never from pictures).
enum Shape { PILL, SOFT, SHARP }

class TrackLook:
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

	func to_dict() -> Dictionary:
		return {
			"color": color.to_html(), "parallax": parallax, "shape": shape,
			"icon": icon, "staccato": staccato, "visible": visible,
		}

	static func from_dict(d: Dictionary, fallback: TrackLook) -> TrackLook:
		var t := TrackLook.new()
		t.color = Color.from_string(str(d.get("color", "")), fallback.color)
		t.parallax = float(d.get("parallax", fallback.parallax))
		t.shape = clampi(int(d.get("shape", fallback.shape)), 0, 2)
		t.icon = str(d.get("icon", ""))
		t.staccato = bool(d.get("staccato", false))
		t.visible = bool(d.get("visible", true))
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
## Seconds the notes are shifted against the audio (+: notes later).
var audio_offset := 0.0
var square := false
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

static func default_track(i: int, count: int) -> TrackLook:
	var t := TrackLook.new()
	var n: float = max(count, 1)
	t.color = Color.from_hsv(1.0 / n * i, 0.62 + float(i + 1) / ((n + 1) * 4), 0.92 - float(i + 1) / ((n + 1) * 4))
	t.parallax = (1.2 / n * (n - i)) + 0.6
	return t

func to_dict() -> Dictionary:
	var tr := {}
	for k in tracks:
		tr[k] = tracks[k].to_dict()
	return {
		"version": 3, "speed": speed, "vertical_offset": vertical_offset,
		"top_margin": top_margin, "velocity_strength": velocity_strength,
		"pitch_bend_strength": pitch_bend_strength, "audio_offset": audio_offset,
			"glow": glow, "thickness": thickness,
		"square": square, "background": background, "tracks": tr, "order": order,
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
	l.square = bool(d.get("square", false))
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
