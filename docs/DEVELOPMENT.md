# Development

## How it's laid out

- `scripts/core/`: no UI. `song.gd` (notes in seconds, edits, splits, MIDI writer), `look.gd` (everything about how it looks), `project.gd` (what is saved per song), `visualizer.gd` (draws a frame from a time), `exporter.gd` (frames to ffmpeg), `icons.gd` + generated `icon_data.gd` (the icons), `importer.gd`, `flp_reader.gd`, `ableton_reader.gd`, `logic_reader.gd` (ported from the MIT LogicBridge: see licenses/).
- `scripts/app/`: the window. `app.gd`, `track_row.gd`, the note editor (`note_editor.gd`, `note_canvas.gd`), small widgets.
- `addons/midi/`: the MIDI file parser (godot-midi-player by arlez80).
- `assets/branding/`: scripts that draw the app icon, launch screen and icon library.

The picture is a pure function of the song time: no node moves on its own, so the preview, seeking and the exported video always agree.

## Saved data

One JSON per song in the app's user folder. Notes are edited as a difference from the file (`Song.edits`), saved against each track's *origin* (its name in the file), so edits survive splitting a track into parts, renaming and reordering. Looks are keyed by track name.

## Tests

Headless Godot, from the project folder:

```
godot --headless --path . -s tests/test_core.gd           # importers, edits, MIDI round trip, release velocity
godot --headless --path . -s tests/test_app.gd            # the whole app: editing, splits, rename, toggles, drag and drop
godot --headless --path . -s tests/test_icon_polygons.gd  # every icon fill can be triangulated
LOGIC_SAMPLE=/path/to/Project.logicx godot --headless --path . -s tests/test_logic.gd  # Logic reader vs the converter's counts
```

The headless renderer draws nothing, so these cover logic and make sure drawing code runs; look at the app itself for how it looks.

## Icons and branding

```
python3 assets/branding/make_icons.py   # icon_data.gd + preview sheets (assets/branding/preview/)
python3 assets/branding/make_brand.py   # icon.png, launch screen, .ico
python3 docs/make_banner.py             # the README banner
```
These need Pillow (and numpy for the brand script).

## Building

`tools/build_macos.sh` (needs Godot 4.7 with export templates). Video export needs ffmpeg at runtime.

Other platforms are export presets in `export_presets.cfg`: **Windows Desktop**, **Linux** and **iOS**. Export them with Godot's `--export-release "<name>" <path>` (see the platform's folder under `build/`). Notes:

- Godot 4.7 export templates (`export_templates/4.7.2.stable/`) are needed for each platform.
- The iOS preset writes an Xcode project. Build it without signing using `xcodebuild -project … -scheme ALMAMPlayer -sdk iphoneos -configuration Release CODE_SIGNING_ALLOWED=NO build`, then put the `.app` in a `Payload/` folder and zip it as an `.ipa`. The Team ID in the preset is a placeholder that unsigned builds ignore.
- Windows and Linux don't bundle ffmpeg (the macOS build does), so video export there uses the system's.
- Android: `tools/build_android.sh` exports the APK and adds a static arm64 ffmpeg to it as `lib/arm64-v8a/libffmpeg.so` (Android only lets an app run programs from its native library folder, and the app finds it there). To do it by hand: install a JDK 17 and the Android SDK (platform-tools, build-tools 35.0.1, platforms/android-35), point Godot at them (Editor Settings: `export/android/java_sdk_path` and `android_sdk_path`), and export the **Android** preset (no Gradle needed). Sign the release APK with a key given through `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`, `_USER` and `_PASSWORD`, never saved in the preset. Keep that keystore safe: an APK signed with a different key can't update an installed one.
- The iOS build is signed ad hoc (`codesign --force --sign - --deep Payload/ALMAMPlayer.app`) so a jailbroken device will run it.
