# 27. Versión web (HTML5, en el navegador)

> **Estado**: 🚧 **En curso (Fase 1 completada, Fase 2 en depuración)**.
> - **Logrado**: Preajuste Web sin hilos configurado en `export_presets.cfg`, integrado en `tools/export_all.sh`, arranque forzado en perfil «Bajo» en web, shell HTML ligera con botón inicial interactivo antes de cargar WASM, modal de bienvenida centrado sin desbordamiento, y fuentes Quicksand y Roboto reimportadas como `FontFile` dinámico.
> - **Puntos pendientes inmediatos para la próxima sesión**:
>   1. Glifos de teclas y flechas (ej. `⟦←⟧⟦→⟧⟦↑⟧⟦↓⟧` en `mirar` y tutorial) que aparecen como rectángulos de tofu/código en web: la fuente actual no incluye estos símbolos unicode en webgl o no tiene el fallback configurado en FontFile.
>   2. Re-exportar Web con el fix sintáctico de `func draw_art()` en `scripts/boot_loader.gd` para eliminar los errores del log.
>   3. Opciones de gráficos en web: pantalla de opciones adaptada (sin cambio de ventana para no desconfigurar el canvas del navegador).

## 1. Valoración

**Sí se puede, y con poco riesgo técnico.** Godot exporta a WebAssembly y WebGL 2, y el juego ya tiene todo lo que eso exige porque es lo mismo que pide Android:

- un renderizador `gl_compatibility` con su escena ligera (`lo`), que es el único que funciona en el navegador;
- una interfaz táctil ([13](13_INTERFAZ_MOVIL_UTILIZABLE.md)) para tabletas y móviles;
- todo en GDScript (C# no se puede exportar a web en Godot 4).

### La prueba

Exportación con un preajuste «Web» temporal (variante **sin hilos**, la que no necesita cabeceras especiales en el servidor), servida en local y abierta en el navegador integrado (Chromium):

| | Resultado |
|---|---|
| Exportación | Unos segundos, sin errores |
| Arranque | Llega al menú; WebGL 2.0, renderizador Compatibility, un solo hilo |
| Juego | Entrar en el tutorial, mirar arrastrando, hacer una foto y ver su resultado: funciona |
| Fluidez | 60 fotogramas por segundo (en el PC del desarrollo, con una RX 6700 XT: no dice nada de un portátil modesto) |
| Errores en consola | Ninguno del juego; avisos de WebGL durante la carga (un búfer de tamaño cero) |
| Tamaño | `index.wasm` 38 MB (10 MB comprimido) + `index.pck` 70 MB (36 MB comprimido): **unos 46 MB de descarga** con compresión en el servidor, 108 MB sin ella |

No se probó: sonido, guardado entre sesiones, mando, pantalla completa, el parque grande, Firefox ni Safari, ni ningún móvil.

### Lo que se gana

- **Probarlo sin instalar nada**: un enlace. Es la manera más directa de enseñar el proyecto y de cumplir su idea (que alguien entienda y disfrute la fotografía) con la menor fricción.
- itch.io aloja juegos HTML5 y los incrusta en la propia ficha.
- Sirve también para iPhone y iPad sin pasar por la tienda de Apple (con las limitaciones de Safari).

### Lo que se pierde frente al escritorio

- **El aspecto**: en el navegador se ve la versión de Android, no la de escritorio. Sin Forward+, sin los maniquíes y objetos de Blender en alta, sin hierba, sin el cielo propio ni la profundidad de campo en el visor, y sin palomas, patos, perro ni figurantes. Mejorar eso es el mismo trabajo que el bloque D de [26](26_ANDROID_PERFECTO.md).
- **El tamaño**: 46 MB de descarga antes de ver nada es mucho para una web; hay que recortar y poner una buena pantalla de carga.
- **Un solo hilo**: la carga de piezas y texturas, que en el escritorio va en paralelo, aquí va en serie; el arranque es más lento y puede haber tirones.

### Riesgos

| Riesgo | Gravedad | Nota |
|---|---|---|
| Rendimiento en portátiles con gráfica integrada y en móviles | Alta | Sin medir. Es el mismo problema que en Android (35 FPS en un gama media-alta) con la penalización añadida de WebAssembly |
| Tamaño de la descarga | Media | Se puede bajar: el paquete incluye las piezas `hd` y texturas que el navegador no usa |
| Sonido: el navegador no deja sonar nada hasta el primer clic, y la latencia es mayor | Media | Hay que arrancar el sonido tras un gesto del usuario |
| Safari (macOS, iOS): WebGL 2 con fallos propios y límites de memoria | Media | Sin probar |
| Captura del ratón al pasear por el parque grande: exige un clic previo y Escape la suelta | Baja | Convive mal con Escape como pausa |
| Guardado: va al almacenamiento del navegador, que el usuario puede borrar | Baja | Aceptable; avisarlo |

**Conclusión**: merece la pena como **escaparate y puerta de entrada**, no como la versión principal. El coste de tener una primera versión publicable es pequeño (bloques A y B); lo caro es que se vea y vaya tan bien como el escritorio, y eso se comparte casi por entero con el trabajo de Android.

## 2. Lo que falta

**Esfuerzo**: S (horas), M (un día), L (varios días).

### A. Exportación y publicación

| # | Qué falta | Por qué | Esfuerzo |
|---|---|---|:---:|
| A1 | **Preajuste «Web»** en `export_presets.cfg` (sin hilos, sin extensiones) y `web` en `tools/export_all.sh`, con un zip listo para subir | ✅ Configurado con paquete optimizado y reglas de exclusión | S |
| A2 | **Paquete propio del navegador**: sin `data/piezas_hd/`, sin texturas de suelo ni modelos `hd`, sin la música de los vídeos | ✅ Excluidos en el preset Web de exportación | S |
| A3 | Compresión en el servidor (gzip o Brotli) y comprobar que el alojamiento la aplica; alternativa: fragmentar el paquete | De 108 MB a unos 46, y menos tras A2 | S |
| A4 | **Página propia**: pantalla de carga con la marca y barra de progreso, mensaje si el navegador no tiene WebGL 2, botón de pantalla completa | La página por defecto de Godot es un lienzo negro con un logotipo | M |
| A5 | **Publicar en itch.io** como juego HTML5 (tamaño del marco, pantalla completa, móvil) y, si se quiere, en GitHub Pages | Distribución inmediata | S |
| A6 | Decidir **con hilos o sin hilos**: con hilos va más fluido, pero el servidor tiene que enviar cabeceras de aislamiento (itch.io lo ofrece como opción; GitHub Pages no) | La prueba fue sin hilos | S |
| A7 | Aplicación web instalable (PWA) con funcionamiento sin conexión | Opcional: icono en el escritorio o en el móvil | M |

### B. Funcionamiento en el navegador

| # | Qué falta | Por qué | Esfuerzo |
|---|---|---|:---:|
| B1 | **Sonido**: arrancarlo tras el primer clic o toque, y comprobar ambiente, obturador y pitidos | Norma de todos los navegadores; sin probar | S |
| B2 | **Guardado** del progreso, las opciones y el álbum en el almacenamiento del navegador (`user://` sobre IndexedDB): comprobar que persiste entre visitas | Sin probar | S |
| B3 | **Álbum**: descargar una foto como fichero (no hay carpeta que abrir) | El botón «Abrir la carpeta» ya se oculta en web | S |
| B4 | **Captura del ratón** en el parque grande: pedirla con un clic y convivir con Escape, que la suelta | En el navegador Escape es del navegador | M |
| B5 | **Teclas que el navegador se queda**: Tab, F1, Ctrl, Re Pág, Av Pág, espacio (desplaza la página) | Varias son controles del juego | S |
| B6 | Pantalla completa y cambio de tamaño de la ventana; ocultar en Opciones lo que no aplica (modo de pantalla, tamaño de ventana, perfiles de escritorio) | La pantalla de gráficos es la del escritorio | S |
| B7 | **Detección de pantalla táctil** en el navegador para activar la interfaz táctil en tabletas y móviles | Hoy solo se activa en Android/iOS nativos o con `--touch` | S |
| B8 | Mando en el navegador (API Gamepad) | Debería funcionar; sin probar | S |
| B9 | Argumentos de arranque por la dirección (`?nivel=3`, `?tactil=1`) para enlazar a un modo o a una lección | Enlaces directos a una lección de la Academia | S |

### C. Rendimiento y aspecto

| # | Qué falta | Por qué | Esfuerzo |
|---|---|---|:---:|
| C1 | **Medir** en un portátil con gráfica integrada, en Firefox y Safari, y en móviles | Solo se ha visto en un PC potente con Chromium | M |
| C2 | Carga sin hilos: repartir la preparación de piezas y texturas en varios fotogramas, con progreso visible | En un hilo, la carga bloquea la página | M |
| C3 | Precompilar sombreadores durante la carga | En WebGL la primera aparición de cada material da un tirón | M |
| C4 | Límite de memoria del navegador (sobre todo en iOS) | Sin medir | S |
| C5 | Acercar el aspecto al del escritorio dentro de `gl_compatibility` | Es el bloque D de [26](26_ANDROID_PERFECTO.md): se hace una vez para Android y web | L |

### D. Calidad

| # | Qué falta | Por qué | Esfuerzo |
|---|---|---|:---:|
| D1 | **Batería del navegador** (`tools/test_web.sh`): exportar, servir en local, abrir en un navegador sin ventana y comprobar arranque, consola sin errores, una foto y los fotogramas por segundo | Como `tools/test_android.sh`; la prueba de hoy fue a mano | M |
| D2 | Prueba de humo dentro del navegador (argumento por la dirección) | Los mismos invariantes que en Android | S |
| D3 | Matriz de navegadores: Chrome, Firefox, Safari, y Chrome y Safari en móvil | Cada uno tiene sus fallos | M |

## 3. Orden propuesto

1. **Primera versión publicable** (A1, A2, A3, A5, B1, B2, B5): un enlace en itch.io que se puede jugar con teclado y ratón.
2. **Que se use bien** (A4, B3, B4, B6, B7, D1): página propia, táctil en tabletas y red de pruebas.
3. **Que vaya y se vea bien** (C1–C5): compartido con Android; es donde está el coste de verdad.

## 4. Cómo se hizo la prueba (para repetirla)

Preajuste añadido temporalmente a `export_presets.cfg`: plataforma `Web`, los mismos filtros que Windows, `variant/thread_support=false`, `variant/extensions_support=false`, `html/canvas_resize_policy=2`. Después:

```bash
~/bin/godot-4-fp --headless --path . --export-release "Web" build/web/index.html
cd build/web && python3 -m http.server 8765      # y abrir http://localhost:8765/index.html
```

Las plantillas de exportación web de Godot 4.7.2 ya están instaladas en el equipo.
