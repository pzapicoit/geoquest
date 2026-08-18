---
type: scope
parent: int-106-rediseno-tematicas-dificultad-camino
reason: durante el testing local de INT-106, el usuario pidió poder editar directamente desde los listados del panel (sin abrir el formulario completo) y ajustó el diseño de "Nueva pregunta" en Claude Design.
---

## Why

Tras probar INT-106 en local, el admin quiere corregir errores pequeños (una dificultad mal puesta, una temática que hay que desactivar) sin salir del listado y abrir el formulario completo cada vez. También se revisó el diseño de "Nueva pregunta" en Claude Design (`[Admin] - Preguntas - Nueva.dc.html`): el formulario ya implementado en INT-106 coincide en casi todo (mismos tokens de color, mismo layout de tipo/ubicación/mapa), pero el diseño agrupa los campos bajo cabeceras de sección numeradas que el formulario actual no tiene. El diseño importado seguía mostrando la sección "Asignar a nivel(es) ahora" del modelo anterior a INT-106 (niveles curados a mano) — esa parte queda descartada, no se reintroduce.

## What Changes

- El listado de Preguntas permite editar `dificultad` y `activo` directamente en la fila (selector y toggle inline), sin navegar al formulario completo.
- El listado de Temáticas permite editar `activo` directamente en la fila (toggle inline).
- El formulario de "Nueva/Editar pregunta" agrupa sus campos bajo cabeceras de sección numeradas ("1 · Contenido", "2 · Ubicación", "3 · Clasificación", "4 · Datos y estado"), igual que el diseño revisado. Sin cambio de campos ni de validación.

## Capabilities

### Modified Capabilities
- `panel-questions-listing`: añade edición inline de `dificultad` y `activo` por fila.
- `panel-topics-listing`: añade edición inline de `activo` por fila.

## Impact
- **Panel**: `panel/src/pages/Preguntas.tsx`, `panel/src/lib/preguntas.ts` (nueva función de actualización parcial), `panel/src/pages/Tematicas.tsx`, `panel/src/lib/tematicas.ts` (nueva función de actualización parcial), `panel/src/pages/PreguntaForm.tsx` (cabeceras de sección, sin cambio de comportamiento — no lleva spec delta propia por ser puramente visual).
- Sin cambios de esquema ni de RPCs.
