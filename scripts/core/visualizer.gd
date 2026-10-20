## Draws a song at one moment, [member time] (seconds into the song). The
## picture is worked out from that time alone: no node moves by itself and
## nothing waits on timers, so the live preview, seeking and the exported
## video always agree with the audio, frame for frame.
##
## The look matches the original ALMAMPlayer: notes scroll right to left
## past the middle of a 1920×1080 frame; a note lights up, dips and swells
## a little as it plays (more with velocity), its "note on" image pops at
## the playhead, pitch bends shift the playing notes, and tracks with more
## parallax move faster and sit in front.
class_name Visualizer
extends Node2D

const WIDTH := 1920.0
const HEIGHT := 1080.0
const PLAYHEAD := WIDTH / 2.0

var song: Song
var look: Look
## Seconds into the song (negative: before it starts; the tracks rise in).
var time := 0.0:
	set(v):
		time = v
		queue_redraw()

var _tex_cache := {} # path → Texture2D (or null if it couldn't load)
var _boxes := {} # track name → StyleBoxTexture
var _background: Texture2D
var _background_path := "?"

## Call after the song or look changed in ways that need reloading
## (textures, background, margins).
func refresh() -> void:
	_boxes.clear()
	queue_redraw()

func texture(path: String) -> Texture2D:
	if path == "":
		return null
	if _tex_cache.has(path):
		return _tex_cache[path]
	var t: Texture2D = null
	if path.begins_with("res://"):
		t = load(path)
	elif FileAccess.file_exists(path):
		var img := Image.load_from_file(path)
		if img != null:
			t = ImageTexture.create_from_image(img)
	_tex_cache[path] = t
	return t

func _box(name: String, tl: Look.TrackLook) -> StyleBoxTexture:
	if _boxes.has(name):
		return _boxes[name]
	var b := StyleBoxTexture.new()
	b.texture = texture(tl.note_texture)
	if b.texture == null:
		b.texture = load(Look.DEFAULT_NOTE)
	b.texture_margin_left = tl.margins.x
	b.texture_margin_right = tl.margins.y
	b.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	_boxes[name] = b
	return b

func spacing() -> float:
	if song == null:
		return 10.0
	var span: float = max(1, song.highest - song.lowest)
	return (look.vertical_offset + look.top_margin) / span

static func _ease(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return 0.5 - 0.5 * cos(PI * x) # sine in-out, as the original's tweens

func _draw() -> void:
	draw_rect(Rect2(0, 0, WIDTH, HEIGHT), Color.BLACK)
	if look == null:
		return
	_draw_background()
	if song == null:
		return
	var count := song.tracks.size()
	# farther tracks (less parallax) first, nearer ones on top
	var order: Array = []
	for i in count:
		var tr: Song.Track = song.tracks[i]
		order.append([look.track_look(tr.name, i, count), tr])
	order.sort_custom(func(a, b): return a[0].parallax < b[0].parallax)
	var base_y := HEIGHT + look.vertical_offset
	var gap := spacing()
	# the tracks rise in over the first second
	var intro := _ease((time + 1.0) / 0.5)
	var intro_y := 128.0 * (1.0 - _ease((time + 1.5) / 1.0))
	var effects: Array = []
	for pair in order:
		var tl: Look.TrackLook = pair[0]
		var tr: Song.Track = pair[1]
		if not tl.visible:
			continue
		var px_per_s: float = look.speed * tl.parallax
		var color: Color = Color.WHITE if tl.plain else tl.color
		var box := _box(tr.name, tl)
		var stacc: Texture2D = texture(Look.DEFAULT_STACCATO) if tl.staccato else null
		var note_h: float = box.texture.get_height()
		var bend := Song.bend_at(tr, time) * 4.0 * gap * look.pitch_bend_strength
		# notes whose rectangle can reach the screen
		var from_t := time - PLAYHEAD / px_per_s - tr.longest - 0.5
		var to_t := time + PLAYHEAD / px_per_s + 0.1
		var i := Song.first_from(tr, from_t)
		while i < tr.notes.size():
			var n: Song.Note = tr.notes[i]
			i += 1
			if n.start > to_t:
				break
			var dur: float = n.end - n.start if not tl.staccato else 0.1
			var x := PLAYHEAD + (n.start - time) * px_per_s
			var w: float = stacc.get_width() if stacc else max(dur * px_per_s, 2.0)
			if x + w < 0:
				continue
			var y := base_y - (n.pitch - song.lowest) * gap + intro_y
			# playing: light up and dip (more with velocity), then back
			var on := time - n.start
			var light := 0.0
			var dip := 0.0
			var swell := 0.0
			var dip_px := 6.0 if look.velocity_strength < 0.01 \
					else 0.25 + n.velocity * look.velocity_strength * 0.7
			if on >= 0.0:
				var off: float = time - (n.start + max(dur, 0.1))
				var up := _ease(on / 0.17)
				var down := 1.0 - _ease(off / 0.27) if off > 0.0 else 1.0
				light = 0.3 * up * down
				dip = dip_px * up * down
				swell = 0.03 * _ease(on / 0.2)
				if off < 1.2:
					y += bend
			var c := Color(color.r + light, color.g + light, color.b + light, intro)
			if dur > 1.0 and on > 0.0:
				var fade := lerpf(1.0, 0.941, clampf(on / 1.494, 0.0, 1.0))
				c = Color(c.r * fade, c.g * fade, c.b * fade, c.a)
			var top := y + dip - note_h / 2.0
			draw_set_transform(Vector2(x, y + dip), 0.0, Vector2.ONE * (1.0 + swell))
			if stacc:
				draw_texture_rect(stacc, Rect2(0, -stacc.get_height() / 2.0, w, stacc.get_height()), false, c)
			else:
				box.modulate_color = c
				draw_style_box(box, Rect2(0, -note_h / 2.0, w, note_h))
			draw_set_transform(Vector2.ZERO)
			# its "note on" image, at the playhead
			if on >= 0.0 and on < max(dur - 0.025, 0.065) + 0.17:
				effects.append([tl, n, y + dip, on, dur])
			if top > HEIGHT + 64:
				pass
	_draw_effects(effects)

func _draw_effects(effects: Array) -> void:
	for e in effects:
		var tl: Look.TrackLook = e[0]
		var n: Song.Note = e[1]
		var y: float = e[2]
		var on: float = e[3]
		var dur: float = e[4]
		var tex := texture(tl.effect_texture)
		if tex == null:
			tex = load(Look.DEFAULT_EFFECT)
		var hold: float = max(dur - 0.025, 0.065)
		var s := 1.0
		var a := 1.0
		if on < 0.0269:
			s = lerpf(0.8, 1.16, on / 0.0269)
		elif on < 0.0956:
			s = lerpf(1.16, 1.0, (on - 0.0269) / (0.0956 - 0.0269))
		if on > hold:
			var end := on - hold
			s = lerpf(1.0, 0.0, clampf(end / 0.1667, 0.0, 1.0))
			a = 1.0 - clampf((end - 0.0833) / (0.1458 - 0.0833), 0.0, 1.0)
		if look.velocity_strength > 0.01:
			s *= 0.55 + n.velocity / 127.0 * 0.5
		var col: Color = Color.WHITE if tl.plain else tl.color
		col = Color(col.r + 0.1, col.g + 0.1, col.b + 0.1, a)
		var size := tex.get_size() * s
		draw_texture_rect(tex, Rect2(Vector2(PLAYHEAD, y) - size / 2.0, size), false, col)

func _draw_background() -> void:
	if _background_path != look.background:
		_background_path = look.background
		_background = texture(look.background)
	if _background == null:
		return
	var area := Rect2(0, 0, WIDTH, HEIGHT)
	if look.square:
		area = Rect2((WIDTH - HEIGHT) / 2.0, 0, HEIGHT, HEIGHT)
	# cover the area, keeping the picture's shape
	var ts := _background.get_size()
	var k: float = max(area.size.x / ts.x, area.size.y / ts.y)
	var shown := area.size / k
	var src := Rect2((ts - shown) / 2.0, shown)
	draw_texture_rect_region(_background, area, src)
