-- INT-87: RPCs y vistas de soporte al panel (reordenar, metricas, alertas).
-- Ver design.md de openspec/changes/int-87-rpcs-vistas-panel para el porque
-- de cada decision referenciada como D1-D7 en los comentarios.

-- 1. Constraints de orden pasan a diferibles (D1). "alter table ... alter
-- constraint" solo admite foreign keys en Postgres (confirmado contra el
-- remoto: error 42809), asi que hace falta drop + add. Permite reasignar
-- orden a varias filas en una sola sentencia -- incluyendo intercambios de
-- posicion -- sin violar el unique de forma transitoria.
alter table tematicas drop constraint tematicas_orden_key;
alter table tematicas
  add constraint tematicas_orden_key unique (orden) deferrable initially immediate;

alter table niveles drop constraint niveles_tematica_id_orden_key;
alter table niveles
  add constraint niveles_tematica_id_orden_key unique (tematica_id, orden) deferrable initially immediate;

alter table nivel_desafios drop constraint nivel_desafios_nivel_id_orden_key;
alter table nivel_desafios
  add constraint nivel_desafios_nivel_id_orden_key unique (nivel_id, orden) deferrable initially immediate;

-- 2.1 reordenar_tematicas (D2: exige el conjunto completo antes de tocar
-- nada; security invoker porque la RLS de tematicas_admin_update de INT-77
-- ya exige is_admin() para el UPDATE de mas abajo).
create function reordenar_tematicas(ids_en_orden uuid[])
returns void
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_input integer;
  v_distinct integer;
  v_current integer;
  v_match integer;
begin
  if not is_admin() then
    raise exception 'Solo un admin puede reordenar tematicas';
  end if;

  v_input := coalesce(array_length(ids_en_orden, 1), 0);
  select count(distinct x) into v_distinct from unnest(ids_en_orden) x;
  select count(*) into v_current from tematicas;
  select count(*) into v_match from tematicas t where t.id = any(ids_en_orden);

  if v_input <> v_distinct or v_input <> v_current or v_match <> v_current then
    raise exception 'ids_en_orden debe contener exactamente las % tematicas existentes, sin duplicados (recibidos %)',
      v_current, v_input;
  end if;

  set constraints tematicas_orden_key deferred;

  update tematicas t
  set orden = pos.posicion
  from unnest(ids_en_orden) with ordinality as pos(id, posicion)
  where t.id = pos.id;
end;
$$;

-- 2.2 reordenar_niveles: igual que 2.1, acotado a una tematica.
create function reordenar_niveles(p_tematica_id uuid, ids_en_orden uuid[])
returns void
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_input integer;
  v_distinct integer;
  v_current integer;
  v_match integer;
begin
  if not is_admin() then
    raise exception 'Solo un admin puede reordenar niveles';
  end if;

  v_input := coalesce(array_length(ids_en_orden, 1), 0);
  select count(distinct x) into v_distinct from unnest(ids_en_orden) x;
  select count(*) into v_current from niveles where tematica_id = p_tematica_id;
  select count(*) into v_match
  from niveles n
  where n.tematica_id = p_tematica_id and n.id = any(ids_en_orden);

  if v_input <> v_distinct or v_input <> v_current or v_match <> v_current then
    raise exception 'ids_en_orden debe contener exactamente los % niveles de la tematica %, sin duplicados ni ids de otra tematica (recibidos %)',
      v_current, p_tematica_id, v_input;
  end if;

  set constraints niveles_tematica_id_orden_key deferred;

  update niveles n
  set orden = pos.posicion
  from unnest(ids_en_orden) with ordinality as pos(id, posicion)
  where n.tematica_id = p_tematica_id and n.id = pos.id;
end;
$$;

-- 2.3 reordenar_preguntas_nivel: igual, sobre nivel_desafios (clave
-- compuesta nivel_id+desafio_id, sin id propio -- ids_en_orden son
-- desafio_id).
create function reordenar_preguntas_nivel(p_nivel_id uuid, ids_en_orden uuid[])
returns void
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_input integer;
  v_distinct integer;
  v_current integer;
  v_match integer;
begin
  if not is_admin() then
    raise exception 'Solo un admin puede reordenar los desafios de un nivel';
  end if;

  v_input := coalesce(array_length(ids_en_orden, 1), 0);
  select count(distinct x) into v_distinct from unnest(ids_en_orden) x;
  select count(*) into v_current from nivel_desafios where nivel_id = p_nivel_id;
  select count(*) into v_match
  from nivel_desafios nd
  where nd.nivel_id = p_nivel_id and nd.desafio_id = any(ids_en_orden);

  if v_input <> v_distinct or v_input <> v_current or v_match <> v_current then
    raise exception 'ids_en_orden debe contener exactamente los % desafios asignados al nivel %, sin duplicados ni desafios de otro nivel (recibidos %)',
      v_current, p_nivel_id, v_input;
  end if;

  set constraints nivel_desafios_nivel_id_orden_key deferred;

  update nivel_desafios nd
  set orden = pos.posicion
  from unnest(ids_en_orden) with ordinality as pos(desafio_id, posicion)
  where nd.nivel_id = p_nivel_id and nd.desafio_id = pos.desafio_id;
end;
$$;

-- 3.1 metricas_home (D3: security definer -- a diferencia de is_admin()/
-- cerrar_intento_nivel, aqui hace falta agregar sobre TODOS los jugadores,
-- y la RLS de intentos_nivel/profiles es "cada cual lo suyo". El check de
-- is_admin() va primero, antes de tocar cualquier tabla).
create function metricas_home()
returns table (
  jugadores_totales integer,
  jugadores_activos_7d integer,
  partidas_hoy integer,
  niveles_activos integer
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_admin() then
    raise exception 'Solo un admin puede consultar las metricas del panel';
  end if;

  return query
  select
    (select count(*)::integer from profiles where role = 'jugador'),
    (select count(distinct usuario_id)::integer
       from intentos_nivel
       where fecha >= now() - interval '7 days'),
    (select count(*)::integer
       from intentos_nivel
       where fecha::date = current_date),
    (select count(*)::integer from niveles where activo);
end;
$$;

-- 3.2 alertas_contenido (D3 misma razon que metricas_home; D5: forma de
-- retorno generica tipo/referencia_id/titulo/detalle; D6: definicion de
-- "desafio incompleto"; D7: umbral de tasa de superacion baja).
create function alertas_contenido()
returns table (
  tipo text,
  referencia_id uuid,
  titulo text,
  detalle jsonb
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_admin() then
    raise exception 'Solo un admin puede consultar las alertas de contenido';
  end if;

  return query
  select
    'nivel_baja_tasa'::text,
    n.id,
    'Nivel con baja tasa de superacion'::text,
    jsonb_build_object(
      'tasa_superacion', round(resumen.superados::numeric / resumen.total, 4),
      'total_intentos', resumen.total
    )
  from niveles n
  join lateral (
    select count(*) as total,
           count(*) filter (where superado) as superados
    from intentos_nivel
    where nivel_id = n.id
  ) resumen on true
  where n.activo
    and resumen.total >= 5
    and resumen.superados::numeric / resumen.total < 0.4

  union all

  -- D6, corregido tras revision adversarial: el campo que falta se calcula
  -- una sola vez en el lateral y el WHERE filtra sobre ese mismo resultado
  -- (campo_faltante is not null), en vez de duplicar la misma condicion en
  -- un CASE y en un WHERE por separado -- un CASE sin ELSE desincronizado
  -- del WHERE podria devolver campo_faltante nulo para una fila que si
  -- entra en el resultado.
  select
    'desafio_incompleto'::text,
    d.id,
    'Desafio con datos incompletos'::text,
    jsonb_build_object('tipo', d.tipo, 'campo_faltante', c.campo_faltante)
  from desafios d
  cross join lateral (
    select case
      when d.tipo = 'imagen' and coalesce(trim(d.imagen_url), '') = '' then 'imagen_url'
      when d.tipo = 'video' and coalesce(trim(d.video_url), '') = '' then 'video_url'
      when d.tipo = 'pregunta_texto' and coalesce(trim(d.texto_pregunta), '') = '' then 'texto_pregunta'
      when d.lat_real = 0 and d.lng_real = 0 then 'coordenadas'
    end as campo_faltante
  ) c
  where d.activo
    and c.campo_faltante is not null;
end;
$$;

-- 4.1 desafios_uso (D4: vista sin security_invoker ejecuta con los
-- privilegios del dueño -- postgres, con bypassrls -- igual que un
-- security definer; el "where is_admin()" es lo que de verdad gatea el
-- acceso a no-admins).
create view desafios_uso as
select
  d.id as desafio_id,
  count(nd.nivel_id) as usos
from desafios d
left join nivel_desafios nd on nd.desafio_id = d.id
where is_admin()
group by d.id;
