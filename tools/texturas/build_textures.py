"""Texturas procedurales del suelo del parque (docs/futuro/17 fase 2).

    python3 tools/texturas/build_textures.py [--size 2048] [--only losas,cesped]

Genera en assets/texturas/ tres mapas por material, todos periódicos (se repiten sin costura):
  <material>_color.webp   albedo sRGB
  <material>_normal.webp  normal en coordenadas del suelo: R = x del mundo, G = z del mundo,
                          B = arriba (convenio propio de shaders/park_ground.gdshader)
  <material>_orm.webp     R = oclusión, G = rugosidad, B = altura
El tamaño de cada baldosa en metros está en MATERIALS (campo "tile") y lo usa el shader.
"""
import argparse
import os

import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "texturas")


# ---------------------------------------------------------------- ruido y celdas periódicas

def fractal(n, rng, beta=2.0, low=2, high=None):
    """Ruido 1/f^beta periódico (filtrado en frecuencia), normalizado a [0, 1]."""
    white = rng.standard_normal((n, n))
    f = np.fft.fftfreq(n) * n
    fx, fy = np.meshgrid(f, f)
    radius = np.sqrt(fx * fx + fy * fy)
    radius[0, 0] = 1.0
    mask = 1.0 / radius ** (beta / 2)
    mask[radius < low] = 0.0
    if high:
        mask *= np.exp(-(radius / high) ** 2)
    out = np.real(np.fft.ifft2(np.fft.fft2(white) * mask))
    out -= out.min()
    return out / max(out.max(), 1e-9)


def voronoi(n, cells, rng, jitter=0.9):
    """Voronoi periódico sobre una rejilla de cells × cells puntos: devuelve (F1, F2, id)."""
    size = n / cells
    pts = (np.arange(cells)[:, None, None] + 0.5 + (rng.random((cells, cells, 2)) - 0.5) * jitter)
    ys, xs = np.mgrid[0:n, 0:n].astype(np.float32)
    gx, gy = xs / size, ys / size
    cx, cy = np.floor(gx).astype(int), np.floor(gy).astype(int)
    best = np.full((n, n), 1e9, np.float32)
    second = np.full((n, n), 1e9, np.float32)
    ident = np.zeros((n, n), np.int64)
    for oy in (-1, 0, 1):
        for ox in (-1, 0, 1):
            ix, iy = cx + ox, cy + oy
            wx, wy = ix % cells, iy % cells
            px = ix + (pts[wy, wx, 0] - np.floor(pts[wy, wx, 0]))
            py = iy + (pts[wy, wx, 1] - np.floor(pts[wy, wx, 1]))
            d = np.sqrt((gx - px) ** 2 + (gy - py) ** 2)
            closer = d < best
            second = np.where(closer, best, np.minimum(second, d))
            ident = np.where(closer, wy * cells + wx, ident)
            best = np.where(closer, d, best)
    return best, second, ident


def normals(height, strength):
    """Normal (x, z del mundo, arriba) a partir de la altura, con derivadas periódicas."""
    dx = (np.roll(height, -1, 1) - np.roll(height, 1, 1)) * 0.5
    dz = (np.roll(height, -1, 0) - np.roll(height, 1, 0)) * 0.5
    nx, nz, ny = -dx * strength, -dz * strength, np.ones_like(height)
    length = np.sqrt(nx * nx + ny * ny + nz * nz)
    return np.stack([nx / length, nz / length, ny / length], -1)


def cavity(height, radius=6):
    """Oclusión barata: cuánto está un píxel por debajo de la media de su entorno."""
    blurred = height.copy()
    for axis in (0, 1):
        acc = np.zeros_like(blurred)
        for k in range(-radius, radius + 1):
            acc += np.roll(blurred, k, axis)
        blurred = acc / (2 * radius + 1)
    return np.clip(1.0 - np.maximum(0.0, blurred - height) * 3.0, 0.0, 1.0)


def hexcolor(h):
    return np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)], np.float32)


def rounded_box(u, v, half_u, half_v, radius):
    """Distancia con signo a un rectángulo de esquinas redondeadas centrado en el origen."""
    qx = np.abs(u) - half_u + radius
    qy = np.abs(v) - half_v + radius
    outside = np.sqrt(np.maximum(qx, 0) ** 2 + np.maximum(qy, 0) ** 2)
    return outside + np.minimum(np.maximum(qx, qy), 0) - radius


# ---------------------------------------------------------------- materiales

def losas(n, rng):
    """Losas de piedra clara de 0,6 × 0,6 m en hiladas desfasadas (plaza central)."""
    tile = 2.4
    px = n / tile
    cols, rows = 4, 4
    ys, xs = np.mgrid[0:n, 0:n].astype(np.float32) / px
    row = np.floor(ys / 0.6).astype(int)
    xs_s = (xs + (row % 2) * 0.3) % tile
    col = np.floor(xs_s / 0.6).astype(int) % cols
    u = xs_s - (col + 0.5) * 0.6
    v = ys - (row + 0.5) * 0.6
    ident = (row % rows) * cols + col
    d = rounded_box(u, v, 0.296, 0.296, 0.01)
    slab = np.clip(-d / 0.008, 0, 1)
    tint = rng.uniform(0.9, 1.06, rows * cols)[ident]
    grain = fractal(n, rng, beta=1.6, low=8)
    stain = fractal(n, rng, beta=2.6, low=2)
    height = slab * (0.9 + 0.1 * grain) + (1 - slab) * 0.1 * grain
    base = hexcolor("cfc8b8")
    color = base[None, None, :] * (tint * (0.9 + 0.12 * grain) * (0.92 + 0.1 * stain))[..., None]
    joint = hexcolor("6f6a5e")
    color = color * slab[..., None] + joint[None, None, :] * (1 - slab[..., None]) * (0.85 + 0.3 * grain[..., None])
    rough = 0.72 + 0.12 * grain + (1 - slab) * 0.15
    return color, height, rough, 5.0, tile


def asfalto(n, rng):
    """Asfalto claro de paseo: árido fino, manchas amplias y alguna grieta capilar."""
    tile = 3.0
    # Moteado fino del árido con lascas claras y oscuras dispersas, sin dibujar celdas.
    grain = fractal(n, rng, beta=0.2, low=300)
    mid = fractal(n, rng, beta=1.2, low=40)
    f1, _, chip_id = voronoi(n, 240, rng)
    chip = np.clip(1.0 - f1 / 0.22, 0, 1) * (rng.random(240 * 240) < 0.35)[chip_id]
    chip_tone = rng.choice([0.6, 1.45], 240 * 240)[chip_id]
    stain = fractal(n, rng, beta=2.8, low=1)
    height = 0.35 * grain + 0.25 * mid + 0.4 * chip
    base = hexcolor("8a8984")
    shade = (0.85 + 0.25 * grain) * (0.94 + 0.1 * mid) * (0.9 + 0.16 * stain) * np.where(chip > 0.3, chip_tone, 1.0)
    color = base[None, None, :] * shade[..., None]
    rough = 0.86 + 0.1 * grain
    return color, height, rough, 3.0, tile


def adoquin(n, rng):
    """Adoquín de granito de 0,15 × 0,12 m en hiladas, con juntas de arena."""
    tile = 1.8
    px = n / tile
    w, h = 0.15, 0.12
    cols, rows = int(round(tile / w)), int(round(tile / h))
    ys, xs = np.mgrid[0:n, 0:n].astype(np.float32) / px
    row = np.floor(ys / h).astype(int)
    xs_s = (xs + (row % 2) * w * 0.5) % tile
    col = np.floor(xs_s / w).astype(int) % cols
    ident = (row % rows) * cols + col
    jx = rng.uniform(-0.008, 0.008, rows * cols)[ident]
    jy = rng.uniform(-0.006, 0.006, rows * cols)[ident]
    u = xs_s - (col + 0.5) * w + jx
    v = ys - (row + 0.5) * h + jy
    # Juntas de ~1 cm, canto nítido y cara ligeramente abombada.
    d = rounded_box(u, v, w * 0.47, h * 0.455, 0.012)
    stone = np.clip(-d / 0.003, 0, 1)
    dome = np.sqrt(np.clip(-d / 0.03, 0, 1))
    grain = fractal(n, rng, beta=1.2, low=20)
    height = dome * (0.8 + 0.2 * grain)
    palette = np.array([hexcolor(c) for c in ("a9a396", "b8b29c", "9c978d", "c2bba8", "8f8b82")])
    stone_color = palette[rng.integers(0, len(palette), rows * cols)][ident]
    sand = hexcolor("7d7466")
    color = stone_color * (0.85 + 0.2 * grain[..., None]) * stone[..., None] + sand * (1 - stone[..., None]) * (0.8 + 0.3 * grain[..., None])
    rough = 0.7 + 0.15 * grain + (1 - stone) * 0.2
    return color, height, rough, 6.0, tile


def grava(n, rng):
    """Grava compactada del paseo perimetral: guijarros de varios tamaños sobre tierra."""
    tile = 2.0
    f1, f2, ident = voronoi(n, 70, rng)
    small1, small2, small_id = voronoi(n, 150, rng)
    pebble = np.clip((f2 - f1) * 2.2, 0, 1) ** 0.6
    small = np.clip((small2 - small1) * 2.0, 0, 1) ** 0.6
    grain = fractal(n, rng, beta=1.0, low=30)
    height = np.maximum(pebble * 0.9, small * 0.6) + 0.15 * grain
    palette = np.array([hexcolor(c) for c in ("c4b89c", "a89f8c", "d6cdb5", "9a8f7a", "b8b29c")])
    big_color = palette[rng.integers(0, len(palette), 70 * 70)][ident]
    small_color = palette[rng.integers(0, len(palette), 150 * 150)][small_id]
    soil = hexcolor("8c7d63")
    top = np.where((pebble * 0.9 > small * 0.6)[..., None], big_color, small_color)
    cover = np.clip(np.maximum(pebble, small) * 1.6, 0, 1)[..., None]
    color = (top * cover + soil * (1 - cover)) * (0.85 + 0.25 * grain[..., None])
    rough = 0.85 + 0.1 * grain
    return color, height, rough, 4.0, tile


def cesped(n, rng):
    """Césped: briznas finas, matas y manchas de tono, más claro y amarillento en claros."""
    tile = 3.0
    blades = fractal(n, rng, beta=0.3, low=250)
    tufts = fractal(n, rng, beta=1.4, low=40)
    patches = fractal(n, rng, beta=2.6, low=1)
    dry = fractal(n, rng, beta=2.2, low=2)
    height = 0.55 * blades + 0.45 * tufts
    green = hexcolor("6f9a40")
    dark = hexcolor("4a7030")
    yellow = hexcolor("a3a85a")
    mix = np.clip(height * 1.2 - 0.1, 0, 1)[..., None]
    color = dark * (1 - mix) + green * mix
    dry_mask = np.clip((dry - 0.62) * 4, 0, 1)[..., None] * 0.55
    color = color * (1 - dry_mask) + yellow * dry_mask
    color = color * (0.8 + 0.3 * patches[..., None]) * (0.85 + 0.3 * blades[..., None])
    rough = 0.9 - 0.1 * blades
    return color, height, rough, 4.0, tile


MATERIALS = {"losas": losas, "asfalto": asfalto, "adoquin": adoquin, "grava": grava, "cesped": cesped}


def save(name, color, height, rough, strength):
    os.makedirs(OUT, exist_ok=True)
    rgb = (np.clip(color, 0, 1) * 255).astype(np.uint8)
    Image.fromarray(rgb, "RGB").save(os.path.join(OUT, name + "_color.webp"), quality=90, method=6)
    n = normals(height, strength * height.shape[0] / 512.0)
    Image.fromarray(((n * 0.5 + 0.5) * 255).astype(np.uint8), "RGB").save(os.path.join(OUT, name + "_normal.webp"), quality=92, method=6)
    ao = cavity(height)
    orm = np.stack([ao, np.clip(rough, 0, 1), np.clip(height, 0, 1)], -1)
    Image.fromarray((orm * 255).astype(np.uint8), "RGB").save(os.path.join(OUT, name + "_orm.webp"), quality=92, method=6)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--size", type=int, default=2048)
    parser.add_argument("--only", default="")
    args = parser.parse_args()
    only = set(filter(None, args.only.split(",")))
    for index, (name, build) in enumerate(MATERIALS.items()):
        if only and name not in only:
            continue
        rng = np.random.default_rng(1000 + index)
        color, height, rough, strength, tile = build(args.size, rng)
        save(name, color, height, rough, strength)
        print("TEXTURA %s: %d px, baldosa %.1f m" % (name, args.size, tile))


main()
