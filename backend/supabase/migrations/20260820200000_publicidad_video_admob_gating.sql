-- INT-117: publicidad en video (AdMob Rewarded Interstitial) -- anuncio de
-- desbloqueo la primera vez que se juega una parada de orden > 1, y anuncio
-- de cadencia cada 3 intentos jugados (contador de por vida). Ver design.md
-- de openspec/changes/int-117-publicidad-video-admob (D1-D7) para el porque
-- de cada decision referenciada en los comentarios.

-- 1. Catalogo cerrado del tipo de anuncio pendiente (D2).
create type tipo_anuncio_pendiente as enum ('ninguno', 'desbloqueo', 'cadencia');

-- 2. Contador persistente de intentos desde el ultimo anuncio de cadencia
-- (D1): un unico contador por jugador cabe en una columna de profiles, a
-- diferencia del inventario de comodines (4 tipos, INT-119) que si pidio
-- tabla aparte. Ya cubierta por la policy profiles_update_own existente
-- (INT-77, no toca `role`), asi que no hace falta ninguna policy nueva.
alter table profiles add column intentos_desde_ultimo_anuncio_cadencia integer not null default 0;

-- 3. RPC de solo lectura: que anuncio (si alguno) toca antes de arrancar un
-- intento, sin mutar nada (D3) -- la app la consulta antes de navegar a la
-- pantalla de juego, para poder mostrar el video ANTES de iniciar_intento_parada.
-- security invoker: las policies ya vigentes de intentos_nivel/profiles/camino
-- bastan.
create function anuncio_debido(p_camino_id uuid)
returns tipo_anuncio_pendiente
language plpgsql
security invoker
set search_path = public
stable
as $$
declare
  v_orden integer;
  v_es_desbloqueo boolean;
  v_contador integer;
begin
  select orden into v_orden from camino where id = p_camino_id;

  if not found then
    raise exception 'La parada % no existe', p_camino_id;
  end if;

  -- D-video-ads "Anuncio de desbloqueo": la parada de orden 1 nunca lo pide;
  -- el resto, solo si el usuario no tiene ya un intento previo en ella --
  -- derivado, sin flag nuevo.
  v_es_desbloqueo := v_orden > 1 and not exists (
    select 1 from intentos_nivel
    where usuario_id = auth.uid() and camino_id = p_camino_id
  );

  -- D5: prioridad fija -- desbloqueo gana sobre cadencia, un unico video.
  if v_es_desbloqueo then
    return 'desbloqueo';
  end if;

  select intentos_desde_ultimo_anuncio_cadencia into v_contador
  from profiles where id = auth.uid();

  if coalesce(v_contador, 0) + 1 >= 3 then
    return 'cadencia';
  end if;

  return 'ninguno';
end;
$$;

revoke execute on function anuncio_debido(uuid) from public;
grant execute on function anuncio_debido(uuid) to authenticated;

-- 4. iniciar_intento_parada recalcula la misma logica dentro de su propia
-- transaccion (D4): no hay parametro "ya vi el anuncio" que el cliente
-- pueda reportar -- la mutacion del contador depende solo de estado ya
-- persistido, en la misma transaccion que crea el intento. Firma y forma de
-- la respuesta sin cambios.
create or replace function iniciar_intento_parada(p_camino_id uuid)
returns jsonb
language plpgsql
security invoker
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
