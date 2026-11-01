## Renders a song to a video: each frame is drawn at its exact time and
## handed straight to ffmpeg, which adds the song's own audio file (not a
## recording of it). No second app, no giant AVI, and it can be stopped.
## A .mov (ProRes 4444, HEVC or VP9 by the look) or a .webm (VP9) keeps an
## alpha channel: the notes are
## drawn over nothing, so they drop straight onto other footage with no
## keying. Any other name (.mp4) is a normal video on black.
class_name Exporter
extends Node

signal progress(done: float)
signal finished(ok: bool, message: String)

const FPS_DEFAULT := 60
## Seconds of lead-in (the tracks rise in) and of tail after the last note.
const LEAD := 1.0
const TAIL := 2.0

var _cancel := false
## Frames whose picture couldn't be confirmed for their time (should stay 0).
var stale := 0
var running := false

## Where ffmpeg is: inside the app, else this folder's tools, else the
## system's (Homebrew, Program Files, or anywhere on PATH).
static func ffmpeg_path() -> String:
	var exe_dir := OS.get_executable_path().get_base_dir()
	var arch := "arm64" if Engine.get_architecture_name() == "arm64" else "x86_64"
	var name := "ffmpeg.exe" if OS.get_name() == "Windows" else "ffmpeg"
	var candidates := [
		exe_dir.path_join(name),
		ProjectSettings.globalize_path("res://.tools/ffmpeg/%s/ffmpeg" % arch),
		"/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg", "/usr/bin/ffmpeg",
		"C:/ffmpeg/bin/ffmpeg.exe", "C:/Program Files/ffmpeg/bin/ffmpeg.exe",
	]
	if OS.get_name() == "Android":
		# an app may only run programs from its native library folder, so the
		# APK carries ffmpeg there as libffmpeg.so (the way YTDLnis does)
		var lib := android_library_dir()
		if lib != "":
			candidates.push_front(lib.path_join("libffmpeg.so"))
	var sep := ";" if OS.get_name() == "Windows" else ":"
	for dir in OS.get_environment("PATH").split(sep, false):
		candidates.append(dir.path_join(name))
	for p in candidates:
		if FileAccess.file_exists(p):
			return p
	return ""

## The folder Android unpacked this app's native libraries into: where
## libgodot_android.so was loaded from (read from the process's memory map).
static func android_library_dir() -> String:
	var f := FileAccess.open("/proc/self/maps", FileAccess.READ)
	if f == null:
		return ""
	while not f.eof_reached():
		var dir := library_dir_in(f.get_line())
		if dir != "":
			return dir
	return ""

## The folder in a line of /proc/self/maps that maps libgodot_android.so ("" if
## the line is about something else).
static func library_dir_in(line: String) -> String:
	var at := line.find("libgodot_android.so")
	if at < 0:
		return ""
	var start := line.rfind(" ", at) + 1
	return line.substr(start, at - start).rstrip("/")

## Draws the picture for time [param t] (already set on [param v]) and gives
## it back. The visualizer's drawing for a new time only happens during one of
## the app's frames, so this lets frames pass until the picture has really
## been drawn for [param t], then renders it, whether or not the window is
## showing (macOS slows or stops a hidden window's frames; drawing straight
## away then would save the old picture again, which looked like stutter).
func _render(vp: SubViewport, v: Visualizer, t: float) -> Image:
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	for attempt in 8:
		await get_tree().process_frame
		if v.drawn_time == t:
			break
	if v.drawn_time != t:
		stale += 1
	RenderingServer.force_draw(false)
	var img := vp.get_texture().get_image()
	if img != null and img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	return img

func cancel() -> void:
	_cancel = true

## Megabits per second for HEVC at a frame height (a sensible fixed rate).
static func _mbps(height: int) -> int:
	return 40 if height >= 2160 else (20 if height >= 1440 else 12)

static func wants_alpha(out: String) -> bool:
	var low := out.to_lower()
	return low.ends_with(".mov") or low.ends_with(".webm")

## The video codec for a transparent [param out]: a .webm is always VP9
## (WebM carries VP9, not ProRes); a .mov uses the look's format.
static func alpha_codec_for(out: String, format: String) -> String:
	if out.to_lower().ends_with(".webm"):
		return "vp9"
	return "hevc" if format == "hevc" else "prores"

## The file ending a format is saved with.
static func extension_for(format: String) -> String:
	match format:
		"prores", "hevc":
			return "mov"
		"webm":
			return "webm"
	return "mp4"

## Renders [song] with [look] (and [audio], if any) to [out] at [fps].
func run(song: Song, look: Look, audio: String, out: String, fps := FPS_DEFAULT, audio_length := 0.0) -> void:
	if running:
		return
	var ff := ffmpeg_path()
	if ff == "":
		if OS.get_name() == "iOS":
			finished.emit(false, "iPhones and iPads can't run ffmpeg, so they can't export video. Screen-record the preview instead.")
		else:
			finished.emit(false, "ffmpeg isn't there, so it can't make a video.")
		return
	running = true
	_cancel = false
	stale = 0
	var vp := SubViewport.new()
	# drawn at the video's own size from the same 1920×1080 picture: shapes
	# stay sharp at 1440p and 4K
	var height: int = look.export_height
	var width: int = int(round(height * 16.0 / 9.0))
	vp.size = Vector2i(width, height)
	vp.size_2d_override = Vector2i(1920, 1080)
	vp.size_2d_override_stretch = true
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED # drawn only when a frame is asked for
	var alpha := wants_alpha(out)
	vp.transparent_bg = alpha
	add_child(vp)
	var v := Visualizer.new()
	v.song = song
	v.look = look
	v.transparent = alpha
	vp.add_child(v)

	var start := -LEAD
	var end: float = max(song.length, audio_length + look.audio_offset) + TAIL
	var frames := int(ceil((end - start) * fps))
	var args := PackedStringArray([
		"-y", "-hide_banner", "-loglevel", "error",
		"-f", "rawvideo", "-pix_fmt", "rgba", "-s", "%dx%d" % [width, height], "-r", str(fps), "-i", "-",
	])
	var webm := out.to_lower().ends_with(".webm")
	if audio != "" and FileAccess.file_exists(audio):
		# the audio starts when the song does (plus its delay), after the lead-in
		var at := LEAD + look.audio_offset
		if at >= 0.0:
			args.append_array(["-itsoffset", "%.4f" % at, "-i", audio])
		else:
			args.append_array(["-ss", "%.4f" % -at, "-i", audio])
		args.append_array(["-map", "0:v", "-map", "1:a"])
		# WebM carries Opus, the .mov files AAC
		args.append_array(["-c:a", "libopus", "-b:a", "192k"] if webm else ["-c:a", "aac", "-b:a", "320k"])
	if look.square:
		args.append_array(["-vf", "crop=%d:%d" % [height, height]])
	if alpha:
		match alpha_codec_for(out, look.export_format):
			"hevc":
				# Apple's compact transparent video (macOS): smaller than ProRes
				args.append_array(["-c:v", "hevc_videotoolbox", "-alpha_quality", "0.75",
						"-tag:v", "hvc1", "-b:v", "%dM" % _mbps(height), "-pix_fmt", "bgra"])
			"vp9":
				# alpha needs auto-alt-ref off; CRF with no bitrate cap
				args.append_array(["-c:v", "libvpx-vp9", "-pix_fmt", "yuva420p", "-b:v", "0",
						"-crf", "28", "-auto-alt-ref", "0", "-row-mt", "1"])
			_:
				# ProRes 4444 with alpha: Final Cut, Premiere, Resolve and After Effects read it
				args.append_array(["-c:v", "prores_ks", "-profile:v", "4444", "-pix_fmt", "yuva444p10le",
						"-alpha_bits", "16", "-vendor", "apl0"])
	else:
		args.append_array(["-c:v", "libx264", "-preset", "medium", "-crf", "16", "-pix_fmt", "yuv420p",
				"-movflags", "+faststart"])
	args.append_array(["-t", "%.3f" % (end - start), out])
	var proc := OS.execute_with_pipe(ff, args)
	if proc.is_empty():
		running = false
		vp.queue_free()
		finished.emit(false, "ffmpeg didn't start.")
		return
	var pipe: FileAccess = proc["stdio"]
	var pid: int = proc["pid"]
	var ok := true
	# frames come as fast as they can be drawn, not as fast as the screen refreshes
	var prev_vsync := DisplayServer.window_get_vsync_mode()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var prev_hash := 0
	var prev_busy := false
	var redrawn := 0
	for i in frames:
		if _cancel or not OS.is_process_running(pid):
			ok = false
			break
		v.time = start + float(i) / fps
		var t: float = v.time
		var img: Image = await _render(vp, v, t)
		if img == null: # no renderer (a headless run): nothing to draw with
			ok = false
			break
		var busy := v.drawn > 0
		var h: int = hash(img.get_data())
		# the same picture twice while notes are moving means the renderer
		# was late with this frame: draw it again (it is never skipped)
		var tries := 0
		while busy and prev_busy and h == prev_hash and tries < 4:
			tries += 1
			img = await _render(vp, v, t)
			if img == null:
				break
			h = hash(img.get_data())
		if img == null:
			ok = false
			break
		if tries > 0:
			redrawn += 1
		prev_hash = h
		prev_busy = busy
		pipe.store_buffer(img.get_data())
		if i % 10 == 0:
			progress.emit(float(i) / frames)
	DisplayServer.window_set_vsync_mode(prev_vsync)
	if redrawn > 0 or stale > 0:
		print("export: %d of %d frames drawn again, %d not confirmed" % [redrawn, frames, stale])
	pipe.close()
	# let ffmpeg finish the file
	while OS.is_process_running(pid) and not _cancel:
		await get_tree().create_timer(0.1).timeout
	if _cancel:
		OS.kill(pid)
		DirAccess.remove_absolute(out)
	var err := ""
	var stderr: FileAccess = proc.get("stderr")
	if stderr:
		err = stderr.get_as_text().strip_edges()
	vp.queue_free()
	running = false
	if _cancel:
		finished.emit(false, "Stopped.")
	elif not ok or not FileAccess.file_exists(out):
		finished.emit(false, "The video couldn't be made. " + err.left(300))
	else:
		progress.emit(1.0)
		finished.emit(true, out)
