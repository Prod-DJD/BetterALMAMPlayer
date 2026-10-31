"""Draws docs/banner.png for the README (run: python3 docs/make_banner.py)."""
import importlib.util, os
from PIL import Image, ImageDraw, ImageFont
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
spec = importlib.util.spec_from_file_location("mi", os.path.join(ROOT, "assets", "branding", "make_icons.py"))
mi = importlib.util.module_from_spec(spec); spec.loader.exec_module(mi)

W, H = 1600, 560
bg = Image.new("RGB", (W, H))
d = ImageDraw.Draw(bg)
for y in range(H):
    t = y / H
    d.line([(0, y), (W, y)], fill=(int(46 - 28 * t), int(40 - 24 * t), int(34 - 20 * t)))
icon = Image.open(os.path.join(ROOT, "icon.png")).convert("RGBA").resize((300, 300), Image.LANCZOS)
bg.paste(icon, (90, 70), icon)
def font(size):
    for p in ("/System/Library/Fonts/Helvetica.ttc", "/Library/Fonts/Arial.ttf"):
        if os.path.exists(p):
            return ImageFont.truetype(p, size)
    return ImageFont.load_default()
d.text((440, 96), "Better ALMAMPlayer", font=font(92), fill=(255, 255, 255))
d.text((444, 214), "A MIDI visualizer that is easy to use every week.", font=font(34), fill=(247, 185, 85))
for i, line in enumerate(("Notes drawn by math, not pictures  ·  a built-in note editor",
                          "FL Studio and Ableton projects  ·  drum kits split into parts",
                          "Up to 4K at 120 fps  ·  transparent video, no keying")):
    d.text((444, 276 + i * 40), line, font=font(26), fill=(255, 255, 255, 190))
names = ["kick", "snare", "hihat", "crash", "piano", "epiano", "organ", "guitar", "bass", "violin", "trumpet", "sax",
         "flute", "vocal", "choir", "synth", "pad", "pluck", "bell", "marimba"]
cols = [(247, 185, 85), (255, 122, 89), (242, 99, 154), (143, 123, 255), (91, 155, 255), (52, 211, 196)]
step = (W - 180) / len(names)
for i, n in enumerate(names):
    ic = mi.render(mi.ICONS[n], 64, cols[i % len(cols)])
    bg.paste(ic, (int(90 + i * step), 450), ic)
bg.save(os.path.join(ROOT, "docs", "banner.png"))
print("docs/banner.png")
