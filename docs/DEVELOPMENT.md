# Development

## How it's laid out

- `scripts/core/`: no UI. `song.gd` (notes in seconds, edits, splits, MIDI writer), `look.gd` (everything about how it looks), `project.gd` (what is saved per song), `visualizer.gd` (draws a frame from a time), `exporter.gd` (frames to ffmpeg), `icons.gd` + generated `icon_data.gd` (the icons), `importer.gd`, `flp_reader.gd`, `ableton_reader.gd`.
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
