# 28 · Enfoque manual: la imagen partida se mueve sola (problema abierto)

> **Estado: ABIERTO, sin solución aceptada, pero con el requisito ya aclarado (§0).** El 11-10-2026
> se probaron cuatro arreglos y el usuario rechazó los cuatro («de ninguna de las maneras que hemos
> probado es aceptable»). **El código está exactamente como en la versión 0.5.3**
> (`scripts/main.gd`, `shaders/focus_aid.gdshader` y `shaders/viewfinder_dof.gdshader` son los del
> commit `c9930b8`). Este documento recoge lo que se pide, lo que se sabe, lo que se probó y por
> qué falló, para retomarlo en la siguiente sesión **antes de tocar nada**.

---

## 0. Lo que se pide (aclarado por el usuario al cerrar la sesión)

> «Quiero que funcione **como en una cámara de verdad**: al cambiar la distancia de enfoque cambias
> el visionado, pero **el visionado solo representa el mundo real partido por la mitad**. **Jamás
> debe ocurrir que al pasar alguien por delante el fondo cambie en la pantalla partida: solo cambia
> la parte de la imagen partida a la que afecta ese objeto.** Vamos, COMO EN UNA CÁMARA DE VERDAD.
> Ahora mismo si pasa un corredor delante, aunque ocupe solo el 10 % de un lateral, el resto de la
> visualización de la imagen partida pega un salto y muestra una imagen distinta, y debería estar
> **completamente inalterado**.»

Dicho con mis palabras, para comprobar que lo he entendido:

1. La imagen partida **no es un indicador, es una vista del mundo**: lo que hay en la zona, cortado por la mitad, con cada mitad desplazada hacia un lado.
2. **Lo único que el jugador controla es la distancia de enfoque** (el anillo). Al girarlo cambia cuánto se desplaza cada cosa: lo que está a la distancia enfocada casa; lo que está más cerca o más lejos queda partido, tanto más cuanto más lejos esté de esa distancia.
3. **Cada cosa se desplaza según su propia distancia, no según la de otra.** Si un corredor entra por un lateral y ocupa un 10 % de la zona, cambia ese 10 %: se ve al corredor, partido. **El otro 90 % (el fondo) sigue exactamente igual que el fotograma anterior**, píxel a píxel.
4. Por tanto no existe una «distancia de la zona» ni nada que elegir: ni prioridad a las personas, ni lo más cercano, ni la mediana, ni lecturas que se congelan. Todo eso era el error.
5. El «punto de enfoque» del que hablaba todo el rato es esto: **dónde casa la imagen partida**. Si él no toca el anillo, lo que casaba tiene que seguir casando.

**El fallo de hoy, en una frase:** el juego calcula *un solo desplazamiento para toda la zona* a partir de «lo que hay debajo»; en cuanto algo entra en la zona, ese número cambia y **toda** la zona, fondo incluido, salta.

**Consecuencia para los cuatro intentos:** el concepto correcto era el del tercero (cada píxel con su desplazamiento, sacado de la profundidad). Se rechazó porque **se veía horrible**, no porque la idea fuera mala: lo pendiente es dibujarlo bien. Los otros tres (1, 2 y 4) seguían eligiendo o congelando un único número y no pueden cumplirlo nunca.

### Criterios de aceptación (para no volver a decir «corregido» sin serlo)

- **A. Fondo inalterado.** Cámara quieta, foco fijo en el fondo. Entra alguien por un lateral de la zona. Los píxeles de la zona que esa persona no ocupa (ni ella ni su imagen desplazada) son **idénticos** a los del fotograma anterior.
- **B. Igual que la 0.5.3 cuando toca.** Con toda la zona a una misma distancia (una pared, el seto), la imagen es **indistinguible** de la de la 0.5.3, enfocada o desenfocada, y al girar el anillo las dos mitades se deslizan igual de suaves. Ese es el aspecto que «era PERFECTO».
- **C. Solo el anillo mueve lo que casa.** Sin tocar el anillo, lo que estaba alineado sigue alineado aunque se mueva la cámara o pase gente.
- **D. La doble imagen de la telemétrica** cumple lo mismo: el fantasma de cada cosa se separa según su distancia; el del fondo enfocado no se mueve cuando alguien cruza.
- **E. Se enseña antes de darlo por bueno**: capturas lado a lado (0.5.3 / nuevo) de los casos A y B, y que el usuario lo vea.

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
- R4. La imagen partida debe **calcularse en cada fotograma** (no quedarse con una lectura vieja): es una vista del mundo, y el mundo se mueve.
- R5. Se conserva todo lo que hay del enfoque manual (imagen partida, doble imagen, etiqueta «foco alineado», lupa).

Durante la sesión no supe qué era «el punto de enfoque» en pantalla para el usuario y lo supuse cuatro veces. Quedó aclarado al final (§0, punto 9 de esta lista): es **dónde casa la imagen partida**.

9. La aclaración final, que es la que manda: «Quiero que funcione como en una cámara de verdad […] Jamás debe ocurrir que al pasar alguien por delante el fondo cambie en la pantalla partida: solo cambia la parte de la imagen partida a la que afecta ese objeto. […] Es que ya no sé cómo explicártelo.» (entera en el §0)

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

Con **un solo desplazamiento para toda la zona**, «en vivo» (R4) implica que cuando alguien entra en la zona se mueve también el fondo enfocado, que es justo lo que el usuario llama «se mueve el punto de enfoque» (R1). Elegir mejor a quién se mira (1 y 2) o congelar la lectura (4) no lo resuelven: sigue habiendo un único número.

**La salida es la del intento 3** (cada punto con su propio desplazamiento), y el usuario lo confirmó sin saberlo cuando dijo que con él «no se mueve el punto de enfoque». Lo que falló fue el dibujo. No era que yo no viera una cuarta vía: era que la tercera estaba mal hecha y, al rechazarla por su aspecto, la abandoné en vez de arreglarla.

---

## 5. Hipótesis sin probar

1. ~~Que «el punto de enfoque» no sea la imagen partida.~~ **Resuelto por la aclaración del §0:** sí es la imagen partida (dónde casa).
2. **Que el intento 3 fuera la idea correcta mal dibujada: confirmado como el camino.** Falta saber **qué** se veía horrible. Sospechas, por orden de probabilidad:
   - *Los bordes de la zona sin desplazar.* Limité las fuentes al interior de la zona, así que al girar el anillo con todo desenfocado se desplazaba el centro y los bordes se quedaban quietos: media zona partida y media no. La 0.5.3 trae imagen de fuera de la zona, y en una cámara real también entra.
   - *Escalones.* La búsqueda probaba 32 desplazamientos (uno cada ~5 px a 1280 de ancho): los contornos salían dentados.
   - *Huecos.* Donde algo cercano se desplaza y deja su sitio, puse la imagen sin desplazar: se ve el objeto dos veces.
   - *Sin el suavizado* de la 0.5.3 (que amortigua el desplazamiento al girar el anillo).
   - *Sin el desenfoque del visor dentro de la zona* y con la zona dibujada antes del tono y el resplandor.
   Hay que **verlo con capturas lado a lado** y preguntárselo, no adivinarlo.
3. ~~Que la referencia deba ser el foco del jugador y no la escena.~~ Descartada: no hay referencia que elegir (§0, punto 4).
4. **Los rayos no sirven para esto** (±24 px en un círculo de 56 px de radio, y contra cápsulas, no contra la silueta que se ve). La distancia tiene que salir de la profundidad de cada píxel, como en el intento 3. En OpenGL (Android y web) ese pase 3D no existe hoy: habrá que ver cómo darle profundidad a la zona allí, o aceptar una aproximación y decirlo.

Hallazgo aparte, también revertido y pendiente de decidir: en las cámaras sin autofoco el **punto de enfoque activo** (`finder.active`) no se dibuja, pero el exposímetro y el seguimiento con teclas lo usan, y puede haberse quedado fuera del centro de un nivel anterior con autofoco. No tiene que ver con la imagen partida.

---

## 6. Plan para la siguiente sesión

El qué ya está claro (§0). Queda el cómo, y enseñarlo antes de darlo por hecho:

1. Recuperar el intento 3 (commit `78d15e8`: `viewfinder_dof.gdshader` con `aid`/`aid_scale` y `main.gd::set_aid_optics()`) en una rama o copia, **sin subirlo**.
2. Sacar capturas lado a lado, 0.5.3 frente a ese intento, de: zona uniforme enfocada, zona uniforme desenfocada (varias posiciones del anillo), alguien entrando por un lateral, alguien ocupando media zona. Enseñárselas al usuario y preguntar **qué** es lo horrible.
3. Rehacer el dibujo hasta cumplir el criterio **B** (indistinguible de la 0.5.3 con la zona a una distancia) y el **A** (fondo inalterado), comprobándolos con diferencia de imágenes, no a ojo.
4. Enseñar el resultado (criterio **E**) y esperar su visto bueno antes de subirlo.

Para reproducir: sesión libre, TLR (`equipment.preset(3)`), `sandbox_paused = true` para parar a la gente, `set_manual_focus(d)`, y mover la cámara con eventos de ratón (botón izquierdo y arrastre). Registrar `smoothed_focus_aid_offset` y capturar el centro de la pantalla.

---

## 7. Trampas en las que caí (y cómo no repetirlas)

1. **Diagnosticar sin reproducir como el usuario.** Empecé leyendo código y simulando la tecla de giro mantenida; el fallo se veía con el ratón y la gente parada. *Primero reproducir con su método y mirar una captura; después, pensar.*
2. **Dar por hecha la causa a la primera coincidencia.** Vi «farola a 2,6 m» en el registro y lo di por bueno; era solo uno de los casos. *Una causa no está confirmada hasta que el arreglo hace desaparecer el síntoma en la reproducción del usuario.*
3. **Arreglar el comportamiento cambiando el aspecto.** Me pidió que algo no se moviera y le rediseñé la imagen partida dos veces (intentos 1 y 3). *Si algo «visualmente es perfecto», el arreglo no toca sombreadores; y cualquier cambio visual se enseña y se pregunta antes.*
4. **Entregar arreglos parciales uno tras otro como si fueran el definitivo.** Cuatro veces dije «corregido». *Cuando el primero falla, parar: el modelo mental es incorrecto. Volver a preguntar qué ve, no probar otra variante.*
5. **No preguntar lo esencial, y no escuchar lo que ya me había dicho.** En su quinto mensaje lo dijo entero: «la doble imagen la controla el jugador y representa la realidad de lo que hay detrás». Era la definición de una imagen partida de verdad y la leí como una queja sobre mi redacción. Tuvo que repetirlo, con un «es que ya no sé cómo explicártelo», para que lo entendiera. *Cuando el usuario describe cómo funciona el objeto real, eso es la especificación: construir eso, no una aproximación con atajos.* Además, nunca le pedí que señalara en una captura qué se movía. Interpreté «zona de enfoque», «punto de enfoque» y «ayuda» por mi cuenta, y «no quiero ninguna ayuda» estuve a punto de entenderlo como «quita la imagen partida». *Con términos ambiguos, una captura anotada y una pregunta concreta antes de programar.*
6. **Confundir «lo físicamente correcto» con «lo que quiere».** El intento 3 era óptica fiel y lo rechazó por su aspecto. *La regla del proyecto es que se entienda y se disfrute, y quien decide el aspecto es él.*
7. **Comprobar durante media hora.** Encadené baterías de pruebas y perseguí un fallo intermitente de la Academia que no tenía que ver; me lo reprochó dos veces. *Solo las pruebas afectadas, y una captura del caso reportado vale más que diez suites.*
8. **Dejar el repositorio a medias al cortar una comprobación.** Hice `git stash` para comparar, maté los procesos con un `pkill` que se llevó mi propia orden y los cambios se quedaron apartados sin que lo notara hasta mirar. *No usar `git stash` para comparar (mejor `git worktree` o una copia), y tras interrumpir algo, comprobar `git stash list` y `git status` antes de seguir.*
9. **Medir el tiempo con el reloj real** en herramientas que corren con la ventana tapada (el compositor frena los fotogramas): di por buenos unos datos de «sujeto inmóvil» que eran un artefacto. *Usar el reloj del juego (`total_time`).*
10. **Añadir «de paso» arreglos que nadie pidió** (el punto activo central en MF) dentro del mismo cambio: hubo que revertirlo con todo lo demás. *Un hallazgo lateral se anota y se propone aparte.*
11. **Abandonar la idea correcta al primer rechazo.** El intento 3 hacía lo que pedía y lo tiré entero porque se veía mal, para volver a un único desplazamiento que no podía cumplirlo. *Si rechaza el aspecto de algo que hace lo que pide, se arregla el aspecto; no se cambia de idea.*
12. **Pensar en «una lectura» donde había «una imagen».** Todo el código existente trata la imagen partida como un indicador (¿está enfocado lo que hay debajo?) y heredé ese marco sin cuestionarlo; por eso mis arreglos discutían *qué* leer. *Antes de arreglar, preguntarse qué representa la cosa en el mundo real y si el código la modela así.*

