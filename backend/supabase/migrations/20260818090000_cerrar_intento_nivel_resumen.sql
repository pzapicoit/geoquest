-- INT-94: la pantalla de resumen del nivel necesita, ademas del resultado
-- del propio cierre, el minimo del nivel (para "cuanto falto") y el mejor
-- puntaje que tenia el jugador en ese nivel ANTES de este cierre (para
-- detectar "nuevo record personal"). Ninguno de los dos viajaba a ningun
-- sitio, y el segundo no se puede leer despues del cierre porque la propia
-- funcion lo sobrescribe con greatest(...). Ver design.md de
-- openspec/changes/int-94-resumen-nivel (D1/D2).
--
-- El tipo de retorno cambia de la fila cruda de intentos_nivel a jsonb, asi
-- que hace falta drop + create (Postgres no permite create or replace con
-- tipo de retorno distinto) y volver a conceder los privilegios que el drop
-- se lleva por delante.
drop function cerrar_intento_nivel(uuid);

create function cerrar_intento_nivel(p_intento_id uuid)
returns jsonb
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
  v_mejor_puntaje_anterior integer;
  v_estrellas_acumuladas_camino integer;
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

  -- D4 de INT-100: un intento sin fila en intento_desafios no puede
  -- cerrarse -- si no, "0 de 0" se leeria como completo.
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

  -- D2 de INT-94: se lee el mejor puntaje ANTES del upsert de mas abajo,
  -- que es el que lo sobrescribe con greatest(...). Sin fila previa queda
  -- NULL -- no 0 -- para que el resumen no anuncie "record" en el primer
  -- despeje del nivel, que no tiene ningun resultado anterior que mejorar.
  select mejor_puntaje into v_mejor_puntaje_anterior
  from progreso_usuario_nivel
  where usuario_id = auth.uid() and nivel_id = v_nivel_id;

  update intentos_nivel
  set puntaje_total = v_puntaje,
      superado = v_superado,
      estrellas_obtenidas = v_estrellas
  where id = p_intento_id;

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

  return jsonb_build_object(
    'puntaje_total', v_puntaje,
    'superado', v_superado,
    'estrellas_obtenidas', v_estrellas,
    'puntaje_minimo_superar', v_puntaje_minimo,
    'mejor_puntaje_anterior', v_mejor_puntaje_anterior
  );
end;
$$;

revoke execute on function cerrar_intento_nivel(uuid) from public;
grant execute on function cerrar_intento_nivel(uuid) to authenticated;
