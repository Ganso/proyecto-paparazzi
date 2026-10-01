# Licencias de los recursos gráficos

Los recursos de `assets/` se generan con el código de este repositorio, salvo la música de los vídeos, que aporta el usuario. El único material de terceros son las fuentes (abajo, con su licencia).

| Carpeta | Origen | Regenerar |
|---|---|---|
| `parque/*.glb` | `tools/blender/build_park_assets.py` (Blender 4.3, sin interfaz) | `./tools/build_park_assets.sh` |
| `audio/musica_videos.mp3` | Música propia del usuario (proyecto GamerConFamilia, «Tutorial #1 [180s]», 3 min 5 s). **Música de fondo oficial de los vídeos del proyecto** | Copia manual; la usa `tools/capture_video.sh` |
| `audio/ambiente/*.wav` | Sonido ambiente sintetizado por `tools/audio/build_ambience.py` (Python + numpy + scipy): pájaros, fuente, grillos, zureo y aleteo | `python3 tools/audio/build_ambience.py` |
| `audio/camara/*.wav` | Sonidos de disparo de cada cuerpo sintetizados por `tools/audio/build_camera_sounds.py` | `python3 tools/audio/build_camera_sounds.py` |
| `fuentes/Quicksand-*.ttf` | Quicksand, de Andrew Paglinawan (licencia SIL Open Font License 1.1), copiada del paquete Debian `fonts-quicksand` | — |
| `fuentes/Roboto-*.ttf` | Roboto, de Google (licencia Apache 2.0), copiada del paquete Debian `fonts-roboto-unhinted` | — |
| `texturas/*.webp` | `tools/texturas/build_textures.py` (Python + numpy) | `./tools/build_park_assets.sh` |

Si se incorpora un recurso de terceros (preferentemente CC0: Poly Haven, ambientCG, Quaternius), se registra aquí con su autor, URL, licencia y fecha ([docs/futuro/17 §1](../docs/futuro/17_SALTO_GRAFICO_ULTRA.md)).
