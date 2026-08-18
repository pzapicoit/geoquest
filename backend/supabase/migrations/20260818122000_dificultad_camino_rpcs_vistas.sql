-- INT-106: RPCs y vistas que resuelven temática+dificultad en vez de
-- niveles/nivel_desafios curados a mano. Tercera de cuatro migraciones.
-- Ver design.md D6 y las specs delta de challenge-play, level-progression,
-- challenge-timer, challenge-scoring, content-alerts, panel-home-metrics,
-- panel-recent-activity, content-reordering, player-path del propio
-- cambio.

-- 3.1a `desafios_para_jugar` gana tematica_id/dificultad (ninguno de los
-- dos es sensible como lat_real/lng_real/nombre_lugar) para que
-- `iniciar_intento_parada` pueda filtrar el pool sin tocar `desafios`
-- directamente -- security invoker no puede leer `desafios` para un
-- jugador (RLS de INT-77 solo permite select a is_admin()), igual que
-- pasaba con nivel_desafios antes de este cambio.
create or replace view desafios_para_jugar as
select id, tipo, imagen_url, video_url, texto_pregunta, activo, tematica_id, dificultad
from desafios;

-- 3.1 `iniciar_intento_parada` reemplaza a `iniciar_intento_nivel`: resuelve
-- la parada de camino (temática+dificultad efectivas, con overrides) y
-- sortea `preguntas_por_partida` desafíos de ese pool, igual que antes
-- pero sobre temática+dificultad en vez de `nivel_desafios` curado.
create function iniciar_intento_parada(p_camino_id uuid)
returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_activo boolean;
  v_tematica_id uuid;
  v_dificultad dificultad;
  v_limite integer;
  v_segundos_por_desafio integer;
  v_pool_disponible integer;
  v_intento intentos_nivel;
  v_desafios jsonb;
begin
  -- `segundos_por_desafio` viaja en la respuesta desde INT-99 (D11 de su
  -- design.md): la app lo lee para inicializar la cuenta atras sin una
  -- segunda consulta -- ver `app/lib/services/nivel_juego_gateway.dart`.
  -- Aqui sale de camino/dificultad_defaults en vez de niveles, pero el
  -- contrato de la respuesta no cambia.
  select c.activo, c.tematica_id, c.dificultad,
         coalesce(c.preguntas_por_partida, dd.preguntas_por_partida),
         coalesce(c.segundos_por_desafio, dd.segundos_por_desafio)
  into v_activo, v_tematica_id, v_dificultad, v_limite, v_segundos_por_desafio
  from camino c
  join dificultad_defaults dd on dd.dificultad = c.dificultad
  where c.id = p_camino_id;

  if not found or not v_activo then
    raise exception 'La parada % no existe o no esta activa', p_camino_id;
  end if;

  select count(*) into v_pool_disponible
  from desafios_para_jugar d
  where d.tematica_id = v_tematica_id
    and d.dificultad = v_dificultad
    and d.activo;

  if v_pool_disponible < v_limite then
    raise exception 'La parada % exige % preguntas activas pero su pool de tematica+dificultad solo tiene %',
      p_camino_id, v_limite, v_pool_disponible;
  end if;

  insert into intentos_nivel (usuario_id, camino_id)
  values (auth.uid(), p_camino_id)
  returning * into v_intento;

  with sorteo as materialized (
    select d.id, d.tipo, d.imagen_url, d.video_url, d.texto_pregunta, d.activo,
           random() as azar
    from desafios_para_jugar d
    where d.tematica_id = v_tematica_id
      and d.dificultad = v_dificultad
      and d.activo
  ),
  seleccion as materialized (
    select id, tipo, imagen_url, video_url, texto_pregunta, activo,
           row_number() over (order by azar) as orden
    from sorteo
    order by azar
    limit v_limite
  ),
  persistido as (
    insert into intento_desafios (intento_id, desafio_id, orden)
    select v_intento.id, s.id, s.orden
    from seleccion s
    returning 1
  )
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', s.id,
           'tipo', s.tipo,
           'imagen_url', s.imagen_url,
           'video_url', s.video_url,
           'texto_pregunta', s.texto_pregunta,
           'activo', s.activo
         ) order by s.orden), '[]'::jsonb)
  into v_desafios
  from seleccion s;

  return jsonb_build_object(
    'intento_id', v_intento.id,
    'segundos_por_desafio', v_segundos_por_desafio,
    'desafios', v_desafios
  );
end;
$$;

revoke execute on function iniciar_intento_parada(uuid) from public;
grant execute on function iniciar_intento_parada(uuid) to authenticated;

drop function iniciar_intento_nivel(uuid);

-- 3.2 `cerrar_intento_parada` reemplaza a `cerrar_intento_nivel`: misma
-- logica de agregacion/superacion/estrellas/desbloqueo, resolviendo
-- puntaje_minimo_superar/umbral_estrella_2/3 efectivos (override de camino
-- o dificultad_defaults) en vez de leerlos de niveles.
create function cerrar_intento_parada(p_intento_id uuid)
returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_camino_id uuid;
  v_puntaje_minimo integer;
  v_umbral_estrella_2 integer;
  v_umbral_estrella_3 integer;
  v_total_desafios integer;
  v_respondidos integer;
  v_puntaje integer;
  v_superado boolean;
  v_estrellas smallint;
  v_mejor_puntaje_anterior integer;
  v_estrellas_acumuladas_camino integer;
begin
  select ni.camino_id,
         coalesce(c.puntaje_minimo_superar, dd.puntaje_minimo_superar),
         coalesce(c.umbral_estrella_2, dd.umbral_estrella_2),
         coalesce(c.umbral_estrella_3, dd.umbral_estrella_3)
  into v_camino_id, v_puntaje_minimo, v_umbral_estrella_2, v_umbral_estrella_3
  from intentos_nivel ni
  join camino c on c.id = ni.camino_id
  join dificultad_defaults dd on dd.dificultad = c.dificultad
  where ni.id = p_intento_id;

  if not found then
    raise exception 'El intento % no existe o no pertenece al usuario autenticado', p_intento_id;
  end if;

  select count(*) into v_total_desafios
  from intento_desafios
  where intento_id = p_intento_id;

  if v_total_desafios = 0 then
    raise exception 'El intento % no tiene desafios asignados en intento_desafios (parada sin desafios, intento creado sin pasar por iniciar_intento_parada, o anterior a esta migracion)', p_intento_id;
  end if;

  select count(distinct rd.desafio_id), coalesce(sum(rd.puntos), 0)
  into v_respondidos, v_puntaje
  from respuestas_desafio rd
  join intento_desafios idf
    on idf.desafio_id = rd.desafio_id
   and idf.intento_id = p_intento_id
  where rd.intento_id = p_intento_id;

  if v_respondidos < v_total_desafios then
    raise exception 'El intento % no tiene respuesta para todos los desafios de la parada (% de %)',
      p_intento_id, v_respondidos, v_total_desafios;
  end if;

  v_superado := v_puntaje >= v_puntaje_minimo;

  v_estrellas := case
    when not v_superado then 0
    when v_puntaje >= v_umbral_estrella_3 then 3
    when v_puntaje >= v_umbral_estrella_2 then 2
    else 1
  end;

  select mejor_puntaje into v_mejor_puntaje_anterior
  from progreso_usuario_nivel
  where usuario_id = auth.uid() and camino_id = v_camino_id;

  update intentos_nivel
  set puntaje_total = v_puntaje,
      superado = v_superado,
      estrellas_obtenidas = v_estrellas
  where id = p_intento_id;

  if not found then
    raise exception 'El intento % ya no existe', p_intento_id;
  end if;

  insert into progreso_usuario_nivel (
    usuario_id, camino_id, superado, mejor_puntaje, mejores_estrellas, desbloqueado
  )
  values (auth.uid(), v_camino_id, v_superado, v_puntaje, v_estrellas, true)
  on conflict (usuario_id, camino_id) do update set
    superado = progreso_usuario_nivel.superado or excluded.superado,
    mejor_puntaje = greatest(progreso_usuario_nivel.mejor_puntaje, excluded.mejor_puntaje),
    mejores_estrellas = greatest(progreso_usuario_nivel.mejores_estrellas, excluded.mejores_estrellas),
    desbloqueado = true,
    actualizado_en = now();

  if v_superado then
    -- Lock de asesoramiento por usuario: bajo READ COMMITTED, dos intentos
    -- del mismo usuario cerrandose a la vez podrian leer la suma de
    -- estrellas del camino sin ver el upsert del otro (D7 de INT-79).
    perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text, 0));

    select coalesce(sum(pun.mejores_estrellas), 0) into v_estrellas_acumuladas_camino
    from progreso_usuario_nivel pun
    where pun.usuario_id = auth.uid();

    insert into progreso_usuario_nivel (usuario_id, camino_id, desbloqueado)
    select auth.uid(), c.id, true
    from camino c
    where c.estrellas_requeridas <= v_estrellas_acumuladas_camino
    on conflict (usuario_id, camino_id) do update set
      desbloqueado = true,
      actualizado_en = now();
  end if;

  return jsonb_build_object(
    'puntaje_total', v_puntaje,
    'superado', v_superado,
    'estrellas_obtenidas', v_estrellas,
    'puntaje_minimo_superar', v_puntaje_minimo,
    'mejor_puntaje_anterior', v_mejor_puntaje_anterior
  );
end;
$$;

revoke execute on function cerrar_intento_parada(uuid) from public;
grant execute on function cerrar_intento_parada(uuid) to authenticated;

drop function cerrar_intento_nivel(uuid);

-- 3.3 trigger de respuestas_desafio: segundos_por_desafio efectivo sale de
-- camino_id + dificultad_defaults en vez de niveles.
create or replace function respuestas_desafio_calcular_antes_de_insertar()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_lat_real double precision;
  v_lng_real double precision;
  v_segundos_por_desafio integer;
  v_mostrado_en timestamptz;
  v_segundos_transcurridos integer;
begin
  select lat_real, lng_real
  into v_lat_real, v_lng_real
  from desafios
  where id = new.desafio_id;

  if not found then
    raise exception 'El desafio % no existe', new.desafio_id;
  end if;

  select coalesce(c.segundos_por_desafio, dd.segundos_por_desafio)
  into v_segundos_por_desafio
  from intentos_nivel it
  join camino c on c.id = it.camino_id
  join dificultad_defaults dd on dd.dificultad = c.dificultad
  where it.id = new.intento_id;

  if not found then
    raise exception 'El intento % no existe', new.intento_id;
  end if;

  select mostrado_en
  into v_mostrado_en
  from intento_desafios
  where intento_id = new.intento_id
    and desafio_id = new.desafio_id;

  if v_mostrado_en is null then
    v_segundos_transcurridos := v_segundos_por_desafio;
  else
    v_segundos_transcurridos := least(
      v_segundos_por_desafio,
      greatest(0, floor(extract(epoch from (now() - v_mostrado_en)))::integer)
    );
  end if;

  new.segundos_transcurridos := v_segundos_transcurridos;

  if new.lat_adivinada is null then
    new.distancia_km := null;
    new.puntos := 0;
  else
    new.distancia_km := calcular_distancia_km(
      v_lat_real, v_lng_real, new.lat_adivinada, new.lng_adivinada
    );
    new.puntos := calcular_puntaje(
      new.distancia_km, v_segundos_transcurridos, v_segundos_por_desafio
    );
  end if;

  return new;
end;
$$;

-- 3.4 `responder_desafio`: el `puntos_maximos` del revelado tambien
-- resuelve segundos_por_desafio efectivo via camino_id + dificultad_defaults
-- (antes via niveles). El resto de la funcion no cambia.
create or replace function responder_desafio(
  p_intento_id uuid,
  p_desafio_id uuid,
  p_lat_adivinada double precision default null,
  p_lng_adivinada double precision default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_lat_real double precision;
  v_lng_real double precision;
  v_nombre_lugar text;
  v_segundos_por_desafio integer;
  v_respuesta respuestas_desafio;
  v_puntos_distancia integer;
  v_puntos_bonus integer;
begin
  if (p_lat_adivinada is null) <> (p_lng_adivinada is null) then
    raise exception 'p_lat_adivinada y p_lng_adivinada deben ser ambos NULL o ambos no nulos';
  end if;

  if not exists (
    select 1
    from intentos_nivel
    where id = p_intento_id
      and usuario_id = auth.uid()
  ) then
    raise exception 'El intento % no pertenece al usuario autenticado', p_intento_id;
  end if;

  select lat_real, lng_real, nombre_lugar
  into v_lat_real, v_lng_real, v_nombre_lugar
  from desafios
  where id = p_desafio_id;

  if not found then
    raise exception 'El desafio % no existe', p_desafio_id;
  end if;

  select coalesce(c.segundos_por_desafio, dd.segundos_por_desafio)
  into v_segundos_por_desafio
  from intentos_nivel it
  join camino c on c.id = it.camino_id
  join dificultad_defaults dd on dd.dificultad = c.dificultad
  where it.id = p_intento_id;

  insert into respuestas_desafio (intento_id, desafio_id, lat_adivinada, lng_adivinada)
  values (p_intento_id, p_desafio_id, p_lat_adivinada, p_lng_adivinada)
  returning * into v_respuesta;

  v_puntos_distancia := coalesce(
    calcular_puntaje_por_distancia(v_respuesta.distancia_km), 0
  );
  v_puntos_bonus := v_respuesta.puntos - v_puntos_distancia;

  return to_jsonb(v_respuesta) || jsonb_build_object(
    'lat_real', v_lat_real,
    'lng_real', v_lng_real,
    'nombre_lugar', v_nombre_lugar,
    'puntos_maximos', calcular_puntaje(0, 0, coalesce(v_segundos_por_desafio, 60)),
    'puntos_distancia', v_puntos_distancia,
    'puntos_bonus', v_puntos_bonus
  );
end;
$$;

-- 3.5 `camino_jugador`: expone tematica+dificultad+nombre de la parada en
-- vez de "el nivel al que apunta"; camino_id sustituye a nivel_id como
-- identificador que usa la app. estrellas_acumuladas sigue sumando sobre
-- TODAS las paradas de progreso_usuario_nivel del jugador -- ya no hace
-- falta el join a camino para filtrar historial huerfano (D2.4 de la
-- migracion de datos): esas filas tienen camino_id NULL y un join interno
-- (no left) a camino ya las excluye por construccion.
--
-- `create or replace` no vale aqui: la vista vieja tiene `nivel_id`/
-- `nivel_nombre` en las posiciones 4 y 5, y esta version los sustituye por
-- `dificultad`/`nombre` en las mismas posiciones -- eso es un cambio de
-- nombre de columna existente, que Postgres rechaza en un CREATE OR REPLACE
-- (solo permite anadir columnas al final). Hace falta drop + create.
drop view camino_jugador;

create view camino_jugador
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
  c.estrellas_requeridas,
  c.dificultad,
  c.nombre,
  t.id as tematica_id,
  t.nombre as tematica_nombre,
  coalesce(pun.superado, false) as superado,
  coalesce(pun.mejores_estrellas, 0) as estrellas_obtenidas,
  ea.total as estrellas_acumuladas_usuario,
  coalesce(pun.desbloqueado, false)
    or c.estrellas_requeridas <= ea.total as desbloqueado,
  coalesce(
    c.orden = min(case when not coalesce(pun.superado, false) then c.orden end)
      over (),
    false
  ) as es_actual
from camino c
join tematicas t on t.id = c.tematica_id
left join progreso_usuario_nivel pun
  on pun.camino_id = c.id and pun.usuario_id = auth.uid()
cross join estrellas_acumuladas ea
order by c.orden;

-- 3.5b (movido desde 20260818121000, ver su comentario): con
-- camino_jugador ya redefinida sin `nivel_id`/`pun.nivel_id`, la dependencia
-- que bloqueaba el DROP COLUMN ha desaparecido -- ahora si se puede repuntar
-- la PK de progreso_usuario_nivel y dropear las dos columnas nivel_id que
-- quedaban.
--
-- progreso_usuario_nivel: la PK compuesta (usuario_id, nivel_id) no admite
-- NULL en ninguna de sus columnas, y camino_id puede serlo (huerfanos de
-- 2.4 de la migracion de datos) -- pasa a una PK propia (id) con un unique
-- que solo exige unicidad de (usuario_id, camino_id) (Postgres ya trata
-- NULL como "distinto de cualquier otro" en un unique normal, asi que un
-- unique corriente sobre (usuario_id, camino_id) basta: nunca colisiona
-- entre huerfanos, y sigue impidiendo dos filas para el mismo
-- usuario+parada real).
alter table progreso_usuario_nivel drop constraint progreso_usuario_nivel_pkey;
alter table progreso_usuario_nivel add column id uuid not null default gen_random_uuid();
alter table progreso_usuario_nivel add constraint progreso_usuario_nivel_pkey primary key (id);
alter table progreso_usuario_nivel add constraint progreso_usuario_nivel_usuario_camino_key unique (usuario_id, camino_id);
alter table progreso_usuario_nivel
  add constraint progreso_usuario_nivel_camino_id_fkey foreign key (camino_id) references camino (id) on delete cascade;
alter table progreso_usuario_nivel drop column nivel_id;

-- camino.nivel_id ya no hace falta -- todo lo que lo consumia (el repunteo
-- de la migracion de datos y la vista de arriba) ya se hizo. Se dropea
-- antes de poder dropear `niveles` en la migracion de limpieza final.
alter table camino drop column nivel_id;

-- 3.6 `metricas_home`: niveles_activos -> paradas_activas (conteo de
-- `camino` activo). `create or replace` no vale: cambia el nombre de una
-- columna de salida (OUT parameter) existente, que Postgres rechaza igual
-- que con una vista (ver 3.5) -- hace falta drop + create.
drop function metricas_home();

create function metricas_home()
returns table (
  jugadores_totales integer,
  jugadores_activos_7d integer,
  partidas_hoy integer,
  paradas_activas integer
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
    (select count(*)::integer from camino where activo);
end;
$$;

-- 3.7 `alertas_contenido`: la alerta de tasa de superacion baja pasa a
-- calcularse por camino_id (parada) en vez de nivel_id.
create or replace function alertas_contenido()
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
    c.id,
    'Parada con baja tasa de superacion'::text,
    jsonb_build_object(
      'tasa_superacion', round(resumen.superados::numeric / resumen.total, 4),
      'total_intentos', resumen.total
    )
  from camino c
  join lateral (
    select count(*) as total,
           count(*) filter (where superado) as superados
    from intentos_nivel
    where camino_id = c.id
  ) resumen on true
  where c.activo
    and resumen.total >= 5
    and resumen.superados::numeric / resumen.total < 0.4

  union all

  select
    'desafio_incompleto'::text,
    d.id,
    'Desafio con datos incompletos'::text,
    jsonb_build_object('tipo', d.tipo, 'campo_faltante', ca.campo_faltante)
  from desafios d
  cross join lateral (
    select case
      when d.tipo = 'imagen' and coalesce(trim(d.imagen_url), '') = '' then 'imagen_url'
      when d.tipo = 'video' and coalesce(trim(d.video_url), '') = '' then 'video_url'
      when d.tipo = 'pregunta_texto' and coalesce(trim(d.texto_pregunta), '') = '' then 'texto_pregunta'
      when d.lat_real = 0 and d.lng_real = 0 then 'coordenadas'
    end as campo_faltante
  ) ca
  where d.activo
    and ca.campo_faltante is not null;
end;
$$;

-- 3.8 `actividad_reciente`: el evento nivel_superado pasa a incluir
-- camino_id en vez de nivel_id.
create or replace function actividad_reciente(p_limite integer default 20)
returns table (
  tipo text,
  ocurrido_en timestamptz,
  texto text,
  detalle jsonb
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_admin() then
    raise exception 'Solo un admin puede consultar la actividad reciente';
  end if;

  return query
  select
    'nuevo_registro'::text,
    u.created_at,
    p.nombre,
    '{}'::jsonb
  from profiles p
  join auth.users u on u.id = p.id
  where p.role = 'jugador'

  union all

  select
    'nivel_superado'::text,
    i.fecha,
    p.nombre,
    jsonb_build_object(
      'estrellas_obtenidas', i.estrellas_obtenidas,
      'camino_id', i.camino_id,
      'tematica_id', c.tematica_id
    )
  from intentos_nivel i
  join profiles p on p.id = i.usuario_id
  join camino c on c.id = i.camino_id
  where i.superado

  order by 2 desc
  limit p_limite;
end;
$$;

-- 3.9 se retiran reordenar_niveles y reordenar_preguntas_nivel (niveles y
-- nivel_desafios desaparecen). reordenar_tematicas y reordenar_camino no
-- cambian.
drop function reordenar_niveles(uuid, uuid[]);
drop function reordenar_preguntas_nivel(uuid, uuid[]);

-- 3.10 se retira desafios_uso (median curacion manual en nivel_desafios).
drop view desafios_uso;
