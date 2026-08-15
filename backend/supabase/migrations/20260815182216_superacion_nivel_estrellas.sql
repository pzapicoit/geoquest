-- INT-79: logica de superacion de nivel, estrellas y desbloqueos. Ver
-- design.md de openspec/changes/int-79-superacion-nivel-estrellas para el
-- porque de cada decision referenciada como D1-D6 en los comentarios.

-- 1.2 RPC que cierra un intento de nivel (D3: security invoker -- a
-- diferencia de responder_desafio (INT-78), aqui no se lee nada que la
-- RLS de INT-77 esconda del propio usuario: tematicas/niveles/
-- nivel_desafios son de lectura publica para autenticados, y las filas de
-- intentos_nivel/respuestas_desafio/progreso_usuario_nivel que se tocan
-- son siempre las del propio auth.uid(), ya garantizado por esa misma RLS
-- al leer/escribir).
create function cerrar_intento_nivel(p_intento_id uuid)
returns intentos_nivel
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_nivel_id uuid;
  v_tematica_id uuid;
  v_puntaje_minimo integer;
  v_umbral_estrella_2 integer;
  v_umbral_estrella_3 integer;
  v_nivel_orden integer;
  v_total_desafios integer;
  v_respondidos integer;
  v_puntaje integer;
  v_superado boolean;
  v_estrellas smallint;
  v_siguiente_nivel_id uuid;
  v_tematica_orden integer;
  v_siguiente_tematica_id uuid;
  v_estrellas_requeridas integer;
  v_estrellas_acumuladas integer;
  v_primer_nivel_siguiente_tematica uuid;
  v_intento intentos_nivel;
begin
  select ni.nivel_id, n.tematica_id, n.puntaje_minimo_superar,
         n.umbral_estrella_2, n.umbral_estrella_3,
         n.orden, t.orden
  into v_nivel_id, v_tematica_id, v_puntaje_minimo,
       v_umbral_estrella_2, v_umbral_estrella_3,
       v_nivel_orden, v_tematica_orden
  from intentos_nivel ni
  join niveles n on n.id = ni.nivel_id
  join tematicas t on t.id = n.tematica_id
  where ni.id = p_intento_id;

  if not found then
    raise exception 'El intento % no existe o no pertenece al usuario autenticado', p_intento_id;
  end if;

  -- 1.3 / D1: el puntaje se agrega solo sobre desafios asignados al nivel
  -- via nivel_desafios, nunca sobre todas las respuestas_desafio del
  -- intento a ciegas -- responder_desafio (INT-78) no ata el desafio_id
  -- recibido al nivel del intento, asi que una respuesta a un desafio
  -- ajeno al nivel no debe poder inflar este calculo.
  select count(*) into v_total_desafios
  from nivel_desafios
  where nivel_id = v_nivel_id;

  select count(distinct rd.desafio_id), coalesce(sum(rd.puntos), 0)
  into v_respondidos, v_puntaje
  from respuestas_desafio rd
  join nivel_desafios nd
    on nd.desafio_id = rd.desafio_id
   and nd.nivel_id = v_nivel_id
  where rd.intento_id = p_intento_id;

  -- 1.4 / D2: el cierre exige una respuesta por cada desafio del nivel.
  if v_respondidos < v_total_desafios then
    raise exception 'El intento % no tiene respuesta para todos los desafios del nivel (% de %)',
      p_intento_id, v_respondidos, v_total_desafios;
  end if;

  -- 1.5 / D4: superado garantiza minimo 1 estrella, aunque el puntaje
  -- quede por debajo de umbral_estrella_1 (el CHECK de INT-74 solo exige
  -- puntaje_minimo_superar <= umbral_estrella_1, no igualdad). Por eso
  -- umbral_estrella_1 no se lee aqui: el "else 1" ya cubre tanto ese
  -- rango como el de encima de umbral_estrella_1, que tampoco necesita
  -- distinguirse de el.
  v_superado := v_puntaje >= v_puntaje_minimo;

  v_estrellas := case
    when not v_superado then 0
    when v_puntaje >= v_umbral_estrella_3 then 3
    when v_puntaje >= v_umbral_estrella_2 then 2
    else 1
  end;

  -- 1.6
  update intentos_nivel
  set puntaje_total = v_puntaje,
      superado = v_superado,
      estrellas_obtenidas = v_estrellas
  where id = p_intento_id
  returning * into v_intento;

  -- 2.1 / D5: upsert monotono -- mejor_puntaje/mejores_estrellas nunca
  -- bajan, superado y desbloqueado nunca vuelven a false. Hace la funcion
  -- idempotente ante una segunda llamada sobre el mismo intento.
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
    -- 2.2 Desbloqueo del siguiente nivel de la misma tematica, si existe.
    select id into v_siguiente_nivel_id
    from niveles
    where tematica_id = v_tematica_id
      and orden = v_nivel_orden + 1;

    if found then
      insert into progreso_usuario_nivel (usuario_id, nivel_id, desbloqueado)
      values (auth.uid(), v_siguiente_nivel_id, true)
      on conflict (usuario_id, nivel_id) do update set
        desbloqueado = true,
        actualizado_en = now();
    end if;

    -- 2.3 / D6: desbloqueo de la siguiente tematica = desbloqueo de su
    -- primer nivel (orden = 1), comparando estrellas acumuladas solo
    -- dentro de la tematica actual (lectura literal del issue: "estrellas
    -- requeridas acumuladas en la tematica").
    select coalesce(sum(pun.mejores_estrellas), 0) into v_estrellas_acumuladas
    from progreso_usuario_nivel pun
    join niveles n on n.id = pun.nivel_id
    where pun.usuario_id = auth.uid()
      and n.tematica_id = v_tematica_id;

    select id, estrellas_requeridas into v_siguiente_tematica_id, v_estrellas_requeridas
    from tematicas
    where orden = v_tematica_orden + 1;

    if found and v_estrellas_acumuladas >= v_estrellas_requeridas then
      select id into v_primer_nivel_siguiente_tematica
      from niveles
      where tematica_id = v_siguiente_tematica_id
        and orden = 1;

      if found then
        insert into progreso_usuario_nivel (usuario_id, nivel_id, desbloqueado)
        values (auth.uid(), v_primer_nivel_siguiente_tematica, true)
        on conflict (usuario_id, nivel_id) do update set
          desbloqueado = true,
          actualizado_en = now();
      end if;
    end if;
  end if;

  return v_intento;
end;
$$;

-- 1.7 Solo authenticated (incluye sesiones anonimas de INT-75) puede
-- llamar la RPC; se revoca de public porque Postgres concede execute a
-- public por defecto en funciones nuevas.
revoke execute on function cerrar_intento_nivel(uuid) from public;
grant execute on function cerrar_intento_nivel(uuid) to authenticated;
