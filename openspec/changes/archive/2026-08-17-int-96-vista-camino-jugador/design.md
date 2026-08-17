## Context

`camino` (`INT-98`) es la secuencia ordenada de posiciones del juego, cada una apuntando a un `nivel`. El progreso del jugador vive en `progreso_usuario_nivel`, con una fila por `(usuario_id, nivel_id)` creada de forma perezosa: no existe fila hasta que el jugador cierra su primer intento de ese nivel (`cerrar_intento_nivel`, decisión D6 de `INT-74`). El desbloqueo tampoco se pre-siembra: `cerrar_intento_nivel` solo escribe `desbloqueado = true` en las posiciones cuyo umbral ya se alcanza, en el momento en que se cierra un intento superado (`level-progression`, requirement "Desbloqueo de posiciones del camino por estrellas acumuladas").

Esto significa que un jugador que nunca jugó nada no tiene ninguna fila en `progreso_usuario_nivel`, ni siquiera para la primera posición del camino (`estrellas_requeridas = 0`). Cualquier consulta que muestre el camino debe reconstruir el estado de desbloqueo con la misma regla que `cerrar_intento_nivel`, no limitarse a leer el flag ya grabado.

Precedente de seguridad ya establecido en el proyecto (`desafios_uso`, `INT-87`): una vista creada por una migración es propiedad de `postgres`, que tiene `bypassrls` sobre las tablas que posee. Una vista sin `security_invoker = true` corre, a efectos de RLS, con los privilegios del dueño — es decir, ignora la RLS de las tablas que consulta. El patrón ya usado en este código base para vistas de un solo usuario/rol es filtrar explícitamente dentro de la consulta (`where is_admin()` en `desafios_uso`), no delegar en la RLS de la tabla.

## Goals / Non-Goals

**Goals:**
- Una vista `camino_jugador` que devuelva, en una sola consulta, el camino completo con el progreso del usuario autenticado.
- Reproducir exactamente la regla de desbloqueo de `cerrar_intento_nivel` (estrellas acumuladas en todo el camino `>=` umbral de la posición), no solo leer `progreso_usuario_nivel.desbloqueado`.
- Garantizar que un jugador solo ve su propio progreso, aunque la vista corra con privilegios del dueño.

**Non-Goals:**
- No se implementa la pantalla Home de la app (`INT-90`) ni ninguna lógica de presentación (iconos por monumento, fronteras visuales entre temáticas, animaciones).
- No se implementa `iniciar_intento_nivel` ni la vista `desafios_para_jugar` (`INT-95`) — capacidades independientes.
- No se modifica `cerrar_intento_nivel` ni la escritura de `progreso_usuario_nivel`: esta vista es de solo lectura y no cambia ningún requirement de `level-progression`.

## Decisions

### 1. Vista de solo lectura, sin `security_invoker`, con filtro explícito por `auth.uid()`

```sql
create view camino_jugador as
with estrellas_acumuladas as (
  select coalesce(sum(pun.mejores_estrellas), 0) as total
  from progreso_usuario_nivel pun
  join camino c on c.nivel_id = pun.nivel_id
  where pun.usuario_id = auth.uid()
)
select
  c.id as camino_id,
  c.orden,
  c.estrellas_requeridas,
  n.id as nivel_id,
  n.nombre as nivel_nombre,
  t.id as tematica_id,
  t.nombre as tematica_nombre,
  coalesce(pun.superado, false) as superado,
  coalesce(pun.mejores_estrellas, 0) as estrellas_obtenidas,
  ea.total as estrellas_acumuladas_usuario,
  coalesce(pun.desbloqueado, false)
    or c.estrellas_requeridas <= ea.total as desbloqueado,
  c.orden = min(case when not coalesce(pun.superado, false) then c.orden end)
    over () as es_actual
from camino c
join niveles n on n.id = c.nivel_id
join tematicas t on t.id = n.tematica_id
left join progreso_usuario_nivel pun
  on pun.nivel_id = n.id and pun.usuario_id = auth.uid()
cross join estrellas_acumuladas ea
order by c.orden;
```

Se descarta `security_invoker = true` (Postgres 15+, disponible en Supabase) porque introduciría un mecanismo de aislamiento nuevo y no probado en este código base, cuando ya existe un patrón validado (`desafios_uso`) para el mismo problema. Mantener un único patrón para "vista de un solo dueño de fila" es más fácil de auditar que mezclar dos.

`estrellas_acumuladas` se calcula en un CTE aparte (no como subconsulta correlacionada por fila) porque su valor no depende de la fila del camino que se está mostrando — es el total del jugador sobre *todo* el camino — y una subconsulta repetida por fila sería tanto más cara como más fácil de escribir mal si algún día alguien la correlaciona por error con `c.id`.

Alternativa descartada: función `security definer` en vez de vista. Una vista es suficiente porque no hay lógica condicional que justifique PL/pgSQL (a diferencia de `cerrar_intento_nivel`, que sí valida y escribe) y es coherente con que el resto de lecturas del juego (`tematicas`, `niveles`, `camino`) son tablas/vistas simples, no RPCs.

### 2. `desbloqueado` se recalcula en la vista, no se lee solo de `progreso_usuario_nivel`

`coalesce(pun.desbloqueado, false) or c.estrellas_requeridas <= ea.total`. El primer término cubre el caso ya escrito por `cerrar_intento_nivel`; el segundo cubre las posiciones que nunca tuvieron una fila creada (típicamente la primera, con `estrellas_requeridas = 0`, para un jugador que nunca jugó). Ambos términos deben coincidir siempre que exista la fila — se mantiene el `or` en vez de depender de uno solo por si en el futuro se desbloquea una posición por otra vía (código promocional, admin) que no pase por `cerrar_intento_nivel`.

### 3. `es_actual`: primera posición no superada por `orden`, sin exigir que esté desbloqueada

La issue pide "el primer nivel no superado de su recorrido" — se implementa literalmente así, vía ventana `min(...) over ()` sobre las posiciones no superadas. No se exige `desbloqueado = true`: dado el desbloqueo no secuencial de `INT-98` (D3), es posible que la primera posición no superada esté bloqueada si el jugador saltó estrellas hacia adelante; en ese caso la app centra el scroll ahí igualmente y muestra el candado, que es el comportamiento esperado por el diseño de `INT-90` ("frontera... con candado y mensaje de cuántas estrellas faltan").

### 4. `estrellas_acumuladas_usuario` se expone como columna repetida, no como consulta aparte

Repetir el mismo valor en cada fila (en vez de un segundo endpoint) evita que la app tenga que orquestar dos llamadas y le da directamente lo necesario para calcular "cuántas estrellas faltan" en una posición bloqueada (`estrellas_requeridas - estrellas_acumuladas_usuario`). El costo de duplicar un entero por fila es despreciable frente a evitar una segunda round-trip.

## Risks / Trade-offs

- [Riesgo] Duplicar la regla de desbloqueo (aquí y en `cerrar_intento_nivel`) crea dos lugares que mantener sincronizados si cambia la fórmula → Mitigación: ambas expresiones son una línea (`estrellas_requeridas <= total`) y quedan documentadas una junto a la otra en `level-progression`/`player-path`; un cambio de regla de negocio ya requeriría tocar `cerrar_intento_nivel` de todas formas.
- [Trade-off] La vista no usa `security_invoker`: si en el futuro se le agrega una columna que lea otra tabla con RLS por usuario, hay que recordar aplicar el mismo filtro explícito o esa tabla quedará expuesta sin restricción. Se documenta aquí y en el comentario de la migración para que el próximo cambio a esta vista lo tenga presente.
