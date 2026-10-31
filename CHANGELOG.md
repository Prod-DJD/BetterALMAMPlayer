# Changelog

## 1.0.1

- **Full-screen preview**: the ⛶ button, F11 or ⌘F shows just the video, filling the screen (Esc leaves). Space, the arrows and a click still work.
- **Android**: an APK for Android 7.0 and up (arm64). Video export isn't available on Android or iOS.
- The iOS build is now signed ad hoc and runs on iPhone and iPad (it was marked iPad-only and had no signature, so it was killed on launch).
- The app no longer starts the last song again if the previous start never finished, so a song that breaks the app can't trap it in a crash loop.
- Removed a leftover microphone setting from the original project.
- On phones and tablets the window scales to fit a landscape screen.

## 1.0.0

The first full release. Everything in 0.1.0, plus:

- Open Logic Pro projects (`.logicx`): every MIDI track in the arrange, in its order, with its notes. Ported from the MIT-licensed LogicBridge (see `licenses/LogicBridge-MIT.txt`), and checked against its own inspection tool.
- Builds for macOS (universal), Windows (64-bit), Linux (64-bit) and iOS (an unsigned IPA, for jailbroken devices).
- Video export finds ffmpeg on the system PATH on Windows and Linux (install it, e.g. `winget install ffmpeg`). The macOS build includes it.
- Track icons show on every note hit, and note-off velocity is used by the velocity effect.

## 0.1.0: first release

Rebuilt from almam's ALMAMPlayer.

- Playback computed from the song position (exact audio sync, instant seeking); settings kept per song by track name and saved automatically.
- Everything drawn by math: shaped notes with glow, drawn note-hit effect, 100+ drawn instrument icons shown on every hit.
- Note editor (select, move, resize, add, delete, snapping, velocity, undo/redo, save fixed MIDI); edits saved as a difference from the file.
- Drum tracks split into parts (kick, snare, hats…), split by note, merge back, add/remove/rename tracks, drag to reorder.
- Open FL Studio (`.flp`), Ableton Live (`.als`) and Logic Pro (`.logicx`) projects.
- Export MP4 or transparent MOV (ProRes 4444 with alpha), 1080p / 1440p / 4K, 24-120 fps, wide or square.
- Note-off velocity read and used by the velocity effect.
- New app icon and launch screen; the old image assets, soundfont and demo song were removed.
