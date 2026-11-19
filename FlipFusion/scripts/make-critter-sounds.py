"""Writes the sounds of the creatures that come out of crates.

Run from the FlipFusion folder:  python scripts/make-critter-sounds.py   (needs numpy)

  chomp   the shark's bite: a crunch on top of a thud
  monkey  the monkey's chatter: five quick yelps, up and down
  ufo     the flying saucer: a warbling, wobbling hum
  roar    the T-rex: a low growl that swells and falls
  stomp   the T-rex's foot coming down: a short heavy thump

Everything is synthesised here, so there are no audio files to license.
"""

import os
import wave

import numpy as np

RATE = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "FlipFusion", "Resources", "Sounds")
rng = np.random.default_rng(7)


def write(name, samples):
    samples = np.asarray(samples, dtype=float)
    samples = samples * (0.9 / max(0.001, float(np.max(np.abs(samples)))))
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes((samples * 32767).astype("<i2").tobytes())
    print("Wrote %.2f seconds: %s.wav" % (len(samples) / RATE, name))


def times(seconds):
    return np.arange(int(RATE * seconds)) / RATE


def lowpass(samples, strength):
    """A one-pole low-pass filter; `strength` nearer 1 keeps less of the fizz."""
    out = np.empty_like(samples)
    last = 0.0
    for i, s in enumerate(samples):
        last = strength * last + (1 - strength) * s
        out[i] = last
    return out


def tone(freqs, t):
    """A sine whose pitch follows `freqs` (one value for each sample)."""
    return np.sin(2 * np.pi * np.cumsum(freqs) / RATE)


# The shark's bite.
t = times(0.22)
crunch = lowpass(rng.uniform(-1, 1, len(t)), 0.55) * np.exp(-26 * t)
thud = tone(170 * np.exp(-9 * t) + 45, t) * np.exp(-12 * t)
write("chomp", crunch * 0.9 + thud * 1.1)

# The monkey's chatter: ooh-ooh-ah-ah-ah.
parts = []
for start, end, length in [(520, 900, 0.09), (560, 980, 0.09), (1000, 620, 0.1), (1080, 660, 0.1), (1150, 560, 0.14)]:
    t = times(length)
    glide = np.linspace(start, end, len(t)) * (1 + 0.04 * np.sin(2 * np.pi * 32 * t))
    voice = tone(glide, t) + 0.45 * tone(glide * 2, t) + 0.2 * tone(glide * 3, t)
    parts.append(voice * np.sin(np.pi * t / length) ** 0.6)
    parts.append(np.zeros(int(RATE * 0.035)))
write("monkey", np.concatenate(parts))

# The flying saucer.
t = times(1.3)
wobble = 620 + 190 * np.sin(2 * np.pi * 8 * t) + 60 * np.sin(2 * np.pi * 0.8 * t)
hum = tone(wobble, t) + 0.35 * tone(wobble * 1.5, t)
swell = np.minimum(1.0, t / 0.12) * np.minimum(1.0, (1.3 - t) / 0.25)
write("ufo", hum * swell * (0.75 + 0.25 * np.sin(2 * np.pi * 16 * t)))

# The T-rex's roar.
t = times(1.1)
pitch = 150 * np.exp(-1.3 * t) + 62
growl = tone(pitch, t) + 0.7 * tone(pitch * 1.51, t) + 0.5 * tone(pitch * 2.02, t) + 0.3 * tone(pitch * 3.1, t)
breath = lowpass(rng.uniform(-1, 1, len(t)), 0.86) * 2.2
rumble = 0.6 + 0.4 * np.sin(2 * np.pi * 27 * t)
shape = np.minimum(1.0, t / 0.1) * np.exp(-2.3 * np.maximum(0, t - 0.35))
write("roar", np.tanh((growl + breath) * rumble * shape * 1.6))

# A stomp.
t = times(0.32)
thump = tone(120 * np.exp(-14 * t) + 38, t) * np.exp(-9 * t)
crack = lowpass(rng.uniform(-1, 1, len(t)), 0.7) * np.exp(-40 * t) * 0.5
write("stomp", thump + crack)
