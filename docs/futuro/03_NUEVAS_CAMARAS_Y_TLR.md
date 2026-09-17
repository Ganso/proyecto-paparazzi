# Especificación Futura: Nuevas Cámaras — TLR, Smartphone y Gran Formato

Este documento detalla el diseño mecánico, óptico y de interfaz para tres nuevas familias de cámaras fotográficas: la **TLR de formato medio** con visor invertido, el **Smartphone computacional** y el **Banco Óptico de gran formato**.

---

## 1. Cámara TLR (Twin-Lens Reflex / Rolleiflex) — [Mecánica Clásica Invertida]

La cámara réflex de objetivos gemelos de formato medio ($6 \times 6\text{ cm}$) introduce una de las mecánicas fotográficas más singulares y desafiantes de la historia de la fotografía.

```
+-------------------------------------------------------------------------------+
|                       VISOR DE CINTURA DE UNA TLR (6x6)                       |
+-------------------------------------------------------------------------------+
| [Caperuza parasol metálica negra]                                             |
|                                                                               |
|       +---------------------------------------------------------------+       |
|       |                                                               |       |
|       |               FORMATO CUADRADO 1:1                            |       |
|       |                                                               |       |
|       |     ¡MOVIMIENTO HORIZONTAL INVERTIDO EN EL ESPEJO!            |       |
|       |     - Si el viandante camina hacia la derecha,                |       |
|       |       en el visor se le ve desplazarse a la izquierda.        |       |
|       |     - Si el jugador gira la cámara hacia la derecha,          |       |
|       |       la escena se desplaza en sentido inverso.               |       |
|       |                                                               |       |
|       |              [ Círculo central con cristal esmerilado ]       |       |
|       |                                                               |       |
|       +---------------------------------------------------------------+       |
|                                                                               |
| [Lupa de enfoque 3x plegable]                    [Nivel de burbuja de aire]   |
+-------------------------------------------------------------------------------+
```

### Características Técnicas y Mecánicas
1. **Punto de Vista a la Cintura**:
   - La altura de la cámara desciende de $y = 1.60\text{ m}$ a **$y = 1.10\text{ m}$**.
   - Proporciona una perspectiva contrapicada clásica que engrandece a los sujetos y cambia radicalmente el horizonte.
2. **Inversión Especular Horizontal (Espejo a $45^\circ$)**:
   - Al no disponer de pentaprisma enderezador, el espejo plano invierte la imagen en el eje X:
     ```glsl
     // develop_tlr.gdshader
     vec2 uv = SCREEN_UV;
     uv.x = 1.0 - uv.x; // Inversión especular
     ```
   - **Jugabilidad**: Exige una concentración espacial superior al seguir a viandantes en movimiento o corregir el encuadre.
3. **Formato Cuadrado $1:1$**:
   - Máscara cuadrada de $720 \times 720$ píxeles en el centro de la pantalla.
   - Evaluación fotográfica adaptada a la simetría central y composiciones cuadradas.
4. **Carrete de Rollo 120**:
   - Exactamente **12 disparos** por rollo.
   - Manivela lateral mecánica animada con sonido de trinquete para avanzar el fotograma.

---

## 2. Smartphone Moderno (Fotografía Computacional)

Una experiencia fotográfica contemporánea basada en interfaces táctiles y algoritmos de procesamiento digital:

### Características Técnicas y Mecánicas
1. **Lentes Múltiples de Focal Fija por Salto (Triple Cámara)**:
   - En lugar de zoom óptico continuo, el visor salta entre 3 cámaras fijas:
     - Ultra Gran Angular: $13\text{ mm}$ ($f/2.2$).
     - Angular Principal: $24\text{ mm}$ ($f/1.8$).
     - Teleobjetivo Óptico: $77\text{ mm}$ ($f/2.8$).
2. **Modo Retrato Computacional**:
   - Simula profundidad de campo artificial mediante mapa de profundidad sintético.
   - **Mecánica visual imperfecta**: En ocasiones comete pequeños errores en mechones de pelo o bordes de sombreros, emulando la realidad de los teléfonos actuales.
3. **Control Táctil Directo**:
   - Tocar en cualquier punto de la pantalla para enfocar al instante con AF por detección de fase (PDAF).
   - Icono de sol deslizante junto al recuadro de enfoque para compensación rápida de exposición ($\pm 3\text{ EV}$).

---

## 3. Banco Óptico de Gran Formato (4 × 5 pulgadas)

La máxima expresión de la fotografía pausada de estudio y arquitectura sobre un trípode de madera:

### Características Técnicas y Mecánicas
1. **Visor de Paño Negro**:
   - La escena se visualiza sobre un gran cristal deslustrado que muestra la imagen **completamente invertida (cabeza abajo y de izquierda a derecha)**:
     ```glsl
     vec2 uv = vec2(1.0 - SCREEN_UV.x, 1.0 - SCREEN_UV.y);
     ```
2. **Movimientos de Fuelle (*Tilt-Shift* / Scheimpflug)**:
   - El jugador puede bascular (*tilt*) y descentrar (*shift*) el plano de la lente respecto al plano focal.
   - Permite mantener enfocados simultáneamente a un viandante en primer plano ($r = 1.8\text{ m}$) y al fondo del parque ($r = 14\text{ m}$) inclinando el plano de nitidez.
3. **Chasis de Placas Individuales**:
   - Un único disparo por chasis antes de tener que insertar el protector y extraer la placa.
   - Calidad de resolución extrema y bokeh cremoso imposible de lograr en formatos pequeños.

---

## 4. Tabla Resumen de Tipologías de Cámara

| Tipo de Cámara | Altura de Visor ($y$) | Relación de Aspecto | Efecto Óptico en Visor | Disparos por Carga |
|---|:---:|:---:|---|:---:|
| **Compacta 35mm** | $1.60\text{ m}$ | $3:2$ | Visor óptico directo con marcos colimados | 24 o 36 fotos |
| **Réflex (SLR)** | $1.60\text{ m}$ | $3:2$ | Imagen TTL real con prisma partido y microprismas | 36 fotos |
| **Telemétrica (Rangefinder)** | $1.60\text{ m}$ | $3:2$ | Imagen directa con doble parche de coincidencia | 36 fotos |
| **TLR (Rolleiflex)** | **$1.10\text{ m}$** | **$1:1$** | **Invertida horizontalmente (espejo plano)** | **12 fotos (Rollo 120)** |
| **Smartphone** | $1.50\text{ m}$ | $4:3$ / $16:9$ | Pantalla digital con PDAF y salto entre 3 cámaras | Ilimitado |
| **Gran Formato (4x5)** | $1.40\text{ m}$ | $5:4$ | **Invertida totalmente (180°) bajo paño negro** | **1 foto por chasis** |
