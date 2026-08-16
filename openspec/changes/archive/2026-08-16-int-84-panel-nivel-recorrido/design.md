## Context

El panel (React 19 + Vite + Tailwind + `@supabase/supabase-js`, sin capa de
estado global ni router de datos) ya tiene el banco de preguntas (`/preguntas`,
`/preguntas/nueva`, `/preguntas/:id/editar`, INT-82/INT-83). El modelo
`tematicas → niveles → nivel_desafios → desafios` y la RPC admin-only
`reordenar_preguntas_nivel(p_nivel_id, ids_en_orden)` ya existen (INT-74,
INT-87). No hay todavía pantallas de listado para `tematicas` ni `niveles`
("Temáticas"/"Niveles" siguen deshabilitados en `PanelLayout`), así que esta
es la primera pantalla que trabaja sobre un nivel concreto.

`niveles` no tiene columna de nombre, solo `orden` — el resto de pantallas
(`Preguntas.tsx`, `preguntaForm.ts`) ya muestran "Nivel {orden}" como
etiqueta. El ticket pide un nombre editable, así que se añade
`niveles.nombre` (nullable) sin romper esas pantallas: si está vacío, se
sigue mostrando "Nivel {orden}".

## Goals / Non-Goals

**Goals:**
- Pantalla `/niveles/:id` para configurar un nivel y gestionar su recorrido
  ordenado de preguntas.
- Reutilizar `reordenar_preguntas_nivel` para persistir el orden tras
  arrastrar o quitar una pregunta.
- Reutilizar el patrón de selector ya usado en `SeccionNiveles` de
  `PreguntaForm.tsx` (buscador + lista con checkboxes) para "Añadir pregunta
  existente", pero acotado a preguntas del banco no asignadas aún a este
  nivel.

**Non-Goals:**
- No se construyen los listados de `Temáticas` ni `Niveles`; el breadcrumb
  de esta pantalla es informativo (texto, no enlaces) porque esos destinos
  no existen todavía. Tampoco se habilitan esos ítems de navegación.
- No se cambia `PreguntaForm.tsx` para preseleccionar el nivel de origen al
  crear una pregunta desde "Crear pregunta nueva" — navega a
  `/preguntas/nueva` tal cual, igual que pide el ticket.
- No se añade ninguna librería de drag-and-drop.

## Decisions

**Drag-and-drop nativo (HTML5), sin dependencia nueva.** El repo no usa hoy
ninguna librería de DnD y solo tiene 6 dependencias de producción. Con
`draggable`, `onDragStart`/`onDragOver`/`onDrop` sobre las filas de la tabla
basta para reordenar una lista de una sola columna; se descarta añadir
`@dnd-kit` u otra librería por ser una lista simple de un solo eje.
Alternativa considerada: botones "subir/bajar" en vez de arrastrar — se
descarta porque el ticket pide explícitamente una lista arrastrable, aunque
se mantienen los botones como fallback accesible por teclado (ver Riesgos).

**Persistencia optimista del reorden.** Al soltar, el estado local se
reordena de inmediato y se llama a `reordenar_preguntas_nivel` en segundo
plano; si falla, se revierte el array local al orden previo y se muestra un
error. Igual que el patrón de `Preguntas.tsx` (`eliminarPregunta` con
revert manual en `rowErrors`), no se introduce una librería de fetching.

**`niveles.nombre` nullable, sin backfill.** Se añade la columna sin
`not null` y sin valor por defecto: los niveles existentes quedan con
`nombre = null` y siguen mostrando "Nivel {orden}" donde ya se hacía. Evita
tener que inventar nombres para niveles ya creados por el seed/migraciones
anteriores.

**Quitar del recorrido renumera el resto.** Tras un `delete` en
`nivel_desafios`, se llama a `reordenar_preguntas_nivel` con los
`desafio_id` restantes en su orden actual (compactando huecos), tal como
pide el criterio de aceptación ("Al reordenar o quitar, actualizar el campo
`orden`"). Alternativa: dejar huecos en `orden` tras borrar — se descarta
porque el ticket es explícito y porque simplifica siempre tener `orden`
contiguo 1..N.

**Selector "Añadir pregunta existente" como panel embebido, no modal
verdadero.** Se reutiliza el mismo patrón visual de `SeccionNiveles`
(buscador + lista con checkboxes dentro de una tarjeta), evitando introducir
gestión de foco/overlay de un `<dialog>` o librería de modal. Se abre/cierra
con estado local (`mostrarSelector`), igual que el resto del panel no usa
ninguna librería de overlay todavía.

**Breadcrumb sin enlaces.** `Temáticas > [temática] > [nivel]` se muestra
como texto plano (sin `<Link>`) porque `/tematicas` y `/tematicas/:id` no
existen como rutas. Cuando existan (fuera de alcance de INT-84), se pueden
convertir en enlaces sin tocar el resto de la pantalla.

## Risks / Trade-offs

- [Drag-and-drop HTML5 nativo no es accesible por teclado] → Se mantienen
  botones de "subir/bajar posición" por fila junto al asa de arrastre, que
  llaman a la misma función de reorden.
- [Reordenar con optimistic update puede desincronizarse si dos admins
  editan el mismo nivel a la vez] → Aceptado: no hay multiusuario concurrente
  real en este panel todavía (un único admin por sesión), mismo supuesto que
  el resto del panel.
- [Añadir `niveles.nombre` nullable no obliga a los niveles existentes a
  tener nombre] → Aceptado como diseño (ver Decisions); no es una regresión,
  es el estado actual (solo `orden`) con un campo opcional nuevo encima.

## Migration Plan

1. Migración SQL: `alter table niveles add column nombre text;` (nullable,
   sin default). No requiere backfill ni cambios de RLS (ya cubierta por las
   policies existentes de `niveles`).
2. Sin pasos de rollback especiales: `alter table niveles drop column
   nombre;` si hiciera falta revertir, sin pérdida de datos en el resto de
   columnas.
