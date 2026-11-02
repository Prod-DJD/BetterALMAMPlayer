#!/usr/bin/env python3
"""Makes a few one-second transparent test clips, each encoded differently, to
find out which one Premiere Pro reads the alpha channel of.

  python3 tools/alpha_variants.py [folder] [path/to/ffmpeg]

Import every clip into Premiere, put a picture on V1 and one clip at a time on V2:
the picture shows through the clip wherever the clip is transparent. The clip's
name says how it was made; tell me which show the picture.
"""
import os, subprocess, sys

out = sys.argv[1] if len(sys.argv) > 1 else "alpha_tests"
ff = sys.argv[2] if len(sys.argv) > 2 else "ffmpeg"
os.makedirs(out, exist_ok=True)
W, H, FPS, N = 1280, 720, 30, 30

# transparent everywhere, except a solid red bar that moves across, a soft
# half-transparent glow around it and a faint blue square: if alpha is read
# the picture below shows through; if it is ignored the clip is solid.
clear = bytes((0, 0, 0, 0)) * W
raw = os.path.join(out, "frames.rgba")
with open(raw, "wb") as f:
    for n in range(N):
        x0 = 100 + n * 30
        rows = []
        for y in range(H):
            row = bytearray(clear)
            if 300 <= y < 420:                      # glow band
                for x in range(max(0, x0 - 40), min(W, x0 + 240)):
                    row[x * 4:x * 4 + 4] = bytes((255, 40, 40, 110))
            if 330 <= y < 390:                      # the solid bar
                for x in range(x0, min(W, x0 + 200)):
                    row[x * 4:x * 4 + 4] = bytes((255, 40, 40, 255))
            if 60 <= y < 160:                       # faint blue square
                for x in range(1000, 1200):
                    row[x * 4:x * 4 + 4] = bytes((0, 100, 255, 70))
            rows.append(bytes(row))
        f.write(b"".join(rows))

base = [ff, "-hide_banner", "-loglevel", "error", "-y", "-f", "rawvideo", "-pix_fmt", "rgba",
        "-s", "%dx%d" % (W, H), "-r", str(FPS), "-i", raw]

variants = {
    # what the app made up to 1.0.10: ProRes 4444, no colour tags
    "A_prores4444_untagged.mov": ["-c:v", "prores_ks", "-profile:v", "4444", "-pix_fmt", "yuva444p10le",
                                   "-alpha_bits", "16", "-vendor", "apl0"],
    # what 1.0.11 makes: the same, tagged Rec. 709
    "B_prores4444_rec709.mov": ["-c:v", "prores_ks", "-profile:v", "4444", "-pix_fmt", "yuva444p10le",
                                 "-alpha_bits", "16", "-vendor", "apl0",
                                 "-colorspace", "bt709", "-color_primaries", "bt709", "-color_trc", "bt709"],
    # ProRes 4444 XQ
    "C_prores4444XQ.mov": ["-c:v", "prores_ks", "-profile:v", "5", "-pix_fmt", "yuva444p10le",
                            "-alpha_bits", "16", "-vendor", "apl0"],
    # 8-bit alpha inside ProRes 4444
    "D_prores4444_alpha8.mov": ["-c:v", "prores_ks", "-profile:v", "4444", "-pix_fmt", "yuva444p10le",
                                 "-alpha_bits", "8", "-vendor", "apl0"],
    # QuickTime Animation: lossless, big, and the codec every editor reads alpha from
    "E_animation_qtrle.mov": ["-c:v", "qtrle", "-pix_fmt", "argb"],
    # ProRes from Apple's own encoder (Apple silicon): the bytes Premiere is made for
    "F_prores4444_apple_encoder.mov": ["-c:v", "prores_videotoolbox", "-profile:v", "4444", "-pix_fmt", "bgra"],
}
for name, opts in variants.items():
    cmd = base + opts + [os.path.join(out, name)]
    r = subprocess.run(cmd, capture_output=True, text=True)
    size = os.path.getsize(os.path.join(out, name)) if os.path.exists(os.path.join(out, name)) else 0
    print("%-34s %s  %s" % (name, "ok" if r.returncode == 0 and size > 0 else "FAILED (this Mac's ffmpeg can't make it)", "%.1f MB" % (size / 1e6) if size else ""))
    if r.returncode != 0 or size == 0:
        try:
            os.remove(os.path.join(out, name))
        except OSError:
            pass
os.remove(raw)
print("\nDone: import the clips in %s into Premiere (see the top of this script)." % out)
