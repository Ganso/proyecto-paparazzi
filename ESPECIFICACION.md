# Proyecto Paparazzi — Especificación funcional del prototipo

**Versión:** 1.0 · **Fecha:** 7 de septiembre de 2026
**Estado:** normativo para el prototipo (*vertical slice*)

Este documento define **qué debe hacer** el prototipo, no cómo construirlo. Es
deliberadamente agnóstico de motor, lenguaje y formato de archivo: describe el
modelo del mundo, los algoritmos y los datos con precisión suficiente para
implementarlo con cualquier tecnología —un motor completo, una librería de
render inmediato o un motor propio— y obtener el mismo comportamiento
observable.

Cuando un valor es una **decisión de diseño ajustable**, aparece marcado como
`[ajustable]` y su valor por defecto es normativo hasta que se cambie.

---

## 1. Propósito y alcance

### 1.1 El juego

El jugador es un fotógrafo situado en un punto fijo. A su alrededor transcurre
una escena poblada de viandantes. Cada encargo le pide **fotografiar a una
persona concreta**, identificada por su aspecto ("el de melena pelirroja, con
americana gris y pantalón rojo"). El jugador debe:

1. **Encontrarla**, paneando la escena y usando el zoom.
2. **Fotografiarla bien**: enfocada, correctamente expuesta, sin trepidación,
   sin nada que la tape y bien encuadrada.

La calidad de la foto se evalúa con las reglas reales de la fotografía —
triángulo de exposición, profundidad de campo, velocidad mínima de obturación —
y se traduce en una nota. El juego es a la vez un buscador tipo *Busca a Wally*
y un simulador didáctico de cámara.

### 1.2 Qué incluye el prototipo

- Una localización jugable, en dos condiciones de luz (día y noche).
- Multitud de viandantes generados proceduralmente, todos distintos.
- Una cámara fotográfica con control manual de apertura, velocidad, ISO,
  distancia focal y enfoque.
- Generación de encargos: elegir un sujeto y describirlo por sus rasgos.
- Disparo, evaluación de la foto y pantalla de resultados con la imagen
  degradada según los errores cometidos.
- Bucle completo: encargo → búsqueda → disparo → evaluación → siguiente.

### 1.3 Qué NO incluye

- Historia, narrativa, personajes con nombre, diálogos o progresión entre
  partidas.
- Modos Escuela y Sandbox, tipos de cámara distintos del descrito en §5.
- Economía persistente, tienda, desbloqueos o guardado entre sesiones.
- Interiores, vehículos, animales, clima o ciclo día-noche dinámico.

### 1.4 Criterios de aceptación

El prototipo se considera terminado cuando, de forma verificable:

1. Se pueden generar 100 viandantes seguidos sin que dos sean idénticos ni
   aparezca ninguno con partes del cuerpo sin cubrir.
2. El sujeto del encargo existe siempre en la escena, es alcanzable con el
   paneo, y su descripción no encaja con ningún otro viandante presente.
3. Panear y hacer zoom responde por debajo de 50 ms en el dispositivo objetivo,
   con al menos 40 viandantes visibles.
4. Dos fotos con los mismos parámetros y el mismo estado de la escena reciben
   exactamente la misma nota (evaluación determinista).
5. Cada componente de la nota es explicable: la pantalla de resultados dice qué
   se hizo mal y por qué.
6. Una foto correcta con parámetros incorrectos (p. ej. sujeto perfecto pero
   1/15 s a 105 mm) recibe una nota baja, y la imagen mostrada exhibe
   visiblemente ese defecto.

---

## 2. Modelo del mundo

### 2.1 Sistema de coordenadas

El mundo es **cilíndrico y centrado en el jugador**. La posición de cualquier
elemento se expresa como `(θ, r, y)`:

| Símbolo | Significado | Unidad |
|---|---|---|
| `θ` | ángulo alrededor del eje vertical, creciente en sentido horario visto desde arriba | grados, `[0, 360)` |
| `r` | distancia horizontal al eje del jugador | metros |
| `y` | altura sobre el suelo | metros |

El jugador ocupa `r = 0`. Su cámara está a `y = 1.60 m` `[ajustable]` y **no se
traslada nunca**: solo gira sobre el eje vertical. No hay movimiento vertical de
cámara (ni *tilt*) en el prototipo `[ajustable]`.

> Esto convierte el escenario en un panorama cilíndrico que se despliega
> alrededor del jugador, que es la premisa del diseño: 3D real presentado como
> capas de profundidad.

### 2.2 Carriles

Los viandantes circulan por **anillos concéntricos** de radio constante. Al
mantenerse la distancia fija dentro de un carril, la profundidad de campo se
comporta de forma predecible y el jugador puede aprender la relación entre
apertura y carril, que es el objetivo didáctico.

| Carril | Radio `r` | Papel |
|---|---|---|
| 0 | 1,8 m | Primer plano de oclusión: farolas, ramas, viandantes que cruzan por delante |
| 1 | 4,0 m | Carril principal: aquí aparece el sujeto del encargo |
| 2 | 7,0 m | Tránsito intermedio |
| 3 | 11,5 m | Tránsito lejano |
| Fondo | ≥ 18 m | Decorado no transitable (edificios, arbolado, horizonte) |

El sujeto del encargo aparece en el carril 1 o 2 `[ajustable]`. Los carriles 0
y 3 existen para generar oclusiones y ruido visual.

### 2.3 Sectores angulares

| Sector | Rango `θ` | Contenido |
|---|---|---|
| Jugable | 0°–240° | Zona que el jugador puede encuadrar; contiene el sujeto |
| Bastidores | 240°–360° | Zona de aparición y retirada de viandantes |

El paneo está limitado al sector jugable más un margen de 10° a cada lado. Los
viandantes **nunca aparecen ni desaparecen a la vista**: entran y salen por
bastidores.

### 2.4 Escala aparente

No se falsea la perspectiva: la escena es 3D real y el tamaño aparente resulta
de la proyección. Con el sensor de §5.1 y una pantalla apaisada 16:9 —que
aprovecha los 36 mm de ancho y deja 20,25 mm de altura efectiva—, un adulto de
1,75 m se proyecta así:

| Distancia focal | Carril 1 (4 m) | Carril 2 (7 m) |
|---|---|---|
| 24 mm | 52 % de la altura | 30 % |
| 35 mm | 76 % | 43 % |
| 50 mm | 108 % (no cabe entero) | 62 % |
| 105 mm | 227 % | 130 % |

Estos números determinan el juego: para un retrato de cuerpo entero bien
encuadrado (§7.7 pide entre el 45 % y el 85 %) hay que combinar carril y focal,
y no existe una focal que sirva para todo.

### 2.5 Localizaciones y luz

El prototipo implementa **una** localización (parque urbano) en dos
condiciones. Cada condición define un valor de exposición de escena `EV_escena`
que es el que la evaluación toma como correcto:

| Condición | `EV_escena` | Descripción |
|---|---|---|
| Día soleado | 14,0 | Luz dura direccional, sombras marcadas |
| Noche con farolas | 4,0 | Luz puntual cálida bajo las farolas, ambiente casi nulo |

Valores de referencia para localizaciones futuras: plaza nublada de día 11,0;
plaza comercial de noche 5,5.

> `EV_escena` es un dato de la escena, no una consecuencia del render. La
> iluminación visual debe ser coherente con él, pero la evaluación usa el valor
> declarado.

### 2.6 Comportamiento de los viandantes

Cada viandante es una máquina de estados:

| Estado | Comportamiento | Transición |
|---|---|---|
| `CAMINANDO` | Recorre su carril a velocidad constante `v ∈ [0,9 ; 1,4] m/s`, orientado tangencialmente | Al alcanzar un punto de interés, `p = 0,15` → `DETENIDO`; al entrar en bastidores → `RETIRADO` |
| `DETENIDO` | Se para y reproduce una animación de espera | Tras `3–8 s` → `CAMINANDO` |
| `SENTADO` | Ocupa un banco libre | Tras `20–60 s` → `CAMINANDO` |
| `RETIRADO` | Fuera de escena, disponible para reutilizar | Al reaparecer → `CAMINANDO` |

La velocidad se expresa como **velocidad angular** `ω = v / r`, de modo que los
viandantes de carriles lejanos recorren más arco en el mismo tiempo aparente.

Densidad objetivo `[ajustable]`: 6 viandantes en el carril 0, 14 en el 1, 12 en
el 2 y 10 en el 3. Total 42 simultáneos.

---

## 3. Los viandantes

### 3.1 Principio

Todos los viandantes se ensamblan en tiempo de ejecución a partir de un
catálogo de piezas intercambiables. Ninguno está modelado a mano. El sistema
debe garantizar dos cosas:

- **Variedad suficiente** para que la búsqueda tenga sentido.
- **Descriptibilidad**: todo rasgo visible debe poder nombrarse en una frase,
  porque es así como se enuncian los encargos.

### 3.2 Perfiles anatómicos

Cuatro complexiones, con las proporciones fijadas por estos parámetros:

| Perfil | Altura | Anchura de hombros | Relación cabeza/cuerpo | Radio de articulación |
|---|---|---|---|---|
| Adulto estándar | 1,75 m | 0,42 m | 1 : 7,5 | 0,045 m |
| Adulto delgado | 1,80 m | 0,36 m | 1 : 8,0 | 0,038 m |
| Adulto robusto | 1,70 m | 0,52 m | 1 : 6,8 | 0,055 m |
| Niño | 1,15 m | 0,28 m | 1 : 4,8 | 0,032 m |

La **anchura de hombros es la de la silueta completa**, incluido el volumen del
hombro: los brazos cuelgan pegados al tronco, no separados de él.

Las alturas de las articulaciones se derivan de `NZ` (altura de la base del
cráneo, es decir, altura total menos la cabeza), como fracción de `NZ`:

```
tobillo 0,030   rodilla 0,323   entrepierna 0,542   cintura 0,692
pecho   0,808   hombro  0,929   cuello       0,965  coronilla 1,000 (= altura)
```

Al depender de `NZ` y no de la altura total, un perfil con la cabeza grande —el
niño— obtiene automáticamente piernas proporcionalmente más cortas, sin
necesidad de una tabla aparte.

Longitudes de extremidades, también relativas a `NZ`: brazo 0,215 · antebrazo
0,169 · mano 0,098. El muslo va de entrepierna a rodilla y la pierna de rodilla
a tobillo.

### 3.3 Estilo visual

Cuerpo articulado de formas simples: tronco de sección variable, esferas en las
articulaciones, extremidades tronco-cónicas, cabeza elipsoidal **sin rasgos
faciales**. Volumen bajo, superficies mates, sin texturas: el color plano es el
que porta la información. La ropa es la misma silueta del cuerpo engordada unos
milímetros, de modo que nunca aparecen escalones ni la piel atraviesa la tela.

**Ningún viandante aparece desnudo.** El cuerpo base siempre lleva las tres
piezas de vestuario.

### 3.4 Ranuras (*slots*) y piezas

Cada viandante se compone de una pieza por ranura:

| Ranura | Piezas | Obligatoria |
|---|---|---|
| `cuerpo` | uno de los cuatro perfiles | sí |
| `torso` | camiseta, camisa, americana, sudadera | sí |
| `piernas` | pantalón, pantalón de vestir, bermudas, falda | sí |
| `cabeza` | pelo corto, flequillo, melena, coleta, calvo, gorra | sí |

Combinaciones de silueta por perfil: 4 × 4 × 6 = **96**; con los cuatro
perfiles, 384. Multiplicado por las paletas (§3.6), el espacio de variantes
supera el millón, muy por encima de los 42 viandantes simultáneos.

### 3.5 Esqueleto y deformación

Un único esqueleto de **20 huesos**, idéntico para todas las piezas y todos los
perfiles (cambian las longitudes, no la jerarquía ni los nombres):

```
raiz
└── caderas
    ├── muslo.I ── pierna.I ── pie.I
    ├── muslo.D ── pierna.D ── pie.D
    └── lumbar ── torax ── cuello ── cabeza
                     ├── clavicula.I ── brazo.I ── antebrazo.I ── mano.I
                     └── clavicula.D ── brazo.D ── antebrazo.D ── mano.D
```

Requisitos de deformación:

- **Peso rígido**: cada vértice pertenece al 100 % a un solo hueso. No hay
  mezcla de influencias y, por tanto, no hay ajuste manual de pesos.
- Las esferas de las articulaciones se asignan al hueso *hijo* (la esfera del
  codo gira con el antebrazo), de modo que la silueta no se abre al doblarse.
- Todas las piezas comparten la misma **pose de reposo**, condición necesaria
  para que una prenda pueda montarse sobre el esqueleto de cualquier cuerpo del
  mismo perfil.

Presupuesto de geometría `[ajustable]`: ≤ 1 500 triángulos por viandante
completo; ≤ 5 000 para el cuerpo base más costoso.

### 3.6 Color y rasgos nombrables

Cada pieza expone hasta cuatro **zonas de color** con significado fijo:

| Zona | Qué tiñe |
|---|---|
| `piel` | cuerpo, cara, manos |
| `pelo` | cabello (no la gorra) |
| `tela_a` | color principal de la prenda superior |
| `tela_b` | color de la prenda inferior, los zapatos y los tocados |

Paletas con nombre, porque el nombre es lo que aparece en el encargo:

- **Piel**: clara, media, morena, oscura. *No se usa nunca para describir al
  objetivo* (§4.2).
- **Pelo**: moreno, castaño, rubio, pelirrojo, canoso.
- **Ropa**: negro, blanco, gris, azul marino, vaquero, rojo, verde, amarillo,
  beige, burdeos.

Cada color almacena sus **cuatro formas gramaticales** (masculino, femenino y
sus plurales) y cada pieza su género y número, para que el briefing concuerde:
"melena rubia", "pantalón vaquero", "bermudas grises".

### 3.7 Animación

| Animación | Duración | Uso |
|---|---|---|
| `caminar` | 1,000 s por ciclo (dos zancadas) | estado `CAMINANDO` |
| `espera` | ≥ 2 s, en bucle | estado `DETENIDO` |
| `sentado` | pose estática | estado `SENTADO` |

La animación reside en el cuerpo y **las prendas la heredan** por compartir
esqueleto: no se duplica por pieza.

Requisitos del ciclo de caminar:

1. **Bucle exacto**: el último fotograma coincide con el primero.
2. **Pie de apoyo a nivel del suelo**: la altura de la cadera en cada instante
   debe calcularse a partir del alcance vertical de la pierna que apoya, no con
   una oscilación arbitraria. Con las proporciones de §3.2 esto produce un
   descenso de ~6 cm en el contacto y ~1 cm a mitad de paso.
3. **Planta paralela al suelo durante el apoyo**: el ángulo del pie se
   especifica respecto al suelo y se corrige restando lo que aportan muslo y
   pierna.
4. **Sin patinaje**: cada perfil declara la distancia que avanza en un ciclo
   completo (su *zancada*). La velocidad de reproducción se ajusta a la
   velocidad real del viandante:

```
velocidad_reproduccion = duracion_ciclo_animacion / (zancada / velocidad_mps)
```

Zancadas de referencia: adulto estándar 1,461 m · delgado 1,518 m · robusto
1,397 m · niño 0,877 m.

5. **Desfase individual**: cada viandante arranca el ciclo en una fase
   aleatoria, para que la multitud no marche al unísono.

### 3.8 El catálogo

El vestuario es **datos, no código**. El pipeline de arte produce un catálogo
que el juego lee al arrancar. Esquema mínimo:

```
catalogo
  perfiles
    <id_perfil>
      etiqueta            "Adulto estándar"
      altura              1.75
      hombros             0.42
      relacion_cabeza     7.5
      zancada             1.461
      fps_animacion       24
      fotogramas_ciclo    24
      piezas
        <id_pieza>
          ranura          "torso" | "piernas" | "cabeza" | "cuerpo"
          etiqueta        "camisa"
          genero          "m" | "f" | "mp" | "fp"
          zona_color      "tela_a" | "tela_b" | "pelo" | ""
          etiquetas       ["manga_larga", "formal", "cuello"]
          admite_patron   true | false
          recurso         ruta o identificador del modelo
          zonas           orden de las zonas de color en la malla
  tonos_piel   { <nombre>: rgb }
  tonos_pelo   { <nombre>: { rgb, formas: [m, f, mp, fp] } }
  tonos_ropa   { <nombre>: { rgb, formas: [m, f, mp, fp] } }
```

Añadir una prenda nueva debe consistir en producir su modelo y su entrada de
catálogo, sin tocar el código del juego.

---

## 4. El encargo

### 4.1 Estructura

Un encargo consta de:

| Campo | Contenido |
|---|---|
| `sujeto` | referencia al viandante objetivo |
| `descripcion` | la frase que lee el jugador |
| `predicados` | los rasgos que definen al sujeto, en forma comprobable |
| `disparos` | número de fotos disponibles: **3** `[ajustable]` |
| `recompensa_base` | créditos que otorga una foto perfecta: **150** `[ajustable]` |

### 4.2 Generación

1. Se puebla la escena con viandantes aleatorios.
2. Se elige un candidato de los carriles 1 o 2 que esté en el sector jugable.
3. Se construye un **conjunto de predicados** a partir de sus rasgos, tomados
   de este vocabulario:

| Predicado | Ejemplo |
|---|---|
| pieza de una ranura | *lleva gorra*, *lleva falda* |
| pieza + color | *camisa amarilla*, *pantalón vaquero* |
| color de pelo | *rubio*, *pelirroja* |
| etiqueta de pieza | *va de traje* (etiqueta `formal`) |
| perfil | *el niño* |
| estado | *el que va corriendo*, *el que está sentado* |

   El tono de piel **no** forma parte del vocabulario: no se describe a nadie
   por el color de su piel.
4. Se comprueba la **unicidad**: si algún otro viandante presente satisface
   todos los predicados, se añade un predicado más. Si con cuatro predicados no
   se logra distinguirlo, se descarta el candidato y se prueba con otro.
5. Se redacta la descripción concordando género y número (§3.6).

### 4.3 Garantías

- El sujeto existe y está en el sector jugable en el momento de dar el encargo.
- El sujeto no entra en bastidores mientras el encargo está activo: al llegar al
  límite del sector, invierte el sentido de la marcha.
- La descripción distingue al sujeto de todos los demás viandantes presentes.
- Dificultad `[ajustable]` por número de predicados: 3 predicados (fácil), 2
  (medio), 1 más un rasgo compartido por varios señuelos (difícil).

---

## 5. La cámara fotográfica

### 5.1 Modelo óptico

Sensor de **36 × 24 mm** (formato completo), círculo de confusión de
referencia `c = 0,030 mm`.

El campo de visión horizontal se deriva de la distancia focal `f` en mm:

```
FOV_horizontal = 2 · atan( 36 / (2 · f) )
```

| `f` | FOV horizontal |
|---|---|
| 24 mm | 73,7° |
| 50 mm | 39,6° |
| 105 mm | 19,4° |

El sensor es de proporción 3:2 y la pantalla, apaisada 16:9. Se conserva el
**ancho**: los 36 mm horizontales se corresponden siempre con el borde
izquierdo y derecho de la imagen, y la altura efectiva del sensor queda en
20,25 mm.

> Si el motor expresa el campo de visión en vertical —lo habitual—, hay que
> convertirlo con la relación de aspecto antes de asignarlo. Usar el valor
> horizontal directamente produce un encuadre notablemente más cerrado de lo
> debido, y con él la evaluación del tamaño del sujeto (§7.7) deja de
> corresponderse con la óptica declarada.

### 5.2 Parámetros y rangos

| Parámetro | Valores | Paso |
|---|---|---|
| Distancia focal | 24 – 105 mm | continuo |
| Apertura `N` | 2,8 · 4 · 5,6 · 8 · 11 · 16 · 22 | pasos completos |
| Velocidad `t` | 1/1000 · 1/500 · 1/250 · 1/125 · 1/60 · 1/30 · 1/15 · 1/8 s | pasos completos |
| Sensibilidad `ISO` | 100 · 200 · 400 · 800 · 1600 · 3200 | pasos completos |
| Distancia de enfoque `s` | 0,8 m – infinito | continuo |

Todos los parámetros son de control manual directo. No hay modos automáticos en
el prototipo `[ajustable]`.

### 5.3 Enfoque

Cuadrícula de **9 puntos de enfoque** `[ajustable]` sobre el encuadre. Al
accionar el enfoque:

1. Se proyecta un rayo desde la cámara a través del punto activo.
2. Si impacta en un elemento del mundo, `s` toma la distancia a ese impacto.
3. El punto activo parpadea durante 0,15 s y suena una confirmación.
4. Si no impacta en nada, el enfoque no cambia y la confirmación es negativa.

El jugador también puede ajustar `s` manualmente.

### 5.4 Visor

La pantalla es el visor de la cámara. Contiene:

- **La imagen de la escena**, ocupando toda el área.
- **Marcas de encuadre** en las cuatro esquinas.
- **Cuadrícula de puntos de enfoque**, con el punto activo resaltado.
- **Barra de datos** con: velocidad, apertura, escala de exposición de −2 a +2
  con la aguja en la desviación actual, sensibilidad, modo de disparo e
  indicador de batería.
- **Indicador de modo manual**.
- **Distancia focal actual** y **disparos restantes**.

La escala de exposición muestra `ΔEV` (§7.4) en tiempo real: es la principal
herramienta de aprendizaje del jugador.

---

## 6. Entrada

### 6.1 Acciones abstractas

La lógica del juego solo conoce estas acciones. Cualquier dispositivo que las
proporcione es válido:

| Acción | Tipo | Efecto |
|---|---|---|
| `PANEO` | eje continuo | gira la cámara en `θ` |
| `ZOOM` | eje continuo | modifica la distancia focal |
| `ENFOCAR` | pulsación | ejecuta §5.3 sobre el punto activo |
| `PUNTO_AF` | selección discreta | cambia el punto de enfoque activo |
| `DISPARAR` | pulsación | toma la foto |
| `APERTURA` / `VELOCIDAD` / `ISO` | incremento y decremento | recorren la lista de valores |
| `ENFOQUE_MANUAL` | eje continuo | ajusta `s` |
| `CONTINUAR` | pulsación | avanza en la pantalla de resultados |

### 6.2 Mapeo táctil (normativo)

| Gesto | Acción |
|---|---|
| Arrastrar un dedo en horizontal | `PANEO`, con inercia y frenado |
| Pellizcar con dos dedos | `ZOOM` |
| Tocar sobre la imagen | `PUNTO_AF` (el más cercano al toque) + `ENFOCAR` |
| Tocar el botón de disparo | `DISPARAR` |
| Tocar un valor de la barra de datos y arrastrar | el parámetro correspondiente |
| Arrastrar dos dedos en vertical | `ENFOQUE_MANUAL` |

El arrastre vertical de un dedo **no hace nada**: el paneo es solo horizontal.

### 6.3 Mapeo de teclado y ratón

**Pendiente de definir.** Requisito: debe cubrir las mismas acciones de §6.1 sin
gestos multitáctiles. Hasta que se decida, cualquier mapeo provisional es
válido y no condiciona el resto de la especificación.

---

## 7. Evaluación de la fotografía

### 7.1 Momento del disparo

Al accionar `DISPARAR`, la simulación se congela y se registra un **expediente**
con todo lo necesario para evaluar sin ambigüedad:

| Dato | Contenido |
|---|---|
| Parámetros | `f`, `N`, `t`, `ISO`, `s` |
| Encuadre | orientación de la cámara y matriz de proyección resultante |
| Escena | `EV_escena` de la condición de luz activa |
| Sujeto | distancia `d`, velocidad, posición proyectada de sus puntos clave |
| Ocluyentes | resultado de los rayos de §7.6 |

La evaluación es **determinista**: el mismo expediente produce siempre la misma
nota. No interviene el contenido de los píxeles renderizados.

### 7.2 Rechazo

La foto se marca como **rechazada** (nota 0, sin estrellas) si:

- El sujeto del encargo no está dentro del encuadre, o
- su pecho queda fuera del rectángulo de imagen, o
- está tapado en 4 o más de los 5 puntos de control (§7.6).

En cualquier otro caso se calculan las cinco subpuntuaciones siguientes, todas
en el rango `[0, 1]`.

### 7.3 Enfoque — `S_foco`

Se mide el **círculo de confusión** con que el sujeto se proyecta en el sensor.
Con todas las distancias en milímetros:

```
CoC = ( f² · |d − s| ) / ( N · d · (s − f) )
```

```
S_foco = clamp( (5c − CoC) / (4c), 0, 1 )        con c = 0,030 mm
```

Es decir: nitidez perfecta mientras el desenfoque quepa en el círculo de
confusión, y degradación lineal hasta anularse en cinco veces ese valor.

| Ejemplo | `CoC` | `S_foco` |
|---|---|---|
| 50 mm, f/4, sujeto y foco a 4,0 m | 0,000 mm | 1,00 |
| 50 mm, f/4, foco a 5,0 m, sujeto a 4,0 m | 0,032 mm | 0,99 |
| 105 mm, f/2,8, foco a 4,2 m, sujeto a 4,0 m | 0,048 mm | 0,85 |
| 105 mm, f/2,8, foco a 7,0 m, sujeto a 4,0 m | 0,428 mm | 0,00 |

Para el visor y la pantalla de resultados se derivan además la **distancia
hiperfocal** y los límites de la profundidad de campo:

```
H  = f² / (N · c) + f
Dn = (H · s) / (H + (s − f))
Df = (H · s) / (H − (s − f))        (infinito si H ≤ s − f)
```

### 7.4 Exposición — `S_exposicion`

```
EV_camara = log2( N² / t ) − log2( ISO / 100 )
ΔEV       = EV_camara − EV_escena
```

```
S_exposicion = clamp( 1 − max(0, |ΔEV| − 0,5) / 2,5 , 0, 1 )
```

| `ΔEV` | `S_exposicion` | Lectura |
|---|---|---|
| 0,0 – 0,5 | 1,00 | correcta |
| 1,0 | 0,80 | ligeramente sub o sobreexpuesta |
| 1,5 | 0,60 | error de un paso y medio |
| 2,0 | 0,40 | claramente mal expuesta |
| ≥ 3,0 | 0,00 | quemada o empastada |

> Esta curva sustituye los escalones del documento de diseño original por una
> función continua: el jugador debe percibir que se acerca al valor correcto,
> no encontrarse saltos bruscos.

### 7.5 Movimiento — `S_movimiento`

Dos riesgos independientes; manda el peor.

**a) Trepidación del fotógrafo.** Regla de la inversa de la focal: el tiempo
límite a pulso es `1/f` segundos con `f` en milímetros.

```
razon      = t · f
S_pulso    = clamp( 1 − (razon − 1) / 2 , 0, 1 )
```

Sin penalización mientras `t ≤ 1/f`; nula a partir de `t = 3/f`.

**b) Movimiento del sujeto.** Se proyecta el desplazamiento del sujeto durante
la exposición sobre el sensor. Con `v` en m/s (componente perpendicular al eje
óptico), `t` en segundos, `f` en mm y `d` en metros:

```
arrastre_mm = (v · t) · f / d
S_sujeto    = clamp( (3c − arrastre_mm) / (2c) , 0, 1 )
```

```
S_movimiento = min( S_pulso, S_sujeto )
```

> El documento de diseño original usaba un umbral absoluto de 1,5 cm de
> desplazamiento en el mundo. Se sustituye por el arrastre proyectado, que es
> lo que de verdad determina si una foto sale movida: con la regla anterior, el
> mismo peatón salía igual de movido a 24 mm que a 105 mm, lo cual es falso y
> además destruye la lección que el juego quiere enseñar.

| Ejemplo (peatón a 1,2 m/s a 4 m) | arrastre | `S_sujeto` |
|---|---|---|
| 50 mm, 1/500 s | 0,030 mm | 1,00 |
| 50 mm, 1/125 s | 0,120 mm | 0,00 |
| 105 mm, 1/500 s | 0,063 mm | 0,45 |

### 7.6 Oclusión — `S_oclusion`

Se lanzan cinco rayos desde la cámara hacia otros tantos puntos de control del
sujeto: **cabeza, pecho, cadera, rodilla izquierda y rodilla derecha**. Un rayo
se considera bloqueado si impacta en cualquier elemento que no sea el propio
sujeto.

```
S_oclusion = (5 − bloqueados) / 5
```

Con 4 o 5 bloqueados la foto se rechaza (§7.2). La pantalla de resultados
nombra el elemento que tapa ("un viandante en primer plano", "una farola").

### 7.7 Encuadre — `S_encuadre`

Sobre la posición proyectada del sujeto, en coordenadas de imagen normalizadas
`[0, 1]`:

**a) Tamaño.** `h` = altura proyectada del sujeto dividida por la altura de la
imagen.

```
h ∈ [0,45 ; 0,85]  →  S_tamano = 1
h < 0,45           →  S_tamano = clamp( (h − 0,15) / 0,30 , 0, 1 )
h > 0,85           →  S_tamano = clamp( (1,15 − h) / 0,30 , 0, 1 )
```

**b) Recorte.** Si la cabeza o los pies quedan fuera del rectángulo de imagen,
`factor_recorte = 0,6`; en caso contrario, 1,0.

**c) Composición.** Si la abscisa del pecho cae a menos de 0,05 de una línea de
tercios (0,333 o 0,667), `bono_tercios = 0,15`; en caso contrario, 0.

```
S_encuadre = clamp( S_tamano · factor_recorte + bono_tercios , 0, 1 )
```

### 7.8 Nota global

```
S = 0,28·S_foco + 0,24·S_exposicion + 0,18·S_movimiento
  + 0,15·S_oclusion + 0,15·S_encuadre

nota = redondear( 100 · S )
```

| Nota | Estrellas | Fracción de recompensa |
|---|---|---|
| 90 – 100 | ★★★★★ | 1,00 |
| 75 – 89 | ★★★★☆ | 0,85 |
| 60 – 74 | ★★★☆☆ | 0,60 |
| 40 – 59 | ★★☆☆☆ | 0,35 |
| 1 – 39 | ★☆☆☆☆ | 0,15 |
| rechazada | — | 0,00 |

```
creditos = redondear( recompensa_base · fraccion )
```

De los disparos de un encargo **cuenta el mejor**. Un encargo se supera con 3
estrellas o más `[ajustable]`.

---

## 8. Revelado y resultados

Tras el disparo se muestra la fotografía obtenida junto a su ficha técnica. La
imagen **no es la captura limpia**: se le aplican las degradaciones que
corresponden a los errores medidos, de modo que el jugador vea el efecto de sus
decisiones.

| Defecto | Efecto sobre la imagen | Magnitud |
|---|---|---|
| Desenfoque | Difuminado uniforme | radio proporcional a `CoC` |
| Exposición | Desplazamiento de brillo y gamma, con recorte a blanco o a negro | proporcional a `ΔEV` |
| Movimiento del sujeto | Arrastre direccional en la dirección de marcha | proporcional a `arrastre_mm` |
| Trepidación | Arrastre direccional de ángulo aleatorio pero fijo por disparo | proporcional a `razon − 1` |
| Sensibilidad | Grano | nulo a ISO 100, muy visible a ISO 3200 |

La ficha muestra: `f`, `N`, `t`, `ISO`, la nota de cada subpuntuación con su
lectura en lenguaje llano, la calificación en estrellas y los créditos
obtenidos.

> Requisito didáctico: cada línea de la ficha debe decir **qué** salió mal y
> **por qué**, con la magnitud concreta. "Movida: a 1/60 s con 105 mm el pulso
> no basta; necesitabas 1/125 s o más" enseña; "Estabilidad: 40 %" no.

---

## 9. Bucle de juego

```
INICIO DE PARTIDA
  ├─ poblar la escena (§2.6)
  └─ para cada uno de los 5 encargos [ajustable]:
       ├─ generar encargo y mostrar el briefing (§4)
       ├─ BÚSQUEDA: el jugador panea, hace zoom, enfoca y ajusta parámetros
       ├─ hasta 3 disparos [ajustable]:
       │    ├─ capturar expediente (§7.1)
       │    ├─ evaluar (§7.2–7.8)
       │    └─ mostrar revelado y resultados (§8)
       └─ registrar el mejor disparo
RESUMEN DE PARTIDA
  └─ encargos superados, créditos totales, mejor fotografía
```

El jugador puede repetir la partida indefinidamente. No hay guardado ni
progresión entre partidas.

---

## 10. Requisitos no funcionales

| Requisito | Valor |
|---|---|
| Plataformas objetivo | tableta y teléfono táctil; ordenador de sobremesa |
| Orientación | apaisada, fija |
| Resolución mínima | 1280 × 720 |
| Fotogramas por segundo | ≥ 30 sostenidos con 42 viandantes visibles |
| Latencia de paneo | < 50 ms desde el gesto al movimiento |
| Conectividad | ninguna; el juego funciona sin red |
| Idioma | español; los textos visibles deben poder externalizarse |
| Determinismo | la evaluación no depende de la tasa de refresco ni del render |

Presupuestos `[ajustable]`: ≤ 1 500 triángulos por viandante, ≤ 80 000 en toda
la escena, ≤ 60 MB de memoria de gráficos.

---

## 11. Glosario

| Término | Definición |
|---|---|
| **Carril** | Anillo concéntrico de radio constante por el que circulan los viandantes |
| **Sector jugable** | Franja angular que el jugador puede encuadrar |
| **Bastidores** | Franja angular donde los viandantes aparecen y se retiran sin ser vistos |
| **Ranura** (*slot*) | Hueco del vestuario que ocupa exactamente una pieza |
| **Pieza** | Elemento intercambiable de vestuario o anatomía |
| **Zona de color** | Región de una pieza que se tiñe con un color de paleta |
| **Predicado** | Rasgo comprobable que forma parte de la descripción del objetivo |
| **Expediente** | Conjunto de datos capturados en el instante del disparo |
| **Zancada** | Distancia que avanza un personaje en un ciclo completo de caminar |
| **`EV`** | Valor de exposición; cada unidad equivale a duplicar o dividir la luz |
| **`CoC`** | Círculo de confusión: diámetro con que un punto se proyecta en el sensor |

---

## 12. Apéndice: implementación de referencia (no normativo)

Existe una implementación en curso que usa un motor 3D con soporte de esqueletos
y un generador de geometría por *script* para producir el catálogo de piezas.
Nada de lo descrito en este documento depende de esa elección: una realización
con una librería de render inmediato y un formato de malla propio sería
igualmente conforme siempre que respete el modelo del mundo (§2), el sistema de
piezas y esqueleto (§3), los algoritmos de evaluación (§7) y los criterios de
aceptación (§1.4).

Las únicas exigencias reales sobre la tecnología son:

1. Proyección en perspectiva con campo de visión controlable en tiempo real.
2. Deformación de mallas por esqueleto, con al menos 20 huesos y una influencia
   por vértice.
3. Consulta de intersección rayo-escena para el enfoque y la oclusión.
4. Sustitución de color por zona en tiempo de ejecución.
5. Post-proceso de imagen: difuminado, arrastre direccional, curva de brillo y
   ruido.

Godot está en el sistema, puedes usarlo para el prototipo