## Context

`cerrar_intento_nivel` (INT-79, redefinida por INT-98 en
`20260817120000_camino_secuencia_propia.sql`) exige, antes de calcular
puntaje/estrellas, que exista una respuesta en `respuestas_desafio` para
cada fila de `nivel_desafios` del nivel del intento:

```sql
select count(*) into v_total_desafios
from nivel_desafios
where nivel_id = v_nivel_id;
...
if v_respondidos < v_total_desafios then
  raise exception '... (% de %)', ...;
```

`iniciar_intento_nivel` (INT-95, `20260817140000_vista_desafios_arranque_intento.sql`)
no reparte esa asignación completa: si `niveles.preguntas_por_partida` tiene
valor, recorta a esa cantidad al azar (INT-98), y siempre excluye
`activo = false`. La selección real solo vive en el `jsonb` de respuesta —
no se persiste en ningún sitio — así que `cerrar_intento_nivel` no tiene
forma de saber cuántas respuestas tocaban *a ese intento en concreto*, y
compara contra el total equivocado.

No hay stack local (`backend/README.md`): todo se verifica contra el
proyecto remoto enlazado con `supabase db push`, igual que los cambios
anteriores sobre este esquema.

## Goals / Non-Goals

**Goals:**

- Que un intento se pueda cerrar exactamente cuando el jugador respondió
  todos los desafíos que **le tocaron a ese intento**, sin importar el
  estado actual de `nivel_desafios`/`desafios.activo`.
- Persistir esa selección en una tabla nueva (`intento_desafios`) en vez de
  solo un contador, porque además de arreglar el conteo deja una base para
  reanudar un intento y saber qué se preguntó (útil para INT-94, resumen
  del nivel, que consume este arreglo).
- Mantener sin cambios la lógica de selección de `iniciar_intento_nivel`
  (qué desafíos y cuántos) y de puntuación/estrellas/desbloqueo de
  `cerrar_intento_nivel` — el arreglo es *de dónde* se cuenta, no *cómo* se
  puntúa.

**Non-Goals:**

- Permitir "resumir" un intento a medio jugar reconstruyendo su pantalla de
  juego desde `intento_desafios` — eso es trabajo de INT-94/futuro; aquí
  solo se deja la tabla que lo hace posible.
- Validar en `responder_desafio` que el `desafio_id` pertenezca a la
  selección del intento (`intento_desafios`). Hoy no lo valida (solo
  comprueba que el desafío exista y que el intento sea del usuario) y este
  cambio no lo endurece — es una mejora de seguridad aparte, no forma
  parte de este bug de datos.
- Migrar o recalcular intentos ya existentes: los intentos creados antes de
  esta migración no tienen fila en `intento_desafios` (ver D4/Riesgos).

## Decisions

### D1. Selección persistida en una tabla propia (`intento_desafios`), no un contador en `intentos_nivel`

Se elige la tabla `intento_desafios (intento_id, desafio_id, orden)` frente
a la alternativa más barata (una columna `total_desafios_esperado` en
`intentos_nivel`) porque:

- Resuelve igual el conteo del cierre.
- Además dice **cuáles** desafíos tocaron y en qué orden, no solo cuántos —
  la única forma de que una "reanudación" futura (o un resumen del nivel)
  pueda reconstruir la partida.
- El intento sigue siendo cerrable si un desafío se desactiva a mitad de
  partida (Goal 1): la selección ya quedó fijada en la tabla, no depende de
  releer `nivel_desafios`/`desafios.activo` en el momento del cierre.

```sql
create table intento_desafios (
  intento_id uuid not null references intentos_nivel (id) on delete cascade,
  desafio_id uuid not null references desafios (id) on delete restrict,
  orden integer not null,
  primary key (intento_id, desafio_id),
  unique (intento_id, orden)
);
```

Mismo patrón que `nivel_desafios` (PK compuesta + `unique(intento_id, orden)`
para que dos desafíos no compartan posición dentro del mismo intento) y
mismo `on delete restrict` hacia `desafios` que ya usan `nivel_desafios` y
`respuestas_desafio` (D5 de INT-74: conserva el historial, un desafío
respondido/asignado alguna vez no se puede borrar).

### D2. RLS de `intento_desafios`: mismo patrón que `respuestas_desafio` (select + insert propios, sin update)

`intento_desafios` no tiene `usuario_id` propio; la pertenencia se resuelve
vía `intento_id -> intentos_nivel.usuario_id`, igual que
`respuestas_desafio` (`20260815112251_rls_esquema_juego.sql`):

```sql
create policy "intento_desafios_select_own"
on public.intento_desafios
for select
to authenticated
using (
  exists (
    select 1 from public.intentos_nivel
    where intentos_nivel.id = intento_desafios.intento_id
      and intentos_nivel.usuario_id = auth.uid()
  )
);

create policy "intento_desafios_insert_own"
on public.intento_desafios
for insert
to authenticated
with check (
  exists (
    select 1 from public.intentos_nivel
    where intentos_nivel.id = intento_desafios.intento_id
      and intentos_nivel.usuario_id = auth.uid()
  )
);
```

Sin policy de `update` ni `delete`: es un snapshot inmutable de qué le tocó
al intento, igual de inmutable que `respuestas_desafio`. `iniciar_intento_nivel`
sigue siendo `security invoker` (D2 de INT-95): el `insert` en
`intento_desafios` lo hace como el propio usuario, y la policy de arriba ya
lo permite porque el `intento_id` que inserta es el suyo (recién creado en
la misma función).

### D3. `iniciar_intento_nivel` persiste la selección en la misma sentencia que la calcula

En vez de seleccionar y luego, en un segundo paso, volver a calcular qué
tocó (con el riesgo de que un segundo `random()` dé un resultado distinto),
la selección se materializa una vez en una CTE y se reutiliza tanto para el
`insert` en `intento_desafios` como para el `jsonb` de respuesta:

```sql
with sorteo as materialized (
  select d.id, d.tipo, d.imagen_url, d.video_url, d.texto_pregunta, d.activo,
         nd.orden as orden_nivel,
         case when v_limite is not null then random() end as azar
  from nivel_desafios nd
  join desafios_para_jugar d on d.id = nd.desafio_id
  where nd.nivel_id = p_nivel_id
    and d.activo
),
seleccion as materialized (
  select id, tipo, imagen_url, video_url, texto_pregunta, activo,
         row_number() over (order by azar, orden_nivel) as orden
  from sorteo
  order by azar, orden_nivel
  limit coalesce(v_limite, 2147483647)
),
persistido as (
  insert into intento_desafios (intento_id, desafio_id, orden)
  select v_intento.id, s.id, s.orden
  from seleccion s
  returning 1
)
select coalesce(jsonb_agg(jsonb_build_object(
         'id', s.id, 'tipo', s.tipo, 'imagen_url', s.imagen_url,
         'video_url', s.video_url, 'texto_pregunta', s.texto_pregunta,
         'activo', s.activo
       ) order by s.orden), '[]'::jsonb)
into v_desafios
from seleccion s;
```

`sorteo as materialized` fija el `random()` de cada fila una sola vez;
`seleccion` reutiliza ese valor tanto para ordenar/recortar como para
numerar el `orden` persistido. `seleccion` se marca también `materialized`
de forma explícita (aunque Postgres ya materializa por defecto una CTE
referenciada más de una vez — aquí lo está, en el `insert` de `persistido`
y en el `select` final) para no depender de ese comportamiento implícito:
así queda garantizado que el `orden` guardado en `intento_desafios`
coincide siempre con el orden en que se devuelven los desafíos en el
`jsonb`. La forma de la respuesta (`{"intento_id", "desafios": [...]}`) no
cambia — `app/lib/services/nivel_juego_gateway.dart` sigue decodificándola
igual.

### D4. `cerrar_intento_nivel` cuenta contra `intento_desafios`, no contra `nivel_desafios`, y exige que la selección exista

```sql
select count(*) into v_total_desafios
from intento_desafios
where intento_id = p_intento_id;

if v_total_desafios = 0 then
  raise exception 'El intento % no tiene desafios asignados en intento_desafios (nivel sin desafios, intento creado sin pasar por iniciar_intento_nivel, o anterior a esta migracion)', p_intento_id;
end if;

select count(distinct rd.desafio_id), coalesce(sum(rd.puntos), 0)
into v_respondidos, v_puntaje
from respuestas_desafio rd
join intento_desafios idf
  on idf.desafio_id = rd.desafio_id
 and idf.intento_id = p_intento_id
where rd.intento_id = p_intento_id;
```

El `count(*) = 0` explícito cubre dos casos que si no, cerrarían en falso
con `puntaje_total = 0` y `superado = false` sin avisar: (a) un intento
creado antes de esta migración, que nunca tuvo fila en `intento_desafios`;
(b) un intento insertado directamente por REST saltándose
`iniciar_intento_nivel` (la policy `intentos_nivel_insert_own` ya lo
permite hoy). En ambos casos es preferible fallar con una excepción clara
a "cerrar" silenciosamente un intento sin haber jugado nada — mismo
espíritu defensivo que el resto de RPCs de este esquema (D5 de INT-95).

El resto de la función (superación, estrellas, `progreso_usuario_nivel`,
desbloqueo del camino) no cambia: solo cambian estas dos consultas.

## Risks / Trade-offs

- **Intentos previos a esta migración quedan permanentemente sin poder
  cerrarse** (fallan con la excepción de D4) → Mitigación: aceptado. El
  issue confirma que la app (INT-92) todavía no llama a
  `cerrar_intento_nivel` — "se entrega sin cerrar el intento por este
  motivo" — así que no hay ningún intento real en producción que dependiera
  de cerrarse hoy. Si `supabase db push` revela intentos existentes en el
  remoto (de pruebas manuales), quedan huérfanos sin más consecuencia que
  no poder cerrarse; no se borran ni corrompen.
- **Doble fuente de verdad transitoria durante el rollout**: entre que se
  aplica la migración y se despliega la nueva versión de la app (si alguna
  vez llega a llamar a `cerrar_intento_nivel` antes del despliegue), un
  intento arrancado con el código viejo de `iniciar_intento_nivel` no
  tendría `intento_desafios` → Mitigación: no aplica todavía, porque
  `iniciar_intento_nivel` se reemplaza en la misma migración que
  `cerrar_intento_nivel`; no hay ventana en la que una arranque con lógica
  vieja y la otra ya exija la tabla nueva.
- **`row_number()` sobre `random()` materializado**: si Postgres decidiera
  no respetar `materialized` (se ignora en versiones muy antiguas, pero
  Supabase corre Postgres 17) el `random()` podría recalcularse por fila
  entre las dos referencias → Mitigación: `materialized` es explícito
  desde Postgres 12; el proyecto corre Postgres 17.6 (`backend/README.md`).

## Migration Plan

Una migración nueva (`persistir_desafios_intento` o similar) con, en orden:
la tabla `intento_desafios` + sus policies (D1/D2), y
`create or replace function` de `iniciar_intento_nivel` (D3) y
`cerrar_intento_nivel` (D4). Aplicada con `supabase db push` contra el
proyecto remoto enlazado. No transforma datos existentes (ver Riesgos).

**Rollback**: `drop function` de ambas (revirtiendo al `create or replace`
anterior de cada una, ver `git log` de sus migraciones) y `drop table
intento_desafios`, en una migración inversa; o `supabase db reset --linked`
mientras no haya intentos reales cerrados a través de la tabla nueva.
