# Especificación Futura: Estilo Visual Canónico (Maniquíes + Cell Shading), Planos de Profundidad y Fondo Escénico

Este documento establece la **dirección artística y técnica canónica** para la evolución gráfica de **Proyecto Paparazzi**, tomando como guía maestra la imagen conceptual de referencia [referencia.jpg](referencia.jpg).

---

## 1. Imagen Conceptual de Referencia

La siguiente imagen representa el objetivo visual definitivo (*target render*) para la estética del juego, la composición de planos, la vida del escenario y la interfaz del visor:

![Referencia Conceptual de Estilo Visual](referencia.jpg)

### 1.1 Desglose del Lenguaje Visual de la Referencia
1. **Personajes de Maniquí Artístico**:
   - Cuerpos de maniquí de dibujo anatómico en madera clara pulida, con **rótulas esféricas visibles** en cuello, hombros, codos, muñecas, caderas y rodillas.
   - Cabezas ovoides lisas y estilizadas sin rasgos faciales individuales, garantizando neutralidad absoluta y reforzando la ética de casting.
   - Ropa estilizada de formas limpias superpuesta sobre el maniquí de madera (camisetas, faldas, pantalones vaqueros, chaquetas abiertas, ropa de running deportiva ajustada).
2. **Sombreado Toon / Cell Shading**:
   - Sombreado en bandas de luz nítidas (2-3 tonos por superficie, sin degradados continuos fotorrealistas).
   - **Líneas de contorno limpias (*ink outlines*)** en color gris carbón/negro que perfilan con elegancia tanto a los personajes como a los elementos arquitectónicos y vegetales.
3. **Composición Escénica en 4 Planos de Profundidad**:
   - **Plano 0 (Primer término)**: Acera de losetas claras con bordillos definidos, parterre verde con bancos de madera ocupados por personas sentadas en actitudes naturales (familias, parejas charlando) y farolas de forja clásicas.
   - **Plano 1 (Calzada principal activa)**: Vía pavimentada donde transita el flujo peatonal principal (caminantes, corredores, adultos llevando niños de la mano).
   - **Plano 2 (Parque interior y vida de fondo no jugable)**: Zona ajardinada profunda con estanque de agua, cenador/pérgola octogonal de madera, verja perimetral de forja con grandes pilares de piedra blanca de remate piramidal, y **viandantes secundarios de ambientación** (estudiantes con mochilas, paseantes en el césped).
   - **Plano 3 (Horizonte urbano)**: Siluetas de rascacielos modernos bajo una agradable bruma atmosférica y desenfoque por profundidad de campo (DoF bokeh).
4. **Visor Réflex de Gama Alta**:
   - Retícula de 15 colimadores de enfoque en disposición de diamante/cruz central.
   - Marcas esquineras de encuadre en el marco visual.
   - Doble franja informativa con displays LCD retroiluminados en verde de 7 segmentos: velocidad (`1/250`), diafragma (`F4.0`), compensación de exposición (`-2..1..0..1..2+`), `ISO 400`, modo de disparo (`ONE SHOT`), nivel de batería y modo manual (`[M]`).

---

## 2. Diagnóstico Técnico: ¿A qué distancia estamos del estado objetivo?

A continuación se evalúa la distancia entre el estado actual del código/motor y la visión marcada por la referencia:

| Dimensión Técnica | Estado Actual en el Repositorio | Objetivo según `referencia.jpg` | Distancia / Brecha Técnica | Esfuerzo Estimado |
|---|---|---|:---:|:---:|
| **Modelado de Personajes** | 4 anatomías (`AFOTANDO`) hechas con prismas y cilindros duros ensamblados rígidamente (`tools/build_catalog.py`). | Maniquíes de madera articulados con rótulas esféricas visibles, torso torneado y prendas de ropa modeladas sobre el maniquí. | **Media-Alta** | Sustituir las mallas base en `data/piezas/` por geometrías de maniquí de madera con esferas de articulación. |
| **Sombreado y Render** | `StandardMaterial3D` con iluminación difusa continua Lambert/PBR rugoso (`gl_compatibility`). Sin bordes. | **Cell Shading / Toon Shading** con cuantización de luz en 2 bandas y delineado exterior (*ink outline*). | **Media** | Crear un shader de material con función `light()` toon y pase de contorno `next_pass` (*inverted hull*). Compatible con WebGL/GLES3. |
| **Planos de Profundidad** | 4 carriles cilíndricos concéntricos estrictos ( \in [1.8, 11.5]\text{ m}$). | 4 planos escénicos diferenciados: acera en primer término, calzada peatonal, parque interior con estanque y quiosco, skyline lejano. | **Media** | Reorganizar las cotas radiales en `park.gd` para crear la acera frontal, el paseo central y la gran pradera interior. |
| **Población y Multitudes** | 21 viandantes exactos (`counts = [3, 7, 6, 5]`). **Todos son 100% jugables** y reciben raycasts fotográficos en cada disparo. | Población dividida en **dos capas**: (1) Peatones jugables (objetivos) y (2) **Multitud de fondo / ambientación** no jugable (estudiantes, personas sentadas). | **Media** | Desacoplar la lista de personajes en `main.gd`: viandantes jugables en calzada vs actores estáticos/ambientales en bancos y parque interior. |
| **Poses y Actitudes** | Solo locomoción cíclica (caminar o correr en círculos sin deslizar el pie según `gait.gd`). Bancos vacíos. | Variedad de actitudes: personas sentadas en bancos charlando, padres con niños de la mano, corredora con zancada deportiva, paseantes de fondo. | **Media** | Añadir poses de reposo/sentado (`SENTADO_BANCO`, `CHARLANDO`) y atrezo de manos vinculadas para niños. |
| **Escenario y Atmósfera** | Parque procedural básico: cubos para edificios, esferas para arbustos, cilindros de farolas simples (`park.gd`). | Parque rico y agradable: acera con bordillos, bancos clásicos de listones de madera, verja con pilares de sillería blanca, quiosco octogonal, estanque y árboles facetados armónicos. | **Media** | Enriquecer las funciones de ensamblado en `park.gd` añadiendo el estanque, la pérgola y pilares de piedra blanca. |
| **Visor HUD Réflex** | Visor funcional con 9 colimadores en cuadrícula, display inferior con textos y modos de cámara (`viewfinder.gd`). | Visor profesional réflex con retícula de 15 puntos en diamante, marcos de esquina y doble barra LCD verde de 7 segmentos. | **Baja-Media** | Rediseñar la retícula y tipografía de `viewfinder.gd` para aproximarla al estándar gráfico de la referencia. |

---

## 3. Especificación del Estilo Canónico: Maniquí de Madera + Cell Shading

### 3.1 Justificación Conceptual y Ética
- **Metáfora artística perfecta**: En un juego centrado en la fotografía y la composición artística, que los personajes sean maniquíes de dibujo articulados es una decisión diegética impecable que refuerza el tono del proyecto.
- **Solución definitiva a la ética de casting**: Los maniquíes de madera neutra eliminan cualquier ambigüedad en el tono de piel (todos comparten el acabado de madera noble natural: haya, arce, roble o nogal), concentrando las descripciones fotográficas exclusivamente en la indumentaria, accesorios y actitudes.
- **Eficiencia matemática de render**: Cada junta esférica o cilindro torneado tiene normales analíticas perfectas que se renderizan limpiamente con muy pocos polígonos (~2.200 a 2.600 triángulos por personaje completo).

```
+-------------------------------------------------------------------------------+
|                    ANATOMÍA DE MANIQUÍ ARTÍSTICO ARTICULADO                   |
+-------------------------------------------------------------------------------+
       (  ) Cabeza ovoide torneada (sin rostro, madera pulida)
        ||  Cuello cilíndrico
      [====] Hombros: articulación esférica vista (hueso hombro.D / hombro.I)
      |    | Torso superior: bloque curvado de madera / camiseta
       (  )  Cintura: esfera de rotación lumbar
      |====| Pelvis / Caderas: rótulas esféricas para fémur
      |    | Muslos torneados / pantalones
       (  )  Rodillas: junta esférica de flexión pura
      |    | Espinillas / pantorrillas
      (____) Pies / Zapatos estilizados de suela plana
```

### 3.2 Pipeline de Sombreado Toon en Godot 4 (`gl_compatibility`)

Para garantizar 60 FPS estables en navegadores y hardware móvil sin sobrecargar la GPU, el sombreado Toon se implementa mediante un shader directo de dos componentes:

#### A) Cuantización de Iluminación en Bandas (Shader Toon)
```glsl
shader_type spatial;
render_mode diffuse_toon, specular_toon;

uniform vec3 wood_albedo : source_color = vec3(0.85, 0.72, 0.55);
uniform float shadow_threshold : hint_range(0.0, 1.0) = 0.45;
uniform float shadow_smoothness : hint_range(0.0, 0.2) = 0.04;

void fragment() {
    ALBEDO = (COLOR.rgb != vec3(1.0)) ? COLOR.rgb : wood_albedo;
    ROUGHNESS = 0.85;
    SPECULAR = 0.15;
}

void light() {
    float NdotL = dot(NORMAL, LIGHT);
    float light_intensity = smoothstep(shadow_threshold - shadow_smoothness, 
                                       shadow_threshold + shadow_smoothness, 
                                       NdotL);
    DIFFUSE_LIGHT += clamp(light_intensity, 0.35, 1.0) * LIGHT_COLOR * ATTENUATION;
}
```

#### B) Líneas de Contorno Limpias (*Inverted Hull Outlines*)
El delineado exterior de los personajes y props se consigue mediante un segundo pase (`next_pass`) en el material:
- Modo de renderizado: `cull_front` (solo dibuja las caras traseras).
- Desplazamiento de vértices: `VERTEX += NORMAL * 0.008;` (extrusión uniforme de 8 mm hacia el exterior).
- Color del contorno: Gris oscuro o negro translúcido (`vec4(0.12, 0.12, 0.14, 1.0)`), insensible a la luz (`unshaded`).
- **Coste**: Renderizado en 1 solo draw call adicional por superficie, 100% compatible con WebGL y OpenGL Core Profile.

---

## 4. Estructura Escénica en 4 Planos y Vida Ambiental de Fondo

Para conseguir la riqueza y profundidad de `referencia.jpg`, el entorno del parque se rediseña en cuatro bandas espaciales concéntricas:

```
+-------------------------------------------------------------------------------+
|                       ESTRUCTURA EN 4 PLANOS DE PROFUNDIDAD                   |
+-------------------------------------------------------------------------------+
  [PLANO 0: PRIMER TÉRMINO]  r = 0.8 m a 2.2 m
    - Acera de losetas claras con bordillo biselado
    - Farolas de fundición de hierro estilo clásico
    - Parterres de césped con arbustos bajos poligonales
    - Bancos de parque de listones con personajes sentados (parejas, familias)
  -----------------------------------------------------------------------------
  [PLANO 1: ZONA JUGABLE PRINCIPAL]  r = 2.8 m a 5.2 m
    - Calzada peatonal ancha y pavimentada (paseo de asfalto/adoquín gris)
    - 21 viandantes activos (los objetivos de los encargos fotográficos)
    - Sistema de navegación 2D continuo con adelantamientos sin atascos
  -----------------------------------------------------------------------------
  [PLANO 2: PARQUE INTERIOR Y MULTITUD AMBIENTAL]  r = 5.8 m a 12.5 m
    - Pradera verde amplia y agradable
    - Estanque circular/elíptico con lámina de agua de azul suave
    - Cenador / Pérgola octogonal de madera con techumbre a varias aguas
    - Verja perimetral de forja con pilares de sillería de piedra blanca
    - MULTITUD DE FONDO (12-16 personajes secundarios no jugables):
        * Estudiantes con mochilas caminando
        * Parejas paseando por el césped
        * Viandantes descansando en el cenador
  -----------------------------------------------------------------------------
  [PLANO 3: HORIZONTE URBANO LEJANO]  r = 16.0 m a 40.0 m
    - Cortina de arbolado estilizado de copas poliédricas
    - Skyline de rascacielos con paleta azulada/bruma aérea
    - Desenfoque por profundidad de campo (DoF bokeh óptico)
```

### 4.1 Desacoplamiento Arquitectónico: Peatones Jugables vs. Multitud de Fondo

Uno de los mayores aprendizajes de la imagen de referencia es que **un escenario vivo requiere personajes de fondo que no necesariamente son objetivos fotográficos**:

1. **Peatones Jugables (Capa Activa)**:
   - Mantienen el límite estricto de **21 viandantes**.
   - Poseen evaluación completa en `photography.gd` (5 rayos de oclusión por personaje, cálculo de encuadre, distancia focal, visibilidad de prendas y puntuación).
   - Recorren la calzada principal del Plano 1.
2. **Multitud de Fondo / Ambientación (Capa Ambiental)**:
   - Se ubican en el Plano 0 (sentados en los bancos delanteros) y en el Plano 2 (parque interior, estanque y quiosco).
   - **Cero coste en el bucle fotográfico**: No se registran en la lista `evaluable_targets` ni emiten raycasts de oclusión física.
   - Si una foto los enfoca o encuadra, el fotómetro calcula la luz correctamente, pero no alteran la puntuación del encargo a menos que un futuro reto de *"paisaje urbano poblado"* lo solicite expresamente.
   - Utilizan una animación simplificada o estática (poses de sentado, charla o paseo lento en bucles prefijados).

---

## 5. Elementos para un Escenario Más Agradable y Armónico

Siguiendo el diseño de `referencia.jpg`, el parque debe incorporar los siguientes elementos arquitectónicos y botánicos:

| Elemento Escénico | Ubicación | Descripción Geométrica / Material | Aporte a la Atmósfera |
|---|---|---|---|
| **Acera y Bordillos** | Plano 0 ( pprox 1.5\text{ m}$) | Prisma curvo con losas rectangulares beige y bordillo blanco | Delimita el espacio del espectador y da sensación de escala humana. |
| **Bancos con Personajes** | Plano 0 ( pprox 2.0\text{ m}$) | Listones de madera clara con patas de fundición gris oscuro | Elimina la sensación de parque vacío; acoge familias y parejas charlando. |
| **Pérgola / Cenador** | Plano 2 ( pprox 8.5\text{ m}$) | Estructura octogonal de madera con 8 columnas, barandilla perimetral y cubierta cónica | Punto focal arquitectónico icónico del parque. |
| **Estanque de Agua** | Plano 2 ( pprox 7.0\text{ m}$) | Disco o elipse de agua azulada con borde de piedra blanca | Reflejos suaves y variedad cromática frente a la uniformidad del césped. |
| **Verja Clásica con Pilares** | Plano 2 ( pprox 12.0\text{ m}$) | Reja de barrotes verticales de hierro negro rematada por pilares de piedra blanca piramidales | Marco señorial y orden visual frente al horizonte. |
| **Vegetación Facetada** | Planos 0, 2 y 3 | Árboles con troncos marrones y copas poliédricas facetadas; arbustos bajos esféricos facetados | Estética *low-poly* armónica, orgánica y contemporánea. |
| **Skyline con Bruma** | Plano 3 ( > 20\text{ m}$) | Prismas de edificios rectangulares con gradiente hacia el azul cielo y atenuación de contraste | Sensación de gran metrópoli moderna rodeando el oasis del parque. |

---

## 6. Banco de Nuevos Accesorios e Interacciones

Para enriquecer la narrativa visual y las combinaciones de encargos, se especifican nuevos accesorios e interacciones de pose:

| Accesorio / Pose | Categoría | Implementación Geométrica | Efecto en Encargo / Pose |
|---|---|---|---|
| **Mochila Escolar / Urbana** | Accesorio `torax` | Cubo biselado con tiras dobles sobre hombros | Usada por estudiantes y jóvenes en Plano 1 y 2. |
| **Niño Pequeño de la Mano** | Interacción doble | Modelo infantil vinculado cinemáticamente a la mano del adulto | Objetivo fotográfico especial: *"Retrato familiar"* o *"Tutor con hijo"*. |
| **Pose Sentado en Banco** | Pose estática | Flexión de caderas y rodillas a 0^\circ$, brazos sobre rodillas o respaldo | Permite habitar los bancos del parque sin consumir CPU de navegación. |
| **Gesticulación de Charla** | Pose animada | Cabeza inclinada 5^\circ$, antebrazo elevado con oscilación suave | Pareja sentada conversando en el banco del Plano 0. |
| **Atuendo de Running Completo** | Ropa deportiva | Top deportivo ceñido, mallas y zapatillas de suela contrastada | Ya presente en `casting.gd`, reforzado estéticamente con silueta cel-shaded. |
| **Periódico o Revista Abierta** | Accesorio `mano` | Hoja doble ligeramente combada de color crema | Personaje leyendo en el banco o cenador. |

---

## 7. Hoja de Ruta de Implementación de la Nueva Estética

1. **Fase 1: Shaders Toon y Delineado**  
   - Implementar el shader `res://shaders/cel_shading.gdshader` con pase de contorno *inverted hull*.
   - Aplicar experimentalmente a los personajes actuales para validar el rendimiento en WebGL y escritorio.
2. **Fase 2: Prototipado del Maniquí Articulado**  
   - Modelar el cuerpo de maniquí de madera con rótulas esféricas en `tools/build_catalog.py`.
   - Vestir el maniquí con las prendas existentes respetando el rig de 20 huesos y el coloreado de vértice.
3. **Fase 3: Remodelación Escénica del Parque**  
   - Reestructurar `scripts/park.gd` para incorporar la acera con bordillos, los pilares de piedra de la verja, el cenador octogonal y el estanque.
4. **Fase 4: Separación de Capas (Jugable vs. Ambiental)**  
   - Añadir soporte en `scripts/main.gd` para instanciar peatones de ambientación no evaluables en bancos y parque interior.
5. **Fase 5: Actualización del Visor HUD**  
   - Rediseñar los colimadores centrales a 15 puntos en diamante y aplicar el display LCD verde de 7 segmentos de la referencia.
