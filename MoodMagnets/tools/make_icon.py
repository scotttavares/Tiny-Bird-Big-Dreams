"""Renders the App Store icon (1024x1024, opaque) to the asset catalog."""
from PIL import Image, ImageDraw, ImageFilter
import math, os, sys
S = 2048
def lerp(a, b, t): return tuple(int(a[i] + (b[i]-a[i])*t) for i in range(3))
def hexc(h): return ((h>>16)&255, (h>>8)&255, h&255)
MOODS = {"happy": (0xFFF3B0, 0xFFC83D, 0xF0861C), "grumpy": (0xFFB8C6, 0xF2546B, 0xB0233F), "nervous": (0xCBFFF4, 0x4FD5C1, 0x17958A)}
INK = hexc(0x3A2440)

def background():
    img = Image.new("RGB", (S, S))
    top, mid, bot = hexc(0xC9B8FF), hexc(0xFFC7D9), hexc(0xFFE7C2)
    d = ImageDraw.Draw(img)
    for y in range(S):
        t = y / (S-1)
        c = lerp(top, mid, t/0.55) if t < 0.55 else lerp(mid, bot, (t-0.55)/0.45)
        d.line([(0, y), (S, y)], fill=c)
    glow = Image.new("L", (S, S), 0); gd = ImageDraw.Draw(glow)
    gd.ellipse([S*0.45, -S*0.2, S*1.2, S*0.5], fill=150)
    glow = glow.filter(ImageFilter.GaussianBlur(S*0.08))
    img.paste(Image.new("RGB", (S, S), (255, 255, 255)), (0, 0), glow)
    return img

def jelly(img, cx, cy, r, mood):
    light, base, deep = (hexc(c) for c in MOODS[mood])
    # shadow
    sh = Image.new("L", (S, S), 0); sd = ImageDraw.Draw(sh)
    sd.ellipse([cx-r*0.95, cy+r*0.78, cx+r*0.95, cy+r*1.12], fill=110)
    sh = sh.filter(ImageFilter.GaussianBlur(r*0.08))
    img.paste(Image.new("RGB", (S, S), INK), (0, 0), sh)
    # body radial gradient
    body = Image.new("RGB", (S, S)); mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(mask).ellipse([cx-r, cy-r, cx+r, cy+r], fill=255)
    bd = ImageDraw.Draw(body)
    hx, hy = cx - r*0.28, cy - r*0.38
    steps = 160
    for i in range(steps, 0, -1):
        t = i / steps; rr = r*1.45*t
        c = lerp(light, base, t/0.45) if t < 0.45 else lerp(base, deep, (t-0.45)/0.55)
        ox = hx + (cx-hx)*t; oy = hy + (cy-hy)*t
        bd.ellipse([ox-rr, oy-rr, ox+rr, oy+rr], fill=c)
    # subsurface glow
    glow = Image.new("L", (S, S), 0)
    ImageDraw.Draw(glow).ellipse([cx-r*0.55, cy+r*0.2, cx+r*0.75, cy+r*0.95], fill=140)
    glow = glow.filter(ImageFilter.GaussianBlur(r*0.18))
    body.paste(Image.new("RGB", (S, S), light), (0, 0), glow)
    # rim
    rim = Image.new("L", (S, S), 0)
    ImageDraw.Draw(rim).ellipse([cx-r, cy-r, cx+r, cy+r], outline=120, width=int(r*0.09))
    rim = rim.filter(ImageFilter.GaussianBlur(r*0.03))
    body.paste(Image.new("RGB", (S, S), deep), (0, 0), rim)
    img.paste(body, (0, 0), mask)
    # specular
    spec = Image.new("L", (S, S), 0); spd = ImageDraw.Draw(spec)
    spd.ellipse([cx-r*0.62, cy-r*0.68, cx-r*0.02, cy-r*0.36], fill=225)
    spec = spec.rotate(26, center=(cx-r*0.32, cy-r*0.52)).filter(ImageFilter.GaussianBlur(r*0.025))
    spd2 = ImageDraw.Draw(spec); spd2.ellipse([cx+r*0.2, cy-r*0.62, cx+r*0.34, cy-r*0.48], fill=180)
    img.paste(Image.new("RGB", (S, S), (255, 255, 255)), (0, 0), spec)
    face(img, cx, cy, r, mood)

def face(img, cx, cy, r, mood):
    d = ImageDraw.Draw(img)
    P = lambda x, y: (cx + x*r, cy - y*r)
    w = int(r*0.085)
    ex, ey = 0.3, 0.12
    def eyes(size, pupil, y):
        for s in (-1, 1):
            x0, y0 = P(s*ex, y)
            d.ellipse([x0-r*size/2, y0-r*size*0.575, x0+r*size/2, y0+r*size*0.575], fill=(255, 255, 255), outline=INK, width=max(2, int(r*0.015)))
            d.ellipse([x0-r*pupil, y0-r*pupil, x0+r*pupil, y0+r*pupil], fill=INK)
            d.ellipse([x0+r*pupil*0.1, y0-r*pupil*0.75, x0+r*pupil*0.8, y0-r*pupil*0.05], fill=(255, 255, 255))
    if mood == "happy":
        for s in (-1, 1):
            x0, y0 = P(s*ex, ey-0.04)
            d.arc([x0-r*0.13, y0-r*0.13, x0+r*0.13, y0+r*0.13], 200, 340, fill=INK, width=w)
            c0 = P(s*0.52, -0.08)
            blush = Image.new("L", (S, S), 0)
            ImageDraw.Draw(blush).ellipse([c0[0]-r*0.15, c0[1]-r*0.08, c0[0]+r*0.15, c0[1]+r*0.08], fill=120)
            img.paste(Image.new("RGB", (S, S), hexc(0xFF6F91)), (0, 0), blush.filter(ImageFilter.GaussianBlur(r*0.02)))
        d = ImageDraw.Draw(img)
        pts = [P(-0.22, -0.1)] + [P(-0.22 + 0.44*i/30, -0.1 - 0.36*math.sin(math.pi*i/30)) for i in range(31)]
        d.polygon(pts, fill=hexc(0x6B2A3A), outline=INK)
        tx, ty = P(0, -0.33); d.ellipse([tx-r*0.1, ty-r*0.06, tx+r*0.1, ty+r*0.05], fill=hexc(0xFF7A8A))
    elif mood == "grumpy":
        eyes(0.2, 0.075, ey-0.02)
        for s in (-1, 1):
            d.line([P(s*(ex+0.17), ey+0.21), P(s*(ex-0.14), ey+0.07)], fill=INK, width=int(r*0.09))
        pts = [P(-0.17 + 0.34*i/30, -0.3 + 0.13*math.sin(math.pi*i/30)) for i in range(31)]
        d.line(pts, fill=INK, width=int(r*0.08), joint="curve")
    else:
        eyes(0.27, 0.06, ey)
        pts = [P(-0.2 + 0.4*i/40, -0.24 + 0.04*math.sin(i/40*math.pi*4)) for i in range(41)]
        d.line(pts, fill=INK, width=int(r*0.06), joint="curve")
        x0, y0 = P(0.62, 0.46)
        d.polygon([(x0, y0-r*0.12), (x0+r*0.08, y0+r*0.03), (x0, y0+r*0.08), (x0-r*0.08, y0+r*0.03)], fill=hexc(0xBDEBFF))
        d.ellipse([x0-r*0.08, y0-r*0.03, x0+r*0.08, y0+r*0.1], fill=hexc(0xBDEBFF))

img = background()
jelly(img, S*0.215, S*0.63, S*0.175, "grumpy")
jelly(img, S*0.785, S*0.63, S*0.175, "nervous")
jelly(img, S*0.5, S*0.5, S*0.235, "happy")
out = img.resize((1024, 1024), Image.LANCZOS)
dest = sys.argv[1]
os.makedirs(os.path.dirname(dest), exist_ok=True)
out.save(dest)
print("saved", dest, out.mode, out.size)
