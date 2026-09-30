#!/usr/bin/env python3
"""Sonido ambiente del parque sintetizado por código (docs/futuro/19_VIDA_EN_EL_PARQUE.md §6).

Genera WAV mono de 16 bits y 22,05 kHz en assets/audio/ambiente/, sin muestras de terceros:

  pajaros.wav   20 s  gorjeos y trinos de varias especies (de día y en la hora dorada)
  fuente.wav    8 s   agua cayendo en el estanque (bucle sin costura)
  grillos.wav   6 s   grillos de noche (bucle)
  viento.wav    12 s  viento suave entre las hojas (bucle)
  ciudad.wav    10 s  rumor lejano de tráfico (bucle)
  zureo.wav     1,6 s zureo de paloma («cu-cuuu»), suelto
  aleteo.wav    1,2 s bandada que alza el vuelo, suelto

Uso: python3 tools/audio/build_ambience.py
"""
import os
import wave

import numpy as np
from scipy import signal

RATE = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "audio", "ambiente")
rng = np.random.default_rng(1906)


def t(seconds):
    return np.arange(int(seconds * RATE)) / RATE


def save(name, data, peak=0.8):
    data = data / (np.max(np.abs(data)) + 1e-9) * peak
    pcm = (np.clip(data, -1, 1) * 32767).astype(np.int16)
    path = os.path.join(OUT, name)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(pcm.tobytes())
    print(f"{path}: {len(pcm) / RATE:.1f} s")


def loopable(data, fade=0.5):
    """Crossfade the tail into the head so the loop has no seam."""
    n = int(fade * RATE)
    head, body, tail = data[:n], data[n:-n], data[-n:]
    ramp = np.linspace(0, 1, n)
    return np.concatenate([tail * (1 - ramp) + head * ramp, body])


def band(noise, low, high, order=4):
    sos = signal.butter(order, [low, high], btype="band", fs=RATE, output="sos")
    return signal.sosfilt(sos, noise)


def lowpass(noise, cutoff, order=4):
    sos = signal.butter(order, cutoff, btype="low", fs=RATE, output="sos")
    return signal.sosfilt(sos, noise)


def chirp(duration, f0, f1, curve=1.0, vibrato=0.0, vib_rate=30.0):
    x = t(duration)
    u = (x / duration) ** curve
    freq = f0 + (f1 - f0) * u + vibrato * np.sin(2 * np.pi * vib_rate * x)
    phase = 2 * np.pi * np.cumsum(freq) / RATE
    env = np.sin(np.pi * x / duration) ** 1.5
    return np.sin(phase) * env + 0.18 * np.sin(2 * phase) * env


def whistle(duration, f0, f1, curve=1.0, vib=0.0, vib_rate=6.0, harmonic=0.12):
    """Tonal bird note: smooth glide, soft attack and release, a faint second harmonic."""
    x = t(duration)
    u = (x / duration) ** curve
    freq = f0 + (f1 - f0) * u + vib * np.sin(2 * np.pi * vib_rate * x)
    phase = 2 * np.pi * np.cumsum(freq) / RATE
    env = np.sin(np.pi * np.clip(x / duration, 0, 1)) ** 2
    return (np.sin(phase) + harmonic * np.sin(2 * phase)) * env


def birds():
    total = np.zeros(int(20 * RATE))

    def great_tit():      # «ti-tu, ti-tu, ti-tu»
        hi, lo = rng.uniform(4600, 5400), rng.uniform(3300, 3900)
        notes = []
        for _ in range(rng.integers(3, 5)):
            notes += [(whistle(0.11, hi, hi * 0.97), 0.03), (whistle(0.13, lo, lo * 0.95), 0.09)]
        return notes

    def blackbird():      # melodic, low, varied phrase
        notes = []
        f = rng.uniform(1900, 2500)
        for _ in range(rng.integers(4, 8)):
            g = float(np.clip(f * rng.uniform(0.8, 1.3), 1600, 3400))
            notes.append((whistle(rng.uniform(0.1, 0.26), f, g, rng.uniform(0.5, 2.0), 25, 7), rng.uniform(0.03, 0.12)))
            f = g
        return notes

    def robin():          # fast descending trill
        start = rng.uniform(5500, 6500)
        return [(whistle(0.045, start - i * 160, start - i * 160 - 500), 0.018) for i in range(rng.integers(7, 12))]

    def sparrow():        # a few short chirps
        return [(whistle(0.08, rng.uniform(4200, 5000), rng.uniform(3000, 3500), 0.6, 0, 6, 0.3), rng.uniform(0.12, 0.3)) for _ in range(rng.integers(2, 5))]

    species = [great_tit, blackbird, blackbird, robin, sparrow, sparrow]
    cursor = 0.3
    while cursor < 18.5:
        gain = rng.uniform(0.2, 1.0)
        pos = int(cursor * RATE)
        for note, gap in species[rng.integers(0, len(species))]():
            end = min(len(total), pos + len(note))
            total[pos:end] += note[: end - pos] * gain
            pos += len(note) + int(gap * RATE)
        cursor = pos / RATE + rng.uniform(0.6, 2.2)
    # Sparse echoes so the song sits in the trees, not in the ear.
    wet = np.zeros_like(total)
    for delay, g in [(0.043, 0.3), (0.087, 0.18), (0.131, 0.11), (0.19, 0.06)]:
        d = int(delay * RATE)
        wet[d:] += total[:-d] * g
    return loopable(band(total + wet, 1200, 9000, 2))


def fountain():
    x = t(8.5)
    noise = rng.standard_normal(len(x))
    splash = band(noise, 400, 5000) * (0.8 + 0.2 * np.sin(2 * np.pi * 0.37 * x))
    drops = np.zeros(len(x))
    for _ in range(900):
        i = rng.integers(0, len(x) - 400)
        f = rng.uniform(900, 2600)
        k = np.arange(400) / RATE
        drops[i:i + 400] += np.sin(2 * np.pi * f * k * (1 + 3 * k)) * np.exp(-k * 90) * rng.uniform(0.1, 0.5)
    rumble = lowpass(noise, 250) * 0.6
    return loopable(splash + drops * 0.5 + rumble)


def crickets():
    x = t(6.5)
    total = np.zeros(len(x))
    for f, rate, offset, gain in [(4700, 2.2, 0.0, 1.0), (4350, 1.7, 0.3, 0.6), (5100, 2.9, 0.7, 0.4)]:
        carrier = np.sin(2 * np.pi * f * x)
        chirps = (np.sin(2 * np.pi * rate * (x + offset)) > 0.55).astype(float)
        pulses = (np.sin(2 * np.pi * 45 * x) > 0).astype(float)   # each chirp is a train of pulses
        env = lowpass(chirps * pulses, 400, 2)
        total += carrier * env * gain
    return loopable(total)


def wind():
    x = t(12.5)
    noise = rng.standard_normal(len(x))
    swell = 0.55 + 0.45 * np.sin(2 * np.pi * x / 12.5 * 2 + 1.0) * np.sin(2 * np.pi * x / 12.5 * 3)
    leaves = band(noise, 1800, 6000) * 0.25 * (swell ** 2)
    body = lowpass(noise, 500) * swell
    return loopable(body + leaves)


def city():
    x = t(10.5)
    noise = rng.standard_normal(len(x))
    hum = lowpass(noise, 180) * (0.8 + 0.2 * np.sin(2 * np.pi * 0.11 * x))
    cars = np.zeros(len(x))
    for _ in range(5):
        c = rng.uniform(1, 9.5)
        cars += np.exp(-((x - c) ** 2) / 1.2) * band(noise, 200, 900) * 0.5
    return loopable(hum + cars)


def coo():
    x = t(1.6)
    total = np.zeros(len(x))
    for start, dur, f in [(0.05, 0.25, 330), (0.42, 0.75, 360)]:
        k = t(dur)
        freq = f * (1 + 0.08 * np.sin(np.pi * k / dur)) + 12 * np.sin(2 * np.pi * 22 * k)
        phase = 2 * np.pi * np.cumsum(freq) / RATE
        env = np.sin(np.pi * k / dur) ** 0.8
        note = (np.sin(phase) + 0.5 * np.sin(2 * phase) + 0.2 * np.sin(3 * phase)) * env
        i = int(start * RATE)
        total[i:i + len(note)] += note
    return lowpass(total, 1500, 2)


def flutter():
    x = t(1.2)
    noise = rng.standard_normal(len(x))
    flaps = (0.5 + 0.5 * np.sin(2 * np.pi * 14 * x)) ** 3
    env = np.exp(-x * 2.2) * (1 - np.exp(-x * 40))
    return band(noise, 300, 3500) * flaps * env


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    save("pajaros.wav", birds(), 0.7)
    save("fuente.wav", fountain(), 0.7)
    save("grillos.wav", crickets(), 0.5)
    save("viento.wav", wind(), 0.6)
    save("ciudad.wav", city(), 0.6)
    save("zureo.wav", coo(), 0.7)
    save("aleteo.wav", flutter(), 0.8)
