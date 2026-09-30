-- INT-137: cierra las escrituras directas del cliente sobre las tablas de
-- juego y valida en `responder_desafio` que el desafio sea del intento.
--
-- Hasta ahora `intentos_nivel`, `intento_desafios`, `respuestas_desafio` y
-- `progreso_usuario_nivel` tenian policies insert/update "own". Con la clave
-- publicable (la que lleva la app) un jugador podia falsear su puntaje y sus
-- estrellas, desbloquear paradas, o insertar una respuesta y deducir la
-- coordenada real a partir de la distancia devuelta. Desde entonces toda
-- escritura legitima va por RPC, asi que esas policies sobran.
--
-- 1. Se eliminan las seis policies de escritura y se revocan los privilegios
--    de escritura de anon/authenticated (segunda barrera: una policy futura
--    puesta por error no sirve sin el privilegio de tabla). Queda solo
--    `select` sobre las filas propias.
-- 2. `iniciar_intento_parada` y `cerrar_intento_parada` eran security invoker
--    y dependian de esas policies: pasan a security definer. Como RLS deja
--    de filtrar, `cerrar_intento_parada` comprueba el dueño del intento a
--    mano (`usuario_id = auth.uid()`); `iniciar_intento_parada` ya derivaba
--    el usuario de auth.uid() y no acepta ningun parametro de usuario.
-- 3. `responder_desafio` y el trigger de calculo exigen que el desafio este
--    en `intento_desafios` del intento. Las cuatro funciones son copia de su
--    ultima definicion con solo estos cambios.

-- 1. Escrituras directas del cliente. `if exists`: el remoto es el unico
--    entorno y no se puede garantizar que coincida al 100% con las migraciones;
--    el `revoke` de abajo es lo que cierra la puerta aunque una policy se
--    llamara distinto.
drop policy if exists "intentos_nivel_insert_own" on public.intentos_nivel;
drop policy if exists "intentos_nivel_update_own" on public.intentos_nivel;
drop policy if exists "respuestas_desafio_insert_own" on public.respuestas_desafio;
drop policy if exists "progreso_usuario_nivel_insert_own" on public.progreso_usuario_nivel;
drop policy if exists "progreso_usuario_nivel_update_own" on public.progreso_usuario_nivel;
drop policy if exists "intento_desafios_insert_own" on public.intento_desafios;

revoke insert, update, delete, truncate on public.intentos_nivel from anon, authenticated;
revoke insert, update, delete, truncate on public.intento_desafios from anon, authenticated;
revoke insert, update, delete, truncate on public.respuestas_desafio from anon, authenticated;
revoke insert, update, delete, truncate on public.progreso_usuario_nivel from anon, authenticated;

-- 2a. iniciar_intento_parada: security definer
create or replace function iniciar_intento_parada(p_camino_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_activo boolean;
  v_orden integer;
  v_tematica_id uuid;
  v_dificultad dificultad;
  v_limite integer;
  v_segundos_por_desafio integer;
  v_objetivo_global text;
  v_pool_disponible integer;
  v_intento intentos_nivel;
  v_desafios jsonb;
  v_es_desbloqueo boolean;
  v_contador integer;
begin
  select c.activo, c.orden, c.tematica_id, c.dificultad,
         coalesce(c.preguntas_por_partida, dd.preguntas_por_partida),
         coalesce(c.segundos_por_desafio, dd.segundos_por_desafio),
         t.objetivo_global
  into v_activo, v_orden, v_tematica_id, v_dificultad, v_limite, v_segundos_por_desafio, v_objetivo_global
  from camino c
  join dificultad_defaults dd on dd.dificultad = c.dificultad
  join tematicas t on t.id = c.tematica_id
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

  -- Calculado ANTES de insertar el intento: si no, la propia fila que se va
  -- a crear contaria como "intento previo" en esta misma parada.
  v_es_desbloqueo := v_orden > 1 and not exists (
    select 1 from intentos_nivel
    where usuario_id = auth.uid() and camino_id = p_camino_id
  );

  insert into intentos_nivel (usuario_id, camino_id)
  values (auth.uid(), p_camino_id)
  returning * into v_intento;

  select intentos_desde_ultimo_anuncio_cadencia into v_contador
  from profiles where id = auth.uid();

  if v_es_desbloqueo then
    -- D4/D5: solape con cadencia o no, un unico video (el de desbloqueo) y
    -- el contador de cadencia queda intacto -- ese ciclo no se consume, se
    -- pospone al siguiente intento de este jugador.
    null;
  elsif coalesce(v_contador, 0) + 1 >= 3 then
    update profiles set intentos_desde_ultimo_anuncio_cadencia = 0 where id = auth.uid();
  else
    update profiles set intentos_desde_ultimo_anuncio_cadencia = coalesce(v_contador, 0) + 1 where id = auth.uid();
  end if;

  with sorteo as materialized (
    select d.id, d.tipo, d.nombre, d.imagen_url, d.video_url, d.texto_pregunta, d.activo,
           random() as azar
    from desafios_para_jugar d
    where d.tematica_id = v_tematica_id
      and d.dificultad = v_dificultad
      and d.activo
  ),
  seleccion as materialized (
    select id, tipo, nombre, imagen_url, video_url, texto_pregunta, activo,
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
           'nombre', s.nombre,
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
    'objetivo_global', v_objetivo_global,
    'desafios', v_desafios
  );
end;
$$;

-- 2b. cerrar_intento_parada: security definer + dueño del intento explicito
create or replace function cerrar_intento_parada(p_intento_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_camino_id uuid;
  v_dificultad dificultad;
  v_total_desafios integer;
  v_respondidos integer;
  v_puntaje integer;
  v_puntaje_maximo integer;
  v_puntaje_minimo integer;
  v_umbral_estrella_2 integer;
  v_umbral_estrella_3 integer;
  v_superado boolean;
  v_estrellas smallint;
  v_mejor_puntaje_anterior integer;
  v_estrellas_acumuladas_camino integer;
begin
  select ni.camino_id, c.dificultad
  into v_camino_id, v_dificultad
  from intentos_nivel ni
  join camino c on c.id = ni.camino_id
  where ni.id = p_intento_id
    and ni.usuario_id = auth.uid();

  if not found then
    raise exception 'El intento % no existe o no pertenece al usuario autenticado', p_intento_id;
  end if;

  select count(*) into v_total_desafios
  from intento_desafios
  where intento_id = p_intento_id;

  if v_total_desafios = 0 then
    raise exception 'El intento % no tiene desafios asignados en intento_desafios (parada sin desafios, intento creado sin pasar por iniciar_intento_parada, o anterior a esta migracion)', p_intento_id;
  end if;

  select maximo, minimo, umbral_estrella_2, umbral_estrella_3
  into v_puntaje_maximo, v_puntaje_minimo, v_umbral_estrella_2, v_umbral_estrella_3
  from umbrales_parada(v_dificultad, v_total_desafios);

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
    where estrellas_requeridas_por_orden(c.orden) <= v_estrellas_acumuladas_camino
    on conflict (usuario_id, camino_id) do update set
      desbloqueado = true,
      actualizado_en = now();
  end if;

  return jsonb_build_object(
    'puntaje_total', v_puntaje,
    'superado', v_superado,
    'estrellas_obtenidas', v_estrellas,
    'puntaje_minimo_superar', v_puntaje_minimo,
    'puntaje_maximo', v_puntaje_maximo,
    'mejor_puntaje_anterior', v_mejor_puntaje_anterior
  );
end;
$$;

-- 3a. responder_desafio: el desafio tiene que ser del intento y no estar respondido
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
  v_ciudad text;
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

  -- INT-137: el desafio tiene que ser de la seleccion persistida de ESTE
  -- intento, y se comprueba antes de leer nada de `desafios`. Un desafio
  -- inexistente y uno de otro intento fallan igual, para que la funcion no
  -- sirva de oraculo de ids ni de coordenadas.
  if not exists (
    select 1
    from intento_desafios
    where intento_id = p_intento_id
      and desafio_id = p_desafio_id
  ) then
    raise exception 'El desafio % no pertenece al intento %', p_desafio_id, p_intento_id;
  end if;

  if exists (
    select 1
    from respuestas_desafio
    where intento_id = p_intento_id
      and desafio_id = p_desafio_id
  ) then
    raise exception 'El desafio % ya tiene respuesta en el intento %', p_desafio_id, p_intento_id;
  end if;

  select lat_real, lng_real, nombre_lugar, ciudad
  into v_lat_real, v_lng_real, v_nombre_lugar, v_ciudad
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
    'ciudad', v_ciudad,
    'puntos_maximos', calcular_puntaje(0, 0, coalesce(v_segundos_por_desafio, 60)),
    'puntos_distancia', v_puntos_distancia,
    'puntos_bonus', v_puntos_bonus
  );
end;
$$;

-- 3b. trigger de calculo: misma regla, defensa en profundidad
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
  if not exists (
    select 1
    from intento_desafios
    where intento_id = new.intento_id
      and desafio_id = new.desafio_id
  ) then
    raise exception 'El desafio % no pertenece al intento %', new.desafio_id, new.intento_id;
  end if;

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

-- `create or replace` conserva los grants vigentes; se reafirman para que la
-- migracion sea autocontenida.
revoke execute on function iniciar_intento_parada(uuid) from public;
grant execute on function iniciar_intento_parada(uuid) to authenticated;
revoke execute on function cerrar_intento_parada(uuid) from public;
grant execute on function cerrar_intento_parada(uuid) to authenticated;
revoke execute on function responder_desafio(uuid, uuid, double precision, double precision) from public;
grant execute on function responder_desafio(uuid, uuid, double precision, double precision) to authenticated;
