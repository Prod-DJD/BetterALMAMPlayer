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

## Makeover (2026-10-31, from DJ D; more to be added)
Done, in the code (see git log):
1. Everything drawn by math, no pictures: notes are rounded shapes (Pill /
   Soft / Sharp, or dots) with a highlight and a glow while they play, the
   "note on" pop is a drawn halo + ring, the instrument icons are drawn
   (scripts/core/icons.gd, picked from the track's name or General MIDI
   program, changeable per track). The hearts and every note/effect PNG
   are gone. Old saved looks still load (missing fields get defaults).
2. Note editor (Edit notes / Tab): piano roll with select, move, resize,
   add (double-click), delete, box select, click a piano key to select a
   pitch (keyswitches), velocity, snap, undo/redo, Save MIDI…, Revert all.
   Edits are saved with the song as a difference from the file
   (Song.edits / apply_edits), so the original is never changed.
3. Import: .mid, FL Studio .flp (scripts/core/flp_reader.gd), Ableton .als
   (ableton_reader.gd): every track found automatically.
   Limits: first tempo only (no tempo automation), audio clips ignored,
   written from the file-format layout and tested on synthetic files only:
   needs a real .flp / .als to confirm.
4. Logic (.logicx): no documented format and no converter found; the app
   says to use File > Export > All Tracks as MIDI Files. If DJ D names the
   FLP-to-Logic converter he means, look at how it reads the package.

Tests (not in git, in .tools/): `.tools/godot.sh --headless --path . -s
.tools/test_core.gd` (importers, edits, MIDI round trip) and `test_app.gd`
(the whole app, editing, reopening). Screenshots can't be taken from the
Claude sandbox (it blocks windows); run `.tools/shot_main.gd` yourself.

Still open: per-track note edge margins are gone with the images (not
needed); FLAC audio; a full-screen preview window; Reaper / MusicXML
import; add new requests here.
