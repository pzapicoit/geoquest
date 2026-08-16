## Why

El panel de administración (INT-81) ya tiene Home, pero el enlace
"Preguntas/Desafíos" de la navegación está deshabilitado porque su pantalla
no existe. Sin un listado, el equipo de contenido no tiene forma de ver,
buscar ni auditar el banco de preguntas/desafíos ni saber en qué niveles se
está usando cada una — un prerrequisito antes de poder crear o editar
preguntas (INT-83, fuera de alcance de este cambio).

## What Changes

- Nueva pantalla `/preguntas` en el panel: listado del banco de
  desafíos con una fila por desafío (no por asignación a nivel).
- Buscador por `nombre_lugar` o `texto_pregunta`.
- Filtros combinables: temática, nivel, tipo de contenido
  (imagen/vídeo/pregunta de texto), estado (activo/inactivo), y "sin
  asignar a ningún nivel".
- Cada fila muestra: miniatura (imagen real para tipo `imagen`, ícono para
  `video`/`pregunta_texto`), nombre del lugar, badge de tipo, estado, y un
  indicador "usado en N niveles" / "Sin asignar" con detalle (hover o
  desplegable) de las temática·nivel concretas donde se usa.
- Acciones por fila: "Editar" deshabilitado (Próximamente — su pantalla es
  INT-83), "Eliminar" habilitado con confirmación, que borra el desafío del
  banco y muestra un mensaje claro si la base de datos lo rechaza por estar
  referenciado (niveles o historial de respuestas de jugadores).
- Botón "Nueva pregunta" deshabilitado (Próximamente — su pantalla es
  INT-83).
- Paginación y estado vacío (sin resultados por filtros, y banco vacío) con
  CTA para crear la primera pregunta (deshabilitado, mismo motivo).
- Habilita el enlace "Preguntas/Desafíos" en la navegación lateral del
  panel, que hasta ahora estaba deshabilitado.

## Capabilities

### New Capabilities
- `panel-questions-listing`: listado, búsqueda, filtros, paginación y
  eliminación del banco de desafíos en el panel admin.

### Modified Capabilities
(ninguna — no cambia el comportamiento de capabilities existentes; se
reutilizan `desafios`, `nivel_desafios`, `niveles` y `tematicas` tal como
las expone `game-data-model`, y la navegación de `panel-home-dashboard` solo
pasa de deshabilitada a habilitada para este enlace, sin cambiar su propio
contrato)

## Impact

- Código: `panel/src/pages/Preguntas.tsx` (nueva), `panel/src/lib/preguntas.ts`
  (nuevo, consultas Supabase), `panel/src/App.tsx` (nueva ruta),
  `panel/src/components/PanelLayout.tsx` (habilita el enlace de nav).
- Datos: solo lecturas sobre `desafios`, `nivel_desafios`, `niveles`,
  `tematicas` (RLS ya restringe a admin, ver `game-data-model`) y un
  `delete` sobre `desafios` (ya permitido a admins). Sin migraciones nuevas.
- Sin cambios de API/RPC nuevos.
