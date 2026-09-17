# Especificación Futura: Estilo Visual, Polígonos y Nuevos Accesorios

Este documento analiza tres enfoques estéticos para una futura evolución gráfica de los personajes y el entorno, junto con la especificación de un nuevo banco de accesorios de vestimenta.

---

## 1. Análisis Comparativo de Enfoques Visuales

Actualmente, los personajes se generan mediante figuras geométricas paramétricas de bajo poligonaje (~1.550 triángulos/persona) unificadas con sombreado plano o Gouraud simple y colores de vértice.

A continuación se analizan tres líneas estilísticas alternativas para una revisión gráfica intensiva:

```
+-------------------------------------------------------------------------------+
| ENFOQUE 1: MANIQUÍ ARTÍSTICO       ENFOQUE 2: LOW-POLY SUAVIZADO   ENFOQUE 3: SEMI-REALISTA
+-------------------------------------------------------------------------------+
  - Esferas y cilindros de madera      - Subdivisiones y biseles       - Esculpido orgánico
  - Juntas esféricas vistas            - Normales ponderadas suaves    - Mallas de ropa drapeada
  - Fuerte identidad visual            - Minimalismo contemporáneo     - Micro-detalles faciales
  - Presupuesto: ~2.500 tris           - Presupuesto: ~3.500 tris      - Presupuesto: ~8.000 tris
```

### Enfoque 1: Muñeco de Referencia Artística (Maniquí de Madera Articulado) — [Opción Muy Recomendada]
- **Concepto**: Los personajes son maniquíes de dibujo artístico de madera clara con rótulas esféricas visibles en hombros, caderas, rodillas y codos, vestidos con prendas de tela estilizadas.
- **Ventajas**:
  - **Identidad visual única y coherente con el arte fotográfico**: Transforma las limitaciones del rig rígido de 20 huesos en una virtud estética intencionada.
  - **Justificación diegética**: Resuelve de forma elegante la ética de casting (todos los personajes tienen la misma base anatómica neutral de madera natural, pulida en diferentes vetas de haya, roble o nogal).
  - **Eficiencia en renderizado**: Los maniquíes se componen de tornos esféricos y cilindros perfectos con normales suaves, requiriendo apenas **~2.500 triángulos por persona**.

### Enfoque 2: Low-Poly Estilizado y Redondeado (*Smooth Low-Poly*)
- **Concepto**: Mantener la estética geométrica limpia pero sustituyendo los prismas de 5-6 lados por superficies con biselado (*bevel*) y normales promediadas (*area-weighted smooth normals*).
- **Ventajas**:
  - Siluetas limpias y redondeadas sin aristas vivas artificiales.
  - Compatibilidad directa con el pipeline actual de generación en `build_catalog.py`.
  - Presupuesto moderado: **~3.200 a 4.000 triángulos por persona**.

### Enfoque 3: Semi-Realismo Fotográfico (*Photoreal Casual*)
- **Concepto**: Modelado orgánico de pliegues en la ropa, cabello volumétrico con múltiples mechones y deformaciones musculares suaves.
- **Desventajas**:
  - Chocaría con el pesaje rígido actual (requeriría pasar a pesaje multihueso *Linear Blend Skinning* con 4 huesos por vértice).
  - Multiplica la carga geométrica por 5 (**~8.000 - 10.000 triángulos por persona**), poniendo en riesgo el límite de 60 FPS en plataformas móviles y WebGL.

---

## 2. Especificación del Nuevo Banco de Accesorios

Para enriquecer la diversidad de los 21 viandantes y multiplicar las combinaciones únicas de los encargos fotográficos, se propone añadir los siguientes accesorios en la ranura `accesorio`:

| Accesorio | Ubicación / Hueso | Geometría Paramétrica | Variantes | Interacción con la Pose |
|---|---|---|---|---|
| **Paraguas / Sombrilla** | `mano.D` / `mano.I` | Cono invertido de 8 lados (abierto) o cilindro largo fino (cerrado) | Abierto (en lluvia/sol) o plegado | Brazo flexionado a $45^\circ$ hacia arriba |
| **Mochila urbana** | `torax` | Cubo biselado con dos asas envolventes sobre hombros | Cuero marrón, lona gris, deportiva reflectante | Pegada a la espalda en `torax` |
| **Bolso en bandolera** | `lumbar` | Caja redondeada apoyada en la cadera con tira diagonal cruzada | Negro, camel, tela verde | Oscila levemente con la zancada |
| **Periódico o Revista** | `mano.D` | Plano curvado o cilindro blanco plegado con líneas grises | Plegado bajo el brazo o abierto leyendo | Lectura si el viandante está `SENTADO` |
| **Vaso de café térmico** | `mano.D` | Cilindro truncado con tapa plástica blanca | Blanco/rojo, marrón ecológico | Brazo elevado hacia el pecho |
| **Gafas de sol / Lectura** | `cabeza` | Marcos rectangulares o redondeados con cristales oscuros | Pasta negra, carey, metálicas | Fijas en el puente nasal |
| **Auriculares de diadema** | `cabeza` | Arco perimetral con dos cilindros acolchados sobre orejas | Blanco mate, negro, azul marino | Sobre la cabeza o descansando en el cuello |
| **Smartphone en mano** | `mano.D` | Prisma rectangular fino reflectante | Negro, plata, oro | Cabeza ligeramente inclinada hacia abajo |

---

## 3. Hoja de Ruta de Implementación

1. **Fase 1**: Modelado de los 8 nuevos accesorios en `tools/build_catalog.py` y registro en `data/catalogo.json`.
2. **Fase 2**: Integración de nuevos descriptores gramaticales en [scripts/casting.gd](file:///home/ganso/codigo/afotando/scripts/casting.gd) (*"con gafas de sol oscuras"*, *"llevando una mochila de cuero"*).
3. **Fase 3**: Experimentación con el shader de maniquí de madera artística en una rama visual aislada.
