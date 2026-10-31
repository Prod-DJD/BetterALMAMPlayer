#!/bin/sh
# Builds build/ALMAMPlayer.app (universal, ad-hoc signed) with ffmpeg inside,
# so video export works on a Mac that doesn't have ffmpeg.
#
#   GODOT=/path/to/Godot   Godot 4.7 with the macOS export templates installed
#   FFMPEG_ARM64=/path     a static ffmpeg for Apple silicon   (optional)
#   FFMPEG_X86_64=/path    a static ffmpeg for Intel           (optional)
#
# ffmpeg builds with x264/x265 are GPL: this project is GPLv3, and the app's
# licenses/ folder says where its source is. Without the ffmpeg variables the
# app is built without ffmpeg and finds one on the Mac (Homebrew etc.) instead.
set -e
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
mkdir -p build
"$GODOT" --headless --path . --import > /dev/null 2>&1   # registers script classes
"$GODOT" --headless --path . --import > build/import.log 2>&1
if grep -E "SCRIPT ERROR|Parse Error" build/import.log; then echo "script errors: not building"; exit 1; fi
rm -f build/ALMAMPlayer.zip # never package an old export if this one fails
"$GODOT" --headless --path . --export-release "macOS" build/ALMAMPlayer.zip 2>&1 | grep -E "ERROR" || true
if [ ! -s build/ALMAMPlayer.zip ]; then echo "export failed: not building"; exit 1; fi
cd build
rm -rf ALMAMPlayer.app
unzip -q ALMAMPlayer.zip
rm -f ALMAMPlayer.zip
if [ -n "$FFMPEG_ARM64" ] && [ -n "$FFMPEG_X86_64" ]; then
  lipo -create "$FFMPEG_ARM64" "$FFMPEG_X86_64" -output ALMAMPlayer.app/Contents/MacOS/ffmpeg
elif [ -n "$FFMPEG_ARM64$FFMPEG_X86_64" ]; then
  cp "$FFMPEG_ARM64$FFMPEG_X86_64" ALMAMPlayer.app/Contents/MacOS/ffmpeg
fi
codesign --force --deep -s - ALMAMPlayer.app 2>&1 | grep -v "replacing existing" || true
echo "built build/ALMAMPlayer.app"
