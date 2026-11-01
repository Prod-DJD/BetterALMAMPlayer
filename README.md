<p align="center"><img src="docs/banner.png" alt="Better ALMAMPlayer" width="100%"></p>

<p align="center">
  <a href="https://github.com/Prod-DJD/BetterALMAMPlayer/releases/download/v1.0.2/Better-ALMAMPlayer-1.0.2-macOS.zip"><img alt="Download for macOS" src="https://img.shields.io/badge/macOS-download-f7b955?style=for-the-badge&logo=apple&logoColor=black"></a>
  <a href="https://github.com/Prod-DJD/BetterALMAMPlayer/releases/download/v1.0.2/Better-ALMAMPlayer-1.0.2-Windows.zip"><img alt="Download for Windows" src="https://img.shields.io/badge/Windows-download-f7b955?style=for-the-badge&logo=windows&logoColor=black"></a>
  <a href="https://github.com/Prod-DJD/BetterALMAMPlayer/releases/download/v1.0.2/Better-ALMAMPlayer-1.0.2-Linux.tar.gz"><img alt="Download for Linux" src="https://img.shields.io/badge/Linux-download-f7b955?style=for-the-badge&logo=linux&logoColor=black"></a>
  <a href="https://github.com/Prod-DJD/BetterALMAMPlayer/releases/download/v1.0.2/Better-ALMAMPlayer-1.0.2-Android.apk"><img alt="Download for Android" src="https://img.shields.io/badge/Android-download-f7b955?style=for-the-badge&logo=android&logoColor=black"></a>
  <a href="https://github.com/Prod-DJD/BetterALMAMPlayer/releases/download/v1.0.2/Better-ALMAMPlayer-1.0.2-iOS-jailbreak.ipa"><img alt="Download for iOS jailbreak" src="https://img.shields.io/badge/iOS-jailbreak-download-8a8a8a?style=for-the-badge&logo=apple&logoColor=black"></a>
  <a href="https://github.com/Prod-DJD/BetterALMAMPlayer/releases"><img alt="All releases" src="https://img.shields.io/badge/all%20releases-GitHub-8a8a8a?style=for-the-badge&logo=github"></a>
  <img alt="License" src="https://img.shields.io/badge/license-GPLv3-f7b955?style=for-the-badge">
</p>

**Better ALMAMPlayer** turns MIDI into a scrolling note video, the kind you see under music on YouTube. It's a fork of [almam's ALMAMPlayer](https://github.com/almam72/ALMAMPlayer), rebuilt to be quick to use every week: open a song, adjust the look, fix any wrong notes, and export.

## Contents

- [Download](#download)
- [Quick start](#quick-start)
- [Opening songs](#opening-songs)
- [Playing and previewing](#playing-and-previewing)
- [Tracks](#tracks)
- [Drum kits](#drum-kits)
- [Icons](#icons)
- [The scene](#the-scene)
- [Note editor](#note-editor)
- [Exporting video](#exporting-video)
- [Keyboard shortcuts](#keyboard-shortcuts)
- [Where your work is saved](#where-your-work-is-saved)
- [Platforms and limits](#platforms-and-limits)
- [Build from source](#build-from-source)

## Download

Get the latest build from the [releases page](https://github.com/Prod-DJD/BetterALMAMPlayer/releases). Each platform's file is listed in the buttons above.

| Platform | File | Notes |
|---|---|---|
| macOS, Apple silicon and Intel | `…-macOS.zip` | Not notarized: right-click the app, choose **Open**, then **Open** again. Includes ffmpeg. |
| Windows, 64-bit | `…-Windows.zip` | Video export needs ffmpeg on your PATH (`winget install ffmpeg`). |
| Linux, 64-bit | `…-Linux.tar.gz` | Unzip, make the file executable, run it. Video export needs ffmpeg (`sudo apt install ffmpeg`). |
| Android 7.0 and up, arm64 | `…-Android.apk` | Allow installing from your browser or files app. Video export works, with ffmpeg built in (experimental). |
| iOS (jailbroken devices) | `…-iOS-jailbreak.ipa` | Signed ad hoc, not by Apple: install it with your jailbreak's installer. Video export isn't possible on iOS. |

## Quick start

1. Drop a MIDI file, an FL Studio or Ableton project, or a Logic project folder on the window (or use **Open…**).
2. Press **Space** to play. Adjust colors, shapes, speed and icons on the left and in the **Scene** panel on the right.
3. Fix any wrong notes with **Edit notes** (or **Tab**).
4. **Export video…** writes an MP4, or a transparent MOV or WebM.

Everything saves as you go. There is no save button.

## Opening songs

Drop files on the window, use **Open…** (⌘O / Ctrl+O), or pick one from **Recent ▾**. The last song you had open is reopened next time, unless the last start didn't finish.

| You open | What you get |
|---|---|
| **MIDI** (`.mid`, `.midi`) | Every track with notes. Multi-track (type 1) files keep their track names; the tempo changes in the file are followed. |
| **FL Studio** (`.flp`) | Every channel that has notes becomes a track with its name from the channel rack. Patterns are placed where the playlist puts them. The first tempo in the project is used throughout. Audio clips and plugin sounds are not read. |
| **Ableton Live** (`.als`) | Every MIDI track in the arrangement, with its clips placed and looped clips repeated. The set's tempo is used throughout. Session view clips and audio are not read. |
| **Logic Pro** (`.logicx`) | The project **folder** (drop it, or pick it in Open…). Every MIDI track in the arrange, in its order, with its notes. The first tempo is used throughout. Audio regions and plugin settings are not read. The reader is ported from the MIT-licensed LogicBridge in the FLP to Logic converter (see [Credits](#credits)). |

**Sound:** a sound file named like the song is picked up by itself: `song.mid` with `song.mp3`, `.wav` or `.ogg` beside it. Otherwise drop a sound file on the window, or use **Choose…** in the scene's **Sound** section. **Remove** takes it off.

**Pictures:** drop a `.png`, `.jpg`, `.jpeg` or `.webp` on the window to make it the background, or use **Background** in the scene panel. A background is not drawn in transparent exports.

**Looks:** **Save this look…** keeps the current scene and track settings for use on other songs, and **Use a look ▾** applies one. Old ALMAMPlayer config files (`.json`) load as a look.

## Playing and previewing

- **Click the preview** or press **Space** to play and pause. **←** and **→** jump 5 seconds, **Home** goes back to the start, and the seek bar moves anywhere in the song.
- **Preview** shows the video as it will export. **Edit notes** switches to the note editor, on the same view.
- The **⛶** button in the bottom-right corner of the video, **F11** or **⌘F** shows just the video full screen. **Esc** brings the panels back.
- The notes start a second before the song, so the tracks rise in before the first note.

The picture is drawn from the song's time alone, so the preview, seeking and the exported video always match the audio, frame for frame.

## Tracks

Each track in the **Tracks** list (left side) has:

- **Show/hide**: the pill switch on the left. Hidden tracks are left out of the picture and the video.
- **Icon**: click it to choose from the icon picker (see [Icons](#icons)).
- **Color**: click the swatch for a color picker.
- **Name**: hover it to see the full name. Double-click it, or use **⋯ ▸ Rename…**, to change it. Renames are kept per song and carry over the track's colors, icon, order and edits.
- **Edit**: opens the note editor on that track.
- **⋯** menu: split a drum track into parts, merge split parts back, rename, or remove the track (with a warning if it has notes).
- **× depth**: how fast the track moves. Faster tracks look nearer.
- **Shape**: **Pill**, **Soft** or **Sharp** note shapes.
- **Dots**: short dots instead of held notes (staccato).

**Reordering:** press and hold a track and drag it up or down. A line shows where it will land. The top track is drawn **in front** of the tracks below it, whatever their speed.

**Adding and removing:** **＋ Track** adds an empty track, which you fill in the note editor. Remove a track from its **⋯** menu.

**Shortcuts for many tracks**, in the toolbar above the list. Press one to apply it, and press it again to go back to your own settings:
- **Rainbow**: spreads the colors around the color wheel.
- **Gradient**: colors from the first track's color to the last's.
- **Depth**: the default speeds, with the top tracks fastest.
- **Icons**: picks every track's icon again from its name and instrument.

## Drum kits

A drum track on MIDI channel 10 (the General MIDI drum channel) is split into one track per drum sound **the first time you open the song**. Each part is named after its drum (Kick, Snare, Closed Hat, Open Hat, Low Floor Tom, Crash, Ride, and so on), gets its own icon, and starts as dots. The parts move together at the same speed.

- **Split by hand:** on any track with several notes, use **⋯ ▸ Split into drum parts** or **⋯ ▸ Split by note** (one track per pitch).
- **Merge:** **⋯ ▸ Merge the parts back into one track**. Your edits to the parts are kept.
- **Moving notes between parts:** in the note editor, notes in a drum part can be moved up and down. A note that moves onto another part's pitch joins that part.
- **Taking notes out:** select them and use **Send to** in the note editor to move them to a new or existing track (hi-hats out of a kit, say).

## Icons

There are 104 drawn instrument icons, grouped into categories: drums and percussion, keyboards, mallets and bells, guitars and plucked strings, orchestral strings, brass, woodwinds, voice, synths, FX and ambience, and other.

- **Automatic:** each track's icon is picked from its name (for example "808 Bass" gets the bass icon, "Kick" the kick) or from its General MIDI instrument number. A drum part is named by its drum sound.
- **Choose your own:** click a track's icon. The picker has a search box and the categories. **Automatic** brings back the picked one.
- **Circles:** when no icon matches a track, it gets a plain circle.
- **Size:** the **Icon size** slider in the scene panel. The default is bigger, and double-clicking the slider brings it back.
- **On note hits:** each note hit draws the track's icon at the playhead, with a soft glow behind it, in the track's color.

## The scene

The **Scene** panel on the right holds the settings for the whole picture. Double-click a slider's name or the slider to put it back to its usual setting.

| Setting | What it does |
|---|---|
| **Speed** | How fast the notes move, in pixels a second |
| **Notes reach up to** | How high the highest note goes on the screen |
| **Lowest note sits at** | How far up from the bottom the lowest note sits |
| **Velocity effect** | How much the note's velocity changes its look when it plays, and how fast a hard note-off lets go (note-off velocity, read from the file) |
| **Pitch bend** | How far pitch bends push the notes that are playing |
| **Glow** | How much light each note gives off (a "more or less than usual" setting: the glow follows the note's thickness) |
| **Note thickness** | How thick the notes are |
| **Icon size** | How big the icon is when a note hits |
| **Audio delay** | Moves the notes earlier or later against the sound, in milliseconds |
| **Square video (1:1)** | Crops the picture to the middle square. The preview crops too |
| **Export** | Size, frame rate and video format (see below) |

## Note editor

Open it with **Edit notes** or **Tab**, or with a track's **Edit** button. It shows the track's notes as a piano roll, with the other tracks behind as faint outlines (turn that off with **Other tracks**).

**Editing:**
- **Add:** double-click an empty spot.
- **Move:** drag a note. **Resize:** drag its right edge.
- **Delete:** select and press **Delete**, or right-click a note.
- **Select:** click a note, shift-click to add more, or drag a box around several.
- **Select a whole pitch:** click that key on the piano at the left. This is how you clear a keyswitch in one go.
- **Transpose:** **↑** and **↓** move the selection by a semitone, **⇧↑** and **⇧↓** by an octave.
- **Nudge:** **←** and **→** move the selection in time, by the snap size.
- **Velocity:** set it in the toolbar for the selected notes.
- **Snap:** Off, 1 beat, ½, ¼ (the default), ⅛ or 1/16.
- **Undo** and **Redo** (⌘Z, ⇧⌘Z / ⌘Y), as far back as the session goes.

**Toolbar:** pick the track, snap, undo, redo, delete, velocity, **Send to**, **Other tracks**, **Save MIDI…**, and **Revert all**.

- **Save MIDI…** writes the whole song, with your edits, as a new `.mid` file. Your original file is never changed.
- **Revert all** throws away every edit to the song (after asking) and goes back to the file.

**Edits are kept as differences from the file.** They're saved with the song, and they follow the track when you split it into drum parts, merge it back, rename it or reorder it.

**Drop a MIDI on the editor** to replace the track you're editing. You can pick a track from a MIDI or project, then choose whether:
- the notes keep the timing from the file, or
- they start in the bar where this track's notes started before (useful when the new export has no empty bars at the start).

You can also match the tempo of the file to the song. The whole change is one undo step.

## Exporting video

**Export video…** (in the middle column, under the preview) saves the video, with the song's sound. Progress shows in the bar, and **Stop exporting** cancels it.

Choose the settings in the scene panel's **Export** section:

- **Size:** 1080p, 1440p or 4K. 4K takes much longer and makes big files.
- **Frame rate:** 24, 30, 60 or 120 fps.
- **Format:**
  - **MP4 (plays anywhere):** the usual choice. The background is the picture you chose, or black.
  - **MOV, transparent: ProRes 4444:** the best for editing, and the biggest. Drop it onto other footage with no keying.
  - **MOV, transparent: HEVC:** much smaller. Made for Apple apps. Not yet tested on a Mac.
  - **WebM, transparent: VP9:** the smallest. Browsers and some editors read it.

The transparent formats drop the background, so the notes sit straight on your footage. The **Square** setting crops every format to 1:1.

ffmpeg does the encoding. The macOS build includes it. The Windows and Linux builds use the one on your system. Android includes it inside the app (experimental). iOS can't export video.

## Keyboard shortcuts

**In the main window:**

| Key | Action |
|---|---|
| **Space** | Play or pause (works even with a button focused) |
| **←** / **→** | Back or forward 5 seconds |
| **Home** | Back to the start |
| **Tab** | Switch between the preview and the note editor |
| **⌘O** / **Ctrl+O** | Open a song |
| **⌘Z** / **Ctrl+Z** | Undo (in the note editor) |
| **F11** or **⌘F** | Full-screen preview |
| **Esc** | Leave full-screen |

**In the note editor:**

| Key | Action |
|---|---|
| **Delete** / **Backspace** | Delete the selected notes |
| **⌘A** / **Ctrl+A** | Select every note of the track |
| **⌘Z** / **⇧⌘Z** (or **⌘Y**) | Undo and redo |
| **↑** / **↓** | Move the selection a semitone |
| **⇧↑** / **⇧↓** | Move it an octave |
| **←** / **→** | Move it in time, by the snap size |
| **Esc** | Clear the selection |

**Mouse:** the wheel scrolls up and down through the pitches. **⇧-wheel** or sideways scrolling moves through time. **⌘-wheel** (or a pinch on a trackpad) zooms. Click the ruler at the top to jump the playhead.

## Where your work is saved

- **Each song** has its own saved file in the app's data folder. It holds the sound file it uses, its look, its track names and order, and your note edits. Nothing is written back into your MIDI or project files.
- **Recent songs** and the last song are remembered too.
- **Looks** you save are kept for any song.

If macOS asks whether the app can read a folder, such as Music, allow it in **System Settings ▸ Privacy & Security ▸ Files and Folders** (or move the project out of that folder). A file that can't be read shows a message instead of stopping the app.

## Platforms and limits

| Platform | Opens and plays | Edits | Exports video |
|---|---|---|---|
| macOS (Apple silicon and Intel) | Yes | Yes | Yes, with ffmpeg built in |
| Windows, 64-bit | Yes | Yes | Yes, with ffmpeg on your PATH |
| Linux, 64-bit | Yes | Yes | Yes, with ffmpeg on your PATH |
| Android 7.0 and up | Yes | Yes | Yes, with ffmpeg built in (experimental) |
| iOS 15 and up (jailbroken devices) | Yes | Yes | No. Use screen recording |

**Limits:**
- The FL Studio, Ableton and Logic readers use the first tempo in the project. Tempo changes are not followed.
- Audio clips and plugin sounds in FL Studio, Ableton and Logic projects are not read. Use your own sound file for the sound.
- The window is laid out for a desktop. On phones and tablets it's scaled to fit a landscape screen.
- Not yet tested on: Windows, Linux, Android and iOS builds (they build cleanly, but haven't been run), and the HEVC transparent format on a Mac.

## Build from source

You need [Godot 4.7](https://godotengine.org). Open the project in Godot and run it, or on a Mac run `tools/build_macos.sh`. Other platforms are export presets in `export_presets.cfg`. See [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) for the layout of the code, the tests, the icon and banner scripts, and how each platform is built. Video export needs ffmpeg: the macOS build includes it, otherwise install it (for example `brew install ffmpeg`).

[CHANGELOG.md](CHANGELOG.md) lists what changed in each release. [CONTRIBUTING.md](CONTRIBUTING.md) explains how to help.

## Credits

- **ALMAMPlayer** by [almam](https://github.com/almam72), with contributions from speaksy and yohannd1: this project is built on their work.
- The MIDI parser is from [godot-midi-player](https://github.com/arlez80/godot-midi-player) by arlez80.
- The Logic Pro reader is ported from the MIT-licensed LogicBridge in the FLP to Logic converter (Jon Kubis), see [licenses/LogicBridge-MIT.txt](licenses/LogicBridge-MIT.txt).
- Video is written with [FFmpeg](https://ffmpeg.org); the engine is [Godot](https://godotengine.org).
- Better ALMAMPlayer by DJ D.

## License

GPLv3, like the original. See [LICENSE](LICENSE) and [licenses/](licenses/). Contributions are welcome: see [CONTRIBUTING.md](CONTRIBUTING.md).

## Support

If Better ALMAMPlayer is useful to you, you can send a donation. I accept any token on these chains, USDC preferred:

| Chain | Address |
|---|---|
| Solana | `ESpBQ2Tg9SyTRb2GQSz7LHJ5R2nKZLP17vhxf9ziFTh` |
| Polygon | `0xbD5C233Ff80CDe7811D2360cA14ffe0A1Ce8CB92` |
| Sui | `0x5299b8166d54ec9e46eaa54d9e7c3cd6c6b872e36e0664ef8fc769850a82863e` |

Always check the address you're sending to matches one above, and the chain you're sending on. Donations are optional; the app stays free and GPLv3 either way.

