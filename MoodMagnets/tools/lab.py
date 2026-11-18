import sys, json
from sim import *
FLOOR = {"a":[0,40],"b":[400,40],"r":8}
def show(level, actions, max_t=10):
    w = run(level, [], max_t)
    print(level["name"], "| no-action:", "WON" if w.won else ("FELL" if w.failed else "-"), f"t={w.t:.2f}", [(a.id,a.mood,round(a.x),round(a.y)) for a in w.jellies])
    w = run(level, actions, max_t, trace=True)
    print("  solution:", "WON" if w.won else ("FELL" if w.failed else "-"), f"t={w.t:.2f} moves={w.moves}", [(a.id,a.mood,round(a.x),round(a.y)) for a in w.jellies], w.events[:6])
