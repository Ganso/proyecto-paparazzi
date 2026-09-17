# Especificación Futura: Estilo Visual Canónico (Maniquíes + Cell Shading), Profundidad Multi-Plano (7+ Capas) y Fondo Escénico

Este documento establece la **dirección artística y técnica canónica** para la evolución gráfica de **Proyecto Paparazzi**, tomando como guía maestra la imagen conceptual de referencia [referencia.jpg](referencia.jpg) y expandiendo la composición del parque a una arquitectura de **profundidad multi-plano de 7+ capas**.

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
3. **Composición Escénica Multi-Plano**:
   - Escalado rico de planos espaciales: desde elementos de enmarcado inmediato y bancos delanteros con familias sentadas, pasando por la calzada peatonal de viandantes, praderas interiores con estanque y quiosco, hasta la verja clásica con estudiantes de fondo y el horizonte urbano con bruma.
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
| **Planos de Profundidad** | 4 carriles concéntricos básicos ($r \in [1.8, 11.5]\text{ m}$) sin capas intermedias ni primer plano de enmarcado. | **7+ capas continuas de profundidad**: de enmarcado frontal a skyline atmosférico lejano. | **Media** | Reorganizar las cotas radiales en `park.gd` y segmentar los carriles en capas de atrezo, acción y fondo. |
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

## 4. Arquitectura Escénica de Profundidad Multi-Plano (7+ Capas)

Un entorno de 4 planos ofrece un buen punto de partida, pero la fotografía urbana profesional y las obras maestras del cine se fundamentan en una **gradación continua de profundidad**. Pasar a un sistema de **7+ capas escénicas concéntricas** transforma la cámara de un simple visor a un lienzo donde la distancia focal, el diafragma y la composición por capas (*layering*) cobran su máximo protagonismo.

```
+---------------------------------------------------------------------------------------------------+
|                        ARQUITECTURA DE PROFUNDIDAD EN 7+ CAPAS ESCÉNICAS                          |
+---------------------------------------------------------------------------------------------------+
  [CAPA -1: ENMARCADO INMEDIATO / FOREGROUND BOKEH]       r = 0.4 m a 1.2 m
    * Follaje colgante, hojas de sauce, farola inmediata o barandilla en el borde del encuadre
    * Genera bokeh frontal desenfocado extremo con grandes aperturas (f/1.4 - f/2.8)
  -------------------------------------------------------------------------------------------------
  [CAPA 0: ACERA FRONTAL, DESCANSO Y AMBIENTACIÓN CERCANA] r = 1.4 m a 2.4 m
    * Acera de losas claras biseladas con bordillo de piedra blanca
    * Bancos clásicos de listones de madera ocupados por figuras sentadas (familias, charlas)
    * Papeleras y parterres con arbustos facetados bajos
  -------------------------------------------------------------------------------------------------
  [CAPA 1: CALZADA PEATONAL CERCANA — ACCIÓN PRIMARIA]     r = 2.8 m a 4.2 m
    * Mitad frontal del carril peatonal asfaltado
    * Viandantes evaluables de paso rápido, corredores en ropa de running y niños de la mano
    * Zona idónea para retratos de plano medio y primer plano fotográfico (50 mm - 85 mm)
  -------------------------------------------------------------------------------------------------
  [CAPA 2: CALZADA PEATONAL INTERMEDIA — ACCIÓN SECUNDARIA] r = 4.4 m a 6.2 m
    * Mitad trasera del carril peatonal: adelantamientos continuos y cruces dinámicos
    * Viandantes evaluables de cuerpo entero con teleobjetivo corto (85 mm - 105 mm)
  -------------------------------------------------------------------------------------------------
  [CAPA 3: PRADERA AJARDINADA Y ARQUITECTURA ICÓNICA]     r = 6.8 m a 10.5 m
    * Gran pradera de césped verde con senderos de gravilla suave
    * Estanque de agua con lámina celeste reflectante y borde de sillería
    * Cenador / Pérgola octogonal de madera con techumbre a varias aguas
    * Actores ambientales no evaluables paseando tranquilamente por el césped o descansando
  -------------------------------------------------------------------------------------------------
  [CAPA 4: FRONTERA MONUMENTAL Y VERJA CLÁSICA]           r = 11.0 m a 14.5 m
    * Verja perimetral de hierro negro con barrotes de punta de lanza
    * Pilares macizos de sillería de piedra blanca con remate piramidal clásico
    * Multitud secundaria de fondo: grupos de estudiantes con mochilas dirigiéndose a las puertas
  -------------------------------------------------------------------------------------------------
  [CAPA 5: PANTALLA VEGETAL Y ARBOLADO MEDIO]             r = 15.0 m a 22.0 m
    * Fila continua de árboles estilizados con copas poliédricas facetadas y setos altos
    * Crea la barrera visual natural que aísla el microclima del parque del bullicio exterior
  -------------------------------------------------------------------------------------------------
  [CAPA 6: HORIZONTE URBANO Y SKYLINE METROPOLITANO]      r = 25.0 m a 50.0 m
    * Siluetas escalonadas de rascacielos y torres de oficinas en tonos azulados agrisados
    * Gradiente de perspectiva aérea y bruma de distancia (Distance Fog)
  -------------------------------------------------------------------------------------------------
  [CAPA 7: BÓVEDA CELESTE Y ATMÓSFERA INFINITA]           r > 50.0 m
    * Cúpula celeste procedural con sol dinámico, nubes volumétricas poligonales y atenuación EV
+---------------------------------------------------------------------------------------------------+
```

### 4.1 Desacoplamiento Técnico en 3 Niveles de Fidelidad (Tiers)

Para sostener 7 capas con múltiples personajes y elementos escénicos sin degradar la tasa de 60 FPS ni violar el presupuesto de VRAM (<60 MiB):

```
+-------------------------------------------------------------------------------+
|             PIRÁMIDE DE RENDIMIENTO: 3 NIVELES DE FIDELIDAD (TIERS)           |
+-------------------------------------------------------------------------------+
  TIER 1: NÚCLEO FOTOGRÁFICO JUGABLE (Capas 1 y 2)
    * 21 Viandantes activos evaluables
    * Lógica completa de fotografía: 5 raycasts de oclusión, encuadre, prendas, CoC
    * Navegación cilíndrica 2D con anti-bloqueo y adelantamiento
  -----------------------------------------------------------------------------
  TIER 2: POBLACIÓN AMBIENTAL DESACOPLADA (Capas 0, 3 y 4)
    * 14 a 20 personajes secundarios (familias en bancos, estudiantes al fondo)
    * Cero coste en `photography.gd`: excluidos de listas de objetivos y raycasts
    * Animaciones de bajo coste: poses estáticas o bucles precalculados de paseo
    * Mallas combinadas compartidas con el mismo shader Toon
  -----------------------------------------------------------------------------
  TIER 3: ESCENARIO ESTÁTICO UNIFICADO (Capas -1, 0, 3, 4, 5, 6 y 7)
    * Todo el parque estático (aceras, bancos, cenador, estanque, verja, árboles)
    * Fusión en un único draw call con colores de vértice (`ARRAY_COLOR`)
    * MultiMeshInstance3D para elementos repetitivos (pilares de verja y farolas)
```

### 4.2 Impacto de los 7 Planos en la Jugabilidad Fotográfica

La presencia de 7 capas reales introduce mecánicas de composición profesional ausentes en juegos convencionales:

1. **Enmarcado Natural (*Frame within a Frame*)**:
   - Encuadrar al sujeto (Capa 1 o 2) utilizando elementos desenfocados de la Capa -1 (ramas de sauce) o de la Capa 4 (los barrotes y pilares de la verja clásica).
2. **Bokeh de Primer Término (*Foreground Blur*)**:
   - En objetivos luminosos ($f/1.4$, $f/2.0$), los elementos de la Capa -1 y 0 se diluyen en manchas pictóricas de color suave, otorgando un aspecto tridimensional cinematográfico al retrato del sujeto enfocado.
3. **Compresión de Teleobjetivo vs. Gran Angular**:
   - A $135\text{ mm}$, las 7 capas se comprimen visualmente: el sujeto de la Capa 1 parece caminar justo delante del quiosco de la Capa 3 con el skyline de la Capa 6 alzándose inmediatamente detrás.
   - A $28\text{ mm}$, la perspectiva se expande y acentúa la sensación de inmensidad y soledad dentro del parque urbano.
4. **Nuevos Desafíos Fotográficos de Profundidad**:
   - *"Retrato en Capas"*: Capturar al objetivo nítido con al menos 1 viandante desenfocado en primer término y la multitud de fondo visible en la verja.
   - *"Composición en el Cenador"*: Retratar al sujeto alineado con el eje del cenador octogonal de la Capa 3.

---

## 5. Catálogo de Elementos para las 7 Capas Escénicas

Siguiendo el diseño armónico de `referencia.jpg`, el parque distribuye sus elementos arquitectónicos y vegetales a lo largo de las capas:

| Elemento Escénico | Capa / Radio | Descripción Geométrica / Material | Aporte a la Atmósfera |
|---|---|---|---|
| **Follaje Frontal Colgante** | Capa -1 ($r \approx 0.8\text{ m}$) | Hojas facetadas bajas y ramas de sauce en el margen superior | Crea enmarcado natural y bokeh de primer plano. |
| **Acera y Bordillos** | Capa 0 ($r \approx 1.8\text{ m}$) | Prisma curvo con losas rectangulares beige y bordillo blanco | Delimita el espacio del espectador y da escala humana. |
| **Bancos con Personajes** | Capa 0 ($r \approx 2.0\text{ m}$) | Listones de madera clara con patas de fundición gris oscuro | Elimina la sensación de soledad; familias y parejas charlando. |
| **Calzada Peatonal Bitonal** | Capas 1 y 2 ($r \approx 3.0 - 5.5\text{ m}$) | Firme de asfalto gris neutro con franjas laterales de adoquín | Guía visual del flujo peatonal activo. |
| **Estanque de Agua** | Capa 3 ($r \approx 7.5\text{ m}$) | Elipse de lámina azul reflectante con borde de sillería | Reflejos y contraste de color con la pradera verde. |
| **Pérgola / Cenador** | Capa 3 ($r \approx 9.0\text{ m}$) | Estructura octogonal de madera de 8 pilares con tejado cónico | Gran hito visual e icono paisajístico del parque. |
| **Verja Clásica con Pilares** | Capa 4 ($r \approx 12.5\text{ m}$) | Reja de hierro negro rematada por pilares de piedra blanca piramidales | Marco señorial y orden compositivo frente al fondo. |
| **Multitud Escolar de Fondo** | Capa 4 ($r \approx 13.5\text{ m}$) | Figuras simplificadas con mochilas de colores caminando juntas | Sensación de vida urbana más allá del área jugable. |
| **Arbolado Poligonal Facetado** | Capa 5 ($r \approx 16.0 - 20.0\text{ m}$) | Troncos marrones con copas poliédricas de 3 tonos verdes | Pantalla verde natural con estética de diorama pulido. |
| **Skyline con Bruma Aérea** | Capa 6 ($r \approx 30.0 - 50.0\text{ m}$) | Bloques rectangulares en gradiente hacia el azul celeste | Sensación de metrópoli viva abrazando el parque. |

---

## 6. Banco de Nuevos Accesorios e Interacciones

Para enriquecer la narrativa visual y las combinaciones de encargos, se especifican nuevos accesorios e interacciones de pose:

| Accesorio / Pose | Categoría | Implementación Geométrica | Efecto en Encargo / Pose |
|---|---|---|---|
| **Mochila Escolar / Urbana** | Accesorio `torax` | Cubo biselado con tiras dobles sobre hombros | Usada por estudiantes y jóvenes en Capas 1, 2 y 4. |
| **Niño Pequeño de la Mano** | Interacción doble | Modelo infantil vinculado cinemáticamente a la mano del adulto | Objetivo fotográfico especial: *"Retrato familiar"* o *"Tutor con hijo"*. |
| **Pose Sentado en Banco** | Pose estática | Flexión de caderas y rodillas a $90^\circ$, brazos sobre rodillas o respaldo | Permite habitar los bancos del parque sin consumir CPU de navegación. |
| **Gesticulación de Charla** | Pose animada | Cabeza inclinada $15^\circ$, antebrazo elevado con oscilación suave | Pareja sentada conversando en el banco de la Capa 0. |
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
3. **Fase 3: Remodelación Escénica del Parque a 7 Capas**  
   - Reestructurar `scripts/park.gd` para incorporar la acera frontal, los bancos habitados, el cenador octogonal, el estanque, los pilares de piedra de la verja y el follaje de enmarcado.
4. **Fase 4: Separación de Capas (Jugable vs. Ambiental)**  
   - Añadir soporte en `scripts/main.gd` para instanciar peatones de ambientación no evaluables (Tier 2) en bancos y parque interior.
5. **Fase 5: Actualización del Visor HUD**  
   - Rediseñar los colimadores centrales a 15 puntos en diamante y aplicar el display LCD verde de 7 segmentos de la referencia.
