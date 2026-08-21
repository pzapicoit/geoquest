-- INT-123 (D2, D4): la puntuación del jugador pasa a ser el mejor intento por
-- parada, no la suma histórica de todas sus respuestas.
--
-- El defecto no era que faltara el dato: `progreso_usuario_nivel.mejor_puntaje`
-- ya existe y ya es monótono por el `greatest(...)` de `cerrar_intento_parada`
-- (20260819170000). Lo que pasaba es que dos de las cuatro superficies de
-- puntuación se quedaron atrás: `clasificacion_por_camino` y
-- `clasificacion_por_tematica` (INT-109) ya agregaban `mejor_puntaje`, mientras
-- `clasificacion_global` sumaba `respuestas_desafio.puntos` y la app se
-- descargaba esa tabla entera para sumarla en cliente. Repetir una parada
-- acumulaba en esas dos y no en las otras dos.
--
-- `respuestas_desafio.puntos` NO cambia: se sigue calculando y persistiendo
-- igual por desafío (`calcular_puntaje`, curva exponencial, bonus por rapidez).
-- Lo que cambia es cómo se agrega para dar "la puntuación del jugador".

-- 1. (D2) camino_jugador expone la puntuación de la parada.
--
-- `mejor_puntaje` va al FINAL de la lista de columnas, no junto a
-- `estrellas_obtenidas` donde encajaría mejor por significado: `create or
-- replace view` no admite reordenar ni renombrar columnas existentes, solo
-- añadir al final (mismo límite ya documentado en 20260818122000 y en
-- 20260819182000). Así se conservan privilegios y dependencias sin
-- `drop` + `create`.
--
-- El `coalesce` no es cosmético: `pun` entra por LEFT JOIN, así que una parada
-- que el jugador nunca jugó no tiene fila de progreso. Sin él la columna
-- llegaría NULL y el acumulado que la app calcula sobre el camino se rompería
-- en la primera parada sin jugar.
--
-- No hace falta ningún filtro de `usuario_id` nuevo: la columna se lee del
-- mismo alias `pun` que el LEFT JOIN de abajo ya filtra por
-- `pun.usuario_id = auth.uid()`. Este es exactamente el caso que advierte D1 de
-- INT-96 (el aislamiento por jugador NO lo da la RLS de la tabla, que esta
-- vista ignora por ser `security_invoker = false`, sino ese filtro explícito), y
-- se cumple por reutilizar el join existente, no por suerte.
create or replace view camino_jugador
with (security_invoker = false)
as
with estrellas_acumuladas as (
  select coalesce(sum(pun.mejores_estrellas), 0) as total
  from progreso_usuario_nivel pun
  join camino c on c.id = pun.camino_id
  where pun.usuario_id = auth.uid()
)
select
  c.id as camino_id,
  c.orden,
  estrellas_requeridas_por_orden(c.orden) as estrellas_requeridas,
  c.dificultad,
  c.nombre,
  t.id as tematica_id,
  t.nombre as tematica_nombre,
  coalesce(pun.superado, false) as superado,
  coalesce(pun.mejores_estrellas, 0) as estrellas_obtenidas,
  ea.total as estrellas_acumuladas_usuario,
  coalesce(pun.desbloqueado, false)
    or estrellas_requeridas_por_orden(c.orden) <= ea.total as desbloqueado,
  coalesce(
    c.orden = min(case when not coalesce(pun.superado, false) then c.orden end)
      over (),
    false
  ) as es_actual,
  coalesce(pun.mejor_puntaje, 0) as mejor_puntaje
from camino c
join tematicas t on t.id = c.tematica_id
left join progreso_usuario_nivel pun
  on pun.camino_id = c.id and pun.usuario_id = auth.uid()
cross join estrellas_acumuladas ea
order by c.orden;

-- 2. (D4) clasificacion_global agrega el mejor intento por parada.
--
-- Solo cambia el CTE `base`: de `respuestas_desafio` + `intentos_nivel` a
-- `progreso_usuario_nivel` + `join camino`. El resto de la función queda
-- idéntico -- `ranking` (rank sobre TODO el conjunto, D2 de INT-109), `top_n`
-- (límite acotado a [1,100], D3), `resultado` (la fila de quien llama siempre
-- viaja, D4) y `final` (puntuación 0 y posición null si no hay nada agregable,
-- D5) siguen valiendo palabra por palabra.
--
-- El `join camino` no es decorativo: excluye el progreso huérfano
-- (`progreso_usuario_nivel.camino_id` NULL, historial de paradas que ya no
-- están en el camino -- ver el `raise warning` de 20260818121000) con el mismo
-- criterio que ya aplicaba `clasificacion_por_tematica`. Sin él, el ranking
-- podría acreditarle a un jugador puntos que su propia Home no le muestra,
-- porque `camino_jugador` solo recorre posiciones existentes de `camino`.
--
-- Y desaparece el CTE `superados`: `niveles_superados` se cuenta del mismo
-- `progreso_usuario_nivel` que ya se está agregando, así que sobra recorrer la
-- tabla dos veces para unirla consigo misma.
--
-- Nota sobre `activo`: el join es a `camino`, no a `camino` filtrado por
-- `activo`, así que la puntuación ya ganada en una parada que después se
-- desactiva se conserva (D7 de INT-109, escenario de spec vivo).
create or replace function clasificacion_global(p_limite integer default 50)
returns table (
  usuario_id uuid,
  nombre text,
  avatar_url text,
  puntuacion bigint,
  niveles_superados integer,
  posicion bigint,
  es_usuario_actual boolean
)
language plpgsql
security definer
stable
set search_path = public
as $$
declare
  v_limite integer := least(greatest(coalesce(p_limite, 50), 1), 100);
begin
  return query
  with base as (
    select
      pun.usuario_id,
      sum(pun.mejor_puntaje)::bigint as puntuacion,
      count(*) filter (where pun.superado)::integer as niveles_superados
    from progreso_usuario_nivel pun
    join camino c on c.id = pun.camino_id
    group by pun.usuario_id
  ),
  ranking as (
    select
      b.usuario_id,
      b.puntuacion,
      b.niveles_superados,
      rank() over (order by b.puntuacion desc) as posicion
    from base b
  ),
  top_n as (
    select *
    from ranking rk
    order by rk.puntuacion desc, rk.usuario_id asc
    limit v_limite
  ),
  resultado as (
    select * from top_n
    union all
    select r.*
    from ranking r
    where r.usuario_id = auth.uid()
      and not exists (select 1 from top_n t where t.usuario_id = auth.uid())
  ),
  final as (
    select * from resultado
    union all
    select auth.uid(), 0::bigint, 0, null::bigint
    where not exists (select 1 from resultado rs where rs.usuario_id = auth.uid())
  )
  select
    f.usuario_id,
    p.nombre,
    p.avatar_url,
    f.puntuacion,
    f.niveles_superados,
    f.posicion,
    (f.usuario_id = auth.uid()) as es_usuario_actual
  from final f
  join profiles p on p.id = f.usuario_id
  order by (f.posicion is null), f.posicion, f.usuario_id;
end;
$$;

-- `create or replace function` conserva los privilegios existentes, pero se
-- reemiten para que la migración sea autosuficiente si se aplica sobre una base
-- donde la función no existía todavía.
revoke execute on function clasificacion_global(integer) from public;
grant execute on function clasificacion_global(integer) to authenticated;
