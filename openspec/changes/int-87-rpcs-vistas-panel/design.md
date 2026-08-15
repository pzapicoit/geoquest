## Context

`panel/` no tiene backend propio (ver `.devplugin/architecture.md`): habla
directo con Supabase usando la clave publicable, y la RLS de INT-77 es la
única frontera de seguridad. Esa RLS hoy es "cada cual ve lo suyo" para las
tablas de juego (`intentos_nivel`, `respuestas_desafio`,
`progreso_usuario_nivel` filtran por `usuario_id = auth.uid()`; `profiles`
solo permite leer la propia fila). Eso es exactamente lo que un jugador
necesita, pero es insuficiente para un admin que necesita agregados sobre
**todos** los jugadores (métricas del dashboard, tasa de superación por
nivel). Este ticket resuelve esa brecha con funciones/vistas ad-hoc, sin
tocar la RLS existente de INT-77 (que sigue siendo correcta para el caso de
uso de jugador).

También cubre 3 RPC de reorden (temáticas, niveles, desafíos-de-nivel). Las
tres chocan con el mismo problema técnico: `orden` tiene un constraint
`unique` que una actualización masiva en una sola sentencia puede violar de
forma transitoria si dos filas intercambian posición.

## Goals / Non-Goals

**Goals:**
- Reorder atómico y solo-admin de temáticas/niveles/desafíos-de-nivel sin
  violar el `unique` existente sobre `orden`.
- Agregados de solo lectura (`metricas_home`, `alertas_contenido`) que vean
  **todos** los jugadores, no solo el propio admin, sin abrir esa
  visibilidad a nadie que no sea admin.
- `desafios_uso` como vista simple reutilizando la RLS ya pública de
  `niveles`/`nivel_desafios`, gateada a admin.

**Non-Goals:**
- No se toca la RLS de INT-77 sobre `intentos_nivel` /
  `progreso_usuario_nivel` / `profiles`: sigue siendo "cada cual ve lo
  suyo" para el propio jugador. Los agregados de admin viven en funciones
  aparte, no en un cambio de policy.
- No se pagina ni se cachea nada aquí: son funciones/vistas que el panel
  llama directo; paginación/cacheo del lado del panel, si hace falta, es
  decisión de INT-81/INT-82 al consumirlas.
- No se decide todavía qué desbloquea el dashboard de Jugadores/Ranking
  (fuera de alcance, ver proposal.md).

## Decisions

### D1: Reorder en una sola sentencia + constraint `orden` diferible

Reasignar `orden` a un conjunto de filas donde dos posiciones se
intercambian (ej. fila A pasa de `orden=1` a `orden=2` y B de `2` a `1`) con
un `UPDATE` fila a fila viola el `unique` existente a mitad de camino,
porque Postgres comprueba constraints `unique` no diferibles
inmediatamente tras cada fila tocada, incluso dentro de una sola sentencia.

Alternativas consideradas:
- **Two-phase update** (primero mover todo a valores negativos/temporales,
  luego a los definitivos): funciona sin tocar el schema, pero son 2
  sentencias por RPC y duplica la lógica de validación.
- **Constraint diferible** (elegida): `ALTER TABLE ... ALTER CONSTRAINT`
  **no sirve aquí** — Postgres solo permite esa forma sobre constraints de
  foreign key (confirmado contra el proyecto remoto: `ERROR 42809:
  constraint ... is not a foreign key constraint`). Para un `UNIQUE` hay
  que `DROP CONSTRAINT` + `ADD CONSTRAINT ... UNIQUE (...) DEFERRABLE
  INITIALLY IMMEDIATE` (probado en una transacción de prueba contra el
  remoto, con `ROLLBACK`, antes de escribir la migración definitiva). Cada
  RPC hace `set constraints <nombre> deferred` al principio de la
  transacción implícita de la función. Una sola sentencia `UPDATE ... FROM
  unnest(...) WITH ORDINALITY` reasigna todo, y el constraint solo se
  comprueba al final de la transacción (ya con todos los valores
  consistentes).

Los nombres de constraint (`tematicas_orden_key`,
`niveles_tematica_id_orden_key`, `nivel_desafios_nivel_id_orden_key`) son
los que genera Postgres por defecto para un `unique` declarado sin nombre
explícito en INT-74 — confirmados contra el proyecto remoto vía
`pg_constraint` antes de escribir el `DROP`/`ADD`, no asumidos a ciegas.

### D2: Reorder valida el conjunto completo antes de tocar nada

Cada RPC de reorden exige que `ids_en_orden` contenga **exactamente** las
filas que hoy existen para ese padre (misma temática / mismo nivel) — ni de
más ni de menos — y lo comprueba con un `count(*)` antes de cualquier
`UPDATE`. Si no coincide, `raise exception` y no se toca ninguna fila.

Alternativa descartada: aceptar un subconjunto y reordenar solo esas filas,
dejando el resto con su `orden` actual. Se descarta porque un `orden`
parcialmente actualizado con huecos o duplicados silenciosos es peor que
rechazar la llamada — el panel siempre debería mandar el listado completo
tal como lo tiene en pantalla.

### D3: Agregados de todos los jugadores vía `security definer`, gateados por `is_admin()`

`metricas_home()` y `alertas_contenido()` necesitan contar/agregar sobre
**todas** las filas de `intentos_nivel`/`progreso_usuario_nivel`/`profiles`,
no solo las del admin que las invoca — y la RLS de INT-77 sobre esas tablas
es "cada cual lo suyo". Se implementan como funciones `security definer`
(mismo patrón que `handle_new_user` de INT-75: bypass de RLS deliberado y
acotado), con un `if not is_admin() then raise exception ... end if;`
explícito al principio de cada una.

Alternativa descartada: una vista plana con `where is_admin()`. No sirve
aquí porque ambas funciones son agregados **sin agrupar** (una sola fila de
totales): una vista `select count(*) ... where is_admin()` sobre una
consulta agregada sin `GROUP BY` sigue devolviendo una fila (con ceros)
aunque `is_admin()` sea falso — el `WHERE` de una consulta sin agrupar
filtra antes de agregar, así que "cero filas de entrada" colapsa a "una
fila de salida con conteo 0", no a "cero filas de salida". Eso es
indistinguible de "hay 0 jugadores" para un no-admin, que es peor que un
error explícito.

### D4: `desafios_uso` sí puede ser una vista plana con `where is_admin()`

A diferencia de D3, `desafios_uso` agrupa por `desafio_id` (`GROUP BY`), así
que el `WHERE is_admin()` sí filtra correctamente: al no ser un agregado
colapsado en una sola fila sino un `GROUP BY` sobre filas de entrada, si
`is_admin()` es falso el `WHERE` elimina todas las filas de entrada antes
de agrupar y el resultado son cero grupos (cero filas) — sin el problema de
D3.

No hace falta `security definer` explícito porque una vista creada sin
`security_invoker = true` (default de Postgres) ya ejecuta el acceso a las
tablas subyacentes con los privilegios del **dueño de la vista**, igual que
un `security definer` — y el dueño aquí es el rol que corre la migración
(`postgres`, con `bypassrls`). Eso ya haría bypass de la RLS de
`desafios` (solo-admin) y `nivel_desafios` (pública) por sí solo; el
`where is_admin()` explícito es lo que de verdad gatea el acceso a
no-admins, no una supuesta lectura ya pública de `desafios` (que no lo es:
su RLS es `desafios_admin_select`, solo-admin).

### D5: Forma de retorno de `alertas_contenido()`

Devuelve una tabla genérica `(tipo text, referencia_id uuid, titulo text,
detalle jsonb)` en vez de dos funciones separadas (una por tipo de
alerta), para que el panel pida una sola vez la columna "Alertas de
contenido" completa. `detalle` lleva los campos específicos de cada tipo
(ej. `tasa_superacion` y `total_intentos` para un nivel; `campo_faltante`
para un desafío) sin forzar un esquema de columnas que no aplica a ambos
tipos por igual.

### D6: Definición de "desafío con datos incompletos"

El `CHECK` de INT-74 exige que el campo de contenido (`imagen_url` /
`video_url` / `texto_pregunta`) según `tipo` sea `NOT NULL`, pero no impide
una cadena vacía. Se considera incompleto un desafío `activo` cuyo campo de
contenido correspondiente a su `tipo` es `NULL` o vacío tras `trim()`, **o**
cuyas coordenadas son exactamente `(0, 0)` — el valor que un formulario del
panel dejaría por defecto antes de que el admin marque la ubicación real en
el mapa (`lat_real`/`lng_real` son `NOT NULL` desde INT-74, así que no
pueden faltar del todo; `(0, 0)` es la señal de "nunca se tocó").

**Open question**: si el panel decide usar otro valor centinela para
"sin ubicación aún" (en vez de `0, 0`), este criterio hay que revisarlo
cuando se construya el formulario de alta de desafíos (INT-83).

**Corregido tras revisión adversarial**: la primera versión calculaba
`campo_faltante` con un `CASE` sin `ELSE` y repetía la misma condición en el
`WHERE` por separado — un `CASE` sin `ELSE` desincronizado del `WHERE`
podría devolver `campo_faltante` nulo para una fila que sí entra en el
resultado. Se corrigió calculando `campo_faltante` una sola vez en un
`LATERAL` y filtrando sobre ese mismo resultado
(`where campo_faltante is not null`), eliminando la duplicación.

### D7: Umbral de "tasa de superación baja"

Se considera baja una tasa de superación `< 40%` (`superados / intentos`),
y solo se reporta si el nivel tiene al menos 5 `intentos_nivel` — evita que
un nivel con 1 intento fallido dispare la alerta. Ambos números son
arbitrarios y de producto, no técnicos.

**Open question**: confirmar estos dos números con el usuario al revisar
la propuesta (`40%` / `mínimo 5 intentos`); son fáciles de cambiar (son
literales en el `WHERE` de la función), no una decisión estructural.

## Risks / Trade-offs

- **[Riesgo]** Los nombres de constraint asumidos en D1 no coinciden con
  los reales → **Mitigación**: tarea explícita de verificación contra el
  proyecto remoto antes de escribir el `ALTER TABLE` (ver tasks.md).
- **[Riesgo]** `security definer` en `metricas_home`/`alertas_contenido`
  amplía la superficie si algún día dejan de empezar con el check de
  `is_admin()` → **Mitigación**: mismo patrón ya auditado en
  `handle_new_user` (INT-75); el check va en la primera línea del cuerpo,
  antes de tocar cualquier tabla.
- **[Trade-off]** `alertas_contenido` con columna `detalle jsonb` es menos
  cómodo de tipar en el cliente que columnas explícitas → aceptado por
  evitar una función/tabla por tipo de alerta cuando solo hay 2 tipos hoy y
  el consumidor (INT-81) ya necesita parsear una lista heterogénea de
  todos modos.

## Migration Plan

Una sola migración SQL (`supabase/migrations/<timestamp>_rpcs_vistas_panel.sql`):
1. `ALTER TABLE` para volver diferibles los 3 constraints `unique` de
   `orden` (tras confirmar sus nombres reales).
2. Las 3 RPC de reorden.
3. Las 2 funciones de agregado (`metricas_home`, `alertas_contenido`).
4. La vista `desafios_uso`.

Sin rollback especial: `supabase db push` es aditivo (nuevas
funciones/vista, constraints que pasan de no-diferibles a diferibles no
rompe ningún INSERT/UPDATE existente). Si hiciera falta revertir, una
migración posterior con los `DROP FUNCTION`/`DROP VIEW` correspondientes.
