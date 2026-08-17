## Why

La app (`INT-90`, Home del jugador) necesita mostrar el camino completo de niveles con el progreso del jugador — superado, estrellas, bloqueado/desbloqueado, cuál es la parada actual — en una sola pantalla con scroll. Hoy no existe ninguna consulta que devuelva eso: `camino` es solo la secuencia de posiciones (`INT-98`), y el progreso vive por separado en `progreso_usuario_nivel`, con filas creadas de forma perezosa (una posición nunca jugada no tiene fila). Reconstruir esto desde la app con varias consultas obligaría a duplicar en Dart la lógica de desbloqueo que ya vive en `cerrar_intento_nivel` (estrellas acumuladas en todo el camino vs. `estrellas_requeridas` por posición).

## What Changes

- Nueva vista `camino_jugador`: una fila por posición del camino, en orden, con la temática y el nivel al que apunta, y el progreso del usuario autenticado sobre ese nivel.
- Progreso por fila: `superado`, `estrellas_obtenidas` — `false`/`0` cuando el jugador no tiene fila en `progreso_usuario_nivel` para ese nivel (posición nunca jugada), sin fallar ni omitir la fila del camino.
- `desbloqueado` por fila calculado con la misma regla que `cerrar_intento_nivel` (`INT-98`): estrellas acumuladas del jugador en todo el camino `>=` `estrellas_requeridas` de la posición — no solo lo que ya quedó grabado en `progreso_usuario_nivel`, para que una posición con umbral 0 aparezca desbloqueada aunque el jugador no haya jugado nunca (sin fila previa).
- Columna `estrellas_acumuladas_usuario` (igual en todas las filas): total de estrellas del jugador sobre el camino, para que la app calcule cuántas le faltan a una posición bloqueada sin una consulta aparte.
- Columna `es_actual`: `true` en la primera posición (menor `orden`) no superada del camino, para que la app centre el scroll ahí.
- La vista aísla el progreso a su propio usuario mediante un filtro explícito por `auth.uid()` en el join hacia `progreso_usuario_nivel` (no depende de que la vista respete RLS por sí sola) — mismo patrón que `desafios_uso` (`INT-87`), donde una vista sin `security_invoker` corre con los privilegios del dueño (`postgres`, con `bypassrls`) y el filtro de pertenencia va explícito en la consulta, no delegado a la RLS de la tabla subyacente.

## Capabilities

### New Capabilities
- `player-path`: lectura del camino de niveles con el progreso y estado de desbloqueo del jugador autenticado, consumida por la Home de la app (`INT-90`).

### Modified Capabilities
(ninguna — no cambia ningún requirement ya archivado; `level-progression` sigue describiendo la escritura del progreso y no se toca)

## Impact

- Backend: nueva migración en `backend/supabase/migrations/` que crea la vista `camino_jugador`. No modifica tablas existentes.
- Sin cambios en `panel` ni en `app`: esta tarea solo expone el dato; `INT-90` lo consume en un cambio aparte.
