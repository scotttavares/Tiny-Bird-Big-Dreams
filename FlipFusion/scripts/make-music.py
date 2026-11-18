"""Composes the game's background music: a 30-second arcade loop, written as a WAV.

Run from the FlipFusion folder:  python scripts/make-music.py
The tune is written out note by note below and synthesised here (square-wave lead,
pulse arpeggio, triangle bass, noise drums), so there is no audio to license.
"""

import math
import os
import random
import struct
import wave

RATE = 22050
BPM = 128
BEAT = 60.0 / BPM
EIGHTH = BEAT / 2
SIXTEENTH = BEAT / 4
BAR = BEAT * 4
OUT = os.path.join(os.path.dirname(__file__), "..", "FlipFusion", "Resources", "Sounds", "music.wav")


def hz(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


def pulse(phase, duty):
    return 1.0 if (phase % 1.0) < duty else -1.0


def triangle(phase):
    p = phase % 1.0
    return 4 * p - 1 if p < 0.5 else 3 - 4 * p


# Each bar: (bass root, the three chord notes for the arpeggio, eight eighth-note
# melody slots; None holds or rests).
AM = (45, (69, 72, 76))
F = (41, (65, 69, 72))
C = (48, (64, 67, 72))
G = (43, (62, 67, 71))
E = (40, (64, 68, 71))

SECTION_A = [
    (AM, [76, None, 81, None, 79, 76, None, None]),
    (F, [77, None, 81, None, 84, 81, None, None]),
    (C, [79, None, 76, None, 79, 84, None, None]),
    (G, [83, 81, 79, None, 74, None, 79, None]),
    (AM, [81, None, 84, None, 88, 84, 81, None]),
    (F, [81, None, 77, None, 81, 84, None, None]),
    (C, [79, 76, 79, 84, None, 79, 76, None]),
    (E, [76, None, 80, None, 83, None, 88, None]),
]
# The second half answers the first: its two phrases swapped, ending on G so the
# loop falls back onto A minor.
SECTION_B = SECTION_A[4:7] + [(G, [83, None, 79, None, 74, 79, 83, None])] + SECTION_A[0:4]
SONG = SECTION_A + SECTION_B

total = int(round(len(SONG) * BAR * RATE))
mix = [0.0] * total


def add_note(start, length, freq, voice, volume):
    first = int(start * RATE)
    count = int(length * RATE)
    for i in range(count):
        index = first + i
        if index >= total:
            break
        t = i / RATE
        attack = min(1.0, t / 0.004)
        release = min(1.0, (length - t) / 0.02)
        phase = freq * t
        if voice == "lead":
            # A little vibrato and a decay to a held level.
            phase = freq * t + 0.004 * freq * math.sin(2 * math.pi * 6 * t) / (2 * math.pi * 6) * 6
            sample = pulse(phase, 0.25) * (0.55 + 0.45 * math.exp(-6 * t))
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


random.seed(11)
for bar_index, ((root, chord), melody) in enumerate(SONG):
    bar_start = bar_index * BAR

    # Bass: eighth notes, jumping the octave on the off-beats.
    for step in range(8):
        note = root + (12 if step % 2 else 0)
        add_note(bar_start + step * EIGHTH, EIGHTH * 0.85, hz(note), "bass", 0.30)

    # Arpeggio: sixteenth notes running up and down the chord.
    pattern = [0, 1, 2, 1]
    for step in range(16):
        note = chord[pattern[step % 4]] + (12 if (step // 4) % 2 else 0)
        add_note(bar_start + step * SIXTEENTH, SIXTEENTH * 0.9, hz(note), "arp", 0.085)

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
        length = min(held, 3) * EIGHTH * 0.92
        add_note(bar_start + step * EIGHTH, length, hz(note), "lead", 0.17)
        step += held

    # Drums: kick on 1 and 3 (and a pickup into the next bar), snare on 2 and 4,
    # hats on every eighth.
    for beat in range(4):
        beat_start = bar_start + beat * BEAT
        if beat % 2 == 0:
            add_kick(beat_start, 0.55)
        else:
            add_noise(beat_start, 0.14, 22, 0.22, bright=False)
            add_note(beat_start, 0.06, 190, "bass", 0.12)
        add_noise(beat_start, 0.04, 80, 0.07, bright=True)
        add_noise(beat_start + EIGHTH, 0.05, 60, 0.10, bright=True)
    add_kick(bar_start + 3.5 * BEAT, 0.35)

peak = max(abs(s) for s in mix)
scale = 0.85 / peak
os.makedirs(os.path.dirname(OUT), exist_ok=True)
with wave.open(OUT, "wb") as f:
    f.setnchannels(1)
    f.setsampwidth(2)
    f.setframerate(RATE)
    f.writeframes(b"".join(struct.pack("<h", int(s * scale * 32767)) for s in mix))

print("Wrote %.1f seconds of music to %s" % (total / RATE, os.path.normpath(OUT)))
