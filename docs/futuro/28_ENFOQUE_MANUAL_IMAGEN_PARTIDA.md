# 28 · Enfoque manual: la imagen partida se mueve sola (problema abierto)

> **Estado: ABIERTO, sin solución aceptada.** El 11-10-2026 se probaron cuatro arreglos y el usuario
> rechazó los cuatro («de ninguna de las maneras que hemos probado es aceptable»). **El código está
> exactamente como en la versión 0.5.3** (`scripts/main.gd`, `shaders/focus_aid.gdshader` y
> `shaders/viewfinder_dof.gdshader` son los del commit `c9930b8`). Este documento recoge lo que se
> sabe, lo que se probó y por qué falló, para analizarlo a fondo en la siguiente sesión
> **antes de tocar nada**.

---

## 1. Lo que dice el usuario (literal, en orden)

1. «Haciendo enfoque manual, a veces al mover la cámara la zona de enfoque pega un salto y luego vuelve. Y eso me ha pasado con la TLR, por ejemplo, que no debería nunca autoenfocar.»
2. Tras el primer arreglo: «No solo sigue pasando, sino que además ahora la pantalla partida de la TLR hace efectos rarísimos con los objetos de detrás.»
3. «Para a los personajes, y mueve tú el ratón, mejor que usar el movimiento automático.»
4. «No quiero ningún tipo de ayuda enfocando en manual», aclarado enseguida: «**Deja todo lo que tenemos del enfoque manual.** Lo que quería decir es que **no podemos ayudar nunca al jugador moviendo por él el punto de enfoque si estamos en MF: solo debe reaccionar a lo que el jugador quiera mover**.»
5. Tras el segundo arreglo: «He dejado el punto de enfoque fijo al fondo en MF con una TLR, ha pasado alguien por delante, y se ha movido. No entiendo por qué pasa ni eso de "la doble imagen se guía por lo que ocupa la mayor parte de la zona": **la doble imagen la controla el jugador y representa la realidad de lo que hay detrás**.»
6. Tras el tercero: «Ahora no se mueve el punto de enfoque manual, pero **la imagen partida se ve HORRIBLE. Visualmente era PERFECTO antes de empezar todos estos cambios**: solo quiero que no se mueva el punto de enfoque.»
7. Tras el cuarto: «Listo, eso era lo que quería», y acto seguido: «¿No puedes hacer que la imagen partida **se recalcule en cada frame, pero sin mover el punto de foco**?»
8. Cierre: «Revierte todos los cambios y documenta a fondo este problema. […] de ninguna de las maneras que hemos probado es aceptable.»

### Requisitos que se deducen (todos a la vez)

- R1. En MF **nada mueve el punto de enfoque salvo el jugador** (anillo de enfoque; y la cámara, que es suya).
- R2. La imagen partida y la doble imagen **representan la realidad** de lo que hay en la zona y **las controla el jugador**.
- R3. El **aspecto** de la imagen partida de la 0.5.3 es el bueno: no se rediseña.
- R4. La imagen partida debe **calcularse en cada fotograma** (no quedarse con una lectura vieja).
- R5. Se conserva todo lo que hay del enfoque manual (imagen partida, doble imagen, etiqueta «foco alineado», lupa).

**No está aclarado qué es exactamente «el punto de enfoque» en pantalla para el usuario.** Es la primera cosa que hay que resolver (§6): mis cuatro intentos partieron de suponerlo.

---

## 2. Cómo funciona hoy (0.5.3)

`main.gd::update_focus_aid(dt)`, en cada fotograma mientras se busca con la cámara en el ojo y el modo de enfoque es MF:

1. Lanza **cinco rayos** desde la zona central del visor: el centro y ±24 px en horizontal, ±16 px en vertical (píxeles de interfaz).
2. Elige la «distancia de la zona» (`patch_distance`): **la persona más cercana que toque cualquiera de los cinco**; si ninguno toca a una persona, **el decorado más cercano** de los cinco.
3. Calcula un único desplazamiento: `(1/foco − 1/distancia_zona) · focal · 0,006`, limitado a ±0,06 del ancho, y lo suaviza (`1 − e^(−22·dt)`).
4. `shaders/focus_aid.gdshader` (capa 2D sobre el visor) desplaza con ese valor **toda la zona**: la mitad de arriba hacia un lado y la de abajo hacia el otro (TLR, réflex en MF) o una copia semitransparente (telemétrica).
5. La etiqueta «foco alineado» se enciende si esa distancia cae dentro de la profundidad de campo o el desplazamiento es casi nulo.

Es decir: la imagen partida **no es óptica, es una lectura**. Compara el foco del jugador con «lo que hay debajo», decidido por cinco rayos con prioridad para las personas, y mueve toda la zona con un solo número.

### Lo que NO cambia (comprobado fotograma a fotograma)

Girando 25 s con la tecla mantenida y moviendo el ratón con la gente parada, con la TLR en MF, **no cambió ni una vez**: `focus_distance`, el plano de enfoque del desenfoque del visor (`focus_m` de `viewfinder_dof.gdshader`), si el desenfoque está activo, la focal, la lupa, `view_rect`, la posición de la capa de la ayuda, ni el punto activo. `focus_distance` solo se asigna en `autofocus()` (sale si es MF), el AF continuo (sale si no es AF-C/AF-A), `set_manual_focus()` (anillo, rueda, ratón derecho, palanca derecha), las demostraciones y la Academia.

**Lo único que cambia es `smoothed_focus_aid_offset`**: el desplazamiento de la imagen partida.

---

## 3. Lo que se midió

- **Girando con la TLR, foco a 7 m, 40 s:** 34 saltos del desplazamiento. En cada uno, bajo la zona había mezcla de distancias: «persona a 1,3 m» junto a «papelera a 5,7 m», «farola a 2,6 m» junto a «suelo a 15,8 m», etc.
- **Ratón, gente parada (método del usuario):** captura con la zona mostrando un banco enfocado («foco alineado») y, dos fotogramas después, el brazo de alguien a 1,3 m rozando el borde izquierdo del círculo: toda la imagen partida al máximo desplazamiento («alinear imagen»). Un solo rayo de los cinco tocaba a la persona.
- **Cámara quieta, foco al fondo, alguien cruza por delante:** el desplazamiento salta a la distancia de esa persona mientras ocupa la zona y vuelve después (es el punto 5 del usuario).
- Los rayos están a ±24 px de interfaz, pero el círculo de la TLR mide unos 56 px de radio (a 720 de alto): se mide el centro de la zona, no la zona.

---

## 4. Los cuatro intentos y por qué se rechazaron

| # | Qué se hizo | Resultado para el usuario | Por qué falló |
|---|---|---|---|
| 1 | **Once franjas**: once rayos a lo ancho de la zona, un desplazamiento por franja en el sombreador 2D | «Sigue pasando» y «efectos rarísimos con los objetos de detrás» | Diagnóstico a medias (creí que era una farola rozando la zona) y arreglo que **cambiaba el aspecto**. Los rayos chocan con colisionadores (cápsulas), no con la silueta que se ve, y cada franja muestreaba con el desplazamiento del destino, no del origen |
| 2 | **Mediana de las cinco lecturas**, sin prioridad a personas ni a lo más cercano (y punto activo siempre central en MF) | «He dejado el punto de enfoque fijo al fondo, ha pasado alguien por delante, y se ha movido» | Seguía siendo un solo número para toda la zona: quien **ocupa** la zona se la lleva entera, fondo incluido. Solo arreglaba el roce en el borde |
| 3 | **Óptica píxel a píxel** en el pase 3D del visor (`viewfinder_dof.gdshader`, con la profundidad de cada píxel): lo enfocado queda alineado, solo se parte lo que está a otra distancia | «Ahora no se mueve el punto de enfoque manual, pero la imagen partida se ve HORRIBLE» | Cumplía R1 y R2 pero rompía R3. Causas probables del mal aspecto, **sin confirmar con el usuario**: búsqueda en 32 pasos (escalones de ~5 px), huecos donde lo desplazado deja su sitio, fuentes limitadas al interior de la zona (los bordes quedaban sin desplazar: media zona se movía y media no al girar el anillo), sin el suavizado del original |
| 4 | **Sombreadores de la 0.5.3 intactos**; la distancia de la zona solo se relee cuando el jugador mueve cámara, focal, posición o anillo | «Eso era lo que quería», y luego «¿no puedes hacer que se recalcule en cada frame, pero sin mover el punto de foco?» | Cumple R1 y R3 a costa de R4: con todo quieto, la zona muestra una lectura vieja (alguien que se para delante no se refleja) |

Propuse además un quinto (en vivo, pero un cambio no provocado por el jugador solo cuenta si dura ~1 s) y **no se llegó a probar**: el usuario cerró con «de ninguna de las maneras».

### La contradicción de fondo

Con **un solo desplazamiento para toda la zona** (el aspecto que gusta, R3), «en vivo» (R4) implica que cuando alguien entra en la zona se mueve también el fondo enfocado, que es justo lo que el usuario percibe como «se mueve el punto de enfoque» (R1). Las salidas conocidas son tres y las tres están rechazadas: congelar la lectura (4), que cada punto tenga su desplazamiento (3) o elegir mejor a quién se mira (1 y 2). **O falta una cuarta que no he visto, o no he entendido qué ve el usuario.**

---

## 5. Hipótesis sin probar

1. **Que «el punto de enfoque» no sea la imagen partida.** Solo comprobé variables; no vi nunca la pantalla del usuario (4K, perfil con MSAA 8×, SDFGI 8). Puede haber algo visual que salte y que no esté en lo que registré: el desenfoque del visor con MSAA, la etiqueta «foco alineado» y el círculo que cambian de color, la marca del seguimiento con teclas, el paralaje. **Hay que verlo con él** (una grabación de pantalla o describirlo sobre una captura) antes de cualquier otra cosa.
2. **Que el intento 3 fuera la idea correcta mal dibujada.** El usuario dijo que con él «no se mueve el punto de enfoque». Si lo «horrible» eran los artefactos (escalones, huecos, bordes) y no el concepto, cabe rehacerlo bien: desplazamiento continuo, sin límite a la zona, con el mismo suavizado y el mismo aspecto que el original cuando toda la zona está a una distancia. **Preguntar primero qué era lo horrible, con capturas de antes y después lado a lado.**
3. **Que la referencia deba ser el foco del jugador y no la escena.** Por ejemplo, un desplazamiento que dependa solo de cuánto falta para alinear *lo que el jugador estaba alineando* (la última distancia que dejó alineada), en vez de «lo que hay debajo ahora». No está pensado a fondo.
4. **Los rayos miden mal la zona** (±24 px en un círculo de 56 px de radio, y contra cápsulas). Aunque no sea la causa, cualquier solución basada en rayos hereda ese defecto.

Hallazgo aparte, también revertido y pendiente de decidir: en las cámaras sin autofoco el **punto de enfoque activo** (`finder.active`) no se dibuja, pero el exposímetro y el seguimiento con teclas lo usan, y puede haberse quedado fuera del centro de un nivel anterior con autofoco. No tiene que ver con la imagen partida.

---

## 6. Plan para la siguiente sesión

1. **Aclarar con el usuario, sobre una captura o una grabación suya, qué es «el punto de enfoque» que ve moverse** y qué debería pasar exactamente en estos tres casos: (a) cámara quieta, foco al fondo, alguien cruza la zona; (b) cámara quieta, foco al fondo, alguien se para en la zona; (c) girando la cámara, la zona pasa de un sujeto enfocado al fondo.
2. Enseñarle lado a lado la 0.5.3 y el intento 3 en esos tres casos y preguntar **qué** es lo horrible.
3. Solo entonces proponer **una** solución, con capturas, y esperar su visto bueno antes de programarla.

Para reproducir: sesión libre, TLR (`equipment.preset(3)`), `sandbox_paused = true` para parar a la gente, `set_manual_focus(d)`, y mover la cámara con eventos de ratón (botón izquierdo y arrastre). Registrar `smoothed_focus_aid_offset` y capturar el centro de la pantalla.

---

## 7. Trampas en las que caí (y cómo no repetirlas)

1. **Diagnosticar sin reproducir como el usuario.** Empecé leyendo código y simulando la tecla de giro mantenida; el fallo se veía con el ratón y la gente parada. *Primero reproducir con su método y mirar una captura; después, pensar.*
2. **Dar por hecha la causa a la primera coincidencia.** Vi «farola a 2,6 m» en el registro y lo di por bueno; era solo uno de los casos. *Una causa no está confirmada hasta que el arreglo hace desaparecer el síntoma en la reproducción del usuario.*
3. **Arreglar el comportamiento cambiando el aspecto.** Me pidió que algo no se moviera y le rediseñé la imagen partida dos veces (intentos 1 y 3). *Si algo «visualmente es perfecto», el arreglo no toca sombreadores; y cualquier cambio visual se enseña y se pregunta antes.*
4. **Entregar arreglos parciales uno tras otro como si fueran el definitivo.** Cuatro veces dije «corregido». *Cuando el primero falla, parar: el modelo mental es incorrecto. Volver a preguntar qué ve, no probar otra variante.*
5. **No preguntar lo esencial.** Nunca le pedí que señalara en una captura qué se movía. Interpreté «zona de enfoque», «punto de enfoque» y «ayuda» por mi cuenta, y «no quiero ninguna ayuda» estuve a punto de entenderlo como «quita la imagen partida». *Con términos ambiguos, una captura anotada y una pregunta concreta antes de programar.*
6. **Confundir «lo físicamente correcto» con «lo que quiere».** El intento 3 era óptica fiel y lo rechazó por su aspecto. *La regla del proyecto es que se entienda y se disfrute, y quien decide el aspecto es él.*
7. **Comprobar durante media hora.** Encadené baterías de pruebas y perseguí un fallo intermitente de la Academia que no tenía que ver; me lo reprochó dos veces. *Solo las pruebas afectadas, y una captura del caso reportado vale más que diez suites.*
8. **Dejar el repositorio a medias al cortar una comprobación.** Hice `git stash` para comparar, maté los procesos con un `pkill` que se llevó mi propia orden y los cambios se quedaron apartados sin que lo notara hasta mirar. *No usar `git stash` para comparar (mejor `git worktree` o una copia), y tras interrumpir algo, comprobar `git stash list` y `git status` antes de seguir.*
9. **Medir el tiempo con el reloj real** en herramientas que corren con la ventana tapada (el compositor frena los fotogramas): di por buenos unos datos de «sujeto inmóvil» que eran un artefacto. *Usar el reloj del juego (`total_time`).*
10. **Añadir «de paso» arreglos que nadie pidió** (el punto activo central en MF) dentro del mismo cambio: hubo que revertirlo con todo lo demás. *Un hallazgo lateral se anota y se propone aparte.*
