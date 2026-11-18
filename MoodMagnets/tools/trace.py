import sys
from sim import *; from levels_src import LEVELS
def trace(idx, every=8, n=300, idn=0, acts=None):
    L=LEVELS[idx]; L.setdefault('pegs',[])
    w=World(L)
    for a in (acts if acts is not None else L['solution']):
        if a['t']==0: w.apply(a['target'],a['mood'])
    for k in range(n):
        w.step()
        if k%every==0:
            print(f'{w.t:.2f} '+' '.join(f'{b.id}:{b.mood[0]}({b.x:.0f},{b.y:.0f}) v=({b.vx:.0f},{b.vy:.0f})' for b in w.jellies))
        if w.won: print('WON', w.t); break
if __name__=='__main__': trace(int(sys.argv[1]))
