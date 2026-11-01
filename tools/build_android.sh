#!/bin/sh
# Builds build/android/ALMAMPlayer.apk with ffmpeg inside, signed with your key.
#
# Android only lets an app run programs from its native library folder, so
# ffmpeg is added to the APK as lib/arm64-v8a/libffmpeg.so (as YTDLnis does);
# the app finds it there. Needs:
#   GODOT=/path/to/godot       Godot 4.7 with the Android export template
#   FFMPEG_ANDROID=/path       a static arm64 Linux ffmpeg (GPL builds are fine: this project is GPLv3)
#   JAVA_HOME, ANDROID_SDK_ROOT  a JDK 17 and the Android SDK (build-tools 35.0.1)
#   KEYSTORE, KEYSTORE_PASS    your release key (the alias is "release"); an APK signed
#                              with a different key can't update an installed one
set -e
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
BT="$ANDROID_SDK_ROOT/build-tools/35.0.1"
mkdir -p build/android
rm -f build/android/ALMAMPlayer.apk build/android/ALMAMPlayer.apk.idsig
GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$KEYSTORE" GODOT_ANDROID_KEYSTORE_RELEASE_USER=release \
  GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="$KEYSTORE_PASS" \
  "$GODOT" --headless --path . --export-release "Android" build/android/ALMAMPlayer.apk 2>&1 | grep -E "ERROR" | grep -v "noErr\|tmpproject" || true
[ -s build/android/ALMAMPlayer.apk ] || { echo "export failed"; exit 1; }
if [ -n "$FFMPEG_ANDROID" ]; then
  work="$(mktemp -d)"
  mkdir -p "$work/lib/arm64-v8a"
  cp "$FFMPEG_ANDROID" "$work/lib/arm64-v8a/libffmpeg.so"
  chmod 755 "$work/lib/arm64-v8a/libffmpeg.so"
  # adding a file breaks the signature: add it, align to 16 KB pages, sign again
  cp build/android/ALMAMPlayer.apk build/android/with-ffmpeg.apk
  (cd "$work" && zip -q "$OLDPWD/build/android/with-ffmpeg.apk" lib/arm64-v8a/libffmpeg.so)
  "$BT/zipalign" -f -P 16 4 build/android/with-ffmpeg.apk build/android/ALMAMPlayer.apk
  rm -f build/android/with-ffmpeg.apk
  "$BT/apksigner" sign --ks "$KEYSTORE" --ks-key-alias release --ks-pass "pass:$KEYSTORE_PASS" build/android/ALMAMPlayer.apk
  rm -rf "$work" build/android/ALMAMPlayer.apk.idsig
fi
"$BT/apksigner" verify build/android/ALMAMPlayer.apk && echo "built build/android/ALMAMPlayer.apk"
