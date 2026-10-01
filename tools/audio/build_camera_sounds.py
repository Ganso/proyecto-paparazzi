#!/usr/bin/env python3
"""Sonidos de disparo de cada cuerpo, sintetizados (docs/futuro/07 §1).

Genera WAV mono de 16 bits y 22,05 kHz en assets/audio/camara/:

  reflex.wav       espejo que sube, cortinilla y espejo que baja: «clac-clac» grave y seco
  telemetrica.wav  obturador de cortinilla de tela: un «tic» suave y corto, casi silencioso
  compacta.wav     beep electrónico de confirmación seguido del falso obturador de altavoz

Uso: python3 tools/audio/build_camera_sounds.py
"""
import os
import wave

import numpy as np
from scipy import signal

RATE = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "audio", "camara")
rng = np.random.default_rng(2026)


def t(seconds):
    return np.arange(int(seconds * RATE)) / RATE


def save(name, data, peak=0.85):
    data = data / (np.max(np.abs(data)) + 1e-9) * peak
    fade = int(0.004 * RATE)
    data[-fade:] *= np.linspace(1, 0, fade)
    pcm = (np.clip(data, -1, 1) * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(pcm.tobytes())
    print(name, f"{len(pcm) / RATE:.2f} s")


def band(x, low, high):
    sos = signal.butter(3, [low, high], btype="band", fs=RATE, output="sos")
    return signal.sosfilt(sos, x)


def click(length, low, high, decay, body_freq=0.0, body_amount=0.0):
    """Mechanical transient: filtered noise burst plus a short resonance of the camera body."""
    x = t(length)
    burst = band(rng.standard_normal(len(x)), low, high) * np.exp(-x * decay)
    if body_freq:
        burst += np.sin(2 * np.pi * body_freq * x) * np.exp(-x * decay * 0.6) * body_amount
    return burst


def place(total, pieces):
    out = np.zeros(int(total * RATE))
    for start, piece, gain in pieces:
        i = int(start * RATE)
        end = min(len(out), i + len(piece))
        out[i:end] += piece[: end - i] * gain
    return out


def reflex():
    mirror_up = click(0.09, 300, 4500, 55, 180, 0.6)
    curtain = click(0.05, 1500, 8000, 120)
    mirror_down = click(0.11, 250, 3500, 45, 150, 0.8)
    return place(0.3, [(0.0, mirror_up, 1.0), (0.035, curtain, 0.5), (0.085, curtain, 0.45), (0.1, mirror_down, 0.9)])


def rangefinder():
    tick = click(0.05, 1200, 7000, 160, 900, 0.15)
    return place(0.12, [(0.0, tick, 1.0), (0.018, click(0.04, 2000, 9000, 220), 0.5)])


def compact():
    x = t(0.07)
    beep = np.sin(2 * np.pi * 2730 * x) * np.minimum(1, x * 300) * np.exp(-x * 25)
    fake = click(0.12, 400, 6000, 40, 0, 0)
    return place(0.32, [(0.0, beep, 0.35), (0.11, beep, 0.35), (0.19, fake, 1.0)])


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    save("reflex.wav", reflex())
    save("telemetrica.wav", rangefinder(), 0.55)
    save("compacta.wav", compact(), 0.7)
