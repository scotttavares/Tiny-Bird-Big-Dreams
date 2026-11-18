"""Exhaustive search for the fewest mood changes that solve a level.
Usage: python3 solve.py ../MoodMagnets/Resources/levels.json [levelId ...]"""
import copy, sys, json
from sim import *

TIMES = [0.0, 0.75, 1.5, 2.5, 3.5]
HORIZON = 12.0

def advance(w, until):
    while w.t + 1e-9 < until and not (w.won or w.failed):
        w.step()

def finish(w):
    advance(w, HORIZON)
    return w.won

def search(level, max_moves):
    palette = level.get("palette", ["happy", "grumpy", "nervous"])
    best = None
    def rec(w, ti, path):
        nonlocal best
        if best is not None and len(path) >= len(best): return
        # option: no more actions
        w2 = copy.deepcopy(w)
        if finish(w2):
            best = list(path); return
        if len(path) >= max_moves: return
        for i in range(ti, len(TIMES)):
            base = copy.deepcopy(w); advance(base, TIMES[i])
            if base.won or base.failed: break
            for b in base.jellies + base.pegs:
                if not b.swappable or b.fallen: continue
                for m in palette:
                    if m == b.mood: continue
                    w3 = copy.deepcopy(base); w3.apply(b.id, m)
                    rec(w3, i + 1, path + [{"t": TIMES[i], "target": b.id, "mood": m}])
    rec(World(level), 0, [])
    return best

if __name__ == "__main__":
    levels = load(sys.argv[1]); only = set(sys.argv[2:])
    for L in levels:
        if only and str(L["id"]) not in only: continue
        idle = run(L, [], HORIZON)
        sol = run(L, L.get("solution", []), HORIZON)
        found = search(L, L.get("par", 1))
        print(f'{L["id"]:>2} {L["name"]:<22} idle={"WON!!" if idle.won else ("fell" if idle.failed else "no")}'
              f' scripted={"WON" if sol.won else "FAIL"}@{sol.t:.2f}s moves={sol.moves} par={L.get("par")}'
              f' min={len(found) if found is not None else ">par"} {found if found is not None and len(found) < L.get("par",1) else ""}')
