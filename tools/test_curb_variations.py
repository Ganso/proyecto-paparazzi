#!/usr/bin/env python3
"""Genera capturas de prueba de bordillos en Parque Grande:
- Diferentes partes del parque: Avenida (adoquín), Plaza Central (losas), Glorieta Quiosco, Bancos.
- Diferentes horas: Día (--time=day) y Hora Dorada (--time=golden).
- Diferentes vistas: Detalle rasante, perspectiva media, vista amplia con personajes y bancos.
"""
import os
import subprocess
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
BIN = os.path.expanduser("~/bin/godot-4-fp")
OUT_DIR = os.path.join(ROOT, "docs", "evidencias", "margenes")
os.makedirs(OUT_DIR, exist_ok=True)

SHOTS = [
    ("avenida_detalle", "--at=1.2,16,10 --pitch=-25 --focal=50", "Avenida · Detalle Rasante de Bordillo"),
    ("avenida_perspectiva", "--at=0,22,0 --pitch=-6 --focal=45", "Avenida · Perspectiva con Bancos"),
    ("plaza_fuente", "--at=0,10.5,180 --pitch=-14 --focal=38", "Plaza Central · Bordillo Circular y Bancos"),
    ("quiosco_diagonal", "--at=-22,-24,-135 --pitch=-12 --focal=42", "Quiosco · Encuentro de Pavimentos"),
    ("banco_detalle", "--at=3.4,20,-90 --pitch=-18 --focal=55", "Banco y Margen · Holgura sin Colisión"),
]

def capture_shot(shot_id, camera_args, time_of_day, filename):
    cmd = [
        BIN, "--path", ROOT, "--disable-vsync", "--rendering-method", "forward_plus",
        "--resolution", "1920x1080", "--",
        "--scenario=grande", "--sandbox", f"--time={time_of_day}", "--profile=Ultra",
        "--debug-off=dof", "--hud=0", f"--screenshot={filename}"
    ] + camera_args.split()
    print(f"Capturing: {shot_id} ({time_of_day}) -> {filename}...")
    proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    return proc.returncode == 0

if __name__ == "__main__":
    time = sys.argv[1] if len(sys.argv) > 1 else "day"
    for shot_id, cam, title in SHOTS:
        out = os.path.join(OUT_DIR, f"{shot_id}_{time}.png")
        capture_shot(shot_id, cam, time, out)
    print("Captures complete!")
