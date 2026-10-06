# 24 · Efectos de sonido que hacen falta

**Estado: ✅ Sonidos integrados el 06-10-2026** (ver «Integración» al final; faltan 32 variaciones y la música). Antes: pendiente de recibir los sonidos del usuario (lista enviada el 03-10-2026 y ampliada el 06-10-2026 con el apartado E; él avisará cuando los tenga). Hoy todo el sonido es sintetizado: `tools/audio/build_ambience.py` (ambiente), `tools/audio/build_camera_sounds.py` (obturadores) y tonos generados en `main.gd::play_tone()`.

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

**Total: 70 sonidos, 112 ficheros contando las variaciones.** Los imprescindibles para notar el cambio son los de la cámara (1–9, 13–16), los pasos (26–29), los ambientes (17–21) y los de nivel (48–52).

## Fichas de producción (06-10-2026)

La especificación unívoca que se envió al usuario para generar los sonidos. Reglas comunes: WAV PCM 48 kHz 16 bits; pico real el de cada ficha (tolerancia 0 a −1 dB, nunca por encima de −1 dBFS); ruido de fondo < −60 dBFS; paso alto a 40 Hz (80 Hz en cámara e interfaz); totalmente secos; los de un disparo empiezan en los primeros 5 ms y acaban en silencio digital; los bucles duran exactamente lo indicado (±1 ms) y enlazan sin fundidos; las variaciones son tomas distintas, no copias con el tono cambiado; M = mono, E = estéreo.


### A. CÁMARAS (se oyen pegadas al oído del fotógrafo: primer plano, muy secas)

| N.º | Fichero | Canales | Duración | Bucle | Var. | Pico | Descripción |
|---|---|---|---|---|---|---|---|
| 1 | `obturador_reflex` | M | 0,35–0,45 s | no | 1 | -3 dBFS | Réflex mecánica de 35 mm de los años 80 a 1/125 s. Tres eventos encadenados sin pausa audible: golpe del espejo al subir (grave, 150–400 Hz, ataque < 5 ms), chasquido de la cortinilla (2–6 kHz) y golpe del espejo al bajar, algo más flojo. Cuerpo metálico, sin motor de arrastre ni pitidos. |
| 2 | `obturador_reflex_lento` | M | 0,70–0,90 s | no | 1 | -3 dBFS | La misma cámara a 1/8 s: espejo arriba + primera cortinilla, silencio real de 0,125 s (±10 ms) y segunda cortinilla + espejo abajo. Los dos golpes deben oírse claramente separados. |
| 3 | `obturador_telemetrica` | M | 0,15–0,22 s | no | 1 | -6 dBFS | Cortinilla de tela de una telemétrica: un «clic» suave y corto, sin espejo. Energía en 1–4 kHz, casi sin graves. Mucho más discreto que la réflex. |
| 4 | `obturador_compacta` | M | 0,25–0,35 s | no | 1 | -6 dBFS | Compacta digital de bolsillo: clic electrónico sintético (dos transitorios a 20–30 ms) seguido de un zumbido leve de motor de 80–120 ms que decae. |
| 5 | `obturador_tlr` | M | 0,10–0,18 s | no | 1 | -6 dBFS | Obturador central de una TLR de formato medio: un «tic» metálico muy corto y seco, agudo (3–8 kHz), sin espejo ni cortinilla. |
| 6 | `manivela_tlr` | M | 0,90–1,10 s | no | 1 | -6 dBFS | Avance de película de la TLR: media vuelta de manivela con trinquete (6–8 clics metálicos regulares en 0,6 s) y retorno de la manivela con un tope final. |
| 7 | `carrete_nuevo` | M | 2,0–2,8 s | no | 1 | -6 dBFS | Cargar un rollo: apertura de la tapa trasera (clac), encaje del carrete (roce + tope), cierre de la tapa (clac más grave). Tres gestos separados unos 0,6 s. |
| 8 | `af_confirmado` | M | 0,16–0,22 s | no | 1 | -9 dBFS | Doble pitido de foco conseguido: dos tonos senoidales de 2,8–3,2 kHz, de 60 ms cada uno, separados 40 ms. Envolvente con 5 ms de ataque y de caída, sin clic. |
| 9 | `af_fallo` | M | 0,30–0,45 s | no | 1 | -9 dBFS | El autofoco no encuentra: zumbido corto de motor de ida y vuelta (sube y baja de tono) o, en su defecto, un pitido grave de 400–500 Hz. Debe leerse como «no» sin ser desagradable. |
| 10 | `motor_af` | M | 0,20–0,35 s | no | 2 | -12 dBFS | Motor de enfoque de un objetivo de réflex moviéndose: zumbido mecánico de banda media con arranque y parada. Variación 1: recorrido corto (0,2 s). Variación 2: largo (0,35 s). |
| 11 | `zoom_compacta` | M | 1,5 s exactos | SÍ | 1 | -12 dBFS | Motor del zoom de una compacta en marcha, régimen constante (sin arranque ni parada dentro del fichero). Bucle perfecto: tono y nivel estables. |
| 12 | `zoom_compacta_fin` | M | 0,12–0,18 s | no | 1 | -12 dBFS | El mismo motor al detenerse: caída de tono y un tope mecánico leve. Empalma tras el bucle 11 (mismo timbre y nivel al inicio). |
| 13 | `anillo_enfoque` | M | 0,03–0,06 s | no | 4 | -15 dBFS | Un «paso» del anillo de enfoque manual: roce de helicoide engrasado con un clic muy leve. Se dispara muchas veces seguidas (hasta 20 por segundo): sin cola, y las cuatro variaciones con ±5 % de tono y nivel para que no suene a ametralladora. |
| 14 | `dial` | M | 0,03–0,08 s | no | 3 | -12 dBFS | Un clic de dial de velocidades o de diafragma: retén metálico con muelle, nítido y seco (2–5 kHz). Tres variaciones con diferencias mínimas. |
| 15 | `camara_subir` | M | 0,30–0,45 s | no | 1 | -15 dBFS | Llevarse la cámara al ojo: roce de correa de nailon y de tela de la ropa, sin golpes. Suave, ascendente en intensidad. |
| 16 | `camara_bajar` | M | 0,35–0,50 s | no | 1 | -15 dBFS | Bajar la cámara: el mismo roce, descendente, y al final el golpecito sordo de la cámara al quedar colgada sobre el pecho. |

### B. AMBIENTE DEL PARQUE

| N.º | Fichero | Canales | Duración | Bucle | Var. | Pico | Descripción |
|---|---|---|---|---|---|---|---|
| 17 | `pajaros_dia` | E | 45 s exactos | SÍ | 1 | -12 dBFS | Pájaros de parque urbano a mediodía: gorriones, mirlo, algún carbonero; cantos sueltos con pausas reales de silencio entre ellos (al menos el 40 % del tiempo sin canto). Sin tráfico, sin viento, sin voces, sin siseo de fondo. Imagen estéreo amplia. Sonoridad integrada en torno a −26 LUFS. |
| 18 | `pajaros_atardecer` | E | 45 s exactos | SÍ | 1 | -12 dBFS | Hora dorada: mirlos y cantos más espaciados y melódicos que de día, alguna golondrina. Menos densidad que el 17 (silencio el 55 % del tiempo). Mismas restricciones. |
| 19 | `hora_azul` | E | 40 s exactos | SÍ | 1 | -14 dBFS | Anochecer: los últimos cantos aislados de pájaros (dos o tres en todo el bucle) sobre los primeros grillos, escasos. Transición entre 18 y 20. |
| 20 | `grillos_noche` | E | 30 s exactos | SÍ | 1 | -14 dBFS | Grillos de noche de verano: varios individuos a distancias distintas, con ritmo irregular. Sin ranas, sin viento, sin zumbido eléctrico. |
| 21 | `fuente` | M | 12 s exactos | SÍ | 1 | -12 dBFS | Agua de un surtidor cayendo en su estanque, grabada a 1–2 m: chorro continuo y salpicaduras. Textura estable para que el bucle no se note. Sin eco de plaza. |
| 22 | `hojas_viento` | M | 4–8 s | no | 3 | -15 dBFS | Una ráfaga suave en las copas de los árboles: entra, crece y se apaga dentro del fichero (fundidos naturales de 1 s). Suelta, no continua. Tres variaciones de 4, 6 y 8 s. |
| 23 | `zureo` | M | 1,0–2,0 s | no | 3 | -12 dBFS | Arrullo de una paloma torcaz o bravía, de cerca. Tres frases distintas. |
| 24 | `aleteo_bandada` | M | 1,5–2,5 s | no | 2 | -6 dBFS | Una bandada de 8 a 12 palomas alzando el vuelo de golpe desde el suelo: estallido de aleteos que se aleja y se apaga. Sin arrullos. |
| 25 | `aleteo_paloma` | M | 0,4–0,6 s | no | 2 | -12 dBFS | Una sola paloma que se aparta con cuatro o cinco aleteos rápidos. |

### C. GENTE, ANIMALES Y JUEGOS (fuentes puntuales: el juego las coloca en 3D y las atenúa con la distancia)

| N.º | Fichero | Canales | Duración | Bucle | Var. | Pico | Descripción |
|---|---|---|---|---|---|---|---|
| 26 | `paso_grava` | M | 0,20–0,30 s | no | 6 | -12 dBFS | Un único paso de adulto sobre grava fina, calzado de calle. Seis variaciones (alternando pie izquierdo y derecho). Sin roce de ropa. |
| 27 | `paso_losa` | M | 0,15–0,25 s | no | 6 | -12 dBFS | Un único paso sobre losas de piedra o adoquín: tacón y suela. Seis variaciones. |
| 28 | `paso_cesped` | M | 0,20–0,30 s | no | 4 | -15 dBFS | Un único paso sobre hierba corta: sordo, con un leve crujido. Cuatro variaciones. |
| 29 | `paso_corredor` | M | 0,15–0,25 s | no | 4 | -9 dBFS | Una zancada de alguien corriendo: zapatilla deportiva sobre firme duro, impacto más marcado que 27. Cuatro variaciones. |
| 30 | `charla` | M | 12 s exactos | SÍ | 2 | -15 dBFS | Dos personas conversando a media voz sin que se entienda ninguna palabra (murmullo ininteligible, no un idioma reconocible). Variación 1: dos voces graves. Variación 2: una grave y una aguda. |
| 31 | `risa` | M | 1,0–2,0 s | no | 3 | -12 dBFS | Una risa corta y natural de adulto. Tres personas distintas (dos mujeres, un hombre o al revés). |
| 32 | `ninos_jugando` | M | 20 s exactos | SÍ | 1 | -12 dBFS | Tres o cuatro niños jugando: voces, grititos y risas sin palabras claras. Sin llanto. Densidad estable para el bucle. |
| 33 | `columpio` | M | 2,730 s EXACTOS | SÍ | 1 | -15 dBFS | Chirrido de las cadenas de un columpio: un vaivén completo (ida con chirrido agudo, vuelta con chirrido algo más grave), repartidos a 0 s y a 1,365 s. La duración es crítica: el columpio del juego tarda 2,73 s por vaivén. |
| 34 | `tobogan` | M | 1,0–1,3 s | no | 1 | -12 dBFS | Un niño deslizándose por un tobogán metálico: roce continuo que acelera y un golpe suave al llegar abajo. |
| 35 | `balon_patada` | M | 0,15–0,25 s | no | 2 | -9 dBFS | Patada a un balón de cuero o plástico hinchado: impacto seco con resonancia hueca. |
| 36 | `balon_bote` | M | 0,12–0,18 s | no | 2 | -12 dBFS | Un bote de balón sobre hierba: más sordo que la patada. |
| 37 | `perro_ladrido` | M | 0,3–0,6 s | no | 3 | -9 dBFS | Un ladrido aislado de perro mediano, amistoso, sin gruñido ni agresividad. Tres variaciones. |
| 38 | `perro_jadeo` | M | 2,5 s exactos | SÍ | 1 | -18 dBFS | Jadeo rítmico de un perro paseando con la lengua fuera (unas 5 respiraciones por segundo). |
| 39 | `periodico` | M | 0,5–1,0 s | no | 2 | -15 dBFS | Pasar una página de periódico de papel prensa: crujido y sacudida final. |
| 40 | `taza` | M | 0,15–0,25 s | no | 1 | -15 dBFS | Dejar un vaso de café de cartón, medio lleno, sobre un banco de madera: golpe sordo y hueco. |

### D. INTERFAZ Y JUEGO (no diegéticos: limpios, discretos, familia tímbrica común)

| N.º | Fichero | Canales | Duración | Bucle | Var. | Pico | Descripción |
|---|---|---|---|---|---|---|---|
| 41 | `ui_mover` | E | 0,05–0,10 s | no | 1 | -15 dBFS | Cambiar de modo o de botón en el menú: un «tic» blando y neutro (1–2 kHz), sin tono musical definido. Suena muchas veces: no debe cansar. |
| 42 | `ui_aceptar` | E | 0,10–0,20 s | no | 1 | -12 dBFS | Confirmar o entrar: dos notas ascendentes muy breves (intervalo de cuarta o quinta), timbre cálido tipo marimba o campana apagada. |
| 43 | `ui_atras` | E | 0,10–0,20 s | no | 1 | -12 dBFS | Volver o cancelar: el mismo timbre que 42 con el intervalo descendente. |
| 44 | `ui_bloqueado` | E | 0,15–0,25 s | no | 1 | -12 dBFS | Opción no disponible: un «toc» grave y sordo (150–300 Hz), sin zumbido de error estridente. |
| 45 | `pausa` | E | 0,18–0,25 s | no | 1 | -12 dBFS | Abrir la pausa: una nota suave descendente con filtro que se cierra, sensación de «el mundo se detiene». |
| 46 | `revelado` | E | 0,4–0,7 s | no | 1 | -12 dBFS | Aparece la foto revelada: un «fss» de papel fotográfico saliendo, o de una hoja deslizándose, que termina en un golpecito leve. |
| 47 | `foto_rechazada` | E | 0,3–0,5 s | no | 1 | -12 dBFS | La foto no vale: dos notas descendentes apagadas, del mismo timbre que 42. Informativo, no punitivo. |
| 48 | `estrella` | E | 0,25–0,35 s | no | 1 | -9 dBFS | Una estrella conseguida: campanilla brillante con cola corta. Suena hasta cinco veces seguidas, una cada 0,15 s, y el juego sube el tono en cada una: entregar una sola nota (La5, 880 Hz) limpia. |
| 49 | `nivel_superado` | E | 1,5–3,0 s | no | 1 | -6 dBFS | Pequeña fanfarria de nivel superado: arpegio mayor ascendente de 4 a 6 notas con un acorde final. Instrumentación acústica ligera (marimba, guitarra, pizzicato), no orquesta épica. |
| 50 | `nivel_no_superado` | E | 1,0–2,0 s | no | 1 | -9 dBFS | Cierre breve y neutro: dos o tres notas que resuelven hacia abajo sin dramatismo. Mismo timbre que 49. |
| 51 | `tictac` | E | 0,08–0,12 s | no | 1 | -12 dBFS | Un único tic de reloj mecánico. Suena una vez por segundo en los últimos 10 s de un nivel. |
| 52 | `tiempo_agotado` | E | 0,6–1,0 s | no | 1 | -6 dBFS | Se acabó el tiempo: timbre de reloj de cocina o campanilla doble, claro pero no estridente. |
| 53 | `tutorial_ok` | E | 0,3–0,5 s | no | 1 | -12 dBFS | Paso del tutorial conseguido: un «ding» amable de una sola nota (Mi6 aprox.), con cola de 0,3 s. |

### E. AÑADIDOS EL 06-10

| N.º | Fichero | Canales | Duración | Bucle | Var. | Pico | Descripción |
|---|---|---|---|---|---|---|---|
| 54 | `obturador_reflex_rapido` | M | 0,20–0,30 s | no | 1 | -3 dBFS | La réflex del sonido 1 a 1/2000–1/4000 s: mismo cuerpo y mismo espejo, con la cortinilla reducida a un chasquido único y todo el conjunto más compacto y seco. |
| 55 | `control_elegir` | M | 0,05–0,10 s | no | 1 | -15 dBFS | Elegir otro ajuste en la tira del visor: clic más grave y blando que «dial» (500–1500 Hz), como un conmutador de palanca pequeño. |
| 56 | `dial_tope` | M | 0,05–0,10 s | no | 1 | -15 dBFS | El dial llega al final de su recorrido: clic sordo y amortiguado, claramente distinto de «dial», que transmite «no pasa de aquí». |
| 57 | `bloqueo` | M | 0,10–0,15 s | no | 1 | -9 dBFS | Bloqueo de foco y exposición: un solo pitido corto de 3,8–4,2 kHz, más agudo que af_confirmado y sin repetición. |
| 58 | `medicion` | M | 0,08–0,12 s | no | 1 | -15 dBFS | Cambiar el modo de medición: clic de conmutador deslizante de tres posiciones. |
| 59 | `lupa_tlr` | M | 0,15–0,25 s | no | 1 | -12 dBFS | Desplegar la lupa del capuchón de la TLR: un «clac» metálico leve de chapa fina con muelle. |
| 60 | `pato` | M | 0,3–0,6 s | no | 3 | -9 dBFS | Un graznido de ánade real. Tres variaciones (una de ellas, doble: «cua-cua»). |
| 61 | `pato_agua` | M | 0,8–1,5 s | no | 2 | -12 dBFS | Un pato chapoteando o sacudiéndose las alas sobre el agua: salpicaduras cortas, sin graznido. |
| 62 | `movil` | M | 0,4–0,8 s | no | 2 | -18 dBFS | Aviso de un móvil apagado por la ropa: variación 1, dos pulsos de vibración; variación 2, un tono de mensaje breve y genérico, filtrado (sin agudos por encima de 3 kHz). Ninguna melodía de marca reconocible. |
| 63 | `migas` | M | 0,3–0,5 s | no | 2 | -18 dBFS | Un puñado de migas de pan cayendo sobre grava o losa: lluvia breve de impactos diminutos. |
| 64 | `paraguas` | M | 0,3–0,5 s | no | 2 | -18 dBFS | Roce de la tela de un paraguas cerrado contra la pierna al caminar. |
| 65 | `insignia` | E | 0,8–1,5 s | no | 1 | -6 dBFS | Insignia conseguida: más breve y brillante que nivel_superado; tres notas ascendentes rápidas y un destello agudo (campanilla o glockenspiel). |
| 66 | `album` | E | 0,3–0,5 s | no | 1 | -12 dBFS | Una foto entra en el álbum: una hoja de papel grueso deslizándose en una funda de plástico. |
| 67 | `leccion_superada` | E | 1,0–1,5 s | no | 1 | -9 dBFS | Práctica o examen de la Academia superado: un acorde mayor arpegiado, amable y cálido; menos festivo que nivel_superado. |
| 68 | `graduado` | E | 3,0–5,0 s | no | 1 | -3 dBFS | Título de la Academia: la fanfarria grande del juego. Misma instrumentación que 49 con más cuerpo (se admite un metal suave o cuerdas), frase de 4 compases con final rotundo. |
| 69 | `condicion_ok` | E | 0,15–0,25 s | no | 1 | -12 dBFS | Una condición del nivel cumplida: «tic» afirmativo de una nota (Do6 aprox.), más corto y discreto que «estrella». Suena varias veces seguidas. |

### F. MÚSICA (opcional)

| N.º | Fichero | Canales | Duración | Bucle | Var. | Pico | Descripción |
|---|---|---|---|---|---|---|---|
| 70 | `musica_menu` | E | 90 s exactos (o múltiplo del compás) | SÍ | 1 | -6 dBFS | Música del menú principal: tranquila, optimista, tempo de 80–100 pulsos por minuto, instrumentación acústica ligera (guitarra, piano, pizzicato, percusión suave), en la línea de la música de los vídeos del proyecto. El final debe enlazar con el principio sin corte. Sonoridad integrada de −18 LUFS. |

## Prompts para una IA generadora de audio (06-10-2026)

En inglés, que es como mejor responden los generadores. Duración, bucle, canales y pico, los de la ficha de arriba.

| N.º | Fichero | Prompt |
|---|---|---|
| 1 | `obturador_reflex` | Single shutter release of a 1980s 35mm mechanical SLR film camera at 1/125 second: mirror slap up, focal-plane curtain click, mirror return, in one tight metallic clack. No motor drive, no beep. Close-mic, completely dry studio recording, no reverb, no echo, no music, no voices, no background noise. |
| 2 | `obturador_reflex_lento` | Slow shutter release of a 1980s mechanical SLR film camera at 1/8 second: mirror slaps up with the first curtain, a clear silent gap of about an eighth of a second, then second curtain and mirror dropping back. Two distinct metallic clacks. Close-mic, completely dry studio recording, no reverb, no echo, no music, no voices, no background noise. |
| 3 | `obturador_telemetrica` | Single very soft, short cloth shutter click of a vintage rangefinder film camera. Quiet, discreet, no mirror slap, mid-high frequencies only. Close-mic, completely dry studio recording, no reverb, no echo, no music, no voices, no background noise. |
| 4 | `obturador_compacta` | Shutter sound of a small digital compact pocket camera: a synthetic electronic double click followed by a faint short motor whirr that fades out. Close-mic, completely dry studio recording, no reverb, no echo, no music, no voices, no background noise. |
| 5 | `obturador_tlr` | Single leaf shutter of a vintage twin-lens reflex medium format camera: one very short, dry, high-pitched metallic tick. No mirror, no curtain. Close-mic, completely dry studio recording, no reverb, no echo, no music, no voices, no background noise. |
| 6 | `manivela_tlr` | Winding the film crank of a vintage twin-lens reflex camera: half a turn with six to eight even metallic ratchet clicks, then the crank swinging back to its stop. Close-mic, completely dry studio recording, no reverb, no echo, no music, no voices, no background noise. |
| 7 | `carrete_nuevo` | Loading a roll of film into a vintage camera: back door latch opening with a clack, film spool pushed into place, back door closing with a deeper clack. Three separate handling sounds. Close-mic, completely dry studio recording, no reverb, no echo, no music, no voices, no background noise. |
| 8 | `af_confirmado` | Camera autofocus confirmation: two identical short clean sine beeps at 3 kilohertz, very close together. Electronic, soft attack, no click. Close-mic, completely dry studio recording, no reverb, no echo, no music, no voices, no background noise. |
| 9 | `af_fallo` | Camera autofocus failing to lock: a short lens motor hunting back and forth, pitch rising then falling, ending unresolved. Small electric motor, not harsh. Close-mic, completely dry studio recording, no reverb, no echo, no music, no voices, no background noise. |
| 10 | `motor_af` | Autofocus motor of an SLR camera lens moving briefly: a short mid-pitched electric micro-motor whirr with a clear start and stop. Close-mic, completely dry studio recording, no reverb, no echo, no music, no voices, no background noise. |
| 11 | `zoom_compacta` | Steady continuous whirr of a compact digital camera zoom lens motor running at constant speed, constant pitch and volume, seamless loop. Close-mic, completely dry studio recording, no reverb, no echo, no music, no voices, no background noise. |
| 12 | `zoom_compacta_fin` | A small camera zoom lens motor stopping: pitch quickly dropping and a faint mechanical stop click. Very short. Close-mic, completely dry studio recording, no reverb, no echo, no music, no voices, no background noise. |
| 13 | `anillo_enfoque` | One tiny step of a manual focus ring on a vintage camera lens: a very short greasy helicoid friction sound with a faint click. Extremely short, no tail. Close-mic, completely dry studio recording, no reverb, no echo, no music, no voices, no background noise. |
| 14 | `dial` | One single click of a metal camera dial with a spring detent, like a shutter speed dial. Crisp, dry, very short. Close-mic, completely dry studio recording, no reverb, no echo, no music, no voices, no background noise. |
| 15 | `camara_subir` | Raising a camera to the eye: soft rustle of a nylon camera strap and clothing fabric, short, rising in intensity, no impacts. Close-mic, completely dry studio recording, no reverb, no echo, no music, no voices, no background noise. |
| 16 | `camara_bajar` | Lowering a camera from the eye: soft rustle of camera strap and clothing, ending with a gentle dull thump as the camera rests against the chest. Close-mic, completely dry studio recording, no reverb, no echo, no music, no voices, no background noise. |
| 17 | `pajaros_dia` | Daytime birdsong in a quiet city park: sparrows, a blackbird, a great tit, separate calls with real pauses of silence between them, wide stereo. No traffic, no wind, no people, no hiss, seamless loop. |
| 18 | `pajaros_atardecer` | Late afternoon golden hour birdsong in a quiet park: sparse melodic blackbird phrases and a few swallows, long pauses of silence, wide stereo. No traffic, no wind, no people, seamless loop. |
| 19 | `hora_azul` | Dusk in a quiet park: two or three last isolated bird calls over the first few sparse crickets, calm, wide stereo. No traffic, no wind, no people, seamless loop. |
| 20 | `grillos_noche` | Summer night crickets in a quiet park: several crickets at different distances chirping with irregular rhythm, wide stereo. No frogs, no wind, no electrical hum, seamless loop. |
| 21 | `fuente` | Water of a small park fountain jet falling into its basin, recorded from one metre: steady splashing with an even texture. No echo, no people, seamless loop. |
| 22 | `hojas_viento` | A single gentle gust of wind through tree leaves: it rises, peaks softly and dies away completely. Only rustling leaves, no constant wind noise. Close-mic, completely dry studio recording, no reverb, no echo, no music, no voices, no background noise. |
| 23 | `zureo` | A single pigeon cooing phrase, recorded close. Only the bird. Close-mic, completely dry studio recording, no reverb, no echo, no music, no voices, no background noise. |
| 24 | `aleteo_bandada` | A flock of about ten pigeons suddenly taking off from the ground: a burst of flapping wings that moves away and fades. No cooing. Close-mic, completely dry studio recording, no reverb, no echo, no music, no voices, no background noise. |
| 25 | `aleteo_paloma` | One single pigeon fluttering away with four or five quick wing flaps. Very short. Close-mic, completely dry studio recording, no reverb, no echo, no music, no voices, no background noise. |
| 26 | `paso_grava` | One single adult footstep on fine gravel, street shoes. Just one step. Close-mic, completely dry studio recording, no reverb, no echo, no music, no voices, no background noise. |
| 27 | `paso_losa` | One single adult footstep on stone paving slabs, leather shoe heel and sole. Just one step. Close-mic, completely dry studio recording, no reverb, no echo, no music, no voices, no background noise. |
| 28 | `paso_cesped` | One single adult footstep on short grass: dull and soft with a faint crunch. Just one step. Close-mic, completely dry studio recording, no reverb, no echo, no music, no voices, no background noise. |
| 29 | `paso_corredor` | One single running footstep of a jogger: sports shoe hitting hard pavement firmly. Just one stride. Close-mic, completely dry studio recording, no reverb, no echo, no music, no voices, no background noise. |
| 30 | `charla` | Two people chatting quietly on a park bench, unintelligible murmur, no recognisable words or language, relaxed tone, even density, seamless loop. |
| 31 | `risa` | One short natural adult laugh, friendly and brief. A single person. Close-mic, completely dry studio recording, no reverb, no echo, no music, no voices, no background noise. |
| 32 | `ninos_jugando` | Three or four children playing outdoors: happy voices, squeals and laughter without clear words, no crying, even density, seamless loop. |
| 33 | `columpio` | Rhythmic squeak of the metal chains of a playground swing: exactly one full back-and-forth swing, one higher squeak on the way forward and one slightly lower squeak on the way back, evenly spaced, seamless loop. Close-mic, completely dry studio recording, no reverb, no echo, no music, no voices, no background noise. |
| 34 | `tobogan` | A child sliding down a metal playground slide: a continuous friction sound that speeds up and ends with a soft thump at the bottom. Close-mic, completely dry studio recording, no reverb, no echo, no music, no voices, no background noise. |
| 35 | `balon_patada` | A single kick of an inflated football: one dry hollow thud. Close-mic, completely dry studio recording, no reverb, no echo, no music, no voices, no background noise. |
| 36 | `balon_bote` | A single bounce of a football on grass: one soft dull thud. Close-mic, completely dry studio recording, no reverb, no echo, no music, no voices, no background noise. |
| 37 | `perro_ladrido` | One single friendly bark of a medium-sized dog. No growl, not aggressive. Close-mic, completely dry studio recording, no reverb, no echo, no music, no voices, no background noise. |
| 38 | `perro_jadeo` | Rhythmic panting of a happy dog out for a walk, tongue out, about five breaths per second, steady, seamless loop. Close-mic, completely dry studio recording, no reverb, no echo, no music, no voices, no background noise. |
| 39 | `periodico` | Turning one page of a large newsprint newspaper: paper crackle and a final shake. Close-mic, completely dry studio recording, no reverb, no echo, no music, no voices, no background noise. |
| 40 | `taza` | Setting a half-full paper coffee cup down on a wooden bench: one soft hollow tap. Close-mic, completely dry studio recording, no reverb, no echo, no music, no voices, no background noise. |
| 41 | `ui_mover` | User interface navigation tick for a game menu: one soft, neutral, very short blip around 1.5 kilohertz with no musical pitch. Clean, unobtrusive. Close-mic, completely dry studio recording, no reverb, no echo, no music, no voices, no background noise. |
| 42 | `ui_aceptar` | User interface confirm sound: two very quick ascending notes a fifth apart, warm muted marimba, short and friendly. Dry, no reverb, no background noise. |
| 43 | `ui_atras` | User interface back or cancel sound: two very quick descending notes a fifth apart, warm muted marimba, short and soft. Dry, no reverb, no background noise. |
| 44 | `ui_bloqueado` | User interface locked or unavailable sound: one low dull muted wooden thud, soft, not a harsh error buzzer. Close-mic, completely dry studio recording, no reverb, no echo, no music, no voices, no background noise. |
| 45 | `pausa` | Game pause sound: one soft note gliding down as a low-pass filter closes, like the world gently coming to a stop. Short. Dry, no reverb, no background noise. |
| 46 | `revelado` | A photographic print sliding out: a short soft paper whoosh ending with a light tap. Close-mic, completely dry studio recording, no reverb, no echo, no music, no voices, no background noise. |
| 47 | `foto_rechazada` | Soft negative feedback sound for a game: two muted descending marimba notes, informative, gentle, not punishing. Dry, no reverb, no background noise. |
| 48 | `estrella` | A single bright bell chime note at 880 hertz, glockenspiel-like, with a short clean tail. One note only. Dry, no reverb, no background noise. |
| 49 | `nivel_superado` | Short level complete jingle: a cheerful ascending major arpeggio of five notes ending on a chord, light acoustic instruments, marimba, nylon guitar and pizzicato strings. Not epic, no orchestra. Dry, no reverb, no background noise. |
| 50 | `nivel_no_superado` | Short neutral level failed jingle: three gentle marimba and pizzicato notes resolving downwards, calm, without drama. Dry, no reverb, no background noise. |
| 51 | `tictac` | One single tick of a mechanical clock. Very short, dry. Close-mic, completely dry studio recording, no reverb, no echo, no music, no voices, no background noise. |
| 52 | `tiempo_agotado` | Time is up: a clear double ring of a small kitchen timer bell, bright but not harsh. Close-mic, completely dry studio recording, no reverb, no echo, no music, no voices, no background noise. |
| 53 | `tutorial_ok` | A single friendly ding of a small bell, high pitched, with a short soft tail. Positive feedback. Dry, no reverb, no background noise. |
| 54 | `obturador_reflex_rapido` | Single very fast shutter release of a 1980s mechanical SLR film camera at 1/4000 second: mirror slap and one sharp curtain snap fused into a single tight, dry, compact clack. Close-mic, completely dry studio recording, no reverb, no echo, no music, no voices, no background noise. |
| 55 | `control_elegir` | One click of a small toggle selector switch on a camera: lower and softer than a dial click, short. Close-mic, completely dry studio recording, no reverb, no echo, no music, no voices, no background noise. |
| 56 | `dial_tope` | A camera dial hitting the end of its travel: one dull, dampened, blocked click, clearly softer and deader than a normal dial click. Close-mic, completely dry studio recording, no reverb, no echo, no music, no voices, no background noise. |
| 57 | `bloqueo` | Camera exposure lock confirmation: one single short clean sine beep at 4 kilohertz. Electronic, soft attack. Close-mic, completely dry studio recording, no reverb, no echo, no music, no voices, no background noise. |
| 58 | `medicion` | One click of a small three-position slide switch on a camera body. Short plastic and metal click. Close-mic, completely dry studio recording, no reverb, no echo, no music, no voices, no background noise. |
| 59 | `lupa_tlr` | Flipping up the small magnifier of a vintage camera viewing hood: one light thin sheet-metal clack with a spring. Close-mic, completely dry studio recording, no reverb, no echo, no music, no voices, no background noise. |
| 60 | `pato` | One single quack of a mallard duck, recorded close. Only the duck. Close-mic, completely dry studio recording, no reverb, no echo, no music, no voices, no background noise. |
| 61 | `pato_agua` | A duck splashing and shaking its wings on the water of a pond: short water splashes, no quacking. Close-mic, completely dry studio recording, no reverb, no echo, no music, no voices, no background noise. |
| 62 | `movil` | A mobile phone vibrating twice inside a pocket, muffled by clothing. Two short buzz pulses. Close-mic, completely dry studio recording, no reverb, no echo, no music, no voices, no background noise. |
| 63 | `migas` | A small handful of bread crumbs falling on stone paving: a brief shower of tiny impacts. Close-mic, completely dry studio recording, no reverb, no echo, no music, no voices, no background noise. |
| 64 | `paraguas` | Fabric of a closed umbrella brushing against a trouser leg while walking: one short soft nylon rustle. Close-mic, completely dry studio recording, no reverb, no echo, no music, no voices, no background noise. |
| 65 | `insignia` | Achievement unlocked jingle: three fast ascending notes and a bright glockenspiel sparkle. Short, shiny, joyful. Dry, no reverb, no background noise. |
| 66 | `album` | A thick photo print sliding into a plastic album sleeve: short smooth paper and plastic slide. Close-mic, completely dry studio recording, no reverb, no echo, no music, no voices, no background noise. |
| 67 | `leccion_superada` | Lesson passed jingle: one warm arpeggiated major chord on marimba and soft piano, kind and calm, less festive than a victory fanfare. Dry, no reverb, no background noise. |
| 68 | `graduado` | Graduation fanfare for a cosy game: a four-bar triumphant but warm phrase with marimba, nylon guitar, pizzicato strings and soft brass, ending on a firm final chord. Dry, no reverb, no background noise. |
| 69 | `condicion_ok` | A single short affirmative tick note around 1 kilohertz, soft glockenspiel, very brief, for a checklist item being ticked. Dry, no reverb, no background noise. |
| 70 | `musica_menu` | Calm, optimistic acoustic background music for the main menu of a cosy photography game: nylon guitar, soft piano, pizzicato strings and light brushed percussion, 90 beats per minute, major key, gentle and curious, instrumental, seamless loop. Dry, no reverb, no background noise. |

## Ya generados por código (06-10-2026)

Solo los pitidos de tono puro (decisión del usuario): los sintetiza `tools/audio/build_beeps.py` (`python3 tools/audio/build_beeps.py`) con la duración, el canal y el pico de su ficha.

| N.º | Fichero | Qué es |
|---|---|---|
| 8 | `assets/audio/camara/af_confirmado.wav` | Dos tonos de 3 kHz de 60 ms separados 40 ms |
| 9 | `assets/audio/camara/af_fallo.wav` | La variante de pitido grave (450 Hz, 0,35 s); la de motor que busca sigue pendiente si se prefiere |
| 57 | `assets/audio/camara/bloqueo.wav` | Un pitido de 4 kHz de 0,12 s |

**Todavía no suenan en el juego**: se conectarán junto con el resto. Quedan por generar 67 sonidos (109 ficheros), entre ellos las notas de campanilla (`estrella`, `tutorial_ok`, `condicion_ok`) y el `tictac`.

## Integración (06-10-2026)

El usuario generó los 70 sonidos dos veces, una toma por sonido: con **Stable Audio Open** (44,1 kHz estéreo) y con **AudioGen** (16 kHz mono). Se eligió una por sonido y se integró todo salvo la música y los tres pitidos de tono puro (que ya estaban sintetizados).

**Cómo se eligió** (`tools/audio/import_generated.py`, que tiene la tabla y el motivo de cada excepción): no se pueden escuchar desde aquí, así que el criterio es lo medible frente a la ficha — duración útil, número de eventos, reparto del espectro, ruido de fondo, silencio final — y, a igualdad, Stable Audio (decisión del usuario). Stable Audio gana en casi todo: AudioGen sale limitado a 8 kHz y en muchas tomas con ruido continuo de fondo. Excepciones:

| Sonido | Toma | Por qué |
|---|---|---|
| `zoom_compacta` | AudioGen | La de Stable Audio arranca y se para a los 0,67 s: no da un régimen constante para el bucle |
| `charla` | AudioGen | La de Stable Audio es casi toda energía por debajo de 80 Hz, sin voces |
| `ninos_jugando` | AudioGen | La prefiere el usuario al oírlas (06-10-2026) |
| `hojas_viento` | **ninguna** | Las dos son un rumor por debajo de 80 Hz, sin hojas: hay que regenerarlo |

**Lo que no se puede comprobar midiendo es si el sonido «es» lo que pide** (que el pato suene a pato): eso queda para la prueba del usuario.

**Variaciones**: donde la ficha pide varias, la primera es la toma elegida y la segunda la del otro generador si vale. **Faltan 33** (se añaden como `NN_nombre_3.wav`… en la carpeta del generador y como otra toma en `TABLE`):

| Sonido | Hay | Pide | Faltan | | Sonido | Hay | Pide | Faltan |
|---|---:|---:|---:|---|---|---:|---:|---:|
| `paso_losa` | 1 | 6 | **5** | | `motor_af` | 1 | 2 | 1 |
| `paso_grava` | 2 | 6 | **4** | | `dial` | 2 | 3 | 1 |
| `paso_cesped` | 1 | 4 | **3** | | `zureo` | 2 | 3 | 1 |
| `hojas_viento` | 0 | 3 | **3** | | `aleteo_bandada` | 1 | 2 | 1 |
| `anillo_enfoque` | 2 | 4 | 2 | | `aleteo_paloma` | 1 | 2 | 1 |
| `paso_corredor` | 1 | 4 | 3 | | `charla` | 1 | 2 | 1 |
| `pato` | 1 | 3 | 2 | | `risa` | 2 | 3 | 1 |
| `balon_bote` | 1 | 2 | 1 | | `perro_ladrido` | 2 | 3 | 1 |
| `pato_agua` | 1 | 2 | 1 | | `paraguas` | 1 | 2 | 1 |

(Completos con dos: `balon_patada`, `periodico`, `movil`, `migas`.) Las segundas tomas de AudioGen que no valían: `motor_af`, `aleteo_*`, `paso_losa`, `paso_cesped`, `balon_bote`, `pato`, `pato_agua`, `paraguas` (ruido continuo o solo graves).

**Tratamiento** de cada toma: 48 kHz y 16 bits (los ambientes en bucle, a 32 kHz y mono, porque suenan desde un punto del parque), paso alto, recorte a la parte útil (empieza en la primera muestra, acaba en silencio), pico de la ficha; los bucles, con el final fundido sobre el principio.

**Dónde suena cada uno** (`scripts/sfx.gd`: `play()` sin colocar, `play_at()` y `loop_at()` desde un punto del parque; `main.gd::play_sfx()`; si falta un fichero se conserva el tono sintetizado de antes):

| Qué | Sonidos | Dónde está el enganche |
|---|---|---|
| Disparo | `obturador_compacta`, `_telemetrica`, `_tlr`; la réflex, `obturador_reflex`, `_lento` (1/15 s o más lento) y `_rapido` (1/2000 s o más rápido) | `main.gd::shutter_sound()` |
| Enfoque | `af_confirmado`, `af_fallo`, `motor_af` (réflex), `anillo_enfoque` (cada paso del enfoque manual), `bloqueo` | `autofocus()`, `adjust_focus_delta()`, `toggle_lock()` |
| Diales | `dial` y `dial_tope` (al final del recorrido), `control_elegir`, `medicion` | `change_parameter()`, `select_control()`, `next_metering()` |
| Cuerpo | `camara_subir`/`_bajar`, `zoom_compacta` (bucle mientras cambia la focal) y `_fin`, `lupa_tlr`, `manivela_tlr`, `carrete_nuevo` | `toggle_raise()`, `zoom_sound()`, `wind_film()` |
| Interfaz | `ui_mover` (cambiar de modo), `ui_aceptar`/`ui_atras` (botones), `ui_bloqueado` (modo Historia), `pausa` | `main_menu.gd`, `main.gd::button()`, `show_pause()` |
| Resultado | `revelado` o `foto_rechazada`; `condicion_ok` por condición cumplida y `estrella` por estrella, subiendo de tono | `result_sounds()` |
| Nivel | `tictac` (últimos 10 s), `tiempo_agotado`, `nivel_superado`/`_no_superado` | reloj del arcade, `end_level()` |
| Progreso | `insignia`, `graduado`, `album`, `leccion_superada`, `tutorial_ok` | `announce_badge()`, `save_to_album()`, `academy.gd`, `tutorial.gd` |
| Ambiente (la fuente del parque clásico es un rumor lejano desde su lado: el estanque está a 21 m, tras la verja; en el grande suena en la plaza) | `pajaros_dia`, `pajaros_atardecer`, `hora_azul` (uno por luz), `grillos_noche`, `fuente`, `zureo`, `aleteo_bandada` | `ambience.gd` |
| Gente | Pasos según lo que se pisa (`sfx.gd::step_on()`): `paso_losa` en los caminos y plazas de los dos parques (todos están pavimentados) y `paso_cesped` fuera de ellos y en la pradera (figurantes, el niño del balón); `paso_corredor` para quien corre sobre pavimento (una sola toma: la de AudioGen tenía otro timbre y, alternada con la de Stable Audio, sonaba a dos personas). `paso_grava` queda sin usar hasta que haya un camino de grava. Los cinco paseantes más cercanos a menos de 9 m, un sonido por pie que pisa. **También el fotógrafo** al caminar por el parque grande (sin colocar: bajo sus pies); `charla` (bucle en la conversación más cercana), `risa`, `periodico`, `taza`, `movil`, `migas` según lo que hace cada uno | `sfx.gd::update_world()` |
| Animales y juegos | `perro_jadeo` (bucle) y `perro_ladrido`; `pato` y `pato_agua`; `columpio` (bucle a su ritmo de 2,73 s), `ninos_jugando`, `tobogan`, `balon_patada`, `balon_bote` | `sfx.gd::update_world()`, contadores en `extras.gd` |

**Niveles** (medidos el 06-10-2026 grabando con `--write-movie` y `ffmpeg -af volumedetect`): los pájaros llegaban a la cámara a unos −23 dBFS de media, por encima de todo lo demás (la grabación, la distancia y cuatro árboles cantando a la vez); los grillos, a −28. Un fondo debe estar hacia −40: `ambience.gd::BED_DB` y `CRICKET_DB`, con una corrección por grabación para que día, atardecer y hora azul suenen igual de fuertes. También se bajaron el ladrido (−5 dB) y la primera toma del zureo (un tono sostenido, 10 dB más fuerte que la segunda con el mismo pico). Con el parque clásico en reposo la media queda en −40 dB de día, −43 al atardecer y en la hora azul y −45 de noche.

**Sin enganchar todavía**: `aleteo_paloma`, `paso_grava` y `paraguas` (no hay todavía un momento del juego que los pida), y `hojas_viento` (sin toma válida).

**Los sonidos colocados en el parque no se oían** (ni los pájaros ni la fuente, desde que existen): el visor es un `SubViewport` y no tenía activado su propio oyente (`audio_listener_enable_3d`). Solo sonaban la cámara y la interfaz. Corregido en `main.gd` al crear el visor; comprobado grabando con `--write-movie` y midiendo con `ffmpeg -af volumedetect` (de −91 dB, silencio, a −34 dB de media de día).

## Al recibirlos

Colocarlos en `assets/audio/` (`camara/`, `ambiente/`, `gente/`, `interfaz/`), con `importer="keep"`, añadirlos a los filtros de `export_presets.cfg`, sustituir los sintetizados en `ambience.gd` y `main.gd`, y anotar las licencias.
