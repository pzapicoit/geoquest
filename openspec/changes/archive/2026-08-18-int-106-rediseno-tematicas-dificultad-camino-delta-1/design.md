## Context

INT-106 dejó los listados de Preguntas y Temáticas solo editables a través del formulario/panel lateral completo. El admin, probando en local, pide corrección rápida de campos simples (dificultad, activo) sin ese salto de pantalla.

## Goals / Non-Goals

**Goals:**
- Editar `dificultad`/`activo` de una pregunta, y `activo` de una temática, sin salir del listado.
- Persistir cada cambio inline de inmediato (no hay "guardar" en lote).

**Non-Goals:**
- No se hace editable inline nada que requiera subir un archivo, elegir coordenadas o cambiar el tipo de contenido — eso sigue en el formulario completo.
- No se toca el modelo de datos ni RLS: los updates inline usan las mismas tablas/columnas ya expuestas a `is_admin()`.

## Decisions

- Cada campo inline-editable se guarda con su propia llamada `update` (un `.eq('id', …)` con una sola columna), no con el mismo `guardarPregunta`/`guardarTematica` que usa el formulario completo (esas funciones esperan el conjunto completo de campos, incluida la subida de media). Se añaden `actualizarDificultadPregunta`/`actualizarActivoPregunta` en `preguntas.ts` y `actualizarActivoTematica` en `tematicas.ts`.
- Estado de guardado por fila: mientras una fila está guardando su cambio inline, el control queda deshabilitado y, si falla, la fila muestra el error y revierte el valor mostrado al que tenía antes (mismo patrón de `rowErrors`/`eliminandoIds` ya usado en `Preguntas.tsx` para el borrado).

## Risks / Trade-offs

- [Trade-off] Un cambio inline por columna en vez de un formulario de edición por fila: más simple de implementar y de revertir en error, a costa de una llamada de red por campo si el admin cambia varios campos seguidos en la misma fila — aceptable dado el volumen de uso de este panel.
