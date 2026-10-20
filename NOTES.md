# ALMAMPlayer: DJ D's improved fork

Side project (2026-10-20). DJ D wants ALMAMPlayer (MIDI visualizer by almam,
https://github.com/almam72/ALMAMPlayer, GPLv3) easy enough to use weekly.
This folder is a clone; `upstream` is almam's repo, our work is local
commits. GPLv3: our changes stay GPLv3 and credit almam.

## Running it here
- Godot 4.7.2 lives in `.tools/` (gitignored). Always run it through
  `.tools/godot.sh`, which keeps Godot's data and the app's settings inside
  `.tools/home` instead of ~/Library.
- Screenshot of the running app: `.tools/godot.sh --path . --windowed -s .tools/shot_main.gd`
  (saves `.tools/shots/main.png`).

## What was wrong (audit, 2026-10-20)
1. Timing guessed from frame deltas and per-note timers; drifts from the
   audio, effects early/late, hard-coded fudge offsets. Export inherits it.
2. Settings keyed by track index ("0", "1"…): MIDIs with more tracks than the
   config give nulls (the black screen users report); missing keys crash.
3. load_midi adds every note twice and never clears the previous song's
   notes: the note range (spacing) is wrong after the first file.
4. Export runs a second hidden app instance recording a huge MJPEG AVI, no
   progress, user converts it themselves.
5. Clunky: quit nag, "loaded config" vs "default config", mp3/wav only,
   Godot-drawn file dialogs, preview colors not matching the track list.

## Plan
1. Run on Godot 4.7 (native file dialogs) ✔
2. Playback rebuilt so each frame is computed from the song position ✔
3. Per-project settings keyed by track name, autosave, no quit nag ✔
4. Export to MP4 with progress ✔ (ffmpeg bundled; frames force-drawn so a
   hidden window doesn't stall it)
5. Mac .app for DJ D ✔ (first build sent 2026-10-20). Not done yet: per-track
   note edge margins in the UI, FLAC audio, a full-screen preview window.

## Building
`.tools/build.sh` → `.tools/build/ALMAMPlayer.app` (universal, ffmpeg inside,
ad-hoc signed; it stops if any script has errors). Zip with
`ditto -c -k --keepParent`. Command-line render (also a good test):
`ALMAMPlayer.app/Contents/MacOS/ALMAMPlayer -- --render=song.mid --out=song.mp4`.
