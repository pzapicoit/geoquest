-- INT-100: cerrar_intento_nivel nunca podia cerrar un intento con
-- preguntas_por_partida o con desafios inactivos, porque contaba
-- completitud contra nivel_desafios (la asignacion en vivo del nivel) en
-- vez de contra lo que realmente le toco a ese intento. iniciar_intento_nivel
-- nunca persistia esa seleccion en ningun sitio. Ver design.md de
-- openspec/changes/int-100-persistir-desafios-intento.

-- 1. intento_desafios: snapshot de que desafios (y en que orden) le
-- tocaron a un intento concreto (D1). Mismo patron que nivel_desafios
-- (PK compuesta + unique(intento_id, orden)) y mismo on delete restrict
-- hacia desafios que nivel_desafios/respuestas_desafio (D5 de INT-74).
create table intento_desafios (
  intento_id uuid not null references intentos_nivel (id) on delete cascade,
  desafio_id uuid not null references desafios (id) on delete restrict,
  orden integer not null,
  primary key (intento_id, desafio_id),
  unique (intento_id, orden)
);

-- 2. RLS de intento_desafios (D2): mismo patron que respuestas_desafio --
-- sin usuario_id propio, la pertenencia se resuelve via
-- intento_id -> intentos_nivel.usuario_id. Sin policy de update ni delete:
-- es un snapshot inmutable, igual que respuestas_desafio.
alter table public.intento_desafios enable row level security;

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

-- 3. iniciar_intento_nivel persiste su seleccion (D3). Misma logica de
-- seleccion que INT-95/INT-98 (todos si preguntas_por_partida es NULL, esa
-- cantidad al azar si no, siempre excluyendo activo = false); lo unico que
-- cambia es que la materializa una vez y la guarda en intento_desafios
-- antes de responder. La forma de la respuesta no cambia.
create or replace function iniciar_intento_nivel(p_nivel_id uuid)
returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_activo boolean;
  v_limite integer;
  v_intento intentos_nivel;
  v_desafios jsonb;
begin
  select activo, preguntas_por_partida
  into v_activo, v_limite
  from niveles
  where id = p_nivel_id;

  if not found or not v_activo then
    raise exception 'El nivel % no existe o no esta activo', p_nivel_id;
  end if;

  insert into intentos_nivel (usuario_id, nivel_id)
  values (auth.uid(), p_nivel_id)
  returning * into v_intento;

  -- D3: `materialized` fija el random() de cada fila una sola vez, para
  -- que el mismo valor sirva tanto para ordenar/recortar (`seleccion`)
  -- como para numerar el `orden` que se persiste -- si se releyera
  -- random() una segunda vez, el orden guardado podria no coincidir con
  -- el orden devuelto.
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
    'desafios', v_desafios
  );
end;
$$;

-- 4. cerrar_intento_nivel cuenta completitud y puntaje contra
-- intento_desafios (la seleccion de ESE intento), no contra nivel_desafios
-- (la asignacion en vivo del nivel) (D4). El resto de la funcion
-- (superacion, estrellas, progreso_usuario_nivel, desbloqueo del camino)
-- no cambia.
create or replace function cerrar_intento_nivel(p_intento_id uuid)
returns intentos_nivel
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_nivel_id uuid;
  v_puntaje_minimo integer;
  v_umbral_estrella_2 integer;
  v_umbral_estrella_3 integer;
  v_total_desafios integer;
  v_respondidos integer;
  v_puntaje integer;
  v_superado boolean;
  v_estrellas smallint;
  v_estrellas_acumuladas_camino integer;
  v_intento intentos_nivel;
begin
  select ni.nivel_id, n.puntaje_minimo_superar, n.umbral_estrella_2, n.umbral_estrella_3
  into v_nivel_id, v_puntaje_minimo, v_umbral_estrella_2, v_umbral_estrella_3
  from intentos_nivel ni
  join niveles n on n.id = ni.nivel_id
  where ni.id = p_intento_id;

  if not found then
    raise exception 'El intento % no existe o no pertenece al usuario autenticado', p_intento_id;
  end if;

  select count(*) into v_total_desafios
  from intento_desafios
  where intento_id = p_intento_id;

  -- D4: un intento sin fila en intento_desafios (creado sin pasar por
  -- iniciar_intento_nivel, o anterior a esta migracion) no puede cerrarse
  -- -- si no, "0 de 0" se leeria como completo y cerraria en falso con
  -- puntaje_total = 0 sin avisar.
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

  if v_respondidos < v_total_desafios then
    raise exception 'El intento % no tiene respuesta para todos los desafios del nivel (% de %)',
      p_intento_id, v_respondidos, v_total_desafios;
  end if;

  v_superado := v_puntaje >= v_puntaje_minimo;

  v_estrellas := case
    when not v_superado then 0
    when v_puntaje >= v_umbral_estrella_3 then 3
    when v_puntaje >= v_umbral_estrella_2 then 2
    else 1
  end;

  update intentos_nivel
  set puntaje_total = v_puntaje,
      superado = v_superado,
      estrellas_obtenidas = v_estrellas
  where id = p_intento_id
  returning * into v_intento;

  if not found then
    raise exception 'El intento % ya no existe', p_intento_id;
  end if;

  insert into progreso_usuario_nivel (
    usuario_id, nivel_id, superado, mejor_puntaje, mejores_estrellas, desbloqueado
  )
  values (auth.uid(), v_nivel_id, v_superado, v_puntaje, v_estrellas, true)
  on conflict (usuario_id, nivel_id) do update set
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
    join camino c on c.nivel_id = pun.nivel_id
    where pun.usuario_id = auth.uid();

    -- Desbloquea de una vez todas las posiciones del camino cuyo umbral ya
    -- se alcance, no solo "la siguiente" (decision de producto, INT-98).
    insert into progreso_usuario_nivel (usuario_id, nivel_id, desbloqueado)
    select auth.uid(), c.nivel_id, true
    from camino c
    where c.estrellas_requeridas <= v_estrellas_acumuladas_camino
    on conflict (usuario_id, nivel_id) do update set
      desbloqueado = true,
      actualizado_en = now();
  end if;

  return v_intento;
end;
$$;
