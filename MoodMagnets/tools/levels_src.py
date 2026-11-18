"""Source of truth for level design. Run to write ../MoodMagnets/Resources/levels.json."""
import json, os
F = lambda y=40, x1=0, x2=400, **k: dict(a=[x1, y], b=[x2, y], r=8, **k)
def seg(x1, y1, x2, y2, r=8, **k): return dict(a=[x1, y1], b=[x2, y2], r=r, **k)
def J(i, x, y, mood, swap=False, r=26): return dict(id=i, pos=[x, y], mood=mood, swappable=swap, r=r)
def P(i, x, y, mood, swap=False, r=18, rangeScale=1.0): return dict(id=i, pos=[x, y], mood=mood, swappable=swap, r=r, rangeScale=rangeScale)
def N(x, y, w, h, mood=None, count=1): return dict(rect=[x, y, w, h], mood=mood, count=count)
def A(t, target, mood): return dict(t=t, target=target, mood=mood)
REST = 74  # centre height of a jelly resting on the y=40 floor

LEVELS = [
 dict(id=1, name="Say Cheese", par=1, palette=["happy"],
      hint="Choose a mood below, then tap a jelly to give it that mood. This nest wants a Happy jelly.",
      segments=[F()], jellies=[J("pip", 200, REST, "nervous", True)],
      nests=[N(130, 40, 140, 70, "happy")],
      solution=[A(0, "pip", "happy")]),
 dict(id=2, name="Hug It Out", par=1, palette=["happy", "nervous"],
      hint="Happy jellies pull Nervous ones close. A long enough hug cheers a Nervous jelly up.",
      segments=[F()], jellies=[J("sunny", 150, REST, "happy"), J("wib", 270, REST, "grumpy", True)],
      nests=[N(100, 40, 70, 70, "happy"), N(170, 40, 70, 70, "happy")],
      solution=[A(0, "wib", "nervous")]),
 dict(id=3, name="Grumpy Shove", par=1, palette=["happy", "grumpy"],
      hint="Grumpy jellies push everyone away. Nervous jellies are pushed hardest.",
      segments=[F(), seg(0, 300, 200, 300)],
      jellies=[J("dot", 150, 334, "nervous"), J("mug", 60, 334, "nervous", True)],
      nests=[N(220, 40, 180, 70, "nervous")],
      solution=[A(0, "mug", "grumpy")]),
 dict(id=4, name="Domino Hugs", par=1, palette=["happy", "grumpy"],
      hint="Cheer one jelly up and watch the happiness travel down the line.",
      segments=[F()],
      jellies=[J("a", 40, REST, "grumpy", True), J("b", 105, REST, "nervous"),
               J("c", 170, REST, "nervous"), J("d", 235, REST, "nervous")],
      nests=[N(0, 40, 90, 70, "happy"), N(140, 40, 260, 70, "happy")],
      solution=[A(0, "a", "happy")]),
 dict(id=5, name="Scaredy Hop", par=1, palette=["happy", "nervous"],
      hint="A Nervous jelly that bumps into anything Grumpy jumps away in fright.",
      segments=[F(), seg(230, 40, 230, 140)],
      pegs=[P("grr", 80, 48, "grumpy")],
      jellies=[J("hop", 114, REST, "happy", True)],
      nests=[N(250, 40, 150, 70, "nervous")],
      solution=[A(0, "hop", "nervous")]),
 dict(id=6, name="Springy Pad", par=1, palette=["happy", "grumpy"],
      hint="Bouncy pads fling jellies high. Give someone a push.",
      segments=[F(), seg(0, 220, 100, 220), seg(160, 60, 300, 60, bouncy=True), seg(320, 40, 320, 170)],
      jellies=[J("fizz", 75, 254, "nervous"), J("mo", 24, 252, "nervous", True, r=24)],
      nests=[N(328, 40, 72, 70, "nervous")],
      solution=[A(0, "mo", "grumpy")]),
 dict(id=7, name="Mood Stones", par=1, palette=["happy", "grumpy"],
      hint="Stones with a ring can change mood too. A Happy stone gives the best hugs.",
      segments=[F()], pegs=[P("stone", 200, 130, "grumpy", True)],
      jellies=[J("tum", 290, REST, "nervous")],
      nests=[N(140, 40, 120, 70, "happy")],
      solution=[A(0, "stone", "happy")]),
 dict(id=8, name="Hop and Cheer", par=2, palette=["happy", "nervous"],
      hint="Two moods, one jelly. Scare it up, then cheer it up.",
      segments=[F(), seg(250, 200, 400, 200), seg(250, 200, 250, 40)],
      pegs=[P("grr", 60, 48, "grumpy")],
      jellies=[J("bop", 94, REST, "happy", True)],
      nests=[N(270, 200, 130, 70, "happy")],
      solution=[A(0, "bop", "nervous"), A(1.5, "bop", "happy")]),
 dict(id=9, name="Shelf Party", par=2, palette=["happy", "grumpy", "nervous"],
      hint="Clear the shelf, then get the party started on the floor.",
      segments=[F(), seg(0, 260, 170, 260)],
      pegs=[P("stone", 25, 310, "nervous", True)],
      jellies=[J("ziggy", 70, 294, "nervous", True), J("zag", 130, 294, "nervous")],
      nests=[N(190, 40, 210, 70, "happy", count=2)],
      solution=[A(0, "stone", "grumpy"), A(2.5, "ziggy", "happy")]),
 dict(id=10, name="The Valley", par=2, palette=["happy", "grumpy", "nervous"],
      hint="Two sides, one gap. Sometimes it's the moods that need to swap, not the jellies.",
      segments=[seg(0, 200, 160, 200), seg(230, 200, 400, 200)],
      jellies=[J("sol", 80, 234, "happy", True), J("nim", 300, 234, "nervous"), J("kip", 374, 234, "nervous", True)],
      nests=[N(0, 200, 160, 70, "nervous"), N(230, 200, 170, 70, "happy", count=2)],
      solution=[A(0, "kip", "happy"), A(0, "sol", "nervous")]),
]

if __name__ == "__main__":
    out = os.path.join(os.path.dirname(__file__), "..", "MoodMagnets", "Resources", "levels.json")
    for L in LEVELS:
        L.setdefault("pegs", []); L.setdefault("size", [400, 720])
    with open(out, "w") as f:
        json.dump({"version": 1, "levels": LEVELS}, f, indent=1)
    print("wrote", len(LEVELS), "levels")
