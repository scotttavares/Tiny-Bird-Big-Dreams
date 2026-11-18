"""Writes the game's sound effects as small WAV files.

Run from the FlipFusion folder:  python scripts/make-sounds.py
Everything is synthesised here, so there are no audio files to license.
"""

import math
import os
import random
import struct
import wave

RATE = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "FlipFusion", "Resources", "Sounds")


def write(name, samples):
    peak = max(0.001, max(abs(s) for s in samples))
    scale = min(1.0, 0.9 / peak)
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(b"".join(struct.pack("<h", int(s * scale * 32767)) for s in samples))


def bell(freq, seconds, decay=9.0):
    """A soft bell: the note, an octave above it, and a quick attack."""
    out = []
    for i in range(int(RATE * seconds)):
        t = i / RATE
        attack = min(1.0, t / 0.004)
        env = attack * math.exp(-decay * t)
        out.append(env * (math.sin(2 * math.pi * freq * t)
                          + 0.35 * math.sin(2 * math.pi * freq * 2 * t)
                          + 0.12 * math.sin(2 * math.pi * freq * 3 * t)))
    return out


def sweep(f0, f1, seconds, decay=0.0):
    out = []
    phase = 0.0
    n = int(RATE * seconds)
    for i in range(n):
        t = i / n
        freq = f0 + (f1 - f0) * t
        phase += 2 * math.pi * freq / RATE
        env = math.sin(math.pi * t) if decay == 0 else math.exp(-decay * t) * min(1.0, i / 80)
        out.append(env * math.sin(phase))
    return out


def join(parts, overlap=0.0):
    out = []
    for part in parts:
        start = max(0, len(out) - int(RATE * overlap))
        for i, s in enumerate(part):
            if start + i < len(out):
                out[start + i] += s
            else:
                out.append(s)
    return out


def whoosh(seconds):
    random.seed(4)
    out = []
    low = 0.0
    n = int(RATE * seconds)
    tone = sweep(170, 560, seconds)
    for i in range(n):
        t = i / n
        cutoff = 0.02 + 0.22 * math.sin(math.pi * t)
        low += cutoff * (random.uniform(-1, 1) - low)
        out.append(math.sin(math.pi * t) * (0.9 * low + 0.35 * tone[i]))
    return out


# A swipe: a short downward blip.
write("slide", sweep(520, 300, 0.07, decay=5.0))

# Merges climb a pentatonic scale as the tiles get bigger.
for index, freq in enumerate([523.25, 587.33, 659.25, 783.99, 880.0, 1046.5], start=1):
    write("merge%d" % index, join([sweep(freq * 0.7, freq, 0.03, decay=1.0), bell(freq, 0.32)], overlap=0.01))

# The board turning.
write("rotate", whoosh(0.5))

# A chain reaction: a quick rising arpeggio.
write("chain", join([bell(f, 0.3, decay=8.0) for f in (523.25, 659.25, 783.99, 1046.5)], overlap=0.22))

# The last ten seconds.
write("tick", bell(1318.5, 0.07, decay=45.0))

# Game over: three notes falling.
write("over", join([bell(f, 0.42, decay=6.0) for f in (392.0, 329.63, 261.63)], overlap=0.24))

# New game: two notes rising.
write("start", join([bell(f, 0.28, decay=9.0) for f in (523.25, 783.99)], overlap=0.18))

# A bomb tile: a low thump with a burst of noise.
def boom(seconds):
    random.seed(9)
    out = []
    low = 0.0
    phase = 0.0
    n = int(RATE * seconds)
    for i in range(n):
        t = i / n
        phase += 2 * math.pi * (150 - 100 * t) / RATE
        low += 0.25 * (random.uniform(-1, 1) - low)
        out.append(math.exp(-6 * t) * (math.sin(phase) + 0.8 * low))
    return out

write("boom", boom(0.5))

# A clock tile: three quick bright notes.
write("bonus", join([bell(f, 0.22, decay=10.0) for f in (880.0, 1108.73, 1318.5)], overlap=0.15))

print("Wrote sounds to", os.path.normpath(OUT))
