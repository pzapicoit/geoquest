## Why

Hoy no existe ninguna clasificación entre jugadores: la RLS de `intentos_nivel`, `respuestas_desafio` y `progreso_usuario_nivel` restringe cada tabla al usuario propietario, y los "puntos totales" que ve cada jugador en Home se calculan sumando en el cliente (`camino_gateway.dart`) solo sus propias respuestas — no hay ningún agregado en servidor que cruce jugadores. El panel ya tiene los enlaces "Ranking" y "Jugadores" deshabilitados (`PanelLayout.tsx`) esperando esta base, y sin datos agregados en servidor tampoco se puede construir la futura pantalla de Ranking de la app.

## What Changes

- Tres funciones RPC `security definer` en Postgres/Supabase que agregan puntuación entre jugadores sin exponer el detalle de intentos/respuestas ajenos:
  - `clasificacion_global(limite)`: ranking de todos los jugadores por la suma total histórica de `respuestas_desafio.puntos` (acumulado, sin concepto de temporada — ver más abajo).
  - `clasificacion_por_camino(camino_id, limite)`: ranking de jugadores por su `mejor_puntaje` en `progreso_usuario_nivel` para esa parada concreta del camino.
  - `clasificacion_por_tematica(tematica_id, limite)`: ranking de jugadores agregando `progreso_usuario_nivel.mejor_puntaje` de todas las paradas cuyo `camino.tematica_id` coincide con la temática pedida.
- Cada función devuelve el top N (parametrizable, con tope máximo defensivo) ordenado por puntuación descendente, con posición, nombre y avatar del jugador, y **siempre incluye también la fila de quien llama** (`auth.uid()`) con su posición y puntuación reales aunque quede fuera del top N devuelto.
- El spec documenta explícitamente el bypass de RLS (mismo patrón que `camino_jugador`/`metricas_home`: función `security definer` que agrega por `usuario_id`) y qué campos quedan expuestos entre jugadores (nombre, avatar, puntuación, nº de niveles superados) frente a lo que sigue privado (intentos y respuestas individuales de otros jugadores).
- **Decisión de alcance (producto):** la clasificación global es acumulado total, no "por temporada con reset periódico". El mockup de diseño sugiere temporada, pero ese concepto no existe hoy en el modelo de datos y modelarlo (ciclos, reset, histórico por temporada) es un cambio de alcance mayor que no bloquea el valor de tener una clasificación ya. Queda fuera de alcance explícitamente, para un ticket futuro si se decide.
- **Fuera de alcance:** la UI. Este cambio es solo backend (datos y lógica) — construir la pantalla de Ranking en `app/` y activar los enlaces "Ranking"/"Jugadores" del panel son tickets posteriores que consumirán estas funciones.

## Capabilities

### New Capabilities
- `player-ranking`: define las tres funciones de clasificación (global, por camino, por temática), sus contratos de entrada/salida, el mecanismo de bypass de RLS y las garantías de privacidad de datos individuales de otros jugadores.

### Modified Capabilities
(ninguna — no cambia el comportamiento de especificaciones existentes; solo se añaden funciones nuevas de solo-lectura sobre tablas ya especificadas en `game-data-model`, `player-path` y `level-progression`)

## Impact

- Solo afecta `backend/supabase/migrations/` (una nueva migración). Sin cambios en `app/` ni `panel/` en este ticket.
- Nuevas funciones `security definer`: `clasificacion_global`, `clasificacion_por_camino`, `clasificacion_por_tematica`, con `grant execute (...) to authenticated`.
- Lee `respuestas_desafio`, `intentos_nivel`, `progreso_usuario_nivel`, `camino`, `tematicas` y `profiles` — no modifica su esquema ni sus políticas RLS existentes; el acceso cruzado entre jugadores es un bypass explícito y acotado dentro de las tres funciones nuevas, no un relajamiento de las políticas actuales.
