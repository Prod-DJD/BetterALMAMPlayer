## Renders a song to an MP4: each frame is drawn at its exact time and
## handed straight to ffmpeg, which adds the song's own audio file (not a
## recording of it). No second app, no giant AVI, and it can be stopped.
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

## Where ffmpeg is: inside the app, else this folder's tools, else Homebrew.
static func ffmpeg_path() -> String:
	var exe_dir := OS.get_executable_path().get_base_dir()
	var arch := "arm64" if Engine.get_architecture_name() == "arm64" else "x86_64"
	for p in [
		exe_dir + "/ffmpeg",
		ProjectSettings.globalize_path("res://.tools/ffmpeg/%s/ffmpeg" % arch),
		"/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg", "/usr/bin/ffmpeg",
	]:
		if FileAccess.file_exists(p):
			return p
	return ""

func cancel() -> void:
	_cancel = true

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
	vp.size = Vector2i(1920, 1080)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.transparent_bg = false
	add_child(vp)
	var v := Visualizer.new()
	v.song = song
	v.look = look
	vp.add_child(v)

	var start := -LEAD
	var end: float = max(song.length, audio_length + look.audio_offset) + TAIL
	var frames := int(ceil((end - start) * fps))
	var args := PackedStringArray([
		"-y", "-hide_banner", "-loglevel", "error",
		"-f", "rawvideo", "-pix_fmt", "rgba", "-s", "1920x1080", "-r", str(fps), "-i", "-",
	])
	if audio != "" and FileAccess.file_exists(audio):
		# the audio starts when the song does (plus its delay), after the lead-in
		var at := LEAD + look.audio_offset
		if at >= 0.0:
			args.append_array(["-itsoffset", "%.4f" % at, "-i", audio])
		else:
			args.append_array(["-ss", "%.4f" % -at, "-i", audio])
		args.append_array(["-map", "0:v", "-map", "1:a", "-c:a", "aac", "-b:a", "320k"])
	if look.square:
		args.append_array(["-vf", "crop=1080:1080"])
	args.append_array([
		"-c:v", "libx264", "-preset", "medium", "-crf", "16", "-pix_fmt", "yuv420p",
		"-movflags", "+faststart", "-t", "%.3f" % (end - start), out,
	])
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
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		if img.get_format() != Image.FORMAT_RGBA8:
			img.convert(Image.FORMAT_RGBA8)
		pipe.store_buffer(img.get_data())
		if i % 10 == 0:
			progress.emit(float(i) / frames)
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
