# Galería Visual y Banco de Evidencias Gráficas

Este documento reúne las evidencias gráficas generadas de forma 100% automatizada y determinista por la suite `tools/capture_evidence.gd` y `tools/build_sheets.py`.
Todos los recursos se encuentran aislados del motor Godot mediante `.gdignore` para garantizar **cero polución de `.import` y cero consumo innecesario de VRAM**.

---

## 1. Estados Principales del Juego

Secuencia de momentos clave que recorre el ciclo de juego desde la interfaz inicial vectorial hasta el revelado químico de la fotografía.

| Estado | Captura | Descripción Técnica y Demostración |
|---|---|---|
| **01. Inicio / Intro** | ![Inicio](estados/01_inicio.png) | Menú principal vectorial, tipografía de palo seco antialiased procedural y paleta de diseño editorial sobrio. |
| **02. Briefing del Objetivo** | ![Briefing](estados/02_briefing.png) | Retrato 3D del objetivo con iluminación de estudio, descriptor morfológico y prendas de vestimenta asignadas. |
| **03. Visor Réflex** | ![Visor Réflex](estados/03_visor_reflex.png) | Visor óptico clásico con cuadrícula áurea, 9 puntos de enfoque AF, prisma esmerilado y aguja del exposímetro analógico. |
| **04. Parque en Día Despejado** | ![Parque Día](estados/04_parque_dia.png) | Plaza central abierta a $28\text{ mm}$, 21 viandantes simultáneos y fondo vegetal denso sin caídas de frame. |
| **05. Atenuación Lumínica por Nubes** | ![Nubes y EV](estados/05_nubes_ev.png) | Nube procedural ocultando el sol con atenuación de 3 EV, modificando el exposímetro y la exposición requerida. |
| **05b. Parque en Hora Dorada** | ![Hora Dorada](estados/05b_hora_dorada.png) | Puesta de sol a baja cota ($-15^\circ$), resplandor ambarino cálido, sombras rasantes dramáticas y reflejos en maniquíes. |
| **06. Parque en Modo Nocturno** | ![Parque Noche](estados/06_parque_noche.png) | Encendido crepuscular de farolas cálidas, iluminación omnidireccional y sombras proyectadas en tiempo real. |
| **07. Pantalla de Revelado** | ![Revelado](estados/07_revelado.png) | Procesado de imagen fotográfica con grano químico analógico, bokeh por CoC, desenfoque cinético y desglose de puntos. |
| **08. Ajustes Gráficos (Ultra por defecto)** | ![Ajustes Gráficos](estados/08_ajustes_graficos.png) | Selector escalonado de perfiles estándar (Bajo, Medio, Alto, Ultra) y desglose técnico granular en tiempo real. |

---

## 2. Hojas de Contacto de Assets (Spritesheets)

Renderizado en estudio 3D virtual neutro con iluminación uniforme de tres puntos y focal de $85\text{ mm}$.

### 2.1 Mobiliario Urbano y Parque
Bancos con listones de madera, farolas de forja clásica con emisión cálida, papeleras, jardineras y fuentes de piedra.

![Sheet Mobiliario](sheets/sheet_mobiliario.png)

### 2.2 Flora y Cobertura Vegetal
Árboles procedurales adultos y jóvenes con copas esferoidales facetadas, seto perimetral denso, arbustos de sotobosque y matas florales.

![Sheet Vegetación](sheets/sheet_vegetacion.png)

### 2.3 Catálogo de Prendas de Vestir
Colección completa de torsos (camisetas, polos, chaquetas formales, ropa técnica de running) y piernas (pantalones de vestir, vaqueros, faldas, bermudas y shorts de deporte).

![Sheet Prendas](sheets/sheet_prendas.png)

### 2.4 Accesorios y Peinados
Peinados (pelo corto, flequillo, melena, coleta y calvo), gorra, sombrero de ala, gorro de lana, bufanda y bandolera.

![Sheet Accesorios](sheets/sheet_accesorios.png)

### 2.5 Equipamiento Fotográfico y Ópticas
Cuerpos de cámara (compacta digital, telemétrica analógica, réflex monocular), teleobjetivos profesionales de gran apertura, objetivos fijos luminosos y carretes de película de 35 mm.

![Sheet Equipamiento](sheets/sheet_equipamiento.png)

---

## 3. Muestrario de Personajes (Line-up 3D)

Comprobación de la coherencia anatómica de los **4 somatotipos base** (Estándar, Delgado, Robusto, Infantil), el rig universal de 20 huesos y las combinaciones de vestimenta formal, de paseo y deportiva exclusiva (`sport: true`).

![Line-up de Personajes](personajes/personajes_lineup.png)

![Vistas de revisión](personajes/personajes_vistas.png)

---

## 4. Cinemática, Locomoción y Variación de Luz

Demostración interactiva en bucles GIF animados cuantizados con paleta de color optimizada:

| Animación | Demostración GIF | Fundamento Cinemático Demostrado |
|---|---|---|
| **Caminata Pausada** ($0.75\text{ m/s}$) | ![Anim Caminar](animaciones/anim_caminar.gif) | **Deslizamiento nulo comprobado** (`drift == 0.000000 m/frame`), planta del pie horizontal ($y=0$) durante el apoyo y balanceo pélvico suave. |
| **Carrera Atlética** ($2.80\text{ m/s}$) | ![Anim Correr](animaciones/anim_correr.gif) | **Fase aérea balística** (ambos pies en el aire simultáneamente), torso inclinado hacia delante y flexión angular de rodillas. |
| **Ciclo Sol / Nube / Noche** | ![Anim Clima Luz](animaciones/anim_clima_luz.gif) | Transición de iluminación cenital a sombra de nube (caída de 3 EV) y encendido nocturno de farolas con sombras dinámicas. |

---

## Novedades del 02-10-2026 (capturas sueltas, hechas a mano)

| Qué | Captura | Dónde está descrito |
|---|---|---|
| **Cielo propio**: cirros de día, resplandor de poniente, hora azul y noche con luna y estrellas | ![Cielo](cielo/cielo_cuatro_luces.jpg) | [ESCENARIO_Y_RENDIMIENTO.md §3.3](../ESCENARIO_Y_RENDIMIENTO.md) |
| **Mobiliario de la pradera**: mesas de pícnic, papelera y fuente de beber | ![Pradera](estados/pradera_mobiliario.jpg) | [ESCENARIO_Y_RENDIMIENTO.md §2.2](../ESCENARIO_Y_RENDIMIENTO.md) |
| **Dos amigos en la mesa de pícnic** | ![Mesa](estados/pradera_mesa_picnic.jpg) | [futuro/19 §9](../futuro/19_VIDA_EN_EL_PARQUE.md) |
| **Perros**: el de siempre y el pequeño con manchas | ![Perros](estados/perros.png) | [futuro/19 §9](../futuro/19_VIDA_EN_EL_PARQUE.md) |
| **Pantalla de carga e icono** | ![Carga](interfaz/00_carga.png) | [futuro/20](../futuro/20_INTERFAZ_CLARA.md) |
| **Opciones**, con la vibración del mando | ![Opciones](interfaz/12_opciones.png) | [futuro/22](../futuro/22_MENU_TUTORIAL_MANDO.md) |

---

*Galería compilada automáticamente por `tools/capture_evidence.gd` y `tools/build_sheets.py`.*
