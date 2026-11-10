#!/usr/bin/env python3
"""Evaluación visual y de rendimiento de los márgenes de los caminos en Parque Grande:
1. Línea base (sin bordillos, hierba a 25 cm, pavimento plano sin faldón).
2. Solo Bordillos de piedra (encintado de granito biselado).
3. Solo Hierba orgánica (briznas hasta 5 cm con reborde denso).
4. Solo Faldón vertical (grosor 3D real en las losas y adoquines).
5. Conjunto completo (los tres aplicados a la vez).

Genera capturas a 1080p, paneles comparativos y envía el reporte a Telegram.
"""
import os
import re
import subprocess
import sys
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
BIN = os.path.expanduser("~/bin/godot-4-fp")
OUT_DIR = os.path.join(ROOT, "docs", "evidencias", "margenes")
os.makedirs(OUT_DIR, exist_ok=True)

CONFIGS = [
    ("baseline", "--margins=none", "Línea Base", "Sin bordillo, hierba a 25 cm, pavimento plano"),
    ("curbs", "--margins=curbs", "Solo Bordillos", "Bordillos de piedra biselada en caminos y plazas"),
    ("grass", "--margins=grass", "Solo Hierba", "Hierba hasta el borde (5 cm) con reborde denso"),
    ("skirt", "--margins=skirt", "Solo Faldón", "Pavimento con grosor 3D y faldón vertical a cota 0"),
    ("all", "--margins=all", "Conjunto (Los 3)", "Bordillos + Hierba al borde + Faldón vertical"),
]

SHOTS = [
    ("detalle", "--at=1.4,16,15 --pitch=-22 --focal=45", "Detalle de Margen"),
    ("perspectiva", "--at=0,20,0 --pitch=-8 --focal=50", "Perspectiva Avenida"),
]

def run_capture(cfg_name, cfg_flag, shot_name, shot_flag):
    out_png = os.path.join(OUT_DIR, f"{cfg_name}_{shot_name}.png")
    cmd = [
        BIN, "--path", ROOT, "--disable-vsync", "--rendering-method", "forward_plus",
        "--resolution", "1920x1080", "--",
        "--scenario=grande", "--sandbox", "--time=day", "--profile=Ultra",
        "--debug-off=dof", "--hud=0", cfg_flag,
        f"--screenshot={out_png}"
    ] + shot_flag.split()

    proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    out = proc.stdout
    metrics = {"dc": 0, "prim": 0, "vram": 0.0, "fps": 0}
    m = re.search(r"RENDER_METRICS:\s+dc=(\d+)\s+prim=(\d+)\s+vram=([\d.]+)MB\s+fps=(\d+)", out)
    if m:
        metrics["dc"] = int(m.group(1))
        metrics["prim"] = int(m.group(2))
        metrics["vram"] = float(m.group(3))
        metrics["fps"] = int(m.group(4))
    print(f"[{cfg_name} | {shot_name}] dc={metrics['dc']} prim={metrics['prim']:,} vram={metrics['vram']}MB fps={metrics['fps']}")
    return metrics, out_png

def build_composite_grid(shot_name, shot_title):
    # Composite of all 5 configs for a given shot viewpoint
    # Layout: Top title, then row of Baseline vs All (large 2-up), then row of 3 individual features
    images = {}
    for cfg_name, _, _, _ in CONFIGS:
        p = os.path.join(OUT_DIR, f"{cfg_name}_{shot_name}.png")
        images[cfg_name] = Image.open(p)
    
    # 2x2 grid (1920x2 x 1080x2 scaled to 2560x1440 for Telegram/documentation)
    w, h = 960, 540
    header_h = 70
    comp = Image.new("RGB", (w * 3, h * 2 + header_h), (22, 26, 30))
    draw = ImageDraw.Draw(comp)
    
    try:
        font_title = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 30)
        font_badge = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 22)
        font_sub = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 16)
    except:
        font_title = font_badge = font_sub = ImageFont.load_default()
        
    draw.text((w * 1.5, 22), f"PARQUE GRANDE — Comparativa de Márgenes ({shot_title})", fill=(250, 250, 250), font=font_title, anchor="mt")

    # Placement:
    # Row 1: Baseline (left 1.5w), All (right 1.5w)
    # Row 2: Solo Bordillos (w), Solo Hierba (w), Solo Faldón (w)
    
    # Baseline
    im_base = images["baseline"].resize((int(w * 1.5), int(h * 1.0)), Image.Resampling.LANCZOS)
    comp.paste(im_base, (0, header_h))
    draw.rectangle([20, header_h + 20, 420, header_h + 80], fill=(20, 20, 20, 220), outline=(220, 60, 60), width=2)
    draw.text((35, header_h + 28), "1. LÍNEA BASE (Original)", fill=(255, 100, 100), font=font_badge)
    draw.text((35, header_h + 55), "Sin bordillo, corte plano, hierba a 25 cm", fill=(200, 200, 200), font=font_sub)

    # All (Conjunto)
    im_all = images["all"].resize((int(w * 1.5), int(h * 1.0)), Image.Resampling.LANCZOS)
    comp.paste(im_all, (int(w * 1.5), header_h))
    draw.rectangle([int(w * 1.5) + 20, header_h + 20, int(w * 1.5) + 480, header_h + 80], fill=(20, 20, 20, 220), outline=(50, 230, 120), width=2)
    draw.text((int(w * 1.5) + 35, header_h + 28), "5. CONJUNTO COMPLETO", fill=(50, 255, 150), font=font_badge)
    draw.text((int(w * 1.5) + 35, header_h + 55), "Bordillos + Hierba al borde + Faldón 3D", fill=(200, 200, 200), font=font_sub)

    # Row 2: 3 individual features
    singles = [
        ("curbs", "2. SOLO BORDILLOS", "Encintado biselado de granito"),
        ("grass", "3. SOLO HIERBA", "Briznas hasta 5 cm con reborde"),
        ("skirt", "4. SOLO FALDÓN", "Grosor 3D vertical a cota 0"),
    ]
    y_row2 = header_h + int(h * 1.0)
    for idx, (c_key, c_title, c_desc) in enumerate(singles):
        im_s = images[c_key].resize((w, h), Image.Resampling.LANCZOS)
        x_pos = idx * w
        comp.paste(im_s, (x_pos, y_row2))
        draw.rectangle([x_pos + 15, y_row2 + 15, x_pos + 380, y_row2 + 75], fill=(20, 20, 20, 220), outline=(230, 180, 50), width=2)
        draw.text((x_pos + 25, y_row2 + 22), c_title, fill=(255, 210, 80), font=font_badge)
        draw.text((x_pos + 25, y_row2 + 48), c_desc, fill=(200, 200, 200), font=font_sub)
        
    out_comp = os.path.join(OUT_DIR, f"comparativa_conjunto_{shot_name}.png")
    comp.save(out_comp, quality=95)
    print("Guardado compuesto:", out_comp)
    return out_comp

def build_side_by_side(shot_name, title):
    # 1:1 Side by side Baseline vs All
    p_b = os.path.join(OUT_DIR, f"baseline_{shot_name}.png")
    p_a = os.path.join(OUT_DIR, f"all_{shot_name}.png")
    im_b = Image.open(p_b)
    im_a = Image.open(p_a)
    w, h = im_b.size
    
    header_h = 70
    comp = Image.new("RGB", (w * 2, h + header_h), (20, 24, 28))
    comp.paste(im_b, (0, header_h))
    comp.paste(im_a, (w, header_h))
    
    draw = ImageDraw.Draw(comp)
    draw.line([(w, 0), (w, h + header_h)], fill=(255, 120, 0), width=4)
    
    try:
        font_large = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 34)
        font_badge = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 28)
        font_sub = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 20)
    except:
        font_large = font_badge = font_sub = ImageFont.load_default()
        
    draw.text((w, 22), f"PARQUE GRANDE — {title}", fill=(240, 240, 240), font=font_large, anchor="mt")
    
    # Left badge
    draw.rectangle([30, header_h + 30, 520, header_h + 105], fill=(20, 20, 20, 220), outline=(220, 60, 60), width=3)
    draw.text((50, header_h + 40), "ANTES: Pavimento Plano Desnudo", fill=(255, 100, 100), font=font_badge)
    draw.text((50, header_h + 75), "Sin bordillo, corte recto y franja vacía a 25 cm", fill=(200, 200, 200), font=font_sub)
    
    # Right badge
    draw.rectangle([w + 30, header_h + 30, w + 570, header_h + 105], fill=(20, 20, 20, 220), outline=(0, 210, 120), width=3)
    draw.text((w + 50, header_h + 40), "DESPUÉS: Bordillos + Hierba + Faldón", fill=(50, 255, 150), font=font_badge)
    draw.text((w + 50, header_h + 75), "Encintado biselado, hierba al borde y grosor 3D", fill=(200, 200, 200), font=font_sub)
    
    out_path = os.path.join(OUT_DIR, f"comparativa_directa_{shot_name}.png")
    comp.save(out_path, quality=95)
    print("Guardado side-by-side:", out_path)
    return out_path

def main():
    results = {}
    for cfg_name, cfg_flag, title, desc in CONFIGS:
        results[cfg_name] = {}
        for shot_name, shot_flag, shot_title in SHOTS:
            metrics, out_png = run_capture(cfg_name, cfg_flag, shot_name, shot_flag)
            results[cfg_name][shot_name] = metrics

    # Build composites
    comp_grid_det = build_composite_grid("detalle", "Detalle de Margen")
    comp_grid_per = build_composite_grid("perspectiva", "Perspectiva de la Avenida")
    sbs_det = build_side_by_side("detalle", "Detalle del Margen del Camino")
    sbs_per = build_side_by_side("perspectiva", "Perspectiva de la Avenida Principal")

    # Generate Markdown Table Report
    report_lines = [
        "# Comparativa de Rendimiento: Márgenes de Caminos (Ultra 1080p)",
        "",
        "| Configuración | Triángulos (Detalle) | Draw Calls | VRAM (MB) | Triángulos (Perspectiva) | Draw Calls | VRAM (MB) |",
        "|---|---:|---:|---:|---:|---:|---:|",
    ]
    for cfg_name, _, title, _ in CONFIGS:
        m_det = results[cfg_name]["detalle"]
        m_per = results[cfg_name]["perspectiva"]
        report_lines.append(
            f"| **{title}** | {m_det['prim']:,} | {m_det['dc']} | {m_det['vram']:.1f} | {m_per['prim']:,} | {m_per['dc']} | {m_per['vram']:.1f} |"
        )
    report_md = "\n".join(report_lines)
    print("\n" + report_md + "\n")
    
    with open(os.path.join(OUT_DIR, "informe_rendimiento.md"), "w", encoding="utf-8") as f:
        f.write(report_md)

if __name__ == "__main__":
    main()
