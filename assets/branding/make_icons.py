"""The instrument icon library: every icon is a few lines, curves and fills
in a 0..1 square, authored here and written to scripts/core/icon_data.gd,
which the app draws from (see scripts/core/icons.gd). Also renders a
preview sheets (assets/branding/preview/, hidden from Godot) to look them over.

Run:  python3 assets/branding/make_icons.py   (needs Pillow)

Shapes: ["l", x0,y0,x1,y1, w]   a line            (w: × the base stroke)
        ["p", [x,y,x,y,…], w]   a polyline
        ["f", [x,y,x,y,…], a]   a filled polygon  (a: opacity)
        ["c", x,y,r, a]         a filled circle
        ["r", x,y,r, w]         a ring
"""
import math, os, random
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ICONS = {}
LABELS = {}
CATEGORIES = []
cur = None

def icon(name, label=None):
    global cur
    cur = []
    ICONS[name] = cur
    LABELS[name] = label or name.replace("_", " ").title()

def category(title, names):
    CATEGORIES.append((title, names))

def flat(pts):
    return [round(v, 4) for p in pts for v in p]

def line(x0, y0, x1, y1, w=1.0):
    cur.append(["l", x0, y0, x1, y1, w])

def poly(pts, w=1.0, closed=False):
    pts = list(pts)
    if closed:
        pts.append(pts[0])
    cur.append(["p", flat(pts), w])

def fill(pts, a=0.3):
    cur.append(["f", flat(pts), a])

def circle(x, y, r, a=1.0):
    cur.append(["c", x, y, r, a])

def ring(x, y, r, w=1.0, fa=None):
    if fa:
        circle(x, y, r, fa)
    cur.append(["r", x, y, r, w])

def arcpts(cx, cy, r, a0, a1, n=18, ry=None):
    ry = r if ry is None else ry
    return [(cx + r * math.cos(math.radians(a0 + (a1 - a0) * i / n)),
             cy + ry * math.sin(math.radians(a0 + (a1 - a0) * i / n))) for i in range(n + 1)]

def arc(cx, cy, r, a0, a1, w=1.0, n=18):
    poly(arcpts(cx, cy, r, a0, a1, n), w)

def ell(cx, cy, rx, ry, w=1.0, fa=None, a0=0, a1=360, rot=0):
    pts = arcpts(0, 0, rx, a0, a1, 28, ry)
    c, s = math.cos(math.radians(rot)), math.sin(math.radians(rot))
    pts = [(cx + x * c - y * s, cy + x * s + y * c) for x, y in pts]
    if fa and a1 - a0 >= 360:
        fill(pts, fa)
    poly(pts, w)

def rr_pts(x0, y0, x1, y1, r):
    r = min(r, (x1 - x0) / 2, (y1 - y0) / 2)
    pts = []
    for cx, cy, a in ((x1 - r, y0 + r, -90), (x1 - r, y1 - r, 0), (x0 + r, y1 - r, 90), (x0 + r, y0 + r, 180)):
        pts += arcpts(cx, cy, r, a, a + 90, 5)
    return pts

def rr(x0, y0, x1, y1, r=0.05, w=1.0, fa=None):
    pts = rr_pts(x0, y0, x1, y1, r)
    if fa:
        fill(pts, fa)
    poly(pts, w, closed=True)

def spline(pts, closed=False, n=7):
    """Catmull-Rom through pts."""
    P = list(pts)
    out = []
    m = len(P)
    rng = range(m) if closed else range(m - 1)
    for i in rng:
        p0 = P[(i - 1) % m] if (closed or i > 0) else P[0]
        p1 = P[i]
        p2 = P[(i + 1) % m]
        p3 = P[(i + 2) % m] if (closed or i + 2 < m) else P[-1]
        for k in range(n):
            t = k / n
            out.append(tuple(0.5 * ((2 * p1[j]) + (-p0[j] + p2[j]) * t +
                                    (2 * p0[j] - 5 * p1[j] + 4 * p2[j] - p3[j]) * t * t +
                                    (-p0[j] + 3 * p1[j] - 3 * p2[j] + p3[j]) * t ** 3) for j in (0, 1)))
    if not closed:
        out.append(P[-1])
    return out

def sym(half, cx=0.5):
    """A symmetric closed outline from its right half (top to bottom)."""
    right = list(half)
    # the first and last points sit on the axis: don't repeat them on the left
    left = [(2 * cx - x, y) for x, y in reversed(half[1:-1])]
    return spline(right + left, closed=True)

def body(half, w=1.0, fa=0.22, cx=0.5):
    pts = sym(half, cx)
    fill(pts, fa)
    poly(pts, w, closed=True)

def rotate_icon(deg, cx=0.5, cy=0.5):
    c, s = math.cos(math.radians(deg)), math.sin(math.radians(deg))
    def rp(x, y):
        return cx + (x - cx) * c - (y - cy) * s, cy + (x - cx) * s + (y - cy) * c
    for sh in cur:
        if sh[0] == "l":
            sh[1], sh[2] = [round(v, 4) for v in rp(sh[1], sh[2])]
            sh[3], sh[4] = [round(v, 4) for v in rp(sh[3], sh[4])]
        elif sh[0] in ("p", "f"):
            xs = sh[1]
            for i in range(0, len(xs), 2):
                xs[i], xs[i + 1] = [round(v, 4) for v in rp(xs[i], xs[i + 1])]
        else:
            sh[1], sh[2] = [round(v, 4) for v in rp(sh[1], sh[2])]

def arrowhead(x, y, ang, size=0.1, w=1.0):
    a = math.radians(ang)
    p1 = (x - size * math.cos(a - 0.6), y - size * math.sin(a - 0.6))
    p2 = (x - size * math.cos(a + 0.6), y - size * math.sin(a + 0.6))
    poly([p1, (x, y), p2], w)

def starburst(cx, cy, r1, r2, n, rot=0):
    return [(cx + (r1 if i % 2 == 0 else r2) * math.cos(math.radians(rot + i * 180.0 / n)),
             cy + (r1 if i % 2 == 0 else r2) * math.sin(math.radians(rot + i * 180.0 / n))) for i in range(2 * n)]

def wave(fn, x0=0.1, x1=0.9, n=40):
    return [(x0 + (x1 - x0) * i / n, fn(i / n)) for i in range(n + 1)]

def keys(x0, y0, x1, y1, n=5, black=True, w=0.8):
    for i in range(1, n):
        x = x0 + (x1 - x0) * i / n
        line(x, y0 + (y1 - y0) * (0.5 if black else 0), x, y1, w * 0.8)
    if black:
        for i in (1, 2, 4):
            if i < n:
                x = x0 + (x1 - x0) * i / n
                bw = (x1 - x0) / n * 0.3
                fill([(x - bw, y0), (x + bw, y0), (x + bw, y0 + (y1 - y0) * 0.55), (x - bw, y0 + (y1 - y0) * 0.55)], 1.0)

# ============================================================== DRUMS
def drum_side(cx, top, bot, rx, ry, lugs=True, fa=0.2):
    ell(cx, top, rx, ry, 1.0, fa)
    line(cx - rx, top, cx - rx, bot)
    line(cx + rx, top, cx + rx, bot)
    ell(cx, bot, rx, ry, 1.0, None, 0, 180)
    if lugs:
        for dx in (-0.55, 0, 0.55):
            line(cx + rx * dx, top + ry + 0.05, cx + rx * dx, bot + ry - 0.05, 0.6)

icon("drumkit", "Drum kit")
ring(0.5, 0.64, 0.27, 1.0, 0.2); ring(0.5, 0.64, 0.1, 0.7)
line(0.14, 0.14, 0.42, 0.36, 1.1); line(0.86, 0.14, 0.58, 0.36, 1.1)
icon("kick", "Kick")
ring(0.5, 0.5, 0.38, 1.0, 0.18); ring(0.5, 0.5, 0.17, 0.8)
line(0.88, 0.12, 0.64, 0.36, 1.2); circle(0.9, 0.1, 0.06)
icon("snare", "Snare")
drum_side(0.5, 0.46, 0.66, 0.36, 0.1, False)
for x in (0.3, 0.42, 0.54, 0.66):
    line(x, 0.56, x, 0.7, 0.55)
line(0.12, 0.1, 0.44, 0.34, 1.1); line(0.88, 0.1, 0.56, 0.34, 1.1)
icon("tom", "Tom")
drum_side(0.5, 0.34, 0.64, 0.34, 0.1)
line(0.5, 0.8, 0.5, 0.92); line(0.36, 0.92, 0.64, 0.92)
icon("floortom", "Floor tom")
drum_side(0.5, 0.26, 0.62, 0.34, 0.1)
for a, b in (((0.2, 0.7), (0.12, 0.94)), ((0.8, 0.7), (0.88, 0.94)), ((0.5, 0.75), (0.5, 0.94))):
    line(*a, *b)
icon("hihat", "Hi-hat")
ell(0.5, 0.3, 0.38, 0.07, 1.0, 0.3); ell(0.5, 0.42, 0.38, 0.07, 1.0, 0.3)
line(0.5, 0.5, 0.5, 0.88); line(0.3, 0.9, 0.7, 0.9)
icon("openhat", "Open hat")
ell(0.5, 0.2, 0.38, 0.07, 1.0, 0.3, rot=-8); ell(0.5, 0.46, 0.38, 0.07, 1.0, 0.3)
line(0.5, 0.54, 0.5, 0.88); line(0.3, 0.9, 0.7, 0.9)
line(0.9, 0.26, 0.96, 0.18, 0.7); line(0.9, 0.34, 0.97, 0.3, 0.7)
icon("crash", "Crash")
ell(0.5, 0.4, 0.42, 0.13, 1.0, 0.25, rot=-14); circle(0.5, 0.4, 0.05)
line(0.5, 0.46, 0.5, 0.9); line(0.3, 0.9, 0.7, 0.9)
line(0.1, 0.12, 0.2, 0.2, 0.7); line(0.3, 0.06, 0.34, 0.16, 0.7)
icon("ride", "Ride")
ell(0.5, 0.42, 0.44, 0.15, 1.0, 0.2, rot=-8); ell(0.5, 0.42, 0.14, 0.05, 0.8); circle(0.5, 0.42, 0.03)
line(0.5, 0.5, 0.5, 0.9); line(0.3, 0.9, 0.7, 0.9)
icon("cymbal", "Cymbal")
ell(0.5, 0.44, 0.42, 0.16, 1.0, 0.2); ell(0.5, 0.4, 0.24, 0.08, 0.8); circle(0.5, 0.4, 0.04)
line(0.5, 0.58, 0.5, 0.9); line(0.34, 0.9, 0.66, 0.9)
icon("clap", "Clap")
line(0.2, 0.74, 0.46, 0.4, 2.4); line(0.8, 0.74, 0.54, 0.4, 2.4)
line(0.5, 0.14, 0.5, 0.26, 0.8); line(0.28, 0.2, 0.35, 0.3, 0.8); line(0.72, 0.2, 0.65, 0.3, 0.8)
icon("sidestick", "Rim shot")
ring(0.5, 0.56, 0.3, 0.9, 0.18); line(0.14, 0.86, 0.86, 0.16, 1.4); circle(0.86, 0.16, 0.05)
icon("cowbell", "Cowbell")
body_pts = [(0.3, 0.3), (0.7, 0.3), (0.84, 0.82), (0.16, 0.82)]
fill(body_pts, 0.22); poly(body_pts, 1.0, True); rr(0.4, 0.14, 0.6, 0.3, 0.04); circle(0.5, 0.62, 0.07)
icon("tambourine", "Tambourine")
ring(0.5, 0.5, 0.36, 1.0, 0.16)
for a in (45, 135, 225, 315):
    circle(0.5 + 0.36 * math.cos(math.radians(a)), 0.5 + 0.36 * math.sin(math.radians(a)), 0.06)
ring(0.5, 0.5, 0.1, 0.6)
icon("shaker", "Shaker")
ring(0.3, 0.32, 0.2, 1.0, 0.2); line(0.3, 0.52, 0.3, 0.86); circle(0.3, 0.32, 0.04)
ring(0.7, 0.4, 0.2, 1.0, 0.2); line(0.7, 0.6, 0.7, 0.92); circle(0.7, 0.4, 0.04)
icon("conga", "Conga")
ell(0.5, 0.2, 0.28, 0.07, 1.0, 0.25)
poly(spline([(0.22, 0.2), (0.27, 0.5), (0.34, 0.86)]), 1.0); poly(spline([(0.78, 0.2), (0.73, 0.5), (0.66, 0.86)]), 1.0)
ell(0.5, 0.86, 0.16, 0.04, 1.0, None, 0, 180)
ell(0.5, 0.45, 0.24, 0.05, 0.7, None, 0, 180); ell(0.5, 0.65, 0.21, 0.05, 0.7, None, 0, 180)
icon("bongo", "Bongo")
drum_side(0.28, 0.4, 0.8, 0.18, 0.06, False); drum_side(0.72, 0.48, 0.8, 0.2, 0.06, False)
line(0.44, 0.54, 0.56, 0.58, 1.2)
icon("triangle", "Triangle")
line(0.5, 0.2, 0.84, 0.8); line(0.84, 0.8, 0.16, 0.8); line(0.16, 0.8, 0.34, 0.46)
line(0.12, 0.3, 0.72, 0.5, 0.7); circle(0.12, 0.3, 0.04)
icon("woodblock", "Wood block")
rr(0.1, 0.34, 0.9, 0.7, 0.1, 1.0, 0.22); line(0.26, 0.52, 0.74, 0.52); line(0.76, 0.1, 0.5, 0.32, 1.1); circle(0.78, 0.08, 0.05)
icon("claves", "Claves")
line(0.18, 0.84, 0.74, 0.2, 2.0); line(0.82, 0.84, 0.26, 0.2, 2.0)
icon("guiro", "Guiro")
rr(0.1, 0.46, 0.9, 0.7, 0.12, 1.0, 0.22)
for i in range(7):
    line(0.22 + i * 0.09, 0.46, 0.22 + i * 0.09, 0.52, 0.6)
line(0.16, 0.14, 0.66, 0.44, 1.0)
icon("agogo", "Agogo")
for cx, k in ((0.28, 0.85), (0.72, 1.0)):
    pts = [(cx - 0.1 * k, 0.4), (cx + 0.1 * k, 0.4), (cx + 0.17 * k, 0.86), (cx - 0.17 * k, 0.86)]
    fill(pts, 0.22); poly(pts, 1.0, True)
poly(spline([(0.28, 0.4), (0.34, 0.16), (0.66, 0.16), (0.72, 0.4)]), 1.0)
icon("whistle", "Whistle")
ring(0.62, 0.58, 0.26, 1.0, 0.2); rr(0.08, 0.34, 0.5, 0.52, 0.06, 1.0, 0.2); circle(0.62, 0.58, 0.07); line(0.62, 0.3, 0.62, 0.2, 0.9)
icon("cajon", "Cajón")
rr(0.18, 0.1, 0.82, 0.88, 0.05, 1.0, 0.2); ring(0.5, 0.58, 0.14, 0.9); line(0.18, 0.3, 0.82, 0.3, 0.8)
icon("timpani", "Timpani")
ell(0.5, 0.4, 0.38, 0.1, 1.0, 0.22); arc(0.5, 0.4, 0.38, 0, 180, 1.0)
line(0.34, 0.76, 0.26, 0.92); line(0.66, 0.76, 0.74, 0.92); line(0.8, 0.1, 0.6, 0.3, 1.0); circle(0.82, 0.08, 0.06)
icon("gong", "Gong")
line(0.1, 0.1, 0.1, 0.92); line(0.9, 0.1, 0.9, 0.92); line(0.08, 0.12, 0.92, 0.12)
ring(0.5, 0.54, 0.27, 1.0, 0.2); ring(0.5, 0.54, 0.13, 0.7); circle(0.5, 0.54, 0.04); line(0.5, 0.12, 0.5, 0.27, 0.7)
icon("drummachine", "Drum machine")
for r_ in range(3):
    for c_ in range(3):
        x0, y0 = 0.1 + c_ * 0.29, 0.1 + r_ * 0.29
        lit = (r_, c_) in ((0, 0), (1, 2), (2, 1))
        rr(x0, y0, x0 + 0.23, y0 + 0.23, 0.05, 0.8, 0.6 if lit else 0.12)

category("Drums & percussion", ["drumkit", "kick", "snare", "hihat", "openhat", "tom", "floortom", "crash", "ride", "cymbal",
                                "clap", "sidestick", "cowbell", "tambourine", "shaker", "conga", "bongo", "triangle",
                                "woodblock", "claves", "guiro", "agogo", "whistle", "cajon", "timpani", "gong", "drummachine"])

# ============================================================== KEYS
icon("piano", "Piano")
rr(0.08, 0.2, 0.92, 0.8, 0.06, 1.0, 0.12); keys(0.08, 0.2, 0.92, 0.8, 5)
icon("grandpiano", "Grand piano")
lid = [(0.1, 0.5), (0.46, 0.12), (0.94, 0.34), (0.9, 0.5)]
fill(lid, 0.2); poly(lid, 1.0, True)
line(0.5, 0.5, 0.46, 0.2, 0.7)
case = spline([(0.1, 0.5), (0.1, 0.66), (0.62, 0.66), (0.8, 0.6), (0.9, 0.5)], n=6)
fill(case + [(0.1, 0.5)], 0.2); poly(case, 1.0); line(0.1, 0.5, 0.9, 0.5, 1.0)
line(0.16, 0.66, 0.16, 0.92, 1.1); line(0.76, 0.62, 0.76, 0.92, 1.1); line(0.5, 0.66, 0.5, 0.92, 0.8)
for x in (0.2, 0.28, 0.36, 0.44):
    line(x, 0.5, x, 0.58, 0.5)
icon("epiano", "Electric piano")
rr(0.08, 0.26, 0.92, 0.8, 0.08, 1.0, 0.18)
for x in (0.24, 0.4, 0.56):
    ring(x, 0.4, 0.045, 0.7)
line(0.7, 0.4, 0.84, 0.4, 0.8); keys(0.08, 0.54, 0.92, 0.8, 6, False, 0.6)
icon("organ", "Organ")
rr(0.08, 0.14, 0.92, 0.42, 0.05, 1.0, 0.18); keys(0.08, 0.14, 0.92, 0.42, 8, False, 0.6)
rr(0.08, 0.46, 0.92, 0.74, 0.05, 1.0, 0.18); keys(0.08, 0.46, 0.92, 0.74, 8, False, 0.6)
line(0.2, 0.84, 0.8, 0.84, 1.4)
icon("clav", "Clavinet")
rr(0.08, 0.5, 0.92, 0.8, 0.06, 1.0, 0.18); keys(0.08, 0.5, 0.92, 0.8, 6, False, 0.6)
poly([(0.12, 0.38), (0.26, 0.16), (0.4, 0.38), (0.54, 0.16), (0.68, 0.38), (0.82, 0.16)], 0.8)
icon("accordion", "Accordion")
rr(0.06, 0.18, 0.24, 0.82, 0.05, 1.0, 0.22); rr(0.76, 0.18, 0.94, 0.82, 0.05, 1.0, 0.22)
for i in range(7):
    line(0.3 + i * 0.065, 0.24 if i % 2 == 0 else 0.3, 0.3 + i * 0.065, 0.76 if i % 2 == 0 else 0.7, 0.8)
icon("harmonica", "Harmonica")
rr(0.06, 0.36, 0.94, 0.68, 0.06, 1.0, 0.2)
for i in range(8):
    line(0.16 + i * 0.096, 0.44, 0.16 + i * 0.096, 0.6, 0.7)
icon("mellotron", "Mellotron")
rr(0.08, 0.14, 0.92, 0.88, 0.08, 1.0, 0.16)
ring(0.32, 0.4, 0.14, 0.9); ring(0.68, 0.4, 0.14, 0.9); circle(0.32, 0.4, 0.03); circle(0.68, 0.4, 0.03)
poly([(0.32, 0.54), (0.32, 0.68), (0.68, 0.68), (0.68, 0.54)], 0.8)
category("Keyboards", ["piano", "grandpiano", "epiano", "organ", "clav", "accordion", "harmonica", "mellotron"])

# ============================================================== MALLETS
def bars(n=4, x0=0.1, x1=0.9, top=0.22, bot=0.64, taper=0.07, w=0.14):
    step = (x1 - x0) / n
    for i in range(n):
        x = x0 + i * step + (step - w) / 2
        rr(x, top + i * taper, x + w, bot, 0.03, 1.0, 0.3)

icon("marimba", "Marimba")
bars(4)
for i in range(4):
    cx = 0.1 + i * 0.2 + 0.1
    line(cx, 0.7, cx, 0.9 - i * 0.04, 0.8)
icon("xylophone", "Xylophone")
bars(4, top=0.3, bot=0.7)
line(0.12, 0.1, 0.44, 0.4, 1.0); line(0.88, 0.1, 0.56, 0.4, 1.0); circle(0.12, 0.1, 0.05); circle(0.88, 0.1, 0.05)
icon("vibraphone", "Vibraphone")
bars(4, top=0.2, bot=0.56)
for i in range(4):
    cx = 0.1 + i * 0.2 + 0.1
    line(cx, 0.62, cx, 0.78 - i * 0.02, 0.7); ring(cx, 0.84 - i * 0.02, 0.045, 0.6)
icon("glockenspiel", "Glockenspiel")
for i in range(5):
    x = 0.1 + i * 0.15
    rr(x, 0.3 + i * 0.04, x + 0.1, 0.76, 0.03, 1.0, 0.3)
fill(starburst(0.82, 0.18, 0.12, 0.04, 4), 0.9)
icon("bell", "Bell")
pts = [(0.14, 0.76), (0.26, 0.64), (0.26, 0.42)] + arcpts(0.5, 0.42, 0.24, 180, 360, 12) + [(0.74, 0.64), (0.86, 0.76)]
fill(pts, 0.2); poly(pts, 1.0, True); circle(0.5, 0.88, 0.06); line(0.5, 0.12, 0.5, 0.18, 1.0)
icon("tubular", "Tubular bells")
line(0.08, 0.12, 0.92, 0.12, 1.2)
for i in range(5):
    x = 0.17 + i * 0.165
    line(x, 0.12, x, 0.2, 0.6); rr(x - 0.04, 0.2, x + 0.04, 0.86 - i * 0.08, 0.03, 1.0, 0.3)
icon("kalimba", "Kalimba")
rr(0.14, 0.1, 0.86, 0.9, 0.1, 1.0, 0.16)
for i, h in enumerate((0.5, 0.64, 0.78, 0.64, 0.5)):
    x = 0.28 + i * 0.11
    line(x, 0.78 - h * 0.7 + 0.1, x, 0.78, 1.1)
ring(0.5, 0.82, 0.05, 0.7)
icon("steeldrum", "Steel drum")
ell(0.5, 0.52, 0.42, 0.24, 1.0, 0.2)
for x, y in ((0.34, 0.52), (0.5, 0.42), (0.66, 0.52), (0.5, 0.62), (0.5, 0.52)):
    ell(x, y, 0.07, 0.04, 0.7)
line(0.14, 0.12, 0.32, 0.34, 1.0); line(0.86, 0.12, 0.68, 0.34, 1.0)
icon("musicbox", "Music box")
rr(0.1, 0.4, 0.78, 0.84, 0.06, 1.0, 0.2); line(0.1, 0.52, 0.78, 0.52, 0.8)
line(0.78, 0.66, 0.9, 0.66, 0.9); circle(0.92, 0.66, 0.04)
circle(0.36, 0.22, 0.07); line(0.43, 0.22, 0.43, 0.06, 0.9); line(0.43, 0.06, 0.56, 0.12, 0.9)
category("Mallets & bells", ["marimba", "xylophone", "vibraphone", "glockenspiel", "bell", "tubular", "kalimba", "steeldrum", "musicbox"])

# ============================================================== PLUCKED & BASS
def neck(x, y0, y1, w=0.03):
    line(x - w, y0, x - w, y1, 0.9); line(x + w, y0, x + w, y1, 0.9)

icon("guitar", "Acoustic guitar")
body([(0.5, 0.4), (0.6, 0.42), (0.64, 0.5), (0.6, 0.58), (0.68, 0.66), (0.7, 0.78), (0.6, 0.9), (0.5, 0.92)])
neck(0.5, 0.1, 0.42); rr(0.45, 0.02, 0.55, 0.12, 0.02, 0.9, 0.5); ring(0.5, 0.66, 0.07, 0.8); line(0.42, 0.82, 0.58, 0.82, 0.9)
rotate_icon(32)
icon("electricguitar", "Electric guitar")
body([(0.5, 0.42), (0.58, 0.46), (0.64, 0.34), (0.7, 0.4), (0.68, 0.58), (0.74, 0.7), (0.66, 0.88), (0.5, 0.92)])
neck(0.5, 0.08, 0.44); rr(0.45, 0.0, 0.55, 0.1, 0.02, 0.9, 0.5)
line(0.4, 0.58, 0.6, 0.58, 1.2); line(0.4, 0.7, 0.6, 0.7, 1.2); line(0.4, 0.82, 0.6, 0.82, 0.8)
rotate_icon(32)
icon("bass", "Bass guitar")
body([(0.5, 0.52), (0.58, 0.54), (0.62, 0.46), (0.68, 0.5), (0.66, 0.66), (0.7, 0.78), (0.62, 0.9), (0.5, 0.92)])
neck(0.5, 0.04, 0.54, 0.025); rr(0.46, 0.0, 0.54, 0.08, 0.02, 0.9, 0.5)
line(0.42, 0.68, 0.58, 0.68, 1.2); line(0.42, 0.8, 0.58, 0.8, 0.8)
rotate_icon(32)
icon("upright", "Upright bass")
body([(0.5, 0.22), (0.62, 0.24), (0.66, 0.34), (0.6, 0.44), (0.7, 0.54), (0.72, 0.68), (0.62, 0.84), (0.5, 0.86)])
neck(0.5, 0.0, 0.24, 0.025); line(0.5, 0.86, 0.5, 0.98, 1.0)
line(0.4, 0.5, 0.38, 0.62, 0.7); line(0.6, 0.5, 0.62, 0.62, 0.7); line(0.42, 0.76, 0.58, 0.76, 0.9)
icon("banjo", "Banjo")
ring(0.5, 0.7, 0.24, 1.0, 0.18); ring(0.5, 0.7, 0.15, 0.7); neck(0.5, 0.08, 0.46); rr(0.45, 0.0, 0.55, 0.1, 0.02, 0.9, 0.5)
rotate_icon(30)
icon("mandolin", "Mandolin")
body([(0.5, 0.36), (0.62, 0.42), (0.67, 0.58), (0.62, 0.78), (0.5, 0.86)])
neck(0.5, 0.06, 0.38); ell(0.5, 0.62, 0.07, 0.11, 0.8)
rotate_icon(32)
icon("ukulele", "Ukulele")
body([(0.5, 0.5), (0.58, 0.52), (0.6, 0.58), (0.57, 0.64), (0.64, 0.7), (0.65, 0.8), (0.58, 0.9), (0.5, 0.92)])
neck(0.5, 0.14, 0.5, 0.03); rr(0.46, 0.06, 0.54, 0.16, 0.02, 0.9, 0.5); ring(0.5, 0.72, 0.05, 0.8)
rotate_icon(32)
icon("sitar", "Sitar")
ring(0.5, 0.76, 0.17, 1.0, 0.2); ring(0.5, 0.26, 0.06, 0.8); neck(0.5, 0.06, 0.6, 0.03)
for y in (0.16, 0.24, 0.32, 0.4, 0.48):
    line(0.43, y, 0.57, y, 0.6)
rotate_icon(28)
icon("koto", "Koto")
pts = [(0.06, 0.4), (0.94, 0.3), (0.94, 0.64), (0.06, 0.74)]
fill(pts, 0.18); poly(pts, 1.0, True)
for i in range(3):
    line(0.1, 0.46 + i * 0.1, 0.9, 0.38 + i * 0.1, 0.5)
for x in (0.3, 0.5, 0.7):
    fill([(x - 0.04, 0.58 - (x - 0.06) * 0.11), (x + 0.04, 0.58 - (x - 0.06) * 0.11), (x, 0.48 - (x - 0.06) * 0.11)], 1.0)
icon("harp", "Harp")
neckpts = spline([(0.2, 0.12), (0.5, 0.08), (0.74, 0.26), (0.84, 0.52)])
poly(neckpts, 1.2); line(0.2, 0.12, 0.2, 0.9); line(0.84, 0.52, 0.84, 0.9); line(0.2, 0.9, 0.84, 0.9)
for i in range(5):
    x = 0.3 + i * 0.1
    ys = [p[1] for p in neckpts if abs(p[0] - x) < 0.04]
    y = min(ys) if ys else 0.3
    line(x, y + 0.03, x, 0.9, 0.5)
category("Guitars & plucked", ["guitar", "electricguitar", "bass", "upright", "banjo", "mandolin", "ukulele", "sitar", "koto", "harp"])

# ============================================================== STRINGS
icon("violin", "Violin")
body([(0.5, 0.34), (0.6, 0.36), (0.62, 0.45), (0.56, 0.52), (0.64, 0.6), (0.66, 0.72), (0.58, 0.84), (0.5, 0.86)])
neck(0.5, 0.1, 0.34, 0.025); ring(0.5, 0.07, 0.04, 0.8)
line(0.4, 0.5, 0.38, 0.6, 0.6); line(0.6, 0.5, 0.62, 0.6, 0.6)
line(0.12, 0.84, 0.86, 0.5, 0.7)
rotate_icon(-18)
icon("cello", "Cello")
body([(0.5, 0.3), (0.62, 0.32), (0.66, 0.42), (0.6, 0.5), (0.7, 0.58), (0.72, 0.72), (0.62, 0.86), (0.5, 0.88)])
neck(0.5, 0.04, 0.3, 0.025); line(0.5, 0.88, 0.5, 0.98, 1.0)
line(0.4, 0.5, 0.38, 0.62, 0.6); line(0.6, 0.5, 0.62, 0.62, 0.6)
line(0.86, 0.28, 0.86, 0.9, 0.6)
icon("strings", "Strings")
for x in (0.28, 0.42, 0.58, 0.72):
    line(x, 0.1, x, 0.9, 0.55)
poly(spline([(0.06, 0.62), (0.5, 0.4), (0.94, 0.62)]), 1.5); circle(0.06, 0.62, 0.05)
category("Orchestral strings", ["violin", "cello", "strings"])

# ============================================================== BRASS
def trumpet(ox=0.0, oy=0.0, k=1.0):
    X = lambda x: ox + x * k
    Y = lambda y: oy + y * k
    bell = [(X(0.62), Y(0.44)), (X(0.92), Y(0.26)), (X(0.92), Y(0.74)), (X(0.62), Y(0.56))]
    fill(bell, 0.2); poly(bell, 1.0, True)
    line(X(0.1), Y(0.5), X(0.62), Y(0.5), 1.2)
    poly([(X(0.14), Y(0.5)), (X(0.14), Y(0.7)), (X(0.52), Y(0.7)), (X(0.52), Y(0.5))], 1.0)
    for x in (0.26, 0.34, 0.42):
        line(X(x), Y(0.5), X(x), Y(0.34), 0.9); circle(X(x), Y(0.32), 0.02 * k + 0.008)

icon("trumpet", "Trumpet")
trumpet()
icon("trombone", "Trombone")
poly([(0.1, 0.36), (0.66, 0.36)], 1.0); poly([(0.1, 0.52), (0.66, 0.52)], 1.0); arc(0.1, 0.44, 0.08, 90, 270, 1.0)
poly([(0.66, 0.52), (0.76, 0.52), (0.92, 0.3), (0.92, 0.82), (0.76, 0.7), (0.66, 0.7), (0.66, 0.52)], 1.0)
fill([(0.76, 0.52), (0.92, 0.3), (0.92, 0.82), (0.76, 0.7)], 0.2); line(0.4, 0.36, 0.4, 0.52, 0.8)
icon("horn", "French horn")
ring(0.4, 0.52, 0.3, 1.0, 0.1); ring(0.4, 0.52, 0.17, 0.8)
fill([(0.7, 0.5), (0.94, 0.28), (0.94, 0.8), (0.7, 0.58)], 0.2); poly([(0.7, 0.5), (0.94, 0.28), (0.94, 0.8), (0.7, 0.58)], 1.0, True)
line(0.4, 0.22, 0.4, 0.08, 0.9); circle(0.4, 0.06, 0.035)
icon("tuba", "Tuba")
ring(0.4, 0.66, 0.26, 1.0, 0.14); ring(0.4, 0.66, 0.14, 0.8)
pts = [(0.64, 0.12), (0.94, 0.12), (0.84, 0.42), (0.7, 0.42)]
fill(pts, 0.2); poly(pts, 1.0, True); line(0.66, 0.42, 0.64, 0.7, 1.0); line(0.14, 0.4, 0.14, 0.2, 0.9); circle(0.14, 0.18, 0.04)
icon("brass", "Brass section")
trumpet(0.0, 0.0, 0.66)
trumpet(0.34, 0.34, 0.66)
icon("sax", "Saxophone")
poly(spline([(0.62, 0.1), (0.54, 0.3), (0.44, 0.6), (0.44, 0.82), (0.58, 0.9), (0.74, 0.8), (0.8, 0.6)]), 1.8)
fill([(0.7, 0.6), (0.9, 0.6), (0.86, 0.5), (0.74, 0.5)], 0.9); line(0.62, 0.1, 0.78, 0.06, 1.2)
for p in ((0.52, 0.36), (0.49, 0.48), (0.46, 0.6), (0.45, 0.72)):
    circle(p[0] + 0.07, p[1], 0.032)
category("Brass", ["trumpet", "trombone", "horn", "tuba", "brass", "sax"])

# ============================================================== WINDS
icon("flute", "Flute")
rr(0.45, 0.04, 0.55, 0.96, 0.05, 0.9, 0.18)
for y in (0.34, 0.46, 0.58, 0.7):
    circle(0.5, y, 0.03)
ring(0.5, 0.18, 0.03, 0.6); rotate_icon(45)
icon("clarinet", "Clarinet")
rr(0.46, 0.08, 0.54, 0.8, 0.03, 0.9, 0.18)
fill([(0.46, 0.8), (0.36, 0.94), (0.64, 0.94), (0.54, 0.8)], 0.2); poly([(0.46, 0.8), (0.36, 0.94), (0.64, 0.94), (0.54, 0.8)], 0.9)
for y in (0.28, 0.4, 0.52, 0.64):
    circle(0.5, y, 0.025)
line(0.48, 0.02, 0.52, 0.02, 1.4); rotate_icon(28)
icon("oboe", "Oboe")
rr(0.47, 0.22, 0.53, 0.84, 0.03, 0.9, 0.18); line(0.49, 0.02, 0.49, 0.22, 0.8); line(0.52, 0.02, 0.52, 0.22, 0.8)
fill([(0.47, 0.84), (0.4, 0.94), (0.6, 0.94), (0.53, 0.84)], 0.2); poly([(0.47, 0.84), (0.4, 0.94), (0.6, 0.94), (0.53, 0.84)], 0.9)
for y in (0.34, 0.46, 0.58, 0.7):
    circle(0.5, y, 0.02)
rotate_icon(28)
icon("bassoon", "Bassoon")
line(0.32, 0.12, 0.32, 0.8, 1.0); line(0.54, 0.2, 0.54, 0.8, 1.0); arc(0.43, 0.8, 0.11, 0, 180, 1.0)
poly(spline([(0.54, 0.2), (0.6, 0.06), (0.8, 0.04)]), 1.0)
for y in (0.34, 0.5, 0.66):
    circle(0.32, y, 0.025)
fill([(0.32, 0.12), (0.2, 0.06), (0.32, 0.02)], 0.5)
icon("recorder", "Recorder")
rr(0.45, 0.14, 0.55, 0.96, 0.04, 0.9, 0.18); fill([(0.45, 0.14), (0.5, 0.02), (0.55, 0.14)], 0.6)
for y in (0.38, 0.5, 0.62, 0.74, 0.86):
    circle(0.5, y, 0.025)
rotate_icon(35)
icon("panflute", "Pan flute")
for i in range(5):
    x = 0.1 + i * 0.16
    rr(x, 0.14 + i * 0.12, x + 0.12, 0.86, 0.04, 0.9, 0.22)
poly([(0.08, 0.64), (0.92, 0.5)], 1.2)
icon("bagpipes", "Bagpipes")
ell(0.46, 0.6, 0.3, 0.2, 1.0, 0.2, rot=-10)
line(0.22, 0.46, 0.12, 0.2, 1.0); line(0.56, 0.42, 0.62, 0.08, 1.0); line(0.66, 0.48, 0.84, 0.12, 1.0); line(0.36, 0.76, 0.32, 0.96, 1.0)
icon("ocarina", "Ocarina")
ell(0.5, 0.56, 0.38, 0.24, 1.0, 0.2, rot=-22)
for p in ((0.4, 0.6), (0.52, 0.52), (0.62, 0.44), (0.36, 0.7)):
    circle(p[0], p[1], 0.04)
rr(0.76, 0.14, 0.86, 0.34, 0.03, 0.9, 0.5)
category("Woodwinds", ["flute", "clarinet", "oboe", "bassoon", "recorder", "panflute", "bagpipes", "ocarina"])

# ============================================================== VOICE
icon("vocal", "Vocals")
arc(0.5, 0.26, 0.14, 180, 360, 1.0); line(0.36, 0.26, 0.36, 0.44); line(0.64, 0.26, 0.64, 0.44); arc(0.5, 0.44, 0.14, 0, 180, 1.0)
fill(rr_pts(0.36, 0.12, 0.64, 0.58, 0.14), 0.2)
arc(0.5, 0.44, 0.27, 12, 168, 0.9); line(0.5, 0.71, 0.5, 0.88, 0.9); line(0.34, 0.88, 0.66, 0.88, 1.0)
icon("choir", "Choir")
for cx, cy, r in ((0.5, 0.3, 0.12), (0.2, 0.4, 0.09), (0.8, 0.4, 0.09)):
    ring(cx, cy, r, 1.0, 0.25)
arc(0.5, 0.82, 0.24, 180, 360, 1.0); arc(0.2, 0.86, 0.15, 180, 360, 0.9); arc(0.8, 0.86, 0.15, 180, 360, 0.9)
icon("vocoder", "Vocoder")
for i, h in enumerate((0.3, 0.55, 0.8, 0.5, 0.66, 0.36)):
    x = 0.14 + i * 0.15
    rr(x, 0.5 - h / 2, x + 0.08, 0.5 + h / 2, 0.04, 1.0, 0.35)
category("Voice", ["vocal", "choir", "vocoder"])

# ============================================================== SYNTH
icon("synth", "Synth")
poly(wave(lambda t: 0.5 - 0.27 * math.sin(t * math.tau * 1.5)), 1.4)
icon("lead", "Saw lead")
poly([(0.08, 0.72), (0.4, 0.28), (0.4, 0.72), (0.72, 0.28), (0.72, 0.72), (0.92, 0.5)], 1.2)
icon("squarelead", "Square lead")
poly([(0.08, 0.7), (0.08, 0.3), (0.34, 0.3), (0.34, 0.7), (0.62, 0.7), (0.62, 0.3), (0.92, 0.3)], 1.2)
icon("pad", "Pad")
rr(0.1, 0.22, 0.72, 0.38, 0.08, 1.0, 0.85); rr(0.28, 0.44, 0.9, 0.6, 0.08, 1.0, 0.55); rr(0.16, 0.66, 0.6, 0.82, 0.08, 1.0, 0.3)
icon("pluck", "Pluck")
poly(wave(lambda t: 0.5 - 0.34 * math.exp(-3.2 * t) * math.sin(t * math.tau * 3.2), 0.08, 0.92, 60), 1.3); circle(0.08, 0.5, 0.04)
icon("arp", "Arpeggio")
for i in range(4):
    x = 0.12 + i * 0.2
    rr(x, 0.7 - i * 0.17, x + 0.14, 0.86, 0.05, 1.0, 0.25 + i * 0.2)
icon("subbass", "Sub bass")
poly(wave(lambda t: 0.5 - 0.3 * math.sin(t * math.tau), 0.08, 0.92, 40), 2.0); line(0.08, 0.84, 0.92, 0.84, 0.8)
icon("acid", "Acid")
poly(wave(lambda t: 0.5 - (0.08 + 0.26 * t) * math.sin(t * math.tau * (1.6 + 1.6 * t)), 0.08, 0.86, 80), 1.2); circle(0.9, 0.5, 0.05)
icon("sequence", "Sequencer")
for i in range(8):
    x = 0.1 + i * 0.1
    rr(x, 0.46, x + 0.07, 0.7, 0.02, 0.8, 0.95 if i in (0, 3, 5) else None)
fill([(0.3, 0.22), (0.38, 0.22), (0.34, 0.34)], 1.0)
icon("stab", "Chord stab")
for y in (0.22, 0.44, 0.66):
    rr(0.16, y, 0.7, y + 0.13, 0.05, 1.0, 0.9)
line(0.82, 0.14, 0.92, 0.04, 0.9); line(0.84, 0.3, 0.96, 0.3, 0.9); line(0.82, 0.46, 0.92, 0.54, 0.9)
icon("supersaw", "Supersaw")
for y, al in ((0.36, 1.0), (0.62, 1.0)):
    poly([(0.1, y + 0.1), (0.34, y - 0.1), (0.34, y + 0.1), (0.58, y - 0.1), (0.58, y + 0.1), (0.82, y - 0.1)], 1.0)
line(0.1, 0.84, 0.9, 0.84, 0.5)
icon("wobble", "Wobble")
poly(wave(lambda t: 0.5 - 0.32 * math.sin(t * math.tau * 4) * abs(math.sin(t * math.pi * 1.5)), 0.08, 0.92, 90), 1.2)
icon("noise", "Noise")
random.seed(7)
poly([(0.08 + i * 0.84 / 14, 0.5 + random.uniform(-0.28, 0.28)) for i in range(15)], 1.0)
category("Synths", ["synth", "lead", "squarelead", "pad", "pluck", "arp", "subbass", "acid", "sequence", "stab", "supersaw", "wobble", "noise"])

# ============================================================== FX
icon("riser", "Riser")
poly(spline([(0.1, 0.88), (0.4, 0.82), (0.7, 0.55), (0.86, 0.16)]), 1.6); arrowhead(0.86, 0.16, -75, 0.14, 1.4)
for x, h in ((0.14, 0.14), (0.3, 0.22), (0.46, 0.32)):
    line(x, 0.94, x, 0.94 - h, 0.9)
icon("sweep", "Sweep")
for y, x0, x1, w in ((0.3, 0.1, 0.88, 1.0), (0.5, 0.2, 0.94, 1.4), (0.7, 0.1, 0.7, 1.0)):
    poly(spline([(x0, y + 0.06), ((x0 + x1) / 2, y - 0.08), (x1, y + 0.04)]), w)
icon("impact", "Impact")
pts = starburst(0.5, 0.5, 0.44, 0.22, 10)
fill(pts, 0.25); poly(pts, 1.0, True); circle(0.5, 0.5, 0.1)
icon("laser", "Laser")
line(0.1, 0.9, 0.7, 0.3, 1.8); line(0.2, 0.9, 0.7, 0.4, 0.7)
line(0.82, 0.18, 0.82, 0.04, 0.9); line(0.82, 0.18, 0.96, 0.18, 0.9); line(0.82, 0.18, 0.94, 0.06, 0.9); line(0.82, 0.18, 0.7, 0.06, 0.9); circle(0.8, 0.2, 0.05)
icon("glitch", "Glitch")
rr(0.08, 0.2, 0.62, 0.34, 0.03, 1.0, 0.5); rr(0.3, 0.4, 0.92, 0.54, 0.03, 1.0, 0.9); rr(0.08, 0.6, 0.48, 0.74, 0.03, 1.0, 0.9); rr(0.58, 0.6, 0.8, 0.74, 0.03, 1.0, 0.5)
icon("reverse", "Reverse")
poly([(0.5, 0.26), (0.22, 0.5), (0.5, 0.74)], 1.6); poly([(0.82, 0.26), (0.54, 0.5), (0.82, 0.74)], 1.6)
icon("ambience", "Ambience")
for r in (0.12, 0.26, 0.4):
    ring(0.5, 0.5, r, 0.8)
circle(0.5, 0.5, 0.04)
icon("vinyl", "Vinyl")
ring(0.5, 0.5, 0.4, 1.0, 0.16); ring(0.5, 0.5, 0.28, 0.5); arc(0.5, 0.5, 0.34, 200, 260, 0.6); ring(0.5, 0.5, 0.12, 0.8, 0.5); circle(0.5, 0.5, 0.03)
icon("rain", "Atmosphere")
pts = arcpts(0.3, 0.48, 0.12, 90, 270, 8) + arcpts(0.48, 0.36, 0.18, 180, 360, 10) + arcpts(0.66, 0.48, 0.12, 270, 450, 8)
fill(pts, 0.18); poly(pts, 1.0, True)
for x in (0.3, 0.48, 0.66):
    line(x, 0.72, x - 0.05, 0.9, 0.9)
icon("sfx", "Sound effect")
fill(starburst(0.46, 0.54, 0.4, 0.07, 4, -90), 0.9); fill(starburst(0.8, 0.2, 0.14, 0.04, 4, -90), 0.9)
category("FX & ambience", ["riser", "sweep", "impact", "laser", "glitch", "reverse", "ambience", "vinyl", "rain", "sfx"])

# ============================================================== MISC
icon("metronome", "Metronome")
pts = [(0.28, 0.9), (0.72, 0.9), (0.6, 0.14), (0.4, 0.14)]
fill(pts, 0.2); poly(pts, 1.0, True); line(0.5, 0.78, 0.64, 0.3, 1.0); circle(0.6, 0.42, 0.06); line(0.2, 0.9, 0.8, 0.9, 1.2)
icon("speaker", "Speaker")
fill([(0.12, 0.38), (0.32, 0.38), (0.52, 0.2), (0.52, 0.8), (0.32, 0.62), (0.12, 0.62)], 0.9)
arc(0.52, 0.5, 0.2, -52, 52, 1.0); arc(0.52, 0.5, 0.34, -52, 52, 1.0)
icon("turntable", "Turntable")
rr(0.08, 0.14, 0.92, 0.86, 0.08, 1.0, 0.16); ring(0.4, 0.5, 0.26, 0.9, 0.2); circle(0.4, 0.5, 0.04); line(0.84, 0.24, 0.7, 0.58, 1.0); circle(0.84, 0.24, 0.05)
icon("sampler", "Sampler")
for i, h in enumerate((0.18, 0.5, 0.78, 0.4, 0.62, 0.26, 0.12)):
    x = 0.12 + i * 0.126
    line(x, 0.5 - h / 2, x, 0.5 + h / 2, 1.1)
line(0.5, 0.06, 0.5, 0.94, 0.5)
icon("loop", "Loop")
arc(0.5, 0.5, 0.3, 200, 340, 1.4); arrowhead(0.5 + 0.3 * math.cos(math.radians(340)), 0.5 + 0.3 * math.sin(math.radians(340)), 70, 0.12, 1.4)
arc(0.5, 0.5, 0.3, 20, 160, 1.4); arrowhead(0.5 + 0.3 * math.cos(math.radians(160)), 0.5 + 0.3 * math.sin(math.radians(160)), 250, 0.12, 1.4)
icon("generic", "Circles")
ring(0.5, 0.5, 0.32, 1.2, 0.12); circle(0.5, 0.5, 0.13, 0.95)
icon("note", "Note")
circle(0.36, 0.74, 0.15); line(0.5, 0.72, 0.5, 0.14, 1.0); poly([(0.5, 0.14), (0.68, 0.24), (0.74, 0.42)], 1.0)
category("Other", ["generic", "note", "metronome", "speaker", "turntable", "sampler", "loop"])

# old names saved in earlier looks keep working
ALIASES = {"guitar": "guitar", "winds": "flute", "drums": "drumkit", "fx": "sfx", "pluck": "pluck", "strings": "strings"}

# ============================================================== output
def write_gd():
    out = ["## GENERATED by assets/branding/make_icons.py: do not edit by hand.",
           "## The instrument icons as drawing instructions in a 0..1 square.",
           "class_name IconData",
           "extends RefCounted", "",
           "const SHAPES := {"]
    for name, shapes in ICONS.items():
        out.append('\t"%s": [' % name)
        for s in shapes:
            out.append("\t\t" + repr(s).replace("True", "true").replace("False", "false") + ",")
        out.append("\t],")
    out.append("}")
    out.append("")
    out.append("const LABELS := " + repr(LABELS))
    out.append("")
    out.append("## [title, [icon names]] in the order the picker shows them.")
    out.append("const CATEGORIES := " + repr([[t, n] for t, n in CATEGORIES]))
    open(os.path.join(ROOT, "scripts", "core", "icon_data.gd"), "w").write("\n".join(out) + "\n")

def render(shapes, px, color=(247, 185, 85)):
    k = 4
    S = px * k
    base = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    w = max(1.3, px * 0.07) * k
    P = lambda x, y: (x * S, y * S)
    for sh in shapes:
        t = sh[0]
        layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        d = ImageDraw.Draw(layer)
        if t == "f":
            xs = sh[1]
            d.polygon([P(xs[i], xs[i + 1]) for i in range(0, len(xs), 2)], fill=color + (int(255 * sh[2]),))
        elif t == "c":
            x, y = P(sh[1], sh[2]); r = sh[3] * S
            d.ellipse([x - r, y - r, x + r, y + r], fill=color + (int(255 * sh[4]),))
        elif t == "r":
            x, y = P(sh[1], sh[2]); r = sh[3] * S; ww = w * sh[4]
            d.ellipse([x - r - ww / 2, y - r - ww / 2, x + r + ww / 2, y + r + ww / 2], fill=color + (255,))
            d.ellipse([x - r + ww / 2, y - r + ww / 2, x + r - ww / 2, y + r - ww / 2], fill=(0, 0, 0, 0))
        elif t == "l":
            ww = w * sh[5]
            a, b = P(sh[1], sh[2]), P(sh[3], sh[4])
            d.line([a, b], fill=color + (255,), width=int(ww))
            for q in (a, b):
                d.ellipse([q[0] - ww / 2, q[1] - ww / 2, q[0] + ww / 2, q[1] + ww / 2], fill=color + (255,))
        elif t == "p":
            xs = sh[1]; ww = w * sh[2]
            pts = [P(xs[i], xs[i + 1]) for i in range(0, len(xs), 2)]
            d.line(pts, fill=color + (255,), width=int(ww), joint="curve")
            for q in (pts[0], pts[-1]):
                d.ellipse([q[0] - ww / 2, q[1] - ww / 2, q[0] + ww / 2, q[1] + ww / 2], fill=color + (255,))
        base = Image.alpha_composite(base, layer)
    return base.resize((px, px), Image.LANCZOS)

def write_preview():
    cols = 10
    cell = 104
    names = [n for _, ns in CATEGORIES for n in ns]
    rows = (len(names) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * cell, rows * (cell + 18)), (29, 26, 23))
    font = ImageFont.load_default()
    d = ImageDraw.Draw(sheet)
    for i, n in enumerate(names):
        x, y = (i % cols) * cell, (i // cols) * (cell + 18)
        sheet.paste((44, 39, 35), (x + 8, y + 4, x + cell - 8, y + cell - 12))
        ic = render(ICONS[n], 76)
        sheet.paste(ic, (x + 20, y + 14), ic)
        d.text((x + 10, y + cell - 12), n[:16], fill=(200, 190, 175), font=font)
    sheet.save(os.path.join(ROOT, "assets", "branding", "preview", "icons.png"))
    # the size they're really used at in the app
    small = Image.new("RGB", (cols * 44, rows * 44), (29, 26, 23))
    for i, n in enumerate(names):
        x, y = (i % cols) * 44, (i // cols) * 44
        small.paste((44, 39, 35), (x + 3, y + 3, x + 41, y + 41))
        ic = render(ICONS[n], 30)
        small.paste(ic, (x + 7, y + 7), ic)
    small.resize((small.width * 2, small.height * 2), Image.NEAREST).save(os.path.join(ROOT, "assets", "branding", "preview", "icons_small.png"))
    return len(names)

if __name__ == "__main__":
    write_gd()
    print(write_preview(), "icons")
