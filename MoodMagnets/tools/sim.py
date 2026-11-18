"""Python mirror of MoodMagnets/Core (Simulation.swift). Used to tune levels and find
solutions offline. Keep the two in lock-step: same constants, same order of operations."""
import json, math, sys, itertools, copy

DT = 1.0 / 120.0
ITER = 4
GRAVITY = -900.0
DRAG = 0.35
HAPPY_RANGE = 170.0
GRUMPY_RANGE = 150.0
HAPPY_ACCEL = 1100.0
GRUMPY_ACCEL = 1500.0
RESPONSE = {"happy": 1.0, "grumpy": 0.4, "nervous": 1.5}
MASS = {"happy": 1.0, "grumpy": 3.0, "nervous": 0.6}
RESTITUTION = 0.25
BOUNCY_RESTITUTION = 0.95
BOUNCE_MIN_SPEED = 60.0
FRICTION = 0.4
SLOP = 0.5
CORRECTION = 0.8
CHEER_TIME = 0.45
CONTACT_PAD = 4.0
SCARE_SPEED = 380.0
SCARE_LIFT = 420.0
SCARE_COOLDOWN = 0.8
SETTLE_SPEED = 30.0
WIN_HOLD = 0.6
FALL_Y = -60.0

class Body:
    def __init__(s, d, static):
        s.id = d["id"]; s.x, s.y = map(float, d["pos"]); s.vx = s.vy = 0.0
        s.r = float(d.get("r", 18.0 if static else 26.0)); s.mood = d["mood"]
        s.swappable = d.get("swappable", False); s.static = static
        s.range_scale = float(d.get("rangeScale", 1.0)); s.cool = 0.0; s.fallen = False

    def inv_mass(s):
        return 0.0 if s.static else 1.0 / MASS[s.mood]

class World:
    def __init__(s, level):
        s.level = level; s.t = 0.0
        s.width, s.height = level.get("size", [400, 720])
        s.g = float(level.get("gravity", GRAVITY))
        s.jellies = [Body(j, False) for j in level["jellies"]]
        s.pegs = [Body(p, True) for p in level.get("pegs", [])]
        s.segs = [(float(g["a"][0]), float(g["a"][1]), float(g["b"][0]), float(g["b"][1]),
                   float(g.get("r", 8.0)), bool(g.get("bouncy", False))) for g in level.get("segments", [])]
        s.nests = level["nests"]
        s.cheer = {}; s.win_timer = 0.0; s.won = False; s.failed = False; s.moves = 0
        s.events = []

    def find(s, ident):
        for b in s.jellies + s.pegs:
            if b.id == ident: return b
        return None

    def apply(s, ident, mood):
        b = s.find(ident)
        if b is None or not b.swappable or b.mood == mood: return False
        b.mood = mood; s.moves += 1; return True

    # --- forces -------------------------------------------------------------
    def accel(s, t):
        ax, ay = 0.0, s.g
        for src in s.jellies + s.pegs:
            if src is t or src.fallen: continue
            dx = src.x - t.x; dy = src.y - t.y; d = math.sqrt(dx*dx + dy*dy)
            if d < 1e-6: continue
            nx, ny = dx/d, dy/d
            if src.mood == "happy" and t.mood != "grumpy":
                rng = HAPPY_RANGE * src.range_scale
                if d < rng and d > src.r + t.r + 1.0:
                    m = HAPPY_ACCEL * (1.0 - d/rng) * RESPONSE[t.mood]
                    ax += nx*m; ay += ny*m
            elif src.mood == "grumpy":
                rng = GRUMPY_RANGE * src.range_scale
                if d < rng:
                    m = GRUMPY_ACCEL * (1.0 - d/rng) * RESPONSE[t.mood]
                    ax -= nx*m; ay -= ny*m
        return ax, ay

    # --- contacts ------------------------------------------------------------
    def solve(s, a, ax_, ay_, nx, ny, pen, inv_b, b, e_override=None):
        """Resolve contact for jelly a against b (b may be None = static point), normal from b to a."""
        inv_a = a.inv_mass(); tot = inv_a + inv_b
        if tot <= 0: return 0.0
        if pen > SLOP:
            c = (pen - SLOP) * CORRECTION / tot
            a.x += nx*c*inv_a; a.y += ny*c*inv_a
            if b is not None: b.x -= nx*c*inv_b; b.y -= ny*c*inv_b
        bvx = b.vx if b is not None else 0.0; bvy = b.vy if b is not None else 0.0
        rvx = a.vx - bvx; rvy = a.vy - bvy
        vn = rvx*nx + rvy*ny
        if vn >= 0: return 0.0
        e = e_override if e_override is not None else RESTITUTION
        if -vn < BOUNCE_MIN_SPEED and e_override is None: e = 0.0
        j = -(1.0 + e) * vn / tot
        a.vx += nx*j*inv_a; a.vy += ny*j*inv_a
        if b is not None: b.vx -= nx*j*inv_b; b.vy -= ny*j*inv_b
        tx, ty = -ny, nx
        vt = rvx*tx + rvy*ty
        jt = -vt / tot; lim = FRICTION * j
        if jt > lim: jt = lim
        if jt < -lim: jt = -lim
        a.vx += tx*jt*inv_a; a.vy += ty*jt*inv_a
        if b is not None: b.vx -= tx*jt*inv_b; b.vy -= ty*jt*inv_b
        return j

    def collide(s):
        J = s.jellies
        for _ in range(ITER):
            for i in range(len(J)):
                a = J[i]
                if a.fallen: continue
                for k in range(i+1, len(J)):
                    b = J[k]
                    if b.fallen: continue
                    dx = a.x-b.x; dy = a.y-b.y; d2 = dx*dx+dy*dy; rr = a.r+b.r
                    if d2 < rr*rr and d2 > 1e-9:
                        d = math.sqrt(d2); s.solve(a, 0, 0, dx/d, dy/d, rr-d, b.inv_mass(), b)
                for p in s.pegs:
                    dx = a.x-p.x; dy = a.y-p.y; d2 = dx*dx+dy*dy; rr = a.r+p.r
                    if d2 < rr*rr and d2 > 1e-9:
                        d = math.sqrt(d2); s.solve(a, 0, 0, dx/d, dy/d, rr-d, 0.0, None)
                for (x1, y1, x2, y2, r, bouncy) in s.segs:
                    ex = x2-x1; ey = y2-y1; L2 = ex*ex+ey*ey
                    u = ((a.x-x1)*ex + (a.y-y1)*ey)/L2 if L2 > 0 else 0.0
                    if u < 0: u = 0.0
                    if u > 1: u = 1.0
                    cx = x1+ex*u; cy = y1+ey*u
                    dx = a.x-cx; dy = a.y-cy; d2 = dx*dx+dy*dy; rr = a.r+r
                    if d2 < rr*rr and d2 > 1e-9:
                        d = math.sqrt(d2)
                        s.solve(a, 0, 0, dx/d, dy/d, rr-d, 0.0, None, BOUNCY_RESTITUTION if bouncy else None)
            # world walls (left, right, ceiling)
            for a in J:
                if a.fallen: continue
                if a.x < a.r:
                    a.x = a.r
                    if a.vx < 0: a.vx = -a.vx*RESTITUTION
                if a.x > s.width-a.r:
                    a.x = s.width-a.r
                    if a.vx > 0: a.vx = -a.vx*RESTITUTION
                if a.y > s.height-a.r:
                    a.y = s.height-a.r
                    if a.vy > 0: a.vy = -a.vy*RESTITUTION

    def moods(s):
        J = s.jellies
        for a in J:
            if a.cool > 0: a.cool -= DT
        for i in range(len(J)):
            for k in range(i+1, len(J)):
                a, b = J[i], J[k]
                if a.fallen or b.fallen: continue
                dx = a.x-b.x; dy = a.y-b.y; d = math.sqrt(dx*dx+dy*dy)
                touching = d <= a.r+b.r+CONTACT_PAD
                key = (a.id, b.id)
                pair = {a.mood, b.mood}
                if touching and pair == {"happy", "nervous"}:
                    s.cheer[key] = s.cheer.get(key, 0.0) + DT
                    if s.cheer[key] >= CHEER_TIME:
                        n = a if a.mood == "nervous" else b
                        n.mood = "happy"; s.cheer[key] = 0.0; s.events.append(("cheer", n.id))
                else:
                    s.cheer[key] = 0.0
                if touching and pair == {"grumpy", "nervous"} and d > 1e-6:
                    n, g = (a, b) if a.mood == "nervous" else (b, a)
                    if n.cool <= 0:
                        nx = (n.x-g.x)/d; ny = (n.y-g.y)/d
                        n.vx += nx*SCARE_SPEED; n.vy += ny*SCARE_SPEED + SCARE_LIFT
                        n.cool = SCARE_COOLDOWN; s.events.append(("scare", n.id))
        for a in J:
            for p in s.pegs:
                if a.fallen: continue
                key = (a.id, p.id)
                dx = a.x-p.x; dy = a.y-p.y; d = math.sqrt(dx*dx+dy*dy)
                touching = d <= a.r+p.r+CONTACT_PAD
                if touching and a.mood == "nervous" and p.mood == "happy":
                    s.cheer[key] = s.cheer.get(key, 0.0) + DT
                    if s.cheer[key] >= CHEER_TIME:
                        a.mood = "happy"; s.cheer[key] = 0.0; s.events.append(("cheer", a.id))
                else:
                    s.cheer[key] = 0.0
                if a.mood == "nervous" and p.mood == "grumpy":
                    if touching and a.cool <= 0 and d > 1e-6:
                        a.vx += dx/d*SCARE_SPEED; a.vy += dy/d*SCARE_SPEED + SCARE_LIFT
                        a.cool = SCARE_COOLDOWN; s.events.append(("scare", a.id))

    def nests_ok(s):
        for n in s.nests:
            x, y, w, h = n["rect"]; want = n.get("mood")
            count = 0
            for a in s.jellies:
                if a.fallen: continue
                if x <= a.x <= x+w and y <= a.y <= y+h and (want is None or a.mood == want):
                    if math.sqrt(a.vx*a.vx+a.vy*a.vy) < SETTLE_SPEED: count += 1
            if count < n.get("count", 1): return False
        return True

    def step(s):
        if s.won or s.failed: return
        acc = [s.accel(a) for a in s.jellies]
        for a, (ax, ay) in zip(s.jellies, acc):
            if a.fallen: continue
            a.vx += ax*DT; a.vy += ay*DT
            k = 1.0 - DRAG*DT; a.vx *= k; a.vy *= k
            a.x += a.vx*DT; a.y += a.vy*DT
        s.collide()
        s.moods()
        for a in s.jellies:
            if not a.fallen and a.y < FALL_Y:
                a.fallen = True; s.failed = True; s.events.append(("fall", a.id))
        s.t += DT
        if not s.failed and s.nests_ok():
            s.win_timer += DT
            if s.win_timer >= WIN_HOLD: s.won = True
        else:
            s.win_timer = 0.0

def run(level, actions, max_t=12.0, trace=False):
    w = World(level); acts = sorted(actions, key=lambda a: a["t"]); i = 0
    steps = int(round(max_t / DT))
    for n in range(steps):
        while i < len(acts) and acts[i]["t"] <= w.t + 1e-9:
            w.apply(acts[i]["target"], acts[i]["mood"]); i += 1
        w.step()
        if trace and n % 60 == 0:
            print(f"t={w.t:5.2f} " + " ".join(f"{a.id}:{a.mood[0]}({a.x:.0f},{a.y:.0f})" for a in w.jellies))
        if w.won or w.failed: break
    return w

def load(path):
    with open(path) as f: return json.load(f)["levels"]
