## Context

Hoy no existe ninguna clasificación entre jugadores. Las tres tablas que contienen la puntuación (`respuestas_desafio`, `intentos_nivel`, `progreso_usuario_nivel`) tienen RLS "cada cual lo suyo" (`usuario_id = auth.uid()` / vía `intento_id`), y `profiles` solo permite `select` de la propia fila. El proyecto ya resolvió el problema genérico de "agregar entre jugadores cuando la RLS aísla por usuario" con dos patrones (ver `openspec/changes/archive/2026-08-15-int-87-rpcs-vistas-panel/design.md`, sección D3):

- **Patrón A** — función `security definer` gateada por `is_admin()`, para agregados **sin agrupar** (una sola fila de totales): `metricas_home()`, `alertas_contenido()`, `actividad_reciente()`.
- **Patrón B** — vista sin `security_invoker` (bypass de RLS explícito, dueña `postgres`), con aislamiento manual por fila vía `auth.uid()` o `is_admin()`: `camino_jugador`, `desafios_para_jugar`.

Una clasificación es un agregado **agrupado por `usuario_id`** (una fila por jugador), pero necesita parámetros (`camino_id`, `tematica_id`, un límite de filas) que una vista plana no admite. No hay tampoco entidad "nivel" independiente desde INT-106: cada parada del camino es una fila de `camino`, con su propio `tematica_id` y `dificultad`. "Clasificación por camino" es por tanto clasificación por una fila de `camino` (una parada), y "por temática" agrega todas las filas de `camino` que comparten `tematica_id`.

## Goals / Non-Goals

**Goals:**
- Tres funciones `security definer` de solo lectura (`clasificacion_global`, `clasificacion_por_camino`, `clasificacion_por_tematica`) que agregan puntuación entre jugadores.
- Cada una devuelve el top N (parametrizable, con tope defensivo) más, siempre, la fila de quien llama con su posición real aunque quede fuera del top N.
- Solo se exponen campos agregados ya considerados públicos entre jugadores en el proposal: `usuario_id`, `nombre`, `avatar_url`, la puntuación agregada y el número de niveles superados. Nunca se expone el detalle de intentos/respuestas individuales de otro jugador.
- Accesibles a cualquier `authenticated` (es información social del juego, no administrativa — a diferencia del patrón A).

**Non-Goals:**
- Modelar "temporada" con reset periódico — decisión de alcance ya tomada en `proposal.md`: esta entrega es acumulado histórico total.
- Cualquier cambio de UI (pantalla de Ranking en `app/`, sección Ranking/Jugadores del panel). Este cambio es solo backend.
- Cambiar las políticas RLS existentes de `intentos_nivel`, `respuestas_desafio`, `progreso_usuario_nivel`, `profiles`, `camino` o `tematicas`.
- Materializar/cachear el ranking en una tabla resumen — se calcula al vuelo; si el volumen de datos lo justifica en el futuro, es un cambio posterior.
- Anti-cheat o revalidación de puntuaciones — ya se calculan y validan en otro punto del sistema (`respuestas_desafio_calcular_antes_de_insertar`, INT-101).

## Decisions

**D1 — Funciones `security definer`, no vistas.**
Las tres necesitan parámetros (`camino_id`, `tematica_id`, límite) y lógica de "top N + fila propia garantizada", que no cabe en una vista plana sin trucos de GUC (no usados en ningún otro punto del proyecto). Se implementan como funciones `stable security definer` con `grant execute (...) to authenticated` — mismo mecanismo de bypass que el patrón A, pero **sin** el gate de `is_admin()`: el ranking es social, visible para cualquier jugador autenticado, no solo para admins.

**D2 — Posición con empates compartidos, orden de emisión determinista.**
`posicion = rank() over (order by puntuacion desc)` — dos jugadores con la misma puntuación comparten posición (comportamiento esperado de un leaderboard). El recorte a `limite` filas y el orden de las filas devueltas usan un `order by` distinto, con desempate explícito por `usuario_id asc`, para que la respuesta sea determinista entre llamadas (importante para tests y para que "quién queda justo dentro/fuera del top N" no dependa del plan de ejecución).

**D3 — `limite` parametrizable con tope defensivo.**
Cada función acepta `p_limite integer default 50`, clamped server-side a `[1, 100]` (`least(greatest(p_limite, 1), 100)`). Evita que un cliente pida `limite=999999` y fuerce traer la tabla completa (requisito explícito del issue de origen).

**D4 — La fila de quien llama siempre se devuelve, incluso fuera del top N.**
Cada función calcula el ranking completo en un CTE, selecciona las primeras `limite` filas por el orden de D2, y si `auth.uid()` no está entre ellas añade su fila aparte con su `posicion` real. Columna `es_usuario_actual boolean` para que el cliente la destaque sin tener que comparar `usuario_id` contra su propia sesión.

**D5 — Jugador sin puntuación agregable: fila con `puntuacion = 0` y `posicion = null`.**
Si quien llama no tiene ninguna fila agregable (nunca jugó / nunca jugó esa parada o temática), se le devuelve igual una fila con `puntuacion = 0`, contadores en 0 y `posicion = null` (no compite todavía) en vez de calcular una posición al final de una tabla potencialmente grande.

**D6 — Columnas por función** (todas devuelven `usuario_id`, `nombre`, `avatar_url`, `posicion`, `es_usuario_actual`, más lo específico de su agregación):
- `clasificacion_global(p_limite integer default 50)`: `puntuacion bigint` (suma histórica de `respuestas_desafio.puntos` vía `intentos_nivel.usuario_id`), `niveles_superados integer` (conteo de `progreso_usuario_nivel.superado = true` de ese jugador, todas las paradas).
- `clasificacion_por_camino(p_camino_id uuid, p_limite integer default 50)`: `puntuacion integer` (`progreso_usuario_nivel.mejor_puntaje` para esa `camino_id`), `superado boolean`.
- `clasificacion_por_tematica(p_tematica_id uuid, p_limite integer default 50)`: `puntuacion bigint` (suma de `mejor_puntaje` sobre las filas de `camino` con ese `tematica_id`), `niveles_superados integer` (conteo de `superado = true` dentro de esa temática).

**D7 — Sin filtrar por `camino.activo`/`desafios.activo`.**
La puntuación histórica ya ganada se conserva aunque la parada o el desafío se desactiven después (mismo criterio que ya aplica hoy `camino_gateway.dart` sumando en cliente sin filtrar por activo). Si `p_camino_id`/`p_tematica_id` no existe, la función devuelve simplemente el conjunto vacío (0 filas), sin excepción — coherente con el resto de RPCs de solo lectura del proyecto.

**D8 — Estrategia de test sin pgTAP, simulando distintos jugadores.**
El proyecto no tiene pgTAP ni Docker local (ver `architecture.md`); los tests SQL existentes (`backend/supabase/tests/`) son scripts `do $$ ... $$` autónomos contra el remoto, pero solo cubren funciones puras. Estas funciones sí dependen de `auth.uid()` y de datos de varios jugadores, así que el test:
1. Envuelve todo en `begin; ... rollback;` para no dejar datos de prueba en el remoto.
2. Inserta un puñado de filas fixture (`profiles`, `camino`, `progreso_usuario_nivel`, `intentos_nivel`, `respuestas_desafio`) con UUIDs fijos.
3. Simula "ser" cada jugador con `select set_config('request.jwt.claim.sub', '<uuid>', true);` antes de invocar la función — es la misma GUC que lee `auth.uid()` en producción vía PostgREST/GoTrue, así que no hace falta un JWT real para probar el aislamiento y el "top N + fila propia".
4. Verifica con `raise exception` los casos: orden correcto, empates comparten posición, límite se recorta, fila propia aparece aunque quede fuera del top N, jugador sin puntuación devuelve `posicion null`.

## Risks / Trade-offs

- **[Riesgo]** Exponer `usuario_id` de otros jugadores junto a nombre/avatar permite correlacionar su actividad entre las tres funciones → **Mitigación**: es el mismo nivel de exposición ya decidido en el proposal (nombre + avatar + puntuación son públicos entre jugadores); nunca se expone `device_id`, email ni el detalle de intentos/respuestas.
- **[Riesgo]** Calcular `rank()` sobre toda la tabla en cada llamada escala mal si el número de jugadores crece mucho → **Mitigación**: volumen actual bajo (proyecto en fase temprana); materializar/cachear el ranking queda como mejora futura explícita, no bloquea esta entrega.
- **[Riesgo]** La decisión "acumulado total, no por temporada" puede no coincidir con lo que sugiere el mockup de diseño → **Mitigación**: decisión de producto documentada explícitamente en `proposal.md`; añadir un filtro de fecha/temporada después es extensible sin romper el contrato de `clasificacion_global` (parámetro opcional adicional).
- **[Riesgo]** Sumar histórico completo sin filtrar por `activo` puede incluir puntuación de contenido luego retirado por tener un error → **Mitigación**: se documenta como decisión deliberada (D7); si en el futuro hace falta invalidar puntuación de un desafío roto, es un caso de corrección de datos puntual, no un cambio de la función.

## Migration Plan

- Una única migración nueva `backend/supabase/migrations/<timestamp>_clasificacion_ranking.sql` con las tres funciones y sus `grant execute ... to authenticated`. Sin cambios de esquema (no hay tablas/columnas nuevas), por lo que no hay backfill.
- Aplicar con `supabase db push` (flujo remote-first ya documentado en `architecture.md`); verificar con `supabase db lint --linked`.
- Test SQL nuevo `backend/supabase/tests/test_clasificacion.sql` siguiendo la estrategia D8, ejecutado con `supabase db query --linked -f backend/supabase/tests/test_clasificacion.sql` (siempre termina en `rollback`, seguro de correr contra el remoto; `db execute` no existe en esta versión de la CLI, el subcomando correcto es `db query`).
- Rollback si hiciera falta revertir: `drop function` de las tres — ninguna otra migración depende de ellas.

## Open Questions

Ninguna bloqueante: los dos puntos que el issue original dejaba "a decidir con producto" quedan resueltos — la temporada queda fuera de alcance (`proposal.md`), y el límite/paginación, desempate y caso "jugador sin puntuación" quedan decididos arriba (D2, D3, D5).
