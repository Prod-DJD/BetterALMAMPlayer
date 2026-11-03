# Changelog

## 1.0.11

- **Per-track settings.** Selecting tracks gives the right-hand panel sliders for those tracks alone: where their notes sit (notes reach up to, lowest note sits at), thickness, glow, icon size, velocity effect and pitch bend, plus depth and the lowest and highest note shown. A setting a track hasn't changed follows the scene (its label turns gold once it's the track's own); double-click a slider to follow the scene again. They are saved with the song's look.
- A ProRes export carries its sound as uncompressed 24-bit PCM (editors read it at once, without AAC's start-up delay); the other formats keep AAC or Opus.
- **Audio in exports lines up in Premiere Pro.** The sound's delay was stored as a timestamp offset, which Premiere Pro ignores: it played the sound from the start while the notes waited. The delay is now written into the sound as silence, which every program reads the same way.
- **The export panel now says which programs read each format.** A "transparent" video that looked solid in Premiere Pro was an HEVC export: its transparency is Apple's own, so Finder and QuickTime show it clear while Premiere Pro and DaVinci Resolve show a solid background. ProRes 4444 is the one for editors (tested in Premiere Pro). The menu names are shorter, a line under it says who can read the chosen format, and the "Saved" message names the format written.
- The empty preview's text wraps to the room it has, and its size follows the preview's width, instead of one long cut-off line.
- Checked the whole window for anything cut off, at the minimum size and in every state (empty, song loaded, tracks selected, the note editor): nothing runs past its container now. The one thing found, the "1 track selected" text, got more room.

## 1.0.10

- Selecting a track in the list shows that track's own settings on the right (colour, depth, shape, dots, show in preview, and its note range), in place of the scene's sliders. With several tracks selected, a change applies to all of them. Deselecting brings the scene back.
- Colour changes show at once in the note editor and in the track list, not only after the next redraw.
- The colour popup closes when you copy its hex code (Ctrl/Cmd+C in the hex box).
- Fixed content being cut off: the window can't be made smaller than the three panels need (1200 × 680), the top bar wraps to a second line when the preview column is narrow, and the track panel's settings stack a label above each control so none run off the edge. The note-range boxes moved out of the track rows (they made every row too wide) into the track panel.
- The three panels (tracks, preview, scene) can be resized by dragging the dividers between them. Their widths are remembered between starts.

- Fixed selecting tracks in the list. A click on a track's row now selects just that track (Ctrl/Cmd-click adds or removes one, a click on the only selected track deselects it, Ctrl/Cmd+A selects all, Esc clears). In 1.0.9 only Ctrl+A worked: a plain click was ignored, and would have failed even if it had registered. A hint under the track buttons lists the keys.

## 1.0.9

- Track colours are spread evenly around the colour wheel, with neighbours in the list far apart, instead of a gradient. Tracks already coloured keep their colours.
- Each track has a **low** and **high** note setting in the track list: notes outside the range are hidden, not deleted.
- Click a track's row to select it; Ctrl/Cmd or Shift adds more, and Ctrl+A selects all. Selected rows are outlined.
- The note editor has an **All tracks** switch: pick, select (Ctrl+A), shift, transpose, delete and undo notes of every track together, or only the tracks selected in the list. Notes can be moved up to a second before the start (the upbeat).

- **Logic projects now import in time.** The reader placed regions with a fixed starting point and ignored how each region is cut, so notes drifted and bled past where a region ends. It now follows what Logic itself plays: each region's length and start offset, muted notes (Logic doesn't play them), notes on every MIDI channel (it skipped all but the first, losing chords' middle voices), and the real note data when a record is stored twice (a copied region came out empty). Time zero is bar 1, and a project's upbeat (a start before bar 1) is kept as negative time, so notes line up with a sound bounced from bar 1. Checked note for note against Logic's own MIDI export of a 37-region 3/4 project: all 2,387 notes match, apart from the upbeat that export counts from.
- Tempo changes are still not followed in Logic, FL Studio or Ableton projects (the first tempo is used throughout). The FL Studio and Ableton readers are unchanged and were not checked against their own exports.

## 1.0.8

- Exports run in the app again, as the original did: no second window or process. Each frame is drawn once, and the export stops if the app's own memory goes past 3 GB or the video's graphics memory past 5 GB.
- New export choices: **Fast render** or **Best quality** for each format, and a **Reduce file size** checkbox that compresses harder at the same picture quality (slower to render). It is off for ProRes and HEVC, which have no such setting.

- On a Mac the export draws with Metal instead of Apple's old OpenGL layer, which kept the graphics memory of every frame read back until the whole Mac locked up.
- The whole app now draws with Metal on a Mac (Vulkan or DirectX on Windows and Linux) instead of Apple's old OpenGL layer; phones are unchanged. The Mac froze even during plain playback under OpenGL.
- Icons draw from shapes worked out once, instead of being re-split at every size (which failed on some and logged errors while playing).
- Opening a song with a 24-bit WAV (what Logic bounces) is near instant: Godot took minutes to read those, so a 16-bit copy is made once by ffmpeg and kept.
- Any WAV that isn't plain 16-bit (24-bit, float, or Logic's "extensible" header) is converted once to a 16-bit copy before loading; Godot's own loader used gigabytes and froze the app on those.
- Opening a song writes a step-by-step trace (time and memory at each step) to load_trace.log in the app's data folder, to find what makes a start slow.
- A heartbeat log (heartbeat.log in the app's data folder) records once a second whether the window is answering, so a freeze shows when and where in the song it began.
- **Fixed the cause of the freezes and crashes:** a song with two tracks of the same name (two "Guitar" tracks, say) had them treated as one, so every save and load added the notes again to both, doubling until a saved project was a gigabyte (millions of copies of a note) and the app froze or ran out of memory just drawing them. Each track now has its own identity, and a test saves and reloads such a song eight times to prove it stays put.
- A saved project over 4 MB (a normal one is a few KB) is set aside as .too_big.json, its edits are dropped and its looks, names and order are kept, instead of freezing the app at start. One that big is no longer written either.
- Rename boxes put the cursor at the end of the name instead of selecting all of it, so a click places the cursor where you point.
- Exports run at normal priority (no longer lowered with renice), so they finish sooner. The memory safety stops are unchanged.
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
