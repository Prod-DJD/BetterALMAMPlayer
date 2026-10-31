"""Draws ALMAMPlayer's app icon and launch screen from shapes (no pictures):
notes scrolling past a center playhead, one lit with the app's own pulse.
Run:  python3 assets/branding/make_brand.py   (needs numpy and Pillow)
Writes icon.png (1024), assets/branding/icon.ico and assets/branding/splash.png."""
import numpy as np
from PIL import Image, ImageDraw, ImageFont
import os

S = 2048  # drawn at 2x, then reduced for smooth edges
K = S / 1024.0
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))

def hexc(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)])

yy, xx = np.mgrid[0:S, 0:S].astype(np.float64)
xx = xx / K
yy = yy / K

def rrect_sdf(x0, y0, x1, y1, r):
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    hx, hy = (x1 - x0) / 2 - r, (y1 - y0) / 2 - r
    qx = np.abs(xx - cx) - hx
    qy = np.abs(yy - cy) - hy
    return np.hypot(np.maximum(qx, 0), np.maximum(qy, 0)) + np.minimum(np.maximum(qx, qy), 0) - r

def cover(sdf):  # 1 inside, 0 outside, ~1px soft edge
    return np.clip(0.5 - sdf, 0.0, 1.0)

def over(img, color, a):
    a = a[..., None]
    img[..., :3] = img[..., :3] * (1 - a) + np.asarray(color)[None, None, :] * a

def draw_scene(size_scale=1.0):
    """The tile with notes and the pulse, in 1024-space, on transparent."""
    img = np.zeros((S, S, 4))
    # the tile: a deep warm-dark gradient with a soft glow behind the playhead
    tile = cover(rrect_sdf(100, 100, 924, 924, 190))
    top, bot = hexc("#2e2822"), hexc("#12100e")
    t = np.clip((yy - 100) / 824, 0, 1)[..., None]
    img[..., :3] = top * (1 - t) + bot * t
    glow = np.exp(-(((xx - 512) / 330) ** 2 + ((yy - 470) / 300) ** 2))
    over(img, hexc("#f7b955"), glow * 0.16)
    # faint pitch rows, like the app's grid
    for y in (300, 392, 484, 576, 668):
        over(img, (1, 1, 1), cover(rrect_sdf(150, y - 1.2, 874, y + 1.2, 1.2)) * 0.045)
    # the playhead
    over(img, (1, 1, 1), cover(rrect_sdf(510, 190, 514, 834, 2)) * 0.10)

    amber, coral, rose = hexc("#f7b955"), hexc("#ff7a59"), hexc("#f2639a")
    violet, blue, teal = hexc("#8f7bff"), hexc("#5b9bff"), hexc("#34d3c4")
    H = 56
    notes = [  # x0, x1, row y, color
        (150, 300, 668, teal), (320, 410, 576, blue), (430, 495, 668, teal),
        (668, 790, 392, violet), (808, 900, 300, rose), (700, 830, 576, coral),
        (528, 640, 668, teal), (808, 904, 484, blue), (170, 330, 392, violet),
        (352, 456, 300, coral),
    ]
    lit = (376, 650, 484, amber)  # the note under the playhead
    for x0, x1, y, c in notes + [lit]:
        is_lit = (x0, x1, y) == lit[:3]
        if is_lit:  # its glow while it plays
            d = rrect_sdf(x0, y - H / 2, x1, y + H / 2, H / 2)
            over(img, c, np.exp(-np.maximum(d, 0) / 26.0) * 0.55 * (d > -2) + 0)
        body = cover(rrect_sdf(x0, y - H / 2, x1, y + H / 2, H / 2))
        col = c * 1.0 if not is_lit else np.minimum(c + 0.12, 1.0)
        over(img, col, body)
        # a soft highlight along the top edge
        sheen = cover(rrect_sdf(x0 + 14, y - H / 2 + 7, x1 - 14, y - H / 2 + 22, 7)) * body
        over(img, (1, 1, 1), sheen * 0.22)
    # the pulse at the playhead: halo, ring, bright core
    cx, cy = 512, 484
    r = np.hypot(xx - cx, yy - cy)
    over(img, amber, np.exp(-(r / 105.0) ** 2) * 0.30)  # a soft halo, no hard edge
    ring = np.clip(6.5 - np.abs(r - 66) + 0.5, 0, 1)
    over(img, hexc("#ffe3a8"), ring * 0.95)
    over(img, hexc("#fff4d6"), np.clip(26 - r + 0.5, 0, 1) * 0.97)
    img[..., 3] = tile
    return img

def to_pil(img, px):
    a = (np.clip(img, 0, 1) * 255).astype(np.uint8)
    # premultiply-safe downsample: weight color by alpha
    im = Image.fromarray(a)
    return im.resize((px, px), Image.LANCZOS)

scene = draw_scene()
icon = to_pil(scene, 1024)
icon.save(os.path.join(ROOT, "icon.png"))
icon.save(os.path.join(ROOT, "assets", "branding", "icon.ico"),
          sizes=[(16, 16), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])

# launch screen: the tile, centered on the app's dark background, with the name
W, Ht = 1280, 720
bg = Image.new("RGBA", (W, Ht), (0x1d, 0x1a, 0x17, 255))
tile = icon.resize((360, 360), Image.LANCZOS)
bg.alpha_composite(tile, ((W - 360) // 2, 120))
d = ImageDraw.Draw(bg)
font = None
for path, idx in (("/System/Library/Fonts/Helvetica.ttc", 0), ("/System/Library/Fonts/SFNS.ttf", 0),
                  ("/Library/Fonts/Arial.ttf", 0)):
    if os.path.exists(path):
        try:
            font = ImageFont.truetype(path, 54, index=idx)
            small = ImageFont.truetype(path, 22, index=idx)
            break
        except Exception:
            pass
def spaced(draw, y, text, f, fill, gap):
    widths = [draw.textlength(ch, font=f) for ch in text]
    total = sum(widths) + gap * (len(text) - 1)
    x = (W - total) / 2
    for ch, w in zip(text, widths):
        draw.text((x, y), ch, font=f, fill=fill)
        x += w + gap
if font:
    spaced(d, 514, "ALMAMPlayer", font, (255, 255, 255, 235), 3)
    spaced(d, 586, "MIDI  VISUALIZER", small, (247, 185, 85, 215), 7)
bg.convert("RGB").save(os.path.join(ROOT, "assets", "branding", "splash.png"))
print("icon.png, assets/branding/icon.ico, assets/branding/splash.png")
