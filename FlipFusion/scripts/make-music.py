"""Composes the game's background music as three looping WAV files.

Run from the FlipFusion folder:  python scripts/make-music.py

  music.wav          the timed game: a 45-second arcade tune
  music-endless.wav  the endless game: slower and mellower
  music-rush.wav     double points and the last seconds of a timed game: fast

Every tune is written out note by note below and synthesised here (square-wave
lead, pulse arpeggio, triangle bass, noise drums), so there is no audio to license.
"""

import math
import os
import random
import struct
import wave

RATE = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "FlipFusion", "Resources", "Sounds")


def hz(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


def pulse(phase, duty):
    return 1.0 if (phase % 1.0) < duty else -1.0


def triangle(phase):
    p = phase % 1.0
    return 4 * p - 1 if p < 0.5 else 3 - 4 * p


# A chord is (bass root, the three notes of the arpeggio).
AM = (45, (69, 72, 76))
A7 = (45, (64, 69, 73))
BB = (46, (62, 65, 70))
C = (48, (64, 67, 72))
DM = (38, (62, 65, 69))
E = (40, (64, 68, 71))
F = (41, (65, 69, 72))
G = (43, (62, 67, 71))
GM = (43, (62, 67, 70))

# Each bar: (chord, eight eighth-note melody slots; None holds or rests).

# --- The timed game -------------------------------------------------------
TIMED_A = [
    (AM, [76, None, 81, None, 79, 76, None, None]),
    (F, [77, None, 81, None, 84, 81, None, None]),
    (C, [79, None, 76, None, 79, 84, None, None]),
    (G, [83, 81, 79, None, 74, None, 79, None]),
    (AM, [81, None, 84, None, 88, 84, 81, None]),
    (F, [81, None, 77, None, 81, 84, None, None]),
    (C, [79, 76, 79, 84, None, 79, 76, None]),
    (E, [76, None, 80, None, 83, None, 88, None]),
]
# The second part answers the first: its two phrases swapped, ending on G.
TIMED_B = TIMED_A[4:7] + [(G, [83, None, 79, None, 74, 79, 83, None])] + TIMED_A[0:4]
# A bridge that climbs, then falls back onto A minor for the loop.
TIMED_C = [
    (F, [72, None, 77, None, 81, None, 77, None]),
    (G, [74, None, 79, None, 83, None, 79, None]),
    (AM, [76, None, 81, None, 84, 81, None, None]),
    (AM, [84, 81, 76, None, 81, None, 76, None]),
    (F, [77, None, 81, None, 84, None, 89, None]),
    (G, [79, None, 83, None, 86, None, 91, None]),
    (C, [88, None, 84, None, 79, 84, 88, None]),
    (E, [88, None, 83, None, 80, None, 76, None]),
]

# --- The endless game -----------------------------------------------------
ENDLESS_A = [
    (DM, [69, None, None, 74, None, 72, 69, None]),
    (BB, [70, None, None, 74, None, 70, 65, None]),
    (F, [69, None, 72, None, 77, None, 72, None]),
    (C, [76, None, 72, None, 67, None, 72, None]),
    (DM, [74, None, 77, None, 76, 74, None, None]),
    (BB, [74, None, 70, None, 74, 77, None, None]),
    (F, [72, 69, 72, 77, None, 72, 69, None]),
    (C, [72, None, 76, None, 79, None, 76, None]),
]
ENDLESS_B = [
    (GM, [70, None, 74, None, 79, None, 74, None]),
    (DM, [77, None, 74, None, 69, None, 74, None]),
    (BB, [74, 72, 70, None, 65, None, 70, None]),
    (C, [72, None, 67, None, 72, 76, None, None]),
    (GM, [79, None, 77, None, 74, 70, None, None]),
    (DM, [77, None, 81, None, 77, 74, None, None]),
    (BB, [77, 74, 70, 74, None, 70, 65, None]),
    (A7, [73, None, 76, None, 81, None, 76, None]),
]

# --- The rush ---------------------------------------------------------------
RUSH_A = [
    (AM, [69, 69, 72, 69, 76, None, 72, 69]),
    (AM, [69, None, 72, 76, None, 72, 69, None]),
    (F, [72, 72, 69, 72, 77, None, 72, 69]),
    (G, [71, None, 74, 79, None, 74, 71, None]),
    (AM, [76, 76, 72, 76, 81, None, 76, 72]),
    (C, [79, None, 76, 72, None, 76, 79, None]),
    (F, [77, 76, 72, 69, 72, 76, 77, None]),
    (E, [76, None, 80, None, 83, 80, 76, None]),
]
RUSH_B = RUSH_A[4:7] + [(G, [79, None, 74, 71, None, 74, 79, None])] + RUSH_A[0:3] + [RUSH_A[7]]


def render(name, bpm, song, drive=False, soft=False, seed=11):
    """Writes one tune. `drive` is the fast style (running bass, a kick on every
    beat); `soft` is the mellow one (rounder lead, lighter drums)."""
    beat = 60.0 / bpm
    eighth = beat / 2
    sixteenth = beat / 4
    bar = beat * 4
    total = int(round(len(song) * bar * RATE))
    mix = [0.0] * total
    random.seed(seed)

    def add_note(start, length, freq, voice, volume):
        first = int(start * RATE)
        for i in range(int(length * RATE)):
            index = first + i
            if index >= total:
                break
            t = i / RATE
            attack = min(1.0, t / 0.004)
            release = min(1.0, (length - t) / 0.02)
            phase = freq * t
            if voice == "lead":
                # A little vibrato and a decay to a held level.
                phase += 0.004 * freq * math.sin(2 * math.pi * 6 * t) / (2 * math.pi)
                sample = pulse(phase, 0.5 if soft else 0.25) * (0.55 + 0.45 * math.exp(-6 * t))
            elif voice == "arp":
                sample = pulse(phase, 0.125) * math.exp(-9 * t)
            else:
                sample = triangle(phase)
            mix[index] += volume * attack * release * sample

    def add_kick(start, volume):
        first = int(start * RATE)
        phase = 0.0
        for i in range(int(0.16 * RATE)):
            index = first + i
            if index >= total:
                break
            t = i / RATE
            phase += (45 + 110 * math.exp(-30 * t)) / RATE
            mix[index] += volume * math.exp(-14 * t) * math.sin(2 * math.pi * phase)

    def add_noise(start, length, decay, volume, bright):
        first = int(start * RATE)
        last = 0.0
        for i in range(int(length * RATE)):
            index = first + i
            if index >= total:
                break
            t = i / RATE
            white = random.uniform(-1, 1)
            # Hats keep only the fizz; the snare keeps the body too.
            sample = white - last if bright else white
            last = white
            mix[index] += volume * math.exp(-decay * t) * sample

    for bar_index, ((root, chord), melody) in enumerate(song):
        bar_start = bar_index * bar

        # Bass: eighth notes jumping the octave, or running sixteenths when driving.
        if drive:
            for step in range(16):
                note = root + (12 if step % 4 == 2 else 0)
                add_note(bar_start + step * sixteenth, sixteenth * 0.8, hz(note), "bass", 0.30)
        else:
            for step in range(8):
                note = root + (12 if step % 2 else 0)
                add_note(bar_start + step * eighth, eighth * 0.85, hz(note), "bass", 0.30)

        # Arpeggio: sixteenth notes running up and down the chord (eighths when soft).
        pattern = [0, 1, 2, 1]
        if soft:
            for step in range(8):
                note = chord[pattern[step % 4]]
                add_note(bar_start + step * eighth, eighth * 0.9, hz(note), "arp", 0.075)
        else:
            for step in range(16):
                note = chord[pattern[step % 4]] + (12 if (step // 4) % 2 else 0)
                add_note(bar_start + step * sixteenth, sixteenth * 0.9, hz(note), "arp", 0.085)

        # Lead melody.
        step = 0
        while step < 8:
            note = melody[step]
            if note is None:
                step += 1
                continue
            held = 1
            while step + held < 8 and melody[step + held] is None:
                held += 1
            length = min(held, 3) * eighth * 0.92
            add_note(bar_start + step * eighth, length, hz(note), "lead", 0.13 if soft else 0.17)
            step += held

        # Drums.
        for b in range(4):
            beat_start = bar_start + b * beat
            if drive:
                # A kick on every beat, a snare on 2 and 4, hats on every sixteenth.
                add_kick(beat_start, 0.6)
                if b % 2 == 1:
                    add_noise(beat_start, 0.12, 24, 0.22, bright=False)
                for s in range(4):
                    add_noise(beat_start + s * sixteenth, 0.03, 90, 0.06 if s % 2 else 0.09, bright=True)
            else:
                # Kick on 1 and 3, snare on 2 and 4, hats on every eighth.
                if b % 2 == 0:
                    add_kick(beat_start, 0.4 if soft else 0.55)
                else:
                    add_noise(beat_start, 0.14, 22, 0.13 if soft else 0.22, bright=False)
                    if not soft:
                        add_note(beat_start, 0.06, 190, "bass", 0.12)
                add_noise(beat_start, 0.04, 80, 0.05 if soft else 0.07, bright=True)
                add_noise(beat_start + eighth, 0.05, 60, 0.06 if soft else 0.10, bright=True)
        if not soft:
            add_kick(bar_start + 3.5 * beat, 0.35)

    peak = max(abs(s) for s in mix)
    scale = 0.85 / peak
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(b"".join(struct.pack("<h", int(s * scale * 32767)) for s in mix))
    print("Wrote %.1f seconds to %s" % (total / RATE, os.path.normpath(path)))


render("music", 128, TIMED_A + TIMED_B + TIMED_C)
render("music-endless", 104, ENDLESS_A + ENDLESS_B, soft=True, seed=12)
render("music-rush", 156, RUSH_A + RUSH_B, drive=True, seed=13)
