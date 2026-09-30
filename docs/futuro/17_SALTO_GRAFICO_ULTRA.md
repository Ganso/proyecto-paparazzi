# Paso 2 · Salto Gráfico: Ultra en Forward+, Modelado en Blender y Parque del Mockup

**Estado: ✅ Fases 0–5 implementadas (29/30-09-2026). Queda la optimización de §6.** Es el **paso 2** de la hoja de ruta ([README §4](README.md)) por decisión del usuario; lo que antes era el paso 2 (InputMap y AF/AE) se aplaza detrás de este.

Objetivo: abandonar el *low-poly* de primitivas y llegar a un parque con acabado profesional, cercano a [referencia.jpg](referencia.jpg), con **Ultra a 60 FPS en 2560 × 1440** en el equipo de desarrollo (Radeon RX 6700 XT de 12 GB, Ryzen 5 5500). Capturas en [`docs/evidencias/ultra/`](../evidencias/ultra/).

---

## 1. Decisiones tomadas

| Tema | Decisión |
|---|---|
| **Equipo objetivo de Ultra** | RX 6700 XT, 1440p nativos, 60 FPS (16,7 ms) con margen: objetivo ≤ 12 ms de GPU de día. La VRAM y los polígonos no se escatiman mientras el rendimiento se mantenga: límites de 8 GiB y 5 M de triángulos |
| **Renderizador de Ultra** | `forward_plus` (Vulkan). Bajo, Medio y Alto siguen en `gl_compatibility` |
| **Modelado** | Scripts de **Blender** versionados en `tools/blender/`, ejecutados sin interfaz (`blender -b -P`). Nada se modela a mano: todo se regenera |
| **Alcance del salto** | **Todos los perfiles**: cada objeto sale de Blender en dos niveles de detalle, `hd` (Ultra) y `lo` (Bajo, Medio, Alto) |
| **Texturas** | Generadas por código (`tools/texturas/build_textures.py` y shaders procedurales): el usuario prefirió no descargar texturas de terceros. Se permiten recursos CC0 si hicieran falta, registrándolos en `assets/LICENCIAS.md` |
| **Peana de diorama** | **Eliminada**: el parque se abre a una pradera con quiosco y estanque, como en el mockup |
| **Prioridad** | Primero la calidad visual; la optimización (§6) después |

---

## 2. Arquitectura

### 2.1 Perfiles y renderizador
- El perfil se guarda en `override.cfg` (clave `paparazzi/graficos/perfil`), junto con `rendering/renderer/rendering_method`. Godot lo lee al arrancar: en el directorio del proyecto al jugar desde el código y junto al ejecutable en una exportación. No se versiona (`.gitignore`).
- **Todos los perfiles de escritorio usan Forward+** (decisión del usuario del 30-09-2026: con OpenGL, Alto parecía «super bajo»). Son **subconjuntos de Ultra orientados al rendimiento**: misma escena `hd`, mismos maniquíes, color, curva de tono, gradación y niebla; solo reducen resolución interna (FSR 2), efectos y densidad de hierba (`park.gd::EFFECTS`, `main.gd::RENDER_SCALE`). El cambio de perfil es en caliente, sin reinicio. `gl_compatibility` queda para Android (preset del APK) y como respaldo sin Vulkan, con la escena `lo` y como máximo Alto.
- Primera vez en escritorio: Ultra si hay GPU dedicada, Alto en otro caso; en móvil, Medio (`main.gd::startup_profile()`). `override.cfg` guarda solo el perfil (las versiones anteriores guardaban también el renderizador; se borra al guardar).
- **Detalle por renderizador**: el parque (`Park.detail`) y los maniquíes (`Person.detail`) se construyen en `hd` en Forward+ y en `lo` en `gl_compatibility`.
- **Resolución** (`main.gd::update_render_resolution()`): en Forward+ el `SubViewport` del visor iguala los píxeles físicos de la ventana y cada perfil renderiza internamente a una fracción (Ultra 100 % con MSAA 4×, Alto 85 %, Medio 70 %, Bajo 50 %, con FSR 2). Todo el código normaliza por `viewport.size`, así que foco, fotómetro y puntuación no cambian.
- En el equipo de desarrollo, Ultra se ejecuta con el binario oficial `~/bin/godot-4-fp` (el snap de `godot-4` no arranca Vulkan): ver [TESTS §1](../TESTS_Y_VERIFICACION.md).

### 2.2 Proceso de Blender
```
tools/blender/build_park_assets.py  --(blender -b -P)-->  assets/parque/<objeto>.glb
                                                          mallas "<lod>[_<variante>][_<rol>]"
tools/texturas/build_textures.py    --(python3)-------->  assets/texturas/<material>_{color,normal,orm}.webp
tools/build_park_assets.sh          ejecuta los dos
```
- Cada objeto se genera por código (bmesh con biseles, tornos, barridos y ruido) con su **color base y oclusión horneados en el color de vértice** por Cycles, cada malla aislada durante el horneado. Así entra en la fusión por sectores de [16](16_PARQUE_ILUSTRADO_QUICK_WIN.md) sin materiales nuevos.
- Roles con material propio: `glass` (vidrio), `bulb` (bombillas emisivas), `water` y `spray` (agua quieta y en movimiento), `windows` (ventanas nocturnas) y `trunk` (madera de los árboles, que solo separa su colisionador).
- El juego lee los `.glb` en tiempo de ejecución con `GLTFDocument` (`scripts/park_assets.gd`) y convierte solo el nivel de detalle pedido, sin pasar por el importador: jugar desde el código (`Jugar.bat`) funciona en un clon limpio. El preset Android incluye `assets/parque/*.glb` y excluye `assets/texturas/*`, que solo usa Ultra.

| Objeto | Triángulos `hd` / `lo` |
|---|---|
| Banco (listones de teca, bastidores de fundición, tornillería) | 6.852 / 432 |
| Farola (base moldurada, fuste estriado, linterna) | ~2.500 / ~420 |
| Papelera, jardinera (3 variantes de flor), pilar de piedra | 1.278 / 158 · 6.968 / 124 · 1.844 / 48 |
| Tramo de verja de lanzas (72) | 1.418 / 50 |
| Árboles: 4 especies × 4 variantes | ~2.500–4.000 / ~150–300 |
| Arbusto (6 variantes), quiosco, estanque, torre (6 estilos) | 240–320 / 20 · ~13.300 / ~770 · ~2.600 / ~330 · ~500–700 / 24–100 |

### 2.3 Reglas de coherencia (obligatorias)
1. **Los colisionadores no cambian con el perfil.** Siguen siendo las primitivas de siempre sin malla visible (`Park.collider_only`) o se sacan de la envolvente de la malla `lo` (árboles, quiosco, estanque). Los maniquíes `hd` construyen sus colisionadores con las piezas base.
2. **Dentro de la zona jugable** ($r < 12.8\text{ m}$), la malla visible de cada objeto ocupa el mismo volumen que su colisionador.
3. **Fuera de la zona jugable**, la geometría es libre. Lo que solo dibuja `hd` (segunda franja de arbolado a 46–52 m y matas de la pradera, `Park.hd_only`) conserva sus colisionadores en todos los perfiles: nunca tapa a un viandante y a esa distancia el sol rasante pasa por encima.
4. Lo añadido por debajo de 0,3 m (hierba instanciada, bordillos) no lleva colisionador.

---

## 2.4 Perfiles de escritorio (Forward+)

| Perfil | Resolución interna | SDFGI | SSAO | SSIL / SSR | Niebla volumétrica | Penumbra | Atlas sol | Hierba | Profundidad de campo | GPU a 1440p (día) |
|---|---|---|---|---|---|---|---|---|---|---|
| **Ultra** | 100 % + MSAA 4× | 4 cascadas | Sí | Sí | Sí | Sí | 4096 | 100 % | Sí | 10,9 ms |
| **Alto** | 85 % (FSR 2) | 4 cascadas | Sí | No | Sí | Sí | 4096 | 70 % | Sí | 7,8 ms |
| **Medio** | 70 % (FSR 2) | 3 cascadas | Sí | No | No | No | 2048 | 45 % | No | 3,9 ms |
| **Bajo** | 50 % (FSR 2) | No (ambiente calibrado por hora, `NO_GI_AMBIENT`) | No | No | No | No | 2048 | 20 % | No | 2,2 ms |

Sombras de farola de noche: Ultra las 12, Alto las 4 interiores, Medio y Bajo ninguna. La hierba se baraja al construirla (`set_grass_fraction()` usa `visible_instance_count`), así que cada densidad aclara el césped por igual.

## 2.5 Destellos en los maniquíes (resuelto el 30-09-2026)
- **Síntoma**: puntos blancos de un fotograma sobre articulaciones y piezas de los maniquíes.
- **Diagnóstico**: ráfagas de capturas (`--screenshot=… --burst=<n>`), un detector de píxeles que solo brillan en un fotograma y un pase de depuración que pinta de magenta los píxeles no finitos (`--debug-off=nanview`, `shaders/debug_nan.gdshader`). Eran píxeles NaN aislados que el glow convertía en discos: sobre todo en el casco invertido del contorno de tinta y en el ala del sombrero vista de canto; `atan(0, 0)` en los patrones y el cielo en la profundidad de campo añadían algunos.
- **Corrección**: contorno de tinta retirado (`Person.OUTLINE = false`, decisión del usuario: el estilo realista no lo necesita), ángulo seguro en los patrones (`axis_angle()`), profundidad del cielo acotada y el pase de profundidad de campo, que va antes del glow, sustituye cualquier píxel no finito por la media de sus vecinos. Resultado: 0 destellos en 300 fotogramas (antes, en el 5–9 % de los fotogramas).
- `--debug-off=<lista>` apaga efectos para aislar artefactos: `ssr`, `ssil`, `ssao`, `sdfgi`, `glow`, `volumetric`, `dof`, `textured`, `clearcoat`, `rim`, `lamps`, `pcss`, `sun_shadow`, `pbr`, `outline`, `lo_people`, `nanview`.

## 3. Presupuestos

| Nivel | Perfiles | Renderizador | Resolución 3D | Triángulos en escena | Por maniquí | VRAM |
|---|---|---|---|---|---|---|
| `lo` | Android y respaldo sin Vulkan | `gl_compatibility` | 1280 × 720 | ≤ 100.000 | ≤ 1.900 | < 60 MB |
| `hd` | **Bajo, Medio, Alto y Ultra** en escritorio | `forward_plus` | Nativa × escala del perfil | ≤ 5.000.000 | ≤ 60.000 (maniquíes de Blender, [18](18_PERSONAJES_BLENDER.md)) | < 8 GiB |

Cifras medidas en [TESTS §5](../TESTS_Y_VERIFICACION.md): Ultra a 2560 × 1440 va a 10,3 ms de GPU de día y 11,8 ms de noche con 2,4 M de triángulos y todo el postprocesado (sin la profundidad de campo, 7,3 y 8,9 ms).

---

## 4. Fases

| Fase | Contenido | Estado |
|:---:|---|:---:|
| **0** | Perfiles con renderizador en `override.cfg` y reinicio, resolución nativa en Ultra, entorno Forward+ (SDFGI, SSAO, SSIL, SSR, niebla volumétrica, glow, sombras 4096 con penumbra, MSAA 4×), colores de vértice correctos en Ultra, métricas de GPU (`--metrics`), opciones `--profile`, `--time`, `--angle`, `--pitch` y `--focal`; peana eliminada | ✅ |
| **1** | Proceso de Blender y mobiliario: banco, farola, papelera, jardinera, verja de lanzas con pilares de piedra | ✅ |
| **2** | Suelo: texturas procedurales de losas, asfalto, adoquín, grava y césped en `Texture2DArray` (`shaders/park_ground.gdshader`) y bordillos de piedra (`hd`) | ✅ |
| **3** | Vegetación: 4 especies de árbol con ramas y racimos, 4 variantes cada una, y 6 de arbusto; apertura del muro de árboles | ✅ |
| **4** | Pradera exterior: quiosco iluminado, estanque con fuente y agua animada, tres farolas, verja abierta ante ambos, arbolado lejano en dos franjas, horizonte de torres con ventanas nocturnas y niebla abierta en todos los perfiles | ✅ |
| **5** | Maniquíes `hd` (`data/piezas_hd`, rótulas lisas) con sombreado realista (`mannequin_pbr.gdshader`: madera barnizada y tela, sin bandas toon ni contorno) y texturas procedurales de madera, punto, sarga y pelo; hierba instanciada que se mece con el viento | ✅ |
| **7** | Perfiles de escritorio como subconjuntos de Ultra en Forward+ (§2.4) y destellos resueltos (§2.5) | ✅ |
| **6** | Postprocesado: gradación de color por hora con LUT 3D generada por código (Alto y Ultra), profundidad de campo exacta en el visor (`viewfinder_dof.gdshader`, misma fórmula que `Photography.coc()`, solo Ultra) y carácter de objetivo (`viewfinder_lens.gdshader`: viñeteo y aberración cromática según la focal, en todos los perfiles salvo Bajo) | ✅ |

---

## 5. Criterios de aceptación y pruebas
- ✅ `--metrics` imprime el tiempo de GPU sin sincronía vertical. Ultra a 2560 × 1440: 7,27 ms de día y 8,86 ms de noche (objetivo ≤ 12 y ≤ 16).
- ✅ `--profile=<nombre>` fuerza un perfil y `--smoke-test` comprueba los presupuestos de su nivel de detalle (escena y por maniquí).
- ✅ `test_game.gd`: perfil inicial y nivel de detalle según el renderizador, VRAM y superficies por nivel, suelo texturizado solo en `hd` y antialiasing (MSAA en Forward+, FXAA en `gl_compatibility`).
- ✅ `test_export.gd`: los `.glb` van en el APK y las texturas no.
- ✅ `test_photography.gd`, `test_equipment.gd`, `test_art.gd`, `test_gait.gd`, `test_navigation.gd` y `test_expansion.gd` sin cambios.
- ✅ `./tools/run_evidence.sh` añade las capturas de Ultra a 1440p (`tools/capture_ultra.sh`).
- ✅ Profundidad de campo del visor: cada píxel se desenfoca con su círculo de confusión real, con orden de profundidad (un fondo desenfocado no mancha a un sujeto nítido). La foto se captura de esa misma imagen y, en ese caso, el revelado ya no difumina todo el fotograma (`evidence.rendered_dof`). La puntuación no cambia: sigue calculándose con la fórmula, no con los píxeles. Coste: ~3 ms a 1440p.
- ✅ Calentamiento de shaders al arrancar (`main.gd::warm_up_view()`): la cámara da una vuelta tras la pantalla de inicio para que el agua, la hierba y las ventanas no se compilen a mitad de partida.

---

## 6. Pendiente (optimización)
- **VRAM en `gl_compatibility`**: `test_game.gd` mide 59,91 MiB (límite 57,2 MiB; antes 50,5). El exceso está en los búferes (18,98 MiB) y crece durante la sesión, no al construir el parque. Opciones: menos árboles `lo` en la pradera, mallas `lo` indexadas sin duplicar vértices y liberar los datos de CPU de las superficies fusionadas.
- **Tiempo de construcción** del parque `hd` (Blender, hierba, texturas): medirlo y cachear si pesa.
- **Mobiliario de la pradera**: bancos y paseos de grava dentro de la pradera, gente de ambiente fuera de la zona jugable (02 §10.2).
- Los `.glb` se leen sin importar; si en el futuro se abre el proyecto en el editor, conviene marcar `assets/parque/*.glb` con el importador `keep` para que no se dupliquen como escenas.
