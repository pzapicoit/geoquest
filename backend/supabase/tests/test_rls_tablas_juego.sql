-- Verificacion de INT-137: las tablas de juego no se escriben desde el cliente
-- y `responder_desafio` solo acepta desafios del propio intento.
--
-- Script autonomo sin pgTAP. Todo corre dentro de una transaccion que termina
-- en ROLLBACK: los usuarios de prueba, los intentos y las respuestas no
-- sobreviven. Aun asi escribe (y revierte) sobre la base contra la que se
-- ejecute, y el proyecto solo tiene un entorno: ejecutarlo DESPUES de aplicar
-- la migracion 20260930120000, y con el visto bueno de quien mantiene el
-- remoto. Antes de la migracion, este script falla a proposito: es lo que
-- demuestra la vulnerabilidad.
--
--   supabase db query --linked -f backend/supabase/tests/test_rls_tablas_juego.sql
--
-- Usa una parada real del camino (la de menor `orden` con pool suficiente), asi
-- que necesita contenido cargado (seed.sql). Un fallo aborta con
-- `raise exception`; si llega al final, imprime OK.
begin;

-- 0. Fixtures (como postgres): dos jugadores y una parada jugable.
do $$
declare
  v_u1 uuid := gen_random_uuid();
  v_u2 uuid := gen_random_uuid();
  v_camino uuid;
begin
  insert into auth.users (id, aud, role, email, created_at, updated_at)
  values
    (v_u1, 'authenticated', 'authenticated', 'rls-test-1-' || v_u1 || '@geoquest.invalid', now(), now()),
    (v_u2, 'authenticated', 'authenticated', 'rls-test-2-' || v_u2 || '@geoquest.invalid', now(), now());

  select c.id
  into v_camino
  from camino c
  join dificultad_defaults dd on dd.dificultad = c.dificultad
  where c.activo
    and (
      select count(*)
      from desafios_para_jugar d
      where d.tematica_id = c.tematica_id
        and d.dificultad = c.dificultad
        and d.activo
    ) >= coalesce(c.preguntas_por_partida, dd.preguntas_por_partida)
  order by c.orden
  limit 1;

  if v_camino is null then
    raise exception 'No hay ninguna parada activa con pool suficiente: cargar el contenido (seed.sql) antes del test';
  end if;

  perform set_config('test.u1', v_u1::text, true);
  perform set_config('test.u2', v_u2::text, true);
  perform set_config('test.camino', v_camino::text, true);
end $$;

-- 1. Jugador 1 inicia dos intentos (A y B) por las RPC, como lo hace la app.
do $$
declare
  v_u1 uuid := current_setting('test.u1')::uuid;
  v_a jsonb;
  v_b jsonb;
begin
  perform set_config('request.jwt.claims', json_build_object('sub', v_u1, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', v_u1::text, true);
  set local role authenticated;
  if auth.uid() is distinct from v_u1 then
    raise exception 'auth.uid() no coincide con el jugador simulado (%): el test no impersona bien', auth.uid();
  end if;

  v_a := iniciar_intento_parada(current_setting('test.camino')::uuid);
  v_b := iniciar_intento_parada(current_setting('test.camino')::uuid);

  if (v_a ->> 'intento_id') is null or jsonb_array_length(v_a -> 'desafios') = 0 then
    raise exception 'iniciar_intento_parada no devolvio intento ni desafios: %', v_a;
  end if;

  perform set_config('test.intento_a', v_a ->> 'intento_id', true);
  perform set_config('test.intento_b', v_b ->> 'intento_id', true);
  reset role;
end $$;

-- 2. Escrituras directas rechazadas por privilegio (42501) en las cuatro tablas.
do $$
declare
  v_u1 uuid := current_setting('test.u1')::uuid;
  v_camino uuid := current_setting('test.camino')::uuid;
  v_a uuid := current_setting('test.intento_a')::uuid;
  v_desafio uuid;
  v_sentencias text[];
  v_sql text;
  v_fallo boolean;
begin
  select desafio_id into v_desafio from intento_desafios where intento_id = v_a order by orden limit 1;

  v_sentencias := array[
    format('update progreso_usuario_nivel set mejor_puntaje = 99999999, superado = true, mejores_estrellas = 3, desbloqueado = true where usuario_id = %L', v_u1),
    format('insert into progreso_usuario_nivel (usuario_id, camino_id, mejor_puntaje, desbloqueado) values (%L, %L, 99999999, true)', v_u1, v_camino),
    format('update intentos_nivel set puntaje_total = 99999999, estrellas_obtenidas = 3 where id = %L', v_a),
    format('update intentos_nivel set comodin_usado = null where id = %L', v_a),
    format('insert into intentos_nivel (usuario_id, camino_id) values (%L, %L)', v_u1, v_camino),
    format('insert into respuestas_desafio (intento_id, desafio_id, lat_adivinada, lng_adivinada) values (%L, %L, 0, 0)', v_a, v_desafio),
    format('delete from respuestas_desafio where intento_id = %L', v_a),
    format('insert into intento_desafios (intento_id, desafio_id, orden) values (%L, %L, 99)', v_a, v_desafio),
    format('update intento_desafios set mostrado_en = now() where intento_id = %L', v_a),
    format('delete from intento_desafios where intento_id = %L', v_a)
  ];

  perform set_config('request.jwt.claims', json_build_object('sub', v_u1, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', v_u1::text, true);
  set local role authenticated;
  if auth.uid() is distinct from v_u1 then
    raise exception 'auth.uid() no coincide con el jugador simulado (%): el test no impersona bien', auth.uid();
  end if;

  foreach v_sql in array v_sentencias loop
    v_fallo := false;
    begin
      execute v_sql;
    exception
      when insufficient_privilege then
        v_fallo := true;
    end;
    if not v_fallo then
      raise exception 'La escritura directa NO fue rechazada por privilegio: %', v_sql;
    end if;
  end loop;

  reset role;
end $$;

-- 3. `responder_desafio` con un desafio que no es del intento: rechazado, sin
--    fila y sin revelar nada. Un id inexistente falla con el mismo mensaje.
do $$
declare
  v_u1 uuid := current_setting('test.u1')::uuid;
  v_a uuid := current_setting('test.intento_a')::uuid;
  v_ajeno uuid;
  v_msg_ajeno text;
  v_msg_inexistente text;
  v_respuesta jsonb;
begin
  -- Un desafio que NO esta en la seleccion de A (hay mas en el banco que por partida).
  select d.id
  into v_ajeno
  from desafios d
  where d.id not in (select desafio_id from intento_desafios where intento_id = v_a)
  limit 1;

  if v_ajeno is null then
    raise exception 'No hay ningun desafio fuera de la seleccion del intento A para probar el ataque';
  end if;

  perform set_config('request.jwt.claims', json_build_object('sub', v_u1, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', v_u1::text, true);
  set local role authenticated;
  if auth.uid() is distinct from v_u1 then
    raise exception 'auth.uid() no coincide con el jugador simulado (%): el test no impersona bien', auth.uid();
  end if;

  begin
    v_respuesta := responder_desafio(v_a, v_ajeno, 0, 0);
    raise exception 'DEBIO_FALLAR: responder_desafio acepto un desafio ajeno al intento y devolvio %', v_respuesta;
  exception
    when sqlstate 'P0001' then
      if sqlerrm like 'DEBIO_FALLAR%' then raise; end if;
      v_msg_ajeno := sqlerrm;
  end;

  begin
    v_respuesta := responder_desafio(v_a, gen_random_uuid(), 0, 0);
    raise exception 'DEBIO_FALLAR: responder_desafio acepto un desafio inexistente';
  exception
    when sqlstate 'P0001' then
      if sqlerrm like 'DEBIO_FALLAR%' then raise; end if;
      v_msg_inexistente := sqlerrm;
  end;

  reset role;

  if v_msg_ajeno not like 'El desafio % no pertenece al intento %' then
    raise exception 'Mensaje inesperado para un desafio ajeno: %', v_msg_ajeno;
  end if;
  if regexp_replace(v_msg_ajeno, '[0-9a-f-]{36}', '<id>', 'g')
     <> regexp_replace(v_msg_inexistente, '[0-9a-f-]{36}', '<id>', 'g') then
    raise exception 'Desafio ajeno e inexistente deberian fallar igual: "%" vs "%"', v_msg_ajeno, v_msg_inexistente;
  end if;

  if exists (select 1 from respuestas_desafio where intento_id = v_a and desafio_id = v_ajeno) then
    raise exception 'Se registro una respuesta para un desafio ajeno al intento';
  end if;
end $$;

-- 4. Otro jugador no puede ver ni tocar el intento de jugador 1.
do $$
declare
  v_u2 uuid := current_setting('test.u2')::uuid;
  v_a uuid := current_setting('test.intento_a')::uuid;
  v_desafio uuid;
  v_visibles integer;
  v_msg_responder text;
  v_msg_cerrar text;
begin
  select desafio_id into v_desafio from intento_desafios where intento_id = v_a order by orden limit 1;

  perform set_config('request.jwt.claims', json_build_object('sub', v_u2, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', v_u2::text, true);
  set local role authenticated;
  if auth.uid() is distinct from v_u2 then
    raise exception 'auth.uid() no coincide con el jugador simulado (%): el test no impersona bien', auth.uid();
  end if;

  select count(*) into v_visibles from intentos_nivel where id = v_a;
  if v_visibles <> 0 then
    raise exception 'El jugador 2 ve el intento del jugador 1';
  end if;

  begin
    perform responder_desafio(v_a, v_desafio, 0, 0);
    raise exception 'DEBIO_FALLAR: responder_desafio acepto un intento ajeno';
  exception
    when sqlstate 'P0001' then
      if sqlerrm like 'DEBIO_FALLAR%' then raise; end if;
      v_msg_responder := sqlerrm;
  end;

  begin
    perform cerrar_intento_parada(v_a);
    raise exception 'DEBIO_FALLAR: cerrar_intento_parada acepto un intento ajeno';
  exception
    when sqlstate 'P0001' then
      if sqlerrm like 'DEBIO_FALLAR%' then raise; end if;
      v_msg_cerrar := sqlerrm;
  end;

  reset role;

  -- Tiene que fallar por DUEÑO, no por otra razon (p. ej. intento incompleto).
  if v_msg_responder not like '%no pertenece al usuario autenticado%' then
    raise exception 'responder_desafio sobre intento ajeno fallo por otra razon: %', v_msg_responder;
  end if;
  if v_msg_cerrar not like '%no pertenece al usuario autenticado%' then
    raise exception 'cerrar_intento_parada sobre intento ajeno fallo por otra razon: %', v_msg_cerrar;
  end if;

  if exists (select 1 from respuestas_desafio where intento_id = v_a) then
    raise exception 'El jugador 2 logro registrar una respuesta en el intento del jugador 1';
  end if;
  if exists (select 1 from progreso_usuario_nivel where usuario_id = v_u2) then
    raise exception 'El jugador 2 acabo con progreso por tocar el intento del jugador 1';
  end if;
end $$;

-- 5. Flujo legitimo completo por RPC como jugador 1: sigue funcionando.
do $$
declare
  v_u1 uuid := current_setting('test.u1')::uuid;
  v_a uuid := current_setting('test.intento_a')::uuid;
  v_desafio uuid;
  v_respuesta jsonb;
  v_cierre jsonb;
  v_contestadas integer := 0;
  v_fallo boolean;
begin
  perform set_config('request.jwt.claims', json_build_object('sub', v_u1, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', v_u1::text, true);
  set local role authenticated;
  if auth.uid() is distinct from v_u1 then
    raise exception 'auth.uid() no coincide con el jugador simulado (%): el test no impersona bien', auth.uid();
  end if;

  for v_desafio in
    select desafio_id from intento_desafios where intento_id = v_a order by orden
  loop
    perform marcar_desafio_mostrado(v_a, v_desafio);
    v_respuesta := responder_desafio(v_a, v_desafio, 0, 0);
    if not (v_respuesta ? 'lat_real' and v_respuesta ? 'lng_real' and v_respuesta ? 'ciudad') then
      raise exception 'La respuesta legitima no incluye el revelado: %', v_respuesta;
    end if;
    v_contestadas := v_contestadas + 1;

    -- Responder dos veces el mismo desafio: rechazado.
    if v_contestadas = 1 then
      v_fallo := false;
      begin
        perform responder_desafio(v_a, v_desafio, 0, 0);
      exception
        when sqlstate 'P0001' then
          v_fallo := true;
      end;
      if not v_fallo then
        raise exception 'Se acepto una segunda respuesta al mismo desafio';
      end if;
    end if;
  end loop;

  v_cierre := cerrar_intento_parada(v_a);
  if (v_cierre ->> 'puntaje_total') is null or (v_cierre ->> 'estrellas_obtenidas') is null then
    raise exception 'cerrar_intento_parada no devolvio puntaje ni estrellas: %', v_cierre;
  end if;

  -- Lo escrito por las RPC es legible por su dueño (solo select).
  if not exists (select 1 from progreso_usuario_nivel where usuario_id = v_u1) then
    raise exception 'El cierre no dejo fila de progreso legible para el jugador';
  end if;
  if (select puntaje_total from intentos_nivel where id = v_a) <> (v_cierre ->> 'puntaje_total')::integer then
    raise exception 'El cierre no dejo el puntaje en el intento: %', v_cierre;
  end if;

  reset role;
end $$;

rollback;

do $$ begin raise notice 'test_rls_tablas_juego: OK'; end $$;
