"""Composes one looping tune for each theme, as WAV files named music-<theme>.wav.

Run from the FlipFusion folder:  python scripts/make-theme-music.py   (needs numpy)

Each tune is built from a chord progression and a short motif that follows the
chords, then synthesised here, so there is no audio to license. A theme's style
sets the tempo, the instruments and the drums:

  neon       80s synth-pop: saw lead, running arpeggio, big snare
  sunset     laid back: soft lead, gentle drums
  ocean      slow and watery: bell lead, no snare, soft pulse
  bubblegum  quick and bouncy: square lead, bright drums
  lava       heavy and low: saw lead, pounding kick
  frost      music-box bells, light and high
  gold       a trotting tune with a clip-clop beat
  party      disco: kick on every beat, off-beat hats
  galaxy     slow and spacey: soft pad lead, sparse drums
"""

import os
import struct
import wave

import numpy as np

RATE = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "FlipFusion", "Resources", "Sounds")


def hz(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


# A chord is (bass root, the three notes of the arpeggio).
AM = (45, (69, 72, 76))
C = (48, (64, 67, 72))
D = (38, (62, 66, 69))
DM = (38, (62, 65, 69))
E = (40, (64, 68, 71))
EM = (40, (64, 67, 71))
F = (41, (65, 69, 72))
G = (43, (62, 67, 71))
BB = (46, (62, 65, 70))

# A motif is two bars of eighth notes. Each slot is a step up the chord (0, 1, 2 are
# its three notes, 3 and 4 the first two an octave higher) or None to hold or rest.
MOTIFS = {
    "rise": [0, None, 1, None, 2, 1, None, None, 2, None, 3, None, 4, 3, 2, None],
    "bounce": [2, 2, 1, 2, 3, None, 2, 1, 0, None, 1, 2, None, 1, 0, None],
    "fall": [4, None, 3, None, 2, None, 1, None, 3, None, 2, 1, 0, None, None, None],
    "call": [0, None, None, 2, None, 1, 0, None, 1, None, None, 3, None, 2, 1, None],
    "run": [0, 1, 2, 3, 2, 1, 2, None, 1, 2, 3, 4, 3, 2, 1, None],
    "float": [2, None, None, None, 3, None, None, None, 1, None, None, None, 2, None, 0, None],
}

THEMES = {
    "neon": dict(bpm=112, chords=[AM, F, C, G, AM, F, G, E], motifs=("rise", "run"),
                 lead="saw", arp=16, bass="octave", drums="eighties"),
    "sunset": dict(bpm=92, chords=[F, G, EM, AM, F, G, C, C], motifs=("call", "rise"),
                   lead="soft", arp=8, bass="steady", drums="soft"),
    "ocean": dict(bpm=80, chords=[DM, BB, F, C, DM, BB, C, AM], motifs=("float", "call"),
                  lead="bell", arp=8, bass="long", drums="pulse"),
    "bubblegum": dict(bpm=138, chords=[C, F, G, C, AM, F, G, G], motifs=("bounce", "run"),
                      lead="square", arp=16, bass="octave", drums="bright"),
    "lava": dict(bpm=122, chords=[AM, BB, AM, G, AM, BB, E, E], motifs=("fall", "bounce"),
                 lead="saw", arp=16, bass="pound", drums="pound", low=True),
    "frost": dict(bpm=100, chords=[C, G, AM, F, C, G, F, G], motifs=("call", "fall"),
                  lead="bell", arp=8, bass="steady", drums="sleigh", high=True),
    "gold": dict(bpm=118, chords=[G, C, G, D, G, C, D, G], motifs=("bounce", "rise"),
                 lead="square", arp=8, bass="trot", drums="trot"),
    "party": dict(bpm=126, chords=[F, G, AM, AM, F, G, EM, AM], motifs=("run", "bounce"),
                  lead="square", arp=16, bass="octave", drums="disco"),
    "galaxy": dict(bpm=88, chords=[AM, F, DM, E, AM, F, G, E], motifs=("float", "rise"),
                   lead="pad", arp=8, bass="long", drums="sparse"),
    "rainforest": dict(bpm=104, chords=[DM, C, BB, C, DM, F, C, AM], motifs=("bounce", "call"),
                       lead="bell", arp=8, bass="trot", drums="soft"),
    "jurassic": dict(bpm=96, chords=[EM, C, D, EM, AM, C, D, E], motifs=("fall", "rise"),
                     lead="saw", arp=8, bass="pound", drums="pound", low=True),
}


def render(name, style, seed):
    beat = 60.0 / style["bpm"]
    eighth = beat / 2
    sixteenth = beat / 4
    bar = beat * 4
    # The eight chords are played twice: once under each motif.
    bars = [(chord, motif) for motif in style["motifs"] for chord in style["chords"]]
    total = int(round(len(bars) * bar * RATE))
    mix = np.zeros(total)
    rng = np.random.default_rng(seed)

    def add(start, samples):
        first = int(start * RATE)
        if first >= total:
            return
        samples = samples[: total - first]
        mix[first:first + len(samples)] += samples

    def note(start, length, freq, voice, volume):
        t = np.arange(int(length * RATE)) / RATE
        if len(t) == 0:
            return
        phase = freq * t
        if voice == "saw":
            # Two saws a little apart, like an old poly-synth.
            wave_ = (2 * ((phase * 1.004) % 1) - 1) * 0.5 + (2 * ((phase * 0.996) % 1) - 1) * 0.5
            wave_ = wave_ * (0.55 + 0.45 * np.exp(-5 * t))
        elif voice == "square":
            wave_ = np.where((phase + 0.004 * freq * np.sin(2 * np.pi * 6 * t) / (2 * np.pi)) % 1 < 0.25, 1.0, -1.0)
            wave_ = wave_ * (0.55 + 0.45 * np.exp(-6 * t))
        elif voice == "soft":
            wave_ = np.where(phase % 1 < 0.5, 1.0, -1.0) * 0.6 + np.sin(2 * np.pi * phase) * 0.6
            wave_ = wave_ * (0.6 + 0.4 * np.exp(-4 * t))
        elif voice == "bell":
            wave_ = (np.sin(2 * np.pi * phase) + 0.4 * np.sin(2 * np.pi * phase * 3.01) * np.exp(-8 * t)) * np.exp(-3.2 * t)
        elif voice == "pad":
            wave_ = (np.sin(2 * np.pi * phase) + 0.3 * np.sin(2 * np.pi * phase * 2)) * np.minimum(1.0, t / 0.12)
        elif voice == "arp":
            wave_ = np.where(phase % 1 < 0.125, 1.0, -1.0) * np.exp(-9 * t)
        else:  # bass: a triangle
            p = phase % 1
            wave_ = np.where(p < 0.5, 4 * p - 1, 3 - 4 * p)
        attack = np.minimum(1.0, t / 0.004)
        release = np.minimum(1.0, (length - t) / 0.02)
        add(start, volume * attack * release * wave_)

    def kick(start, volume):
        t = np.arange(int(0.16 * RATE)) / RATE
        phase = np.cumsum(45 + 110 * np.exp(-30 * t)) / RATE
        add(start, volume * np.exp(-14 * t) * np.sin(2 * np.pi * phase))

    def noise(start, length, decay, volume, bright):
        t = np.arange(int(length * RATE)) / RATE
        white = rng.uniform(-1, 1, len(t))
        if bright:
            white = np.diff(white, prepend=0.0)
        add(start, volume * np.exp(-decay * t) * white)

    lead = style["lead"]
    lead_volume = {"saw": 0.15, "square": 0.16, "soft": 0.13, "bell": 0.26, "pad": 0.17}[lead]
    shift = 12 if style.get("high") else (-12 if style.get("low") else 0)

    for index, ((root, chord), motif_name) in enumerate(bars):
        start = index * bar
        ladder = [chord[0], chord[1], chord[2], chord[0] + 12, chord[1] + 12]
        # Odd bars play the second half of the two-bar motif.
        motif = MOTIFS[motif_name][8:] if index % 2 else MOTIFS[motif_name][:8]

        # Bass.
        bass = style["bass"]
        if bass == "octave":
            for step in range(8):
                note(start + step * eighth, eighth * 0.85, hz(root + (12 if step % 2 else 0)), "bass", 0.30)
        elif bass == "pound":
            for step in range(8):
                note(start + step * eighth, eighth * 0.9, hz(root), "bass", 0.36)
        elif bass == "trot":
            for step in range(4):
                note(start + step * beat, beat * 0.45, hz(root + (7 if step % 2 else 0)), "bass", 0.32)
        elif bass == "long":
            note(start, bar * 0.98, hz(root), "bass", 0.26)
            note(start + beat * 2, beat * 1.9, hz(root + 7), "bass", 0.12)
        else:  # steady
            for step in range(4):
                note(start + step * beat, beat * 0.9, hz(root + (12 if step == 2 else 0)), "bass", 0.28)

        # Arpeggio.
        pattern = [0, 1, 2, 1]
        if style["arp"] == 16:
            for step in range(16):
                pitch = chord[pattern[step % 4]] + (12 if (step // 4) % 2 else 0)
                note(start + step * sixteenth, sixteenth * 0.9, hz(pitch), "arp", 0.08)
        else:
            for step in range(8):
                note(start + step * eighth, eighth * 0.9, hz(chord[pattern[step % 4]]), "arp", 0.07)

        # Lead.
        step = 0
        while step < 8:
            rung = motif[step]
            if rung is None:
                step += 1
                continue
            held = 1
            while step + held < 8 and motif[step + held] is None:
                held += 1
            longest = 6 if lead in ("bell", "pad") else 3
            length = min(held, longest) * eighth * 0.94
            note(start + step * eighth, length, hz(ladder[rung] + shift), lead, lead_volume)
            step += held

        # Drums.
        drums = style["drums"]
        for b in range(4):
            at = start + b * beat
            if drums == "eighties":
                if b % 2 == 0:
                    kick(at, 0.6)
                else:
                    noise(at, 0.3, 11, 0.22, bright=False)   # a big, long snare
                noise(at, 0.04, 80, 0.07, bright=True)
                noise(at + eighth, 0.05, 60, 0.09, bright=True)
            elif drums == "disco":
                kick(at, 0.6)
                if b % 2 == 1:
                    noise(at, 0.12, 24, 0.2, bright=False)
                noise(at + eighth, 0.07, 45, 0.13, bright=True)
            elif drums == "pound":
                kick(at, 0.65)
                kick(at + eighth, 0.4)
                if b % 2 == 1:
                    noise(at, 0.16, 18, 0.22, bright=False)
            elif drums == "bright":
                if b % 2 == 0:
                    kick(at, 0.5)
                else:
                    noise(at, 0.1, 28, 0.2, bright=False)
                for s in range(4):
                    noise(at + s * sixteenth, 0.03, 90, 0.05 if s % 2 else 0.08, bright=True)
            elif drums == "trot":
                # Clip-clop: two woody knocks to the beat.
                note(at, 0.05, 520, "bass", 0.16)
                note(at + eighth, 0.05, 390, "bass", 0.13)
                if b == 0:
                    kick(at, 0.4)
            elif drums == "sleigh":
                noise(at, 0.05, 55, 0.07, bright=True)
                noise(at + eighth, 0.05, 55, 0.05, bright=True)
                if b == 0:
                    kick(at, 0.3)
            elif drums == "soft":
                if b % 2 == 0:
                    kick(at, 0.4)
                else:
                    noise(at, 0.14, 22, 0.12, bright=False)
                noise(at + eighth, 0.05, 60, 0.06, bright=True)
            elif drums == "pulse":
                if b == 0:
                    kick(at, 0.32)
                noise(at + eighth, 0.08, 35, 0.035, bright=True)
            else:  # sparse
                if b == 0:
                    kick(at, 0.38)
                if b == 2:
                    noise(at, 0.2, 14, 0.07, bright=False)

    mix *= 0.85 / np.max(np.abs(mix))
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, "music-" + name + ".wav")
    with wave.open(path, "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes((mix * 32767).astype("<i2").tobytes())
    print("Wrote %.1f seconds to %s" % (total / RATE, os.path.normpath(path)))


for number, (name, style) in enumerate(THEMES.items()):
    render(name, style, seed=21 + number)
