"""Draws the Flip Fusion app icon (1024x1024, no transparency). Usage: python make-icon.py OUT.png"""
import math, sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont

S = 1024
SS = 2  # supersample
W = S * SS

def lerp(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))

def hexrgb(h):
    return ((h >> 16) & 255, (h >> 8) & 255, h & 255)

def font(size):
    for name in ("seguibl.ttf", "arialbd.ttf", "DejaVuSans-Bold.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            pass
    return ImageFont.load_default()

img = Image.new("RGB", (W, W))
px = ImageDraw.Draw(img)
top, bottom = hexrgb(0x16207A), hexrgb(0x070A26)
for y in range(W):
    px.line([(0, y), (W, y)], fill=lerp(top, bottom, y / W))

# Purple rotation swoosh behind the tiles.
glow = Image.new("RGBA", (W, W), (0, 0, 0, 0))
g = ImageDraw.Draw(glow)
cx = cy = W / 2
reach = W * 0.41
def pt(deg):
    r = math.radians(deg)
    c, s = math.cos(r), math.sin(r)
    return (cx + reach * math.copysign(abs(c) ** 0.5, c), cy + reach * math.copysign(abs(s) ** 0.5, s))
# A clockwise arrow: a thin tail at the lower left, over the top, ending in an
# arrowhead at the lower right.
ARROW = (192, 140, 255, 255)
START, END = -205, 42
steps = 240
for i in range(steps + 1):
    t = i / steps
    a = START + (END - START) * t
    w = W * 0.036 * (0.15 + 0.85 * min(1, t / 0.45))
    x, y = pt(a)
    g.ellipse([x - w, y - w, x + w, y + w], fill=ARROW)
    if i:
        g.line([prev, (x, y)], fill=ARROW, width=int(2 * w))
    prev = (x, y)
# Arrowhead, pointing the way the arc is travelling.
ex, ey = pt(END)
fx, fy = pt(END + 1.5)
length = math.hypot(fx - ex, fy - ey)
ux, uy = (fx - ex) / length, (fy - ey) / length
head, half = W * 0.15, W * 0.095
g.polygon(
    [
        (ex + ux * head, ey + uy * head),
        (ex - uy * half, ey + ux * half),
        (ex + uy * half, ey - ux * half),
    ],
    fill=ARROW,
)
soft = glow.filter(ImageFilter.GaussianBlur(W * 0.02))
img.paste(soft, (0, 0), soft)
img.paste(glow, (0, 0), glow)

tiles = [("2", 0xFF9484, 0xE8504F), ("4", 0x86F2BC, 0x2FBF7F), ("8", 0x66BEFF, 0x2B6FF0), ("16", 0xBE94FF, 0x7B3FF2)]
size = W * 0.29
gap = W * 0.035
x0 = (W - 2 * size - gap) / 2
for i, (label, c1, c2) in enumerate(tiles):
    x = x0 + (i % 2) * (size + gap)
    y = x0 + (i // 2) * (size + gap)
    r = size * 0.2
    # glow
    halo = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    ImageDraw.Draw(halo).rounded_rectangle([x, y, x + size, y + size], r, fill=hexrgb(c2) + (200,))
    halo = halo.filter(ImageFilter.GaussianBlur(size * 0.12))
    img.paste(halo, (0, 0), halo)
    # body gradient
    body = Image.new("RGB", (int(size), int(size)))
    bd = ImageDraw.Draw(body)
    for yy in range(int(size)):
        bd.line([(0, yy), (int(size), yy)], fill=lerp(hexrgb(c1), hexrgb(c2), yy / size))
    mask = Image.new("L", (int(size), int(size)), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, int(size) - 1, int(size) - 1], r, fill=255)
    img.paste(body, (int(x), int(y)), mask)
    # shine
    shine = Image.new("RGBA", (int(size), int(size)), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shine)
    for yy in range(int(size * 0.46)):
        alpha = int(105 * (1 - yy / (size * 0.46)))
        sd.line([(size * 0.07, size * 0.06 + yy), (size * 0.93, size * 0.06 + yy)], fill=(255, 255, 255, alpha))
    smask = Image.new("L", shine.size, 0)
    ImageDraw.Draw(smask).rounded_rectangle([size * 0.07, size * 0.06, size * 0.93, size * 0.52], r * 0.75, fill=255)
    shine.putalpha(Image.composite(shine.getchannel("A"), Image.new("L", shine.size, 0), smask))
    img.paste(shine, (int(x), int(y)), shine)
    # number
    f = font(int(size * (0.56 if len(label) == 1 else 0.48)))
    d = ImageDraw.Draw(img)
    box = d.textbbox((0, 0), label, font=f)
    tx = x + (size - (box[2] - box[0])) / 2 - box[0]
    ty = y + (size - (box[3] - box[1])) / 2 - box[1]
    d.text((tx + 3, ty + 5), label, font=f, fill=(0, 0, 0))
    d.text((tx, ty), label, font=f, fill=(255, 255, 255))

img.resize((S, S), Image.LANCZOS).save(sys.argv[1], "PNG")
