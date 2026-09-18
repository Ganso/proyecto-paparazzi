#!/usr/bin/env python3
import os, sys, glob, subprocess
from PIL import Image, ImageDraw, ImageFont

BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
DOCS_EVIDENCIAS = os.path.join(BASE_DIR, "docs", "evidencias")
SCRATCH_DIR = os.path.join(DOCS_EVIDENCIAS, "scratch")

def get_font(size, bold=True):
    name = "DejaVuSans-Bold.ttf" if bold else "DejaVuSans.ttf"
    font_path = f"/usr/share/fonts/truetype/dejavu/{name}"
    try:
        return ImageFont.truetype(font_path, size)
    except Exception:
        return ImageFont.load_default()

def create_grid(image_items, grid_cols, cell_w, cell_h, title, subtitle, output_path):
    rows = (len(image_items) + grid_cols - 1) // grid_cols
    header_h = 70
    footer_h = 40
    padding = 16
    total_w = grid_cols * cell_w + (grid_cols + 1) * padding
    total_h = rows * cell_h + (rows + 1) * padding + header_h + footer_h

    canvas = Image.new("RGB", (total_w, total_h), (22, 26, 30))
    draw = ImageDraw.Draw(canvas)

    # Header
    title_font = get_font(24, bold=True)
    sub_font = get_font(13, bold=False)
    draw.text((padding, 16), title, font=title_font, fill=(240, 245, 250))
    draw.text((padding, 46), subtitle, font=sub_font, fill=(160, 175, 190))
    draw.line([(padding, header_h - 4), (total_w - padding, header_h - 4)], fill=(45, 55, 65), width=2)

    font_label = get_font(12, bold=True)

    for idx, item in enumerate(image_items):
        r = idx // grid_cols
        c = idx % grid_cols
        x = padding + c * (cell_w + padding)
        y = header_h + padding + r * (cell_h + padding)

        # Card background
        draw.rectangle([x, y, x + cell_w, y + cell_h], fill=(30, 36, 42), outline=(52, 64, 76), width=1)

        # Draw image
        img_path = item["path"]
        if os.path.exists(img_path):
            with Image.open(img_path) as im:
                im = im.convert("RGBA")
                max_w = cell_w - 16
                max_h = cell_h - 45
                im.thumbnail((max_w, max_h), Image.Resampling.LANCZOS)
                paste_x = x + (cell_w - im.width) // 2
                paste_y = y + 8 + (max_h - im.height) // 2
                canvas.paste(im, (paste_x, paste_y), mask=im.split()[3])

        # Bottom label bar
        draw.rectangle([x, y + cell_h - 28, x + cell_w, y + cell_h], fill=(24, 28, 33))
        label_text = item.get("label", "")
        draw.text((x + 8, y + cell_h - 21), label_text, font=font_label, fill=(210, 225, 235))

    # Footer
    draw.line([(padding, total_h - footer_h + 8), (total_w - padding, total_h - footer_h + 8)], fill=(45, 55, 65), width=1)
    footer_text = f"Proyecto Paparazzi · Estudio 3D Autónomo SubViewport · Total: {len(image_items)} ítems"
    draw.text((padding, total_h - footer_h + 16), footer_text, font=sub_font, fill=(130, 145, 160))

    canvas.save(output_path, "PNG")
    print(f"[OK] Generado Spritesheet: {output_path} ({total_w}x{total_h})")

def build_gif(pattern, output_path, fps=30):
    files = sorted(glob.glob(pattern))
    if not files:
        print(f"[WARN] No se encontraron archivos para {pattern}")
        return
    cmd = [
        "ffmpeg", "-y", "-framerate", str(fps),
        "-pattern_type", "glob", "-i", pattern,
        "-vf", "split[s0][s1];[s0]palettegen=max_colors=128[p];[s1][p]paletteuse=dither=bayer",
        output_path
    ]
    res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if res.returncode == 0:
        print(f"[OK] Generado GIF: {output_path}")
    else:
        print(f"[ERROR] Error al crear GIF {output_path}: {res.stderr.decode()[:200]}")

def build_gallery():
    md_path = os.path.join(DOCS_EVIDENCIAS, "GALERIA.md")
    content = """# Galería Visual y Banco de Evidencias Gráficas

Este documento reúne las evidencias gráficas generadas de forma 100% automatizada y determinista por la suite `tools/capture_evidence.gd` y `tools/build_sheets.py`.
Todos los recursos se encuentran aislados del motor Godot mediante `.gdignore` para garantizar **cero polución de `.import` y cero consumo innecesario de VRAM**.

---

## 1. Estados Principales del Juego

Secuencia de momentos clave que recorre el ciclo de juego desde la interfaz inicial vectorial hasta el revelado químico de la fotografía.

| Estado | Captura | Descripción Técnica y Demostración |
|---|---|---|
| **01. Inicio / Intro** | ![Inicio](estados/01_inicio.png) | Menú principal vectorial, tipografía de palo seco antialiased procedural y paleta de diseño editorial sobrio. |
| **02. Briefing del Objetivo** | ![Briefing](estados/02_briefing.png) | Retrato 3D del objetivo con iluminación de estudio, descriptor morfológico y prendas de vestimenta asignadas. |
| **03. Visor Réflex** | ![Visor Réflex](estados/03_visor_reflex.png) | Visor óptico clásico con cuadrícula áurea, 9 colimadores AF, prisma esmerilado y aguja del exposímetro analógico. |
| **04. Parque en Día Despejado** | ![Parque Día](estados/04_parque_dia.png) | Plaza central abierta a $28\\text{ mm}$, 21 viandantes simultáneos y fondo vegetal denso sin caídas de frame. |
| **05. Atenuación Lumínica por Nubes** | ![Nubes y EV](estados/05_nubes_ev.png) | Nube procedural ocultando el sol con atenuación de 3 EV, modificando el exposímetro y la exposición requerida. |
| **06. Parque en Modo Nocturno** | ![Parque Noche](estados/06_parque_noche.png) | Encendido crepuscular de farolas cálidas, iluminación omnidireccional y sombras proyectadas en tiempo real. |
| **07. Pantalla de Revelado** | ![Revelado](estados/07_revelado.png) | Procesado de imagen fotográfica con grano químico analógico, bokeh por CoC, desenfoque cinético y desglose de puntos. |

---

## 2. Hojas de Contacto de Assets (Spritesheets)

Renderizado en estudio 3D virtual neutro con iluminación uniforme de tres puntos y focal de $85\\text{ mm}$.

### 2.1 Mobiliario Urbano y Parque
Bancos con listones de madera, farolas de forja clásica con emisión cálida, papeleras, jardineras y fuentes de piedra.

![Sheet Mobiliario](sheets/sheet_mobiliario.png)

### 2.2 Flora y Cobertura Vegetal
Árboles procedurales adultos y jóvenes con copas esferoidales facetadas, seto perimetral denso, arbustos de sotobosque y matas florales.

![Sheet Vegetación](sheets/sheet_vegetacion.png)

### 2.3 Catálogo de Prendas de Vestir
Colección completa de torsos (camisetas, polos, chaquetas formales, ropa técnica de running) y piernas (pantalones de vestir, vaqueros, faldas, bermudas y shorts de deporte).

![Sheet Prendas](sheets/sheet_prendas.png)

### 2.4 Accesorios y Peinados
Peinados morfológicos masculinos, femeninos e infantiles, sombreros, gorras visera, gorros de lana, mochilas de tirantes, bandoleras y bolsos cruzados.

![Sheet Accesorios](sheets/sheet_accesorios.png)

### 2.5 Equipamiento Fotográfico y Ópticas
Cuerpos de cámara (compacta digital, telemétrica analógica, réflex monocular), teleobjetivos profesionales de gran apertura, objetivos fijos luminosos y carretes de película de 35 mm.

![Sheet Equipamiento](sheets/sheet_equipamiento.png)

---

## 3. Muestrario de Personajes (Line-up 3D)

Comprobación de la coherencia anatómica de los **4 somatotipos base** (Estándar, Delgado, Robusto, Infantil), el rig universal de 20 huesos y las combinaciones de vestimenta formal, de paseo y deportiva exclusiva (`sport: true`).

![Line-up de Personajes](personajes/personajes_lineup.png)

---

## 4. Cinemática, Locomoción y Variación de Luz

Demostración interactiva en bucles GIF animados cuantizados con paleta de color optimizada:

| Animación | Demostración GIF | Fundamento Cinemático Demostrado |
|---|---|---|
| **Caminata Pausada** ($0.75\\text{ m/s}$) | ![Anim Caminar](animaciones/anim_caminar.gif) | **Deslizamiento nulo comprobado** (`drift == 0.000000 m/frame`), planta del pie horizontal ($y=0$) durante el apoyo y balanceo pélvico suave. |
| **Carrera Atlética** ($2.80\\text{ m/s}$) | ![Anim Correr](animaciones/anim_correr.gif) | **Fase aérea balística** (ambos pies en el aire simultáneamente), torso inclinado hacia delante y flexión angular de rodillas. |
| **Ciclo Sol / Nube / Noche** | ![Anim Clima Luz](animaciones/anim_clima_luz.gif) | Transición de iluminación cenital a sombra de nube (caída de 3 EV) y encendido nocturno de farolas con sombras dinámicas. |

---

*Galería compilada automáticamente por `tools/capture_evidence.gd` y `tools/build_sheets.py`.*
"""
    with open(md_path, "w", encoding="utf-8") as f:
        f.write(content)
    print(f"[OK] Generado {md_path}")

def main():
    sheets_dir = os.path.join(DOCS_EVIDENCIAS, "sheets")
    anim_dir = os.path.join(DOCS_EVIDENCIAS, "animaciones")
    os.makedirs(sheets_dir, exist_ok=True)
    os.makedirs(anim_dir, exist_ok=True)

    # 1. Mobiliario
    mob_items = [
        {"path": f"{SCRATCH_DIR}/mob_banco_madera.png", "label": "Banco de Parque"},
        {"path": f"{SCRATCH_DIR}/mob_farola_forja.png", "label": "Farola Clásica"},
        {"path": f"{SCRATCH_DIR}/mob_papelera.png", "label": "Papelera de Forja"},
        {"path": f"{SCRATCH_DIR}/mob_jardinera.png", "label": "Jardinera Floral"},
        {"path": f"{SCRATCH_DIR}/mob_fuente.png", "label": "Fuente de Piedra"},
        {"path": f"{SCRATCH_DIR}/mob_verja_perimetral.png", "label": "Verja Perimetral"}
    ]
    create_grid(mob_items, 3, 260, 240, "Hoja de Contacto: Mobiliario Urbano", "Elementos estáticos del parque municipal con colisión física y etiquetas de fotómetro", os.path.join(sheets_dir, "sheet_mobiliario.png"))

    # 2. Vegetación
    veg_items = [
        {"path": f"{SCRATCH_DIR}/veg_arbol_grande.png", "label": "Árbol Maduro Procedural"},
        {"path": f"{SCRATCH_DIR}/veg_arbol_medio.png", "label": "Árbol Joven"},
        {"path": f"{SCRATCH_DIR}/veg_seto_denso.png", "label": "Seto Denso de Fondo"},
        {"path": f"{SCRATCH_DIR}/veg_arbusto_redondo.png", "label": "Arbusto Esférico"},
        {"path": f"{SCRATCH_DIR}/veg_mata_flores.png", "label": "Mata Floral Amarilla"},
        {"path": f"{SCRATCH_DIR}/veg_mata_rosas.png", "label": "Mata Floral Rosácea"}
    ]
    create_grid(veg_items, 3, 260, 240, "Hoja de Contacto: Flora y Vegetación", "Masa vegetal densa perimetral y sotobosque procedural de bajo coste geométrico", os.path.join(sheets_dir, "sheet_vegetacion.png"))

    # 3. Prendas
    torso_labels = ["Camiseta Básica", "Camisa Formal", "Chaqueta / Americana", "Jersey / Sudadera", "Camiseta Running (Sport)"]
    legs_labels = ["Pantalón de Vestir", "Vaqueros Rectos", "Falda Clásica", "Bermudas Casual", "Pantalón Chándal", "Short Running (Sport)"]
    garment_items = []
    for i, lbl in enumerate(torso_labels):
        garment_items.append({"path": f"{SCRATCH_DIR}/torso_{i}.png", "label": f"Torso: {lbl}"})
    for i, lbl in enumerate(legs_labels):
        garment_items.append({"path": f"{SCRATCH_DIR}/legs_{i}.png", "label": f"Piernas: {lbl}"})
    create_grid(garment_items, 4, 230, 220, "Hoja de Contacto: Catálogo de Prendas", "Geometría de vestimenta pesada rígidamente sobre el rig universal de 20 huesos", os.path.join(sheets_dir, "sheet_prendas.png"))

    # 4. Accesorios y Cabezas
    head_labels = ["Pelo Corto", "Media Melena", "Melena Larga", "Pelo Ondulado", "Calva", "Gorra Deportiva", "Sombrero Clásico", "Gorro de Lana"]
    acc_labels = ["Sin Accesorio", "Mochila Espalda", "Bolso Bandolera"]
    acc_items = []
    for i, lbl in enumerate(head_labels):
        acc_items.append({"path": f"{SCRATCH_DIR}/head_{i}.png", "label": f"Cabeza: {lbl}"})
    for i, lbl in enumerate(acc_labels):
        acc_items.append({"path": f"{SCRATCH_DIR}/acc_{i}.png", "label": f"Extra: {lbl}"})
    create_grid(acc_items, 4, 230, 210, "Hoja de Contacto: Cabezas, Peinados y Accesorios", "Variaciones de cabello estilizado, sombrería y complementos de transporte personal", os.path.join(sheets_dir, "sheet_accesorios.png"))

    # 5. Equipamiento
    equip_items = [
        {"path": f"{SCRATCH_DIR}/equip_compacta.png", "label": "Compacta Digital"},
        {"path": f"{SCRATCH_DIR}/equip_telemetrica.png", "label": "Telemétrica Clásica"},
        {"path": f"{SCRATCH_DIR}/equip_reflex.png", "label": "Réflex Monocular"},
        {"path": f"{SCRATCH_DIR}/equip_teleobjetivo.png", "label": "Zoom 70-200mm f/2.8"},
        {"path": f"{SCRATCH_DIR}/equip_objetivo_fijo.png", "label": "Fijo 50mm f/1.4"},
        {"path": f"{SCRATCH_DIR}/equip_carrete_35mm.png", "label": "Película 35mm ISO 400"}
    ]
    create_grid(equip_items, 3, 260, 240, "Hoja de Contacto: Equipamiento y Ópticas", "Cuerpos de cámara con sus respectivos visores ópticos, aperturas y soportes analógicos", os.path.join(sheets_dir, "sheet_equipamiento.png"))

    # GIFs
    build_gif(f"{SCRATCH_DIR}/walk_*.png", os.path.join(anim_dir, "anim_caminar.gif"), fps=30)
    build_gif(f"{SCRATCH_DIR}/run_*.png", os.path.join(anim_dir, "anim_correr.gif"), fps=24)
    build_gif(f"{SCRATCH_DIR}/weather_*.png", os.path.join(anim_dir, "anim_clima_luz.gif"), fps=18)

    # Galería Markdown
    build_gallery()

    # Limpieza de scratch
    print("[INFO] Limpiando carpeta temporal de scratch...")
    for f in glob.glob(f"{SCRATCH_DIR}/*.png"):
        os.remove(f)
    if os.path.exists(SCRATCH_DIR):
        os.rmdir(SCRATCH_DIR)
    print("[OK] Pipeline de compilación completado.")

if __name__ == "__main__":
    main()
