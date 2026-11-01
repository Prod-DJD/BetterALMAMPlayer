# Changelog

## 1.0.8

- Export now works the way the original ALMAMPlayer's did: a second, small copy of the app makes the video, at low priority, so your Mac and your other apps come first. The main window stays usable and shows the progress.
- Each frame is drawn once by the engine's normal loop and read back (as Godot's Movie Maker does); nothing is forced or drawn twice, which is what overloaded the GPU and could restart the Mac.
- The app now watches the export's real memory from outside (the operating system's own count, graphics memory included) and stops it if it passes 4 GB. The old check only saw part of it: a crash report showed the export at 26 GB while the check saw nothing wrong.
- On a Mac the export draws with Metal instead of Apple's old OpenGL layer, which kept the graphics memory of every frame read back until the whole Mac locked up.
- The export also stops if the whole Mac runs low on memory (graphics memory doesn't show in the app's own count).
- The whole app now draws with Metal on a Mac (Vulkan or DirectX on Windows and Linux) instead of Apple's old OpenGL layer; phones are unchanged. The Mac froze even during plain playback under OpenGL.
- Icons draw from shapes worked out once, instead of being re-split at every size (which failed on some and logged errors while playing).
- Opening a song with a 24-bit WAV (what Logic bounces) is near instant: Godot took minutes to read those, so a 16-bit copy is made once by ffmpeg and kept.
- Any WAV that isn't plain 16-bit (24-bit, float, or Logic's "extensible" header) is converted once to a 16-bit copy before loading; Godot's own loader used gigabytes and froze the app on those.
- Opening a song writes a step-by-step trace (time and memory at each step) to load_trace.log in the app's data folder, to find what makes a start slow.
- Stopping an export removes the half-made video; closing the app stops the export too.

## 1.0.7

- **Fixed exports that crawled.** In 1.0.5 and 1.0.6, every video frame waited out a two-second timeout (the wait was on a setting that never changes), so exports ran at under 2 frames a second. Each frame is now drawn once, right after its picture has been recorded for its moment, so exports are fast again and still smooth.
- **Doesn't depend on the window being in front**, and the app's loop is capped so it can't run away if the window is hidden.
- The live preview isn't drawn during an export, so the picture isn't rendered twice.

## 1.0.6

- **An export now guards your Mac.** Two crash reports from 1.0.4 showed the app holding about 25 GB of memory partway through an export, which starved macOS's window system and restarted the Mac. 1.0.5 removed the cause (frames were being pushed out faster than the screen could keep up). 1.0.6 also watches memory while exporting: if the app's use grows past a safe size, or the Mac itself is nearly out of memory, the export waits for it, and if it doesn't recover it stops with a clear message instead of risking the machine.

## 1.0.5

- **Fixed: exporting could restart the Mac.** 1.0.4 drove the graphics chip flat out during an export (the screen's frame-rate cap was switched off and extra frames were forced), which could hang the graphics driver partway through and make macOS restart. Exports now keep the normal frame-rate cap and draw each frame once, as part of the app's own frames. They only force a frame when the window is minimized. Every frame is still checked to be drawn for its own moment, so the export stays smooth.
- The video encoder now uses half of the processor's cores, so the Mac stays responsive during an export. WebM (VP9) exports use a faster encoder setting.

## 1.0.4

- **Smooth export to the end.** Exports could still stutter partway through (from about 30 seconds into a test song), because macOS slowed the app's frames when its window was in the background, and the export then reused old pictures. Each frame is now checked to be drawn for its own moment before it's saved, and the app is kept from napping during an export.

## 1.0.3

- **Smooth video export.** The export could repeat frames while notes were moving (about 3% of frames in a test song, in runs of up to 8), which looked like stutter. Each frame now waits for a real draw, and a frame that comes out identical to the one before while notes are moving is drawn again. `tools/check_video.py` counts repeated frames in any export.

## 1.0.2

- **Fixed a crash on start.** When macOS refused to let the app read the last song (it asks before apps read the Music folder), the app crashed, and again on every start. Files are now checked before they're opened, the last song is restored after the window is up, and one that can't be read is forgotten, with a message that says what to try.
- **Window:** the right-hand panel no longer runs off the edge at the default size, there's more room around the scroll bars, the full-screen button sits on the corner of the video, a track's full name shows when you hover it, and the depth box shows its number.
- **Export format menu:** MP4 first, then transparent MOV (ProRes 4444 or HEVC) and WebM. The save dialog follows it.
- **Icons on note hits:** an **Icon size** slider (bigger by default); a new icon shows at once; the glow behind them is smooth (no rings) and weaker.
- **Glow follows note thickness**, so thin notes get a thin glow. The slider means more or less than the usual amount.
- **Double-click any scene slider to put it back to its usual setting.**
- **Note editor:** drop a MIDI (or project) on it to replace the track being edited, choosing its track and whether to keep the file's timing or start in the bar the old notes began in; **Send to** moves selected notes to a new or existing track (pull hi-hats out of a drum track); notes in a part of a drum kit move up and down and join the part for their new pitch; other tracks show as faint outlines, so stacked copies can't look like one solid note.
- **Android:** video export, with ffmpeg carried inside the APK as a native library (experimental: not yet tried on a device). Exports go to Movies/Better ALMAMPlayer.

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
