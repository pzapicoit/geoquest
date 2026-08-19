-- INT-109: clasificacion entre jugadores (global, por camino, por tematica).
-- Ver design.md de openspec/changes/int-109-clasificacion-global-camino-tematica
-- (D1-D8) para el porque de cada decision referenciada abajo.
--
-- D1: se implementan como funciones `security definer` (mismo mecanismo de
-- bypass que metricas_home/alertas_contenido/actividad_reciente de INT-87),
-- no como vistas -- necesitan parametros (camino_id, tematica_id, limite)
-- que una vista plana no admite. A diferencia de esas RPCs de panel, NO
-- llevan gate de is_admin(): el ranking es informacion social entre
-- jugadores, no administrativa, asi que se conceden a `authenticated`.
--
-- El bypass de RLS es deliberado y acotado: cada funcion solo expone
-- usuario_id/nombre/avatar_url (ya publicos entre jugadores por decision de
-- producto, ver proposal.md) mas la puntuacion agregada y el contador de
-- niveles superados -- nunca una fila individual de intentos_nivel o
-- respuestas_desafio de otro jugador.

-- Ranking global: suma historica de respuestas_desafio.puntos por jugador
-- (via intentos_nivel.usuario_id), sin filtrar por camino/desafio activo
-- (D7: la puntuacion ya ganada se conserva aunque el contenido se
-- desactive despues, igual que hoy hace camino_gateway.dart en el cliente).
create function clasificacion_global(p_limite integer default 50)
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
  -- D3: limite acotado en servidor a [1, 100] -- nunca se trae la tabla
  -- completa aunque el cliente pida un numero absurdo.
  v_limite integer := least(greatest(coalesce(p_limite, 50), 1), 100);
begin
  return query
  with base as (
    select
      it.usuario_id,
      sum(rd.puntos)::bigint as puntuacion
    from respuestas_desafio rd
    join intentos_nivel it on it.id = rd.intento_id
    group by it.usuario_id
  ),
  superados as (
    select pun.usuario_id, count(*)::integer as niveles_superados
    from progreso_usuario_nivel pun
    where pun.superado
    group by pun.usuario_id
  ),
  -- D2: posicion = rank() sobre TODO el conjunto, no solo el top devuelto,
  -- para que empates compartan posicion y el numero refleje el puesto real.
  ranking as (
    select
      b.usuario_id,
      b.puntuacion,
      coalesce(s.niveles_superados, 0) as niveles_superados,
      rank() over (order by b.puntuacion desc) as posicion
    from base b
    left join superados s on s.usuario_id = b.usuario_id
  ),
  top_n as (
    select *
    from ranking rk
    order by rk.puntuacion desc, rk.usuario_id asc
    limit v_limite
  ),
  -- D4: la fila de quien llama siempre viaja, aunque quede fuera del top.
  resultado as (
    select * from top_n
    union all
    select r.*
    from ranking r
    where r.usuario_id = auth.uid()
      and not exists (select 1 from top_n t where t.usuario_id = auth.uid())
  ),
  -- D5: si quien llama no tiene ninguna fila agregable, se le devuelve
  -- igual con puntuacion 0 y posicion null (no compite todavia).
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

revoke execute on function clasificacion_global(integer) from public;
grant execute on function clasificacion_global(integer) to authenticated;

-- Ranking por camino: mejor_puntaje de progreso_usuario_nivel para una
-- parada concreta. Sin filtro de existencia de p_camino_id: si no existe,
-- el ranking sale vacio y solo se aplica la regla D5 sobre la fila propia
-- (sin lanzar excepcion).
create function clasificacion_por_camino(p_camino_id uuid, p_limite integer default 50)
returns table (
  usuario_id uuid,
  nombre text,
  avatar_url text,
  puntuacion integer,
  superado boolean,
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
      pun.mejor_puntaje as puntuacion,
      pun.superado
    from progreso_usuario_nivel pun
    where pun.camino_id = p_camino_id
  ),
  ranking as (
    select
      b.usuario_id,
      b.puntuacion,
      b.superado,
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
    select auth.uid(), 0, false, null::bigint
    where not exists (select 1 from resultado rs where rs.usuario_id = auth.uid())
  )
  select
    f.usuario_id,
    p.nombre,
    p.avatar_url,
    f.puntuacion,
    f.superado,
    f.posicion,
    (f.usuario_id = auth.uid()) as es_usuario_actual
  from final f
  join profiles p on p.id = f.usuario_id
  order by (f.posicion is null), f.posicion, f.usuario_id;
end;
$$;

revoke execute on function clasificacion_por_camino(uuid, integer) from public;
grant execute on function clasificacion_por_camino(uuid, integer) to authenticated;

-- Ranking por tematica: suma de mejor_puntaje sobre todas las paradas de
-- camino que comparten tematica_id. El join a camino excluye por
-- construccion las filas huerfanas de progreso_usuario_nivel con
-- camino_id null (mismo criterio que camino_jugador desde INT-106).
create function clasificacion_por_tematica(p_tematica_id uuid, p_limite integer default 50)
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
    where c.tematica_id = p_tematica_id
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

revoke execute on function clasificacion_por_tematica(uuid, integer) from public;
grant execute on function clasificacion_por_tematica(uuid, integer) to authenticated;
