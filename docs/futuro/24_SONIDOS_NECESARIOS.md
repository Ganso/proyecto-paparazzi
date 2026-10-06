# 24 · Efectos de sonido que hacen falta

**Estado: ⏳ Pendiente de recibir los sonidos del usuario** (lista enviada el 03-10-2026 y ampliada el 06-10-2026 con el apartado E; él avisará cuando los tenga). Hoy todo el sonido es sintetizado: `tools/audio/build_ambience.py` (ambiente), `tools/audio/build_camera_sounds.py` (obturadores) y tonos generados en `main.gd::play_tone()`.

## Formato de entrega

- **WAV, 48 kHz (o 44,1 kHz), 16 bits.** Sin compresión ni normalización agresiva; pico a unos −3 dBFS.
- **Mono** todo lo que suena desde un punto del parque o de la cámara; **estéreo** solo los ambientes de fondo, la interfaz y la música.
- **Secos**, sin reverberación ni música de fondo: el juego coloca cada sonido en el espacio.
- **Bucles**: que empalmen sin clic (corte en cruce por cero, sin fundidos de entrada ni salida).
- **Variaciones**: donde se piden varias, ficheros separados y numerados (`pasos_grava_1.wav`…), parecidos pero no idénticos.
- **Sin siseo constante**: el fondo de viento o ciudad continuo se descartó por molesto (01-10-2026). El ambiente son sonidos sueltos sobre silencio.
- Nombres como los de la tabla. Si un sonido viene de una grabación libre, anotar su licencia para `assets/LICENCIAS.md`.

## A. Cámaras (mono, un disparo salvo que se diga)

| N.º | Nombre | Qué es | Duración | Bucle | Var. |
|---|---|---|---|---|---|
| 1 | `obturador_reflex` | Réflex mecánica de los 80: golpe del espejo y cortinilla, a 1/125 | 0,3–0,5 s | No | 1 |
| 2 | `obturador_reflex_lento` | La misma a 1/8: espejo arriba, pausa audible, espejo abajo | 0,6–1,0 s | No | 1 |
| 3 | `obturador_telemetrica` | Cortinilla de tela de una telemétrica: «clic» suave y corto | 0,15–0,25 s | No | 1 |
| 4 | `obturador_compacta` | Compacta digital: clic electrónico con un leve zumbido | 0,25–0,4 s | No | 1 |
| 5 | `obturador_tlr` | Obturador central de una TLR: «tic» metálico muy corto y seco | 0,1–0,2 s | No | 1 |
| 6 | `manivela_tlr` | Avance de película: media vuelta de manivela con trinquete y retorno | 0,8–1,2 s | No | 1 |
| 7 | `carrete_nuevo` | Cargar un rollo: abrir la tapa, encajar, cerrar | 2–3 s | No | 1 |
| 8 | `af_confirmado` | Doble pitido de enfoque conseguido | 0,15–0,25 s | No | 1 |
| 9 | `af_fallo` | El autofoco no encuentra: zumbido corto de ida y vuelta, o pitido grave | 0,3–0,5 s | No | 1 |
| 10 | `motor_af` | Motor de enfoque de la réflex moviéndose | 0,2–0,4 s | No | 2 |
| 11 | `zoom_compacta` | Motor del zoom de la compacta en marcha | 1–2 s | **Sí** | 1 |
| 12 | `zoom_compacta_fin` | El mismo motor al pararse | 0,15 s | No | 1 |
| 13 | `anillo_enfoque` | Un «paso» del anillo de enfoque manual (roce con clic leve) | 0,03–0,06 s | No | 4 |
| 14 | `dial` | Un clic de dial de velocidades o de diafragma | 0,03–0,08 s | No | 3 |
| 15 | `camara_subir` | Llevarse la cámara al ojo: roce de correa y ropa | 0,3–0,5 s | No | 1 |
| 16 | `camara_bajar` | Bajarla: el mismo roce, con el golpecito al colgar | 0,3–0,5 s | No | 1 |

## B. Ambiente del parque

| N.º | Nombre | Qué es | Duración | Bucle | Canales | Var. |
|---|---|---|---|---|---|---|
| 17 | `pajaros_dia` | Pájaros de parque urbano, variados y con pausas; sin tráfico ni viento | 30–60 s | **Sí** | Estéreo | 1 |
| 18 | `pajaros_atardecer` | Hora dorada: mirlos, cantos más espaciados | 30–60 s | **Sí** | Estéreo | 1 |
| 19 | `hora_azul` | Últimos pájaros y primeros grillos | 30–60 s | **Sí** | Estéreo | 1 |
| 20 | `grillos_noche` | Grillos de noche | 20–40 s | **Sí** | Estéreo | 1 |
| 21 | `fuente` | Agua de una fuente cayendo en su estanque, de cerca | 8–15 s | **Sí** | Mono | 1 |
| 22 | `hojas_viento` | Una ráfaga suave en las copas de los árboles (suelta, no continua) | 4–8 s | No | Mono | 3 |
| 23 | `zureo` | Arrullo de paloma | 1–2 s | No | Mono | 3 |
| 24 | `aleteo_bandada` | Una bandada de palomas alzando el vuelo | 1,5–2,5 s | No | Mono | 2 |
| 25 | `aleteo_paloma` | Una sola paloma apartándose | 0,4–0,6 s | No | Mono | 2 |

## C. Gente, animales y juegos (mono)

| N.º | Nombre | Qué es | Duración | Bucle | Var. |
|---|---|---|---|---|---|
| 26 | `paso_grava` | Un paso sobre grava | 0,2–0,3 s | No | 6 |
| 27 | `paso_losa` | Un paso sobre losas o adoquín | 0,15–0,25 s | No | 6 |
| 28 | `paso_cesped` | Un paso sobre hierba | 0,2–0,3 s | No | 4 |
| 29 | `paso_corredor` | Zancada de alguien corriendo (zapatilla sobre firme) | 0,15–0,25 s | No | 4 |
| 30 | `charla` | Dos personas hablando sin que se entienda nada | 10–15 s | **Sí** | 2 |
| 31 | `risa` | Una risa corta de adulto | 1–2 s | No | 3 |
| 32 | `ninos_jugando` | Voces y risas de niños jugando, sin palabras claras | 15–30 s | **Sí** | 1 |
| 33 | `columpio` | Chirrido de las cadenas de un columpio: **un vaivén completo de 2,73 s exactos** (el columpio del juego va a ese ritmo) | 2,73 s | **Sí** | 1 |
| 34 | `tobogan` | Un niño deslizándose por un tobogán metálico | 1,0–1,3 s | No | 1 |
| 35 | `balon_patada` | Patada a un balón | 0,2 s | No | 2 |
| 36 | `balon_bote` | Bote de un balón en la hierba | 0,15 s | No | 2 |
| 37 | `perro_ladrido` | Un ladrido de perro mediano, sin agresividad | 0,3–0,6 s | No | 3 |
| 38 | `perro_jadeo` | Jadeo de perro paseando | 2–3 s | **Sí** | 1 |
| 39 | `periodico` | Pasar la página de un periódico | 0,5–1 s | No | 2 |
| 40 | `taza` | Dejar un vaso de café sobre el banco | 0,2 s | No | 1 |

## D. Interfaz y juego (estéreo o mono, cortos y discretos)

| N.º | Nombre | Qué es | Duración | Bucle | Var. |
|---|---|---|---|---|---|
| 41 | `ui_mover` | Cambiar de modo en el menú o de botón | 0,05–0,1 s | No | 1 |
| 42 | `ui_aceptar` | Entrar o confirmar | 0,1–0,2 s | No | 1 |
| 43 | `ui_atras` | Volver o cancelar | 0,1–0,2 s | No | 1 |
| 44 | `ui_bloqueado` | Opción no disponible (nivel bloqueado, modo Historia) | 0,15–0,25 s | No | 1 |
| 45 | `pausa` | Abrir la pausa | 0,2 s | No | 1 |
| 46 | `revelado` | Aparece la foto revelada: un «fss» de papel o un obturador que se cierra | 0,4–0,7 s | No | 1 |
| 47 | `foto_rechazada` | La foto no vale | 0,3–0,5 s | No | 1 |
| 48 | `estrella` | Una estrella conseguida (suena una vez por estrella, seguidas) | 0,25–0,35 s | No | 1 |
| 49 | `nivel_superado` | Pequeña fanfarria | 1,5–3 s | No | 1 |
| 50 | `nivel_no_superado` | Cierre breve y neutro, sin humillar | 1–2 s | No | 1 |
| 51 | `tictac` | Un tic de reloj (suena cada segundo en los últimos 10 s) | 0,08–0,12 s | No | 1 |
| 52 | `tiempo_agotado` | Se acabó el tiempo | 0,6–1,0 s | No | 1 |
| 53 | `tutorial_ok` | Paso del tutorial conseguido: un «ding» amable | 0,3–0,5 s | No | 1 |

## E. Añadidos desde la primera lista (06-10-2026)

Lo que el juego ha ganado desde el 03-10 y todavía suena con un tono sintetizado o no suena.

| N.º | Nombre | Qué es | Duración | Bucle | Canales | Var. |
|---|---|---|---|---|---|---|
| 54 | `obturador_reflex_rapido` | La réflex a 1/2000–1/4000: el mismo golpe de espejo, más seco y corto | 0,2–0,3 s | No | Mono | 1 |
| 55 | `control_elegir` | Elegir otro ajuste en la tira del visor (más grave y blando que `dial`) | 0,05–0,1 s | No | Mono | 1 |
| 56 | `dial_tope` | El dial llega al final de su recorrido: un clic sordo, sin avanzar | 0,05–0,1 s | No | Mono | 1 |
| 57 | `bloqueo` | Bloqueo de foco y exposición (AE-L/AF-L): pitido corto y agudo, distinto de `af_confirmado` | 0,1–0,15 s | No | Mono | 1 |
| 58 | `medicion` | Cambiar el modo de medición: un clic de conmutador | 0,08–0,12 s | No | Mono | 1 |
| 59 | `lupa_tlr` | Desplegar la lupa del visor de la TLR: un «clac» metálico leve | 0,15–0,25 s | No | Mono | 1 |
| 60 | `pato` | Graznido de pato | 0,3–0,6 s | No | Mono | 3 |
| 61 | `pato_agua` | Un pato chapoteando o sacudiéndose en el estanque | 0,8–1,5 s | No | Mono | 2 |
| 62 | `movil` | Vibración o aviso breve de un móvil, apagado, como dentro de un bolsillo | 0,4–0,8 s | No | Mono | 2 |
| 63 | `migas` | Un puñado de migas cayendo al suelo | 0,3–0,5 s | No | Mono | 2 |
| 64 | `paraguas` | Roce de la tela de un paraguas cerrado al caminar | 0,3–0,5 s | No | Mono | 2 |
| 65 | `insignia` | Insignia conseguida: más breve y brillante que `nivel_superado` | 0,8–1,5 s | No | Estéreo | 1 |
| 66 | `album` | Una foto entra en el álbum: una hoja que se desliza en su funda | 0,3–0,5 s | No | Estéreo | 1 |
| 67 | `leccion_superada` | Práctica o examen de la Academia superado: un acorde amable, no una fanfarria | 1–1,5 s | No | Estéreo | 1 |
| 68 | `graduado` | Título de la Academia (los diez exámenes aprobados): la fanfarria grande del juego | 3–5 s | No | Estéreo | 1 |
| 69 | `condicion_ok` | Una condición del nivel cumplida, al aparecer en el resultado (suena una vez por condición) | 0,15–0,25 s | No | Estéreo | 1 |

## F. Música (opcional, estéreo)

| N.º | Nombre | Qué es | Duración | Bucle |
|---|---|---|---|---|
| 70 | `musica_menu` | Música tranquila para el menú principal, en la línea de `musica_videos.mp3` | 60–120 s | **Sí** |

**Total: 70 sonidos, 121 ficheros contando las variaciones.** Los imprescindibles para notar el cambio son los de la cámara (1–9, 13–16), los pasos (26–29), los ambientes (17–21) y los de nivel (48–52).

## Al recibirlos

Colocarlos en `assets/audio/` (`camara/`, `ambiente/`, `gente/`, `interfaz/`), con `importer="keep"`, añadirlos a los filtros de `export_presets.cfg`, sustituir los sintetizados en `ambience.gd` y `main.gd`, y anotar las licencias.
