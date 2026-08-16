## Why

Tras INT-81 (Home) e INT-82/83 (Preguntas), la navegación del panel sigue
marcando "Temáticas" como deshabilitado: no existe pantalla para crear,
ordenar, activar/desactivar ni eliminar las temáticas (los "mundos" que
agrupan niveles y controlan en qué orden el jugador los desbloquea). Sin
ella, el equipo de contenido no tiene forma de empezar a cargar el juego —
es un prerrequisito de INT-86 (listado de niveles de una temática), que
necesita temáticas ya creadas para tener sentido.

## What Changes

- Nueva pantalla `/tematicas`: listado de temáticas con fila por temática y
  drag handle para reordenar manualmente (reutiliza el RPC
  `reordenar_tematicas`, ya creado en INT-87).
- Cada fila muestra: miniatura de portada, nombre, estrellas requeridas en
  la temática inmediatamente anterior para desbloquearse ("Sin requisito"
  en la primera), cuántos niveles contiene, estado (activo/inactivo) y
  acciones editar/eliminar.
- Botón "Nueva temática" y edición en panel lateral (no pantalla aparte):
  nombre, imagen de portada con previsualización (subida a Supabase
  Storage), estrellas requeridas (oculto/no aplica en la primera temática),
  estado activo/inactivo, Guardar/Cancelar.
- Confirmación de eliminación que advierte explícitamente que se borran en
  cascada los niveles de la temática y sus asignaciones de preguntas (no el
  banco de preguntas, que permanece intacto).
- Estado vacío con CTA para crear la primera temática cuando no hay
  ninguna.
- Habilita el enlace "Temáticas" en la navegación lateral del panel, hoy
  deshabilitado.
- El nombre de cada fila queda preparado para enlazar al listado de
  niveles de esa temática, pero ese enlace se muestra deshabilitado
  ("Próximamente") porque la pantalla destino es INT-86, todavía sin
  construir — ver Impact.

## Capabilities

### New Capabilities
- `panel-topics-listing`: listado de temáticas con reorden por
  drag-and-drop, datos por fila (portada, nombre, requisito de estrellas,
  recuento de niveles, estado), eliminación con confirmación y estado
  vacío.
- `panel-topics-form`: alta y edición de temáticas en panel lateral,
  incluyendo subida/previsualización de la imagen de portada y el campo
  condicional de estrellas requeridas.

### Modified Capabilities
- `challenge-media-storage`: se reutiliza el bucket `challenge-media` para
  las portadas de temática bajo un nuevo prefijo de ruta
  (`tematicas/{tematica_id}.{extension}`), ampliando la convención de ruta
  actual (que hoy solo documenta `{tipo}/{desafio_id}.{extension}` para
  desafíos). Las políticas de RLS existentes (lectura pública, escritura
  solo admin) ya cubren cualquier prefijo del bucket sin cambios.

## Impact

- Código: `panel/src/pages/Tematicas.tsx` (nueva), `panel/src/lib/tematicas.ts`
  (nuevo, consultas/mutaciones Supabase y subida de portada), `panel/src/App.tsx`
  (nueva ruta `/tematicas`), `panel/src/components/PanelLayout.tsx` (habilita
  el enlace de nav).
- Datos: lecturas y escrituras sobre `tematicas` (INT-74) y `niveles` (solo
  lectura, para el recuento por temática); usa el RPC `reordenar_tematicas`
  (INT-87) ya existente para el drag-and-drop. Sin migraciones nuevas de
  esquema.
- Storage: reutiliza el bucket `challenge-media` (INT-76) bajo el prefijo
  `tematicas/`, sin cambios de política.
- Fuera de alcance: la pantalla de listado de niveles de una temática
  (INT-86) — el enlace del nombre queda deshabilitado hasta que exista.
