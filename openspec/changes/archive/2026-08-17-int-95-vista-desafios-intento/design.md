## Context

`desafios` (INT-74) no tiene policy de `select` para no-admins a propósito
(INT-77): protege `lat_real`/`lng_real`/`nombre_lugar` de un jugador antes
de que responda. Eso significa que hoy no existe *ningún* camino para que
la app lea contenido de un desafío (`tipo`, `imagen_url`/`video_url`/
`texto_pregunta`) — ni siquiera lo que sería seguro mostrar.

Por otro lado, `intentos_nivel` sí tiene policy de `insert` propia
(`intentos_nivel_insert_own`, INT-77): un cliente ya podría insertar un
intento directamente por REST. Pero hacerlo así deja fuera la selección de
qué desafíos se juegan — lógica que `game-data-model`
(`niveles.preguntas_por_partida`) ya dejó anotada como pendiente de esta
tarea ("la lógica de arranque de intento, INT-95, selecciona ese número de
preguntas al azar"). Sin una RPC, cada cliente tendría que reimplementar
esa selección aleatoria por su cuenta, con el riesgo de manipularla.

No hay stack local (`backend/README.md`, D6 de INT-73): todo se verifica
contra el proyecto remoto enlazado con `supabase db push`, igual que
INT-77/INT-78.

## Goals / Non-Goals

**Goals:**

- Dar a la app un único punto de lectura de contenido de desafío
  (`desafios_para_jugar`) que nunca exponga la ubicación real.
- Dar a la app un único punto de entrada para "empezar a jugar" un nivel
  (`iniciar_intento_nivel`) que cree el intento y decida qué desafíos se
  juegan, respetando `preguntas_por_partida`, en una sola llamada.
- Confirmar con un caso de prueba explícito que lo que INT-77/INT-78 ya
  dejaron listo (RLS de `desafios`, `responder_desafio` como
  `security definer`) sigue vigente — sin tocar su código.

**Non-Goals:**

- Comprobar si el nivel está desbloqueado para el jugador
  (`progreso_usuario_nivel`/`camino`) dentro de `iniciar_intento_nivel`. La
  UI (INT-90) ya solo deja tocar paradas desbloqueadas; añadir esa
  comprobación aquí es una capa de defensa en profundidad que puede
  llegar en una tarea aparte si se decide que hace falta.
- Cerrar o puntuar un intento — sigue siendo `responder_desafio` (INT-78)
  y la lógica de superación de nivel (INT-79).
- Cualquier cambio en `app/` o `panel/`: esta tarea es solo el contrato de
  backend que INT-91/INT-92 consumirán después.

## Decisions

### D1. La vista se define con `security invoker` desactivado (comportamiento por defecto de Postgres)

Para que `desafios_para_jugar` pueda leer `desafios` aunque quien consulta
la vista no tenga permiso de `select` sobre la tabla, la vista se crea
**sin** `security_invoker = true` (opción de Postgres 15+): así se evalúa
con los privilegios de quien la crea (el rol de migración, que en Supabase
es dueño de la tabla y no está sujeto a sus policies), no con los del
usuario que hace la consulta — el mecanismo estándar en Postgres para
"vista que expone un subconjunto seguro de una tabla con RLS", ya usado
implícitamente por `tematicas_select_authenticated`/etc. al no necesitar
este truco (esas tablas sí son legibles directamente). Alternativa
descartada: `security_invoker = true` — con eso la vista heredaría la RLS
de `desafios` y devolvería cero filas a cualquier no-admin, justo lo
contrario de lo que pide el issue.

### D2. `iniciar_intento_nivel` es `security invoker`, no `security definer`

A diferencia de `responder_desafio` (que sí necesita `security definer`
porque lee `lat_real`/`lng_real`), esta función solo toca: `niveles`
(lectura pública), `nivel_desafios` (lectura pública),
`desafios_para_jugar` (ya expuesta a `authenticated` por D1) y un `insert`
en `intentos_nivel` que la policy `intentos_nivel_insert_own` ya permite
para la propia fila. No hay ninguna columna sensible de por medio, así que
no hace falta saltarse RLS — menos superficie con privilegios elevados que
auditar.

### D3. Selección aleatoria con `order by random() limit`, todo en una única sentencia

```sql
select d.*
from nivel_desafios nd
join desafios_para_jugar d on d.id = nd.desafio_id
where nd.nivel_id = p_nivel_id
order by case when v_limite is not null then random() end
limit coalesce(v_limite, 2147483647)
```

Cuando `v_limite` (el `preguntas_por_partida` del nivel) es `NULL`, el
`order by` no aplica `random()` (queda `NULL` para todas las filas, orden
estable por `nivel_desafios.orden` de por medio via un segundo criterio) y
el `limit` no filtra nada (`2147483647`, el máximo `integer`). Cuando tiene
valor, se ordena al azar y se recorta a esa cantidad — selección y orden de
presentación quedan aleatorios a la vez, que es lo que pide el issue
("seleccione ese número de preguntas al azar") sin necesitar una segunda
pasada para barajar. Alternativa descartada: dos consultas (una para
elegir ids al azar, otra para traer el contenido) — una sola consulta con
`join` es más simple y no hay ninguna ventaja de la separación aquí.

### D4. La RPC devuelve un único `jsonb`, no un `setof`

`iniciar_intento_nivel` devuelve `jsonb` con la forma
`{"intento_id": "<uuid>", "desafios": [{"id":..., "tipo":..., ...}, ...]}`
en vez de `returns setof <tipo>` (que repetiría `intento_id` en cada fila).
Es una única respuesta lógica ("aquí tienes tu intento y lo que vas a
jugar"), y `jsonb_build_object`/`jsonb_agg` lo arman en la misma función sin
necesitar un tipo compuesto nuevo. La app (Flutter, `supabase_flutter`) ya
decodifica el resultado de una RPC como `Map`/`List` dinámicos sin fricción
adicional frente a un `setof`.

### D5. Validación de nivel inexistente/inactivo con una comprobación explícita, igual que D3 de INT-78

Igual que `responder_desafio` valida a mano la pertenencia del intento
(D3 de `int-78-calcular-distancia-puntaje`) en vez de confiar en RLS,
`iniciar_intento_nivel` comprueba con un `select ... into` que el nivel
existe y `activo = true` antes de insertar nada, y lanza excepción si no
— manteniendo el mismo estilo de validación explícita ya establecido para
RPCs de este esquema.

## Risks / Trade-offs

- **Vista sin `security_invoker` es fácil de hacer mal en el futuro**: si
  alguien reescribe `desafios_para_jugar` más adelante y accidentalmente
  añade `security_invoker = true` (o migra a una versión de Postgres donde
  cambie el default), la vista dejaría de devolver filas para jugadores en
  vez de exponer datos de más — falla cerrado, no abierto. Mitigado con el
  caso de prueba de la Requirement 1 del spec, que se puede volver a
  correr tras cualquier cambio futuro a la vista.
- **`order by random()` no escala** a bancos de desafíos enormes, pero
  `nivel_desafios` ya está acotado por nivel (unas pocas decenas de filas
  como mucho, vía `nivel_desafios_desafio_id_idx`), así que el coste es
  irrelevante aquí.
- **Sin comprobación de desbloqueo server-side** (Non-Goal): un cliente
  que se salte la UI de INT-90 podría llamar a `iniciar_intento_nivel`
  para un nivel bloqueado. Aceptado por ahora porque no hay premio en
  juego más allá de puntos propios del jugador (no hay ranking ni
  competición entre jugadores todavía); si eso cambia, es una comprobación
  pequeña de añadir después sin romper el contrato de esta RPC.

## Migration Plan

Una migración nueva (`vista_desafios_arranque_intento` o similar) con: la
vista `desafios_para_jugar`, sus grants (`select` a `authenticated`), la
función `iniciar_intento_nivel` y su `grant execute ... to authenticated`
(revocando antes de `public`, igual que D2.2 de INT-78). Aplicada con
`supabase db push` contra el proyecto remoto enlazado. No transforma datos
existentes ni toca las policies de INT-77/INT-78 (se verifican, no se
tocan).

**Rollback**: `drop function iniciar_intento_nivel`, `drop view
desafios_para_jugar` en una migración inversa, o `supabase db reset
--linked` mientras no haya intentos reales creados a través de esta RPC.
