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
	var sep := ";" if OS.get_name() == "Windows" else ":"
	for dir in OS.get_environment("PATH").split(sep, false):
		candidates.append(dir.path_join(name))
	for p in candidates:
		if FileAccess.file_exists(p):
			return p
	return ""

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
		finished.emit(false, "ffmpeg isn't there, so it can't make a video.")
		return
	running = true
	_cancel = false
	var vp := SubViewport.new()
	# drawn at the video's own size from the same 1920×1080 picture: shapes
	# stay sharp at 1440p and 4K
	var height: int = look.export_height
	var width: int = int(round(height * 16.0 / 9.0))
	vp.size = Vector2i(width, height)
	vp.size_2d_override = Vector2i(1920, 1080)
	vp.size_2d_override_stretch = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
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
	for i in frames:
		if _cancel or not OS.is_process_running(pid):
			ok = false
			break
		v.time = start + float(i) / fps
		# drawn now, on purpose: the window's own frames stop when it's
		# hidden or minimized, and an export must not wait on them
		RenderingServer.force_draw(false)
		var img := vp.get_texture().get_image()
		if img == null: # no renderer (a headless run): nothing to draw with
			ok = false
			break
		if img.get_format() != Image.FORMAT_RGBA8:
			img.convert(Image.FORMAT_RGBA8)
		pipe.store_buffer(img.get_data())
		if i % 10 == 0:
			progress.emit(float(i) / frames)
			await get_tree().process_frame # the window stays responsive
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
