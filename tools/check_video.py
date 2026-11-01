"""Checks an exported video for stutter: counts frames that repeat the one
before while notes are on screen (a smooth export has none).

  python3 tools/check_video.py video.webm [path/to/ffmpeg]

Needs numpy. A transparent video (.webm, .mov) is read with its alpha; for
an .mp4 the notes are found by their difference from the background color.
"""
import subprocess, sys
import numpy as np

video = sys.argv[1]
ff = sys.argv[2] if len(sys.argv) > 2 else "ffmpeg"
W, H = 960, 540
decoder = ["-c:v", "libvpx-vp9"] if video.lower().endswith(".webm") else []
raw = subprocess.run([ff, "-hide_banner", "-loglevel", "error", *decoder, "-i", video,
                      "-vf", f"scale={W}:{H}", "-pix_fmt", "rgba", "-f", "rawvideo", "-"],
                     capture_output=True).stdout
n = len(raw) // (W * H * 4)
frames = np.frombuffer(raw[: n * W * H * 4], dtype=np.uint8).reshape(n, H, W, 4)
alpha = frames[..., 3]
if alpha.min() == 255:  # not transparent: use brightness above the background
    bg = frames[:, :4, :4, :3].reshape(n, -1).mean(axis=1)
    alpha = (np.abs(frames[..., :3].astype(np.int16).mean(axis=3) - bg[:, None, None]) > 12).astype(np.uint8) * 255
busy = (alpha > 16).reshape(n, -1).mean(axis=1) > 0.005
diff = np.abs(np.diff(frames.astype(np.int16), axis=0)).reshape(n - 1, -1).sum(axis=1)
repeats = [i + 1 for i in np.where(diff == 0)[0] if busy[i] and busy[i + 1]]
runs, run = [], 0
for i in range(1, n):
    if diff[i - 1] == 0 and busy[i]:
        run += 1
    elif run:
        runs.append(run)
        run = 0
print(f"{n} frames; {len(repeats)} repeat the previous frame while notes are on screen"
      f" ({100 * len(repeats) / max(n, 1):.1f}%); longest run {max(runs) if runs else 0}")
print("smooth" if len(repeats) <= n * 0.002 else "stutters: frames are being repeated")
