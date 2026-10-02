# 23 · Gráficos personalizados y opciones de pantalla

**Estado: ✅ Implementado (03-10-2026)**, encargo del usuario.

## 1. Un perfil más: Personalizado (`scripts/graphics.gd`)

Los cuatro perfiles (Bajo, Medio, Alto, Ultra) son ahora **tablas de los mismos parámetros** (`Graphics.PRESETS`) y `park.gd` y `main.gd` leen todo de `Graphics.settings(perfil)`: ningún nombre de perfil decide un efecto por su cuenta. **Personalizado** es una tabla que el jugador edita a mano en la pantalla de gráficos (lista con desplazamiento, por grupos), se aplica al momento y se guarda en `user://graficos.cfg`. La primera vez parte de una copia del perfil activo; «Partir de:» la rellena con cualquiera de los cuatro.

Puede ir **más allá de Ultra** (todo ello desactivado o en su valor normal por defecto):

| Grupo | Parámetro | Valores (en negrita, por encima de Ultra) |
|---|---|---|
| Imagen | Resolución 3D | 50–100 %, **125 %, 150 %, 200 % (supermuestreo)** |
| | Reescalado bajo 100 % | FSR 2, FSR 1, bilineal |
| | MSAA | No, 2×, 4×, **8×** |
| | TAA · antialiasing de pantalla | **TAA** · No, **FXAA, SMAA** |
| | Curva de tonos | ACES, **AgX, Filmic** |
| Luz | Iluminación global SDFGI | No, 2, 3, 4, **6, 8** cascadas · rayos normal, **16–128** |
| | SSAO | No, baja, media, **alta, ultra** |
| | SSIL · SSR · niebla volumétrica · resplandor | sí / no |
| Sombras | Sol: alcance | No, 30, 38, 48, **64, 80 m** |
| | Mapa de sombras del sol | 2048, 4096, **8192, 16384** |
| | Suavizado | normal, duras, baja, media, **alta, ultra** |
| | Penumbra física · farolas · mapa de farolas | sí/no · ninguna, 4 interiores, todas · 2048, 4096, **8192** |
| Detalle | Hierba · vetas y tejidos · filtrado anisótropo del suelo · detalle de mallas | 0–100 % · sí/no · no, 2×, 4×, 8×, 16× · normal, **máximo siempre** |

El **filtrado anisótropo** (`aniso`, 02-10-2026) mantiene nítidas las losas y el adoquín vistos casi de canto, a lo lejos: Bajo 2×, Medio 4×, Alto 8× y Ultra 16× (antes, 4× fijo del proyecto). Se aplica con `Viewport.anisotropic_filtering_level` en `main.gd::apply_graphics_preset()`; comprobado en `test_game.gd`.
| Cámara | Profundidad de campo en el visor · viñeteo y aberración | sí / no |

- **Desenfoque de movimiento**: Godot no lo tiene. Se probó uno propio en el pase de posprocesado del visor (solo por el movimiento de la cámara) y se descartó el mismo día a petición del usuario: no desenfocaba a las personas y dejaba halos en los bordes.
- **Trazado de rayos**: Godot 4.7 no lo tiene; la iluminación global más avanzada es SDFGI, cuyas cascadas y rayos sí se pueden subir.
- **GPU integradas**: en los perfiles SDFGI sigue desactivado (`park.gd::sdfgi_cascades()`); en Personalizado manda lo que elija el jugador, y la pantalla lo avisa.
- Los ajustes de calidad globales del renderizador (filtro de sombras, calidad de SSAO, rayos de SDFGI) vuelven a los valores del proyecto al salir de Personalizado.
- FSR 2 es temporal y hace su propio antialiasing: MSAA y TAA solo actúan a resolución nativa o superior.

Coste medido en la RX 6700 XT a 2560 × 1440 de día (`--metrics`): Ultra 11,4 ms; Personalizado con 150 %, MSAA 8×, SMAA, SDFGI 6 cascadas y 64 rayos, SSAO ultra y sombras 8192 ultra a 80 m, 38,4 ms.

## 2. Pantalla (cualquier perfil)

Modo **Ventana**, **Ventana a pantalla completa** (sin bordes) o **Pantalla completa** (exclusiva); tamaño de la ventana (1280 × 720 a 3840 × 2160, limitado a la pantalla y centrado) o, a pantalla completa, **resolución de la imagen 3D** (la nativa de la pantalla o una menor, que se escala para llenarla: la resolución del escritorio no se cambia; `Graphics.fullscreen_height()`) sincronización vertical y **contador de FPS** (arriba a la izquierda, media del último medio segundo y tiempo por fotograma; `main.gd::update_fps_counter()`). Se guarda en `user://graficos.cfg` (`[pantalla]`) y se aplica al arrancar una partida normal, nunca en pruebas, capturas ni ejecuciones guionizadas. La vista 3D sigue los píxeles de la ventana (`update_render_resolution()`).

## 3. Pruebas y herramientas

- `tests/test_game.gd`: las tablas de los perfiles coinciden con los efectos documentados, cada opción edita un parámetro, Personalizado se guarda y se lee, sube por encima de Ultra (supermuestreo, MSAA 8×), apaga las sombras de farola a mano, volver a Ultra restaura sus valores y la pantalla se recuerda.
- `--profile=Personalizado` arranca con él. La variable `PAPARAZZI_GFX_CFG` apunta a otro fichero de ajustes (pruebas y capturas no tocan el del jugador).

## 4. Pendiente

Filtrado anisotrópico (exige reiniciar), VoxelGI o LightmapGI horneados y probar los valores extremos en otras GPU.
