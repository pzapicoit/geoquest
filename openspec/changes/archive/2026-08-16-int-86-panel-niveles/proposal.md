## Why

El panel ya tiene el listado de temáticas (`/tematicas`, INT-85) y la
pantalla de detalle de un nivel (`/niveles/:id`, INT-84), pero no existe
todavía la pantalla intermedia: el listado de niveles dentro de una
temática concreta. Sin ella, un admin no tiene forma de crear un nivel
nuevo ni de ver/reordenar los niveles de una temática — el nombre de cada
temática en `/tematicas` está deliberadamente deshabilitado ("Próximamente")
a la espera de esta pantalla.

## What Changes

- Nueva pantalla `/tematicas/:id/niveles`: listado de los niveles de una
  temática, con breadcrumb, reorden por arrastre (persistido vía la RPC ya
  existente `reordenar_niveles`), botón "Nuevo nivel" y estado vacío.
- Cada fila muestra posición, nombre (o "Nivel N" si no tiene), puntaje
  mínimo para superar, cantidad de preguntas asignadas en `nivel_desafios`
  (resaltada si tiene menos de 3), estado activo/inactivo y una acción de
  eliminar con confirmación a medida.
- El nombre del nivel o el botón "Recorrido →" navegan a `/niveles/:id`
  (pantalla de Recorrido, INT-84).
- "Nuevo nivel" abre un modal centrado con un único campo (nombre); al
  guardar crea el nivel con umbrales en 0 (pendientes de configurar) y
  navega automáticamente a su Recorrido para terminar la configuración.
- Al eliminar un nivel se recompacta el `orden` de los niveles restantes
  de la temática, sin dejar huecos.
- Se habilita el enlace del nombre de temática en `/tematicas` (INT-85),
  que hasta ahora estaba deshabilitado a la espera de esta pantalla.

## Capabilities

### New Capabilities
- `panel-levels-listing`: listado de niveles de una temática — breadcrumb,
  alta rápida por nombre, reorden por arrastre, recuento de preguntas,
  navegación al Recorrido de un nivel, eliminación con confirmación y
  estado vacío.

### Modified Capabilities
- `panel-topics-listing`: el nombre de cada temática deja de mostrarse
  deshabilitado ("Próximamente") y pasa a enlazar a
  `/tematicas/:id/niveles`, ahora que esa pantalla existe.

## Impact

- Frontend (`panel/`): nueva página `NivelesTematica.tsx`, nuevo módulo
  `lib/niveles.ts` (fetch/alta/eliminar/reorden de niveles de una temática,
  recuento de preguntas por nivel), nueva ruta en `App.tsx`, y el cambio de
  enlace en `Tematicas.tsx`.
- Sin cambios de esquema ni de RLS: tabla `niveles`, columna `nombre`
  (INT-84) y la RPC `reordenar_niveles(p_tematica_id, ids_en_orden)`
  (INT-87) ya existen y cubren esta pantalla.
