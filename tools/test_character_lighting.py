#!/usr/bin/env python3
"""Genera comparativas de personajes con y sin Character Fill Light:
1. Contraluz a la hora dorada (Sunset Backlight)
2. Luz lateral a la hora dorada (Cross-lighting a 90°)
3. Sombra diurna bajo los árboles (Daylight Shade)
4. Retrato primer plano a 85 mm (Close-up Portrait)
5. Paseo abierto en Parque Grande (Open Meadow Walkers)

Genera paneles comparativos individuales y un panel general compuesto.
"""
import os
import subprocess
import sys
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
BIN = os.path.expanduser("~/bin/godot-4-fp")
OUT_DIR = os.path.join(ROOT, "docs", "evidencias", "iluminacion_personajes")
os.makedirs(OUT_DIR, exist_ok=True)

SITUATIONS = [
    {
        "id": "1_contraluz_golden",
        "title": "1. CONTRALUZ EN HORA DORADA",
        "sub": "Silueta contra el sol poniente · Rescate de volumen, ropa y rótulas",
        "cmd_base": ["--scenario=clasico", "--sandbox", "--time=golden", "--profile=Ultra", "--debug-off=dof", "--hud=0", "--focal=55", "--angle=-48", "--pitch=-5", "--clock=2"]
    },
    {
        "id": "2_lateral_golden",
        "title": "2. LUZ LATERAL EN HORA DORADA (90°)",
        "sub": "Sol rasante de costado · Relación de contraste 3:1 sin lado negro",
        "cmd_base": ["--scenario=clasico", "--sandbox", "--time=golden", "--profile=Ultra", "--debug-off=dof", "--hud=0", "--focal=50", "--angle=42", "--pitch=-4", "--clock=2"]
    },
    {
        "id": "3_sombra_dia",
        "title": "3. DÍA A PLENO SOL (SOMBRA DE COPA)",
        "sub": "Sombra densa de plátanos a mediodía · Rebote cenital del cielo",
        "cmd_base": ["--scenario=clasico", "--sandbox", "--time=day", "--profile=Ultra", "--debug-off=dof", "--hud=0", "--focal=50", "--angle=-20", "--pitch=-6", "--clock=2"]
    },
    {
        "id": "4_retrato_85mm",
        "title": "4. RETRATO PRIMER PLANO (85 mm)",
        "sub": "Textura de madera barnizada, articulaciones y pelo",
        "cmd_base": ["--scenario=clasico", "--sandbox", "--time=golden", "--profile=Ultra", "--debug-off=dof", "--hud=0", "--focal=85", "--angle=-52", "--pitch=-2", "--clock=2"]
    },
    {
        "id": "5_parque_grande",
        "title": "5. PASEO EN PARQUE GRANDE",
        "sub": "Viandantes en pradera abierta · Integración con el entorno",
        "cmd_base": ["--scenario=grande", "--sandbox", "--time=golden", "--profile=Ultra", "--debug-off=dof", "--hud=0", "--focal=45", "--at=-22,-24,-135", "--pitch=-12"]
    }
]

def run_godot(args, out_path):
    cmd = [
        BIN, "--path", ROOT, "--disable-vsync", "--rendering-method", "forward_plus",
        "--resolution", "1920x1080", "--"
    ] + args + [f"--screenshot={out_path}"]
    subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)

def build_comparison(sit):
    sid = sit["id"]
    p_sin = os.path.join(OUT_DIR, f"{sid}_sin.png")
    p_con = os.path.join(OUT_DIR, f"{sid}_con.png")
    
    print(f"[{sid}] Capturando SIN fill light...")
    run_godot(sit["cmd_base"] + ["--no-fill-light"], p_sin)
    
    print(f"[{sid}] Capturando CON fill light...")
    run_godot(sit["cmd_base"], p_con)

    # Build side by side comparison
    im_sin = Image.open(p_sin).resize((960, 540), Image.Resampling.LANCZOS)
    im_con = Image.open(p_con).resize((960, 540), Image.Resampling.LANCZOS)
    
    header_h = 75
    comp = Image.new("RGB", (1920, 540 + header_h), (18, 22, 26))
    comp.paste(im_sin, (0, header_h))
    comp.paste(im_con, (960, header_h))
    
    draw = ImageDraw.Draw(comp)
    try:
        font_title = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 22)
        font_badge = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 18)
        font_sub = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 14)
    except:
        font_title = font_badge = font_sub = ImageFont.load_default()
        
    draw.text((960, 16), sit["title"], fill=(255, 255, 255), font=font_title, anchor="mt")
    draw.text((960, 44), sit["sub"], fill=(190, 200, 210), font=font_sub, anchor="mt")
    
    # Badge Sin
    draw.rectangle([20, header_h + 15, 420, header_h + 55], fill=(20, 20, 20, 220), outline=(220, 60, 60), width=2)
    draw.text((35, header_h + 23), "SIN LUZ DE RELLENO (Sombra negra)", fill=(255, 120, 120), font=font_badge)

    # Badge Con
    draw.rectangle([980, header_h + 15, 1480, header_h + 55], fill=(20, 20, 20, 220), outline=(50, 220, 120), width=2)
    draw.text((995, header_h + 23), "CON FILL LIGHT + RIM (Volumen y relieve)", fill=(100, 255, 150), font=font_badge)

    out_comp = os.path.join(OUT_DIR, f"comparativa_{sid}.png")
    comp.save(out_comp, quality=95)
    print(f"[{sid}] Comparativa guardada en {out_comp}")
    return out_comp

def build_master_panel():
    # 4-up master collage of situations 1, 2, 3, 4
    w, h = 960, 540
    header_h = 70
    canvas = Image.new("RGB", (w * 2, h * 2 + header_h), (18, 22, 26))
    draw = ImageDraw.Draw(canvas)
    
    try:
        font_main = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 26)
    except:
        font_main = ImageFont.load_default()
        
    draw.text((w, 22), "MEJORA C: ILUMINACIÓN DE PERSONAJES (CHARACTER FILL LIGHT + RIM)", fill=(255, 255, 255), font=font_main, anchor="mt")

    coords = [(0, header_h), (w, header_h), (0, header_h + h), (w, header_h + h)]
    for i in range(4):
        sid = SITUATIONS[i]["id"]
        p = os.path.join(OUT_DIR, f"comparativa_{sid}.png")
        im = Image.open(p).resize((w, h), Image.Resampling.LANCZOS)
        canvas.paste(im, coords[i])

    out_master = os.path.join(OUT_DIR, "panel_general_iluminacion_personajes.png")
    canvas.save(out_master, quality=95)
    print(f"Panel maestro guardado en {out_master}")
    return out_master

if __name__ == "__main__":
    for sit in SITUATIONS:
        build_comparison(sit)
    build_master_panel()
    print("Todo completado con éxito!")
