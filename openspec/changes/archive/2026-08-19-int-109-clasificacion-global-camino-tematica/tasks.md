## 1. Migración: función `clasificacion_global`

- [x] 1.1 Crear `backend/supabase/migrations/<timestamp>_clasificacion_ranking.sql` y en él, la función `clasificacion_global(p_limite integer default 50)`: CTE con `puntuacion` = suma de `respuestas_desafio.puntos` vía `intentos_nivel.usuario_id`, `niveles_superados` = conteo de `progreso_usuario_nivel.superado = true`, `posicion = rank() over (order by puntuacion desc)`.
- [x] 1.2 Clamp de `p_limite` a `[1, 100]` y recorte del resultado a ese límite, con orden de emisión determinista (`puntuacion desc, usuario_id asc`).
- [x] 1.3 Incluir siempre la fila de `auth.uid()` con `es_usuario_actual = true` (añadida aparte si queda fuera del top), o `puntuacion = 0` / `posicion = null` si no tiene ninguna fila agregable.
- [x] 1.4 `security definer`, `stable`, `set search_path = public` y `grant execute on function clasificacion_global(integer) to authenticated`.

## 2. Migración: función `clasificacion_por_camino`

- [x] 2.1 En la misma migración, función `clasificacion_por_camino(p_camino_id uuid, p_limite integer default 50)`: ranking por `progreso_usuario_nivel.mejor_puntaje` filtrado a esa `camino_id`, con columna `superado` (booleano) del jugador en esa parada.
- [x] 2.2 Mismas reglas de límite, empate, fila propia garantizada y jugador sin puntuación que en `clasificacion_global` (D2/D3/D4/D5 de design.md).
- [x] 2.3 `camino_id` inexistente devuelve conjunto vacío del ranking, sin excepción.
- [x] 2.4 `security definer`, `stable`, `set search_path = public` y `grant execute on function clasificacion_por_camino(uuid, integer) to authenticated`.

## 3. Migración: función `clasificacion_por_tematica`

- [x] 3.1 Función `clasificacion_por_tematica(p_tematica_id uuid, p_limite integer default 50)`: ranking sumando `progreso_usuario_nivel.mejor_puntaje` sobre las filas de `camino` con ese `tematica_id`, con `niveles_superados` = conteo de `superado = true` dentro de esa temática.
- [x] 3.2 Mismas reglas de límite, empate, fila propia garantizada y jugador sin puntuación.
- [x] 3.3 `tematica_id` inexistente devuelve conjunto vacío del ranking, sin excepción.
- [x] 3.4 `security definer`, `stable`, `set search_path = public` y `grant execute on function clasificacion_por_tematica(uuid, integer) to authenticated`.

## 4. Verificación local

- [x] 4.1 Aplicar la migración: `supabase db push` (o el flujo remote-first equivalente documentado en `architecture.md`).
- [x] 4.2 `supabase db lint --linked` sobre la migración nueva.
- [x] 4.3 Crear `backend/supabase/tests/test_clasificacion.sql` siguiendo la estrategia D8 de `design.md`: `begin;` + fixtures de `profiles`/`camino`/`progreso_usuario_nivel`/`intentos_nivel`/`respuestas_desafio` + `set_config('request.jwt.claim.sub', ..., true)` para simular distintos jugadores + aserciones (`raise exception`) + `rollback;` final.
- [x] 4.4 Cubrir en el test: orden por puntuación, empate comparte posición, límite se recorta a `[1,100]`, fila propia aparece fuera del top N, jugador sin puntuación agregable devuelve `posicion = null`, `camino_id`/`tematica_id` inexistente devuelve vacío sin excepción.
- [x] 4.5 Ejecutar `supabase db query --linked -f backend/supabase/tests/test_clasificacion.sql` y confirmar que todos los `raise notice` de éxito aparecen sin ningún `raise exception`.
