-- INT-99: temporizador por desafio -- cuenta atras configurable por nivel,
-- bonus de puntuacion por rapidez y comportamiento al agotar el tiempo sin
-- pin colocado. Ver design.md de openspec/changes/int-99-temporizador-desafio
-- para el porque de cada decision referenciada como D1-D14 en los
-- comentarios.

-- 1.1 niveles.segundos_por_desafio: limite de tiempo por desafio,
-- configurable por nivel desde el panel. Default 60s para los niveles ya
-- existentes.
alter table niveles
  add column segundos_por_desafio integer not null default 60
    check (segundos_por_desafio > 0);

-- 1.2 (D1/D2): momento en que el servidor marco ese desafio como el actual
-- del intento. NULL hasta que marcar_desafio_mostrado lo fija; tambien
-- queda NULL para intentos anteriores a esta migracion o si la app nunca
-- llego a llamarla.
alter table intento_desafios
  add column mostrado_en timestamptz;

-- 1.3 (D6): tiempo consumido en el desafio, siempre recalculado por el
-- servidor (ver trigger mas abajo), nunca por lo que reciba el insert.
-- Default 0 solo para el backfill de filas historicas -- el trigger ignora
-- el valor recibido en cualquier insert nuevo.
alter table respuestas_desafio
  add column segundos_transcurridos integer not null default 0
    check (segundos_transcurridos >= 0);

-- 1.4/1.5 (D7): lat_adivinada/lng_adivinada/distancia_km pasan a nullable
-- para el caso de tiempo agotado sin pin colocado. Los checks existentes
-- (`between -90 and 90`, `distancia_km >= 0`) no hace falta reescribirlos:
-- en SQL, un CHECK sobre una columna NULL se evalua a NULL y una fila con
-- un CHECK que da NULL se acepta igual que si diera TRUE -- basta con
-- quitar el NOT NULL.
alter table respuestas_desafio alter column lat_adivinada drop not null;
alter table respuestas_desafio alter column lng_adivinada drop not null;
alter table respuestas_desafio alter column distancia_km drop not null;

-- 1.6 (D7): las dos coordenadas son NULL a la vez o ninguna -- nunca solo
-- una. responder_desafio ya rechaza esa combinacion antes de llegar aqui;
-- este check es la misma garantia de "ninguna via de insert puede saltarse
-- la regla" que ya rige distancia_km/puntos (INT-78).
alter table respuestas_desafio
  add constraint respuestas_desafio_pin_completo_check
  check ((lat_adivinada is null) = (lng_adivinada is null));

-- 2.1 (D5): la curva pura de distancia se aisla en su propia funcion, sin
-- cambiar su cuerpo (INT-101), para que calcular_puntaje pueda reutilizarla
-- al combinarla con el bonus por tiempo.
create function calcular_puntaje_por_distancia(distancia_km double precision)
returns integer
language plpgsql
immutable
security invoker
as $$
declare
  v_max constant double precision := 5000;
  v_piso constant double precision := 50;
  v_k constant double precision := 1500;
begin
  return round(
    v_piso + (v_max - v_piso) * exp(-distancia_km / v_k)
  )::integer;
end;
$$;

-- 2.2 (D5): calcular_puntaje(distancia_km) desaparece -- su unico cuerpo
-- vive ahora en calcular_puntaje_por_distancia; el nombre calcular_puntaje
-- pasa a la version con bonus de tiempo (mas abajo). Solo dos sitios la
-- llamaban (el trigger y responder_desafio) y ambos se actualizan en esta
-- misma migracion.
drop function calcular_puntaje(double precision);

-- 2.3 (D4): calcular_puntaje ahora combina el componente de distancia con
-- un bonus por rapidez, acotado a BONUS_MAX y escalado tanto por tiempo
-- restante como por precision -- para que una respuesta rapida pero muy
-- errada no se beneficie, y para que el suelo de precision (PISO) nunca
-- suba de 50 por responder rapido.
create function calcular_puntaje(
  distancia_km double precision,
  segundos_transcurridos integer,
  segundos_por_desafio integer
)
returns integer
language plpgsql
immutable
security invoker
as $$
declare
  v_piso constant double precision := 50;
  v_max constant double precision := 5000;
  v_bonus_max constant double precision := 500;
  v_puntos_distancia integer;
  v_fraccion_acierto double precision;
  v_fraccion_tiempo double precision;
  v_bonus integer;
begin
  v_puntos_distancia := calcular_puntaje_por_distancia(distancia_km);
  v_fraccion_acierto := (v_puntos_distancia - v_piso) / (v_max - v_piso);
  v_fraccion_tiempo := least(1, greatest(0,
    (segundos_por_desafio - segundos_transcurridos)::double precision
      / segundos_por_desafio
  ));
  v_bonus := round(v_bonus_max * v_fraccion_tiempo * v_fraccion_acierto)::integer;

  return v_puntos_distancia + v_bonus;
end;
$$;

-- 2.4 (D6/D7): el trigger calcula segundos_transcurridos a partir de
-- intento_desafios.mostrado_en -- nunca de lo que diga el insert -- y, si
-- hay coordenadas, el puntaje con bonus; si no hay pin, distancia_km queda
-- NULL y puntos = 0 sin llamar a la curva de distancia. mostrado_en
-- ausente (fila sin marcar, o intento anterior a esta migracion) se trata
-- como tiempo agotado, no como error: una app vieja que nunca llame a
-- marcar_desafio_mostrado sigue pudiendo jugar, solo sin bonus.
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

  select n.segundos_por_desafio
  into v_segundos_por_desafio
  from intentos_nivel it
  join niveles n on n.id = it.nivel_id
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

-- 3.1 (D7): responder_desafio acepta coordenadas ausentes -- rechaza la
-- llamada si llega solo una de las dos, antes de tocar ninguna tabla. Solo
-- cambian los defaults de los parametros, no su lista de tipos ni el tipo
-- de retorno, asi que basta con `create or replace` (sin drop): a
-- diferencia del cambio de firma de INT-93, aqui la identidad de la
-- funcion no cambia y los grants ya concedidos se conservan.
-- 3.2/3.2b: puntos_maximos ahora refleja el maximo real con bonus
-- (distancia 0, tiempo 0), y la respuesta añade puntos_distancia/
-- puntos_bonus (D14) derivados de valores que el trigger ya calculo, sin
-- ninguna columna nueva.
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

  select n.segundos_por_desafio
  into v_segundos_por_desafio
  from intentos_nivel it
  join niveles n on n.id = it.nivel_id
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

-- 3.3 (D2/D3): marcar_desafio_mostrado estampa mostrado_en la primera vez
-- que un desafio se vuelve el actual del intento. security definer porque
-- intento_desafios no admite update por RLS (INT-100); valida a mano la
-- pertenencia del intento, igual que responder_desafio, y el
-- `mostrado_en is null` en el where hace que una segunda llamada sea un
-- no-op -- reabrir la pista de un desafio ya mostrado no reinicia su
-- cronometro.
create function marcar_desafio_mostrado(p_intento_id uuid, p_desafio_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (
    select 1
    from intentos_nivel
    where id = p_intento_id
      and usuario_id = auth.uid()
  ) then
    raise exception 'El intento % no pertenece al usuario autenticado', p_intento_id;
  end if;

  update intento_desafios
  set mostrado_en = now()
  where intento_id = p_intento_id
    and desafio_id = p_desafio_id
    and mostrado_en is null;
end;
$$;

revoke execute on function marcar_desafio_mostrado(uuid, uuid) from public;
grant execute on function marcar_desafio_mostrado(uuid, uuid) to authenticated;

-- 3.6 (no estaba en tasks.md original -- hace falta para que la app tenga
-- de donde leer el dato del punto 6.3): iniciar_intento_nivel expone
-- segundos_por_desafio en su respuesta, para que la app sepa cuanto dura
-- la cuenta atras nada mas arrancar la partida, sin una segunda consulta a
-- niveles.
create or replace function iniciar_intento_nivel(p_nivel_id uuid)
returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_activo boolean;
  v_limite integer;
  v_segundos_por_desafio integer;
  v_intento intentos_nivel;
  v_desafios jsonb;
begin
  select activo, preguntas_por_partida, segundos_por_desafio
  into v_activo, v_limite, v_segundos_por_desafio
  from niveles
  where id = p_nivel_id;

  if not found or not v_activo then
    raise exception 'El nivel % no existe o no esta activo', p_nivel_id;
  end if;

  insert into intentos_nivel (usuario_id, nivel_id)
  values (auth.uid(), p_nivel_id)
  returning * into v_intento;

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
    'segundos_por_desafio', v_segundos_por_desafio,
    'desafios', v_desafios
  );
end;
$$;

-- 4.1 (D9): rebalanceo x1.1 de los niveles ya existentes, para conservar el
-- mismo porcentaje del maximo por desafio que tenian antes de que el bonus
-- de tiempo subiera ese maximo de 5000 a 5500. round() es monotona
-- (x <= y implica round(x) <= round(y)), asi que escalar los cuatro campos
-- por el mismo factor 1.1 nunca puede invertir su orden relativo -- los
-- checks de orden ascendente ya definidos en la tabla (INT-74) abortarian
-- esta migracion entera si lo hiciera, pero es matematicamente imposible
-- con un factor > 1 aplicado por igual a los cuatro campos.
update niveles
set puntaje_minimo_superar = round(puntaje_minimo_superar * 1.1)::integer,
    umbral_estrella_1 = round(umbral_estrella_1 * 1.1)::integer,
    umbral_estrella_2 = round(umbral_estrella_2 * 1.1)::integer,
    umbral_estrella_3 = round(umbral_estrella_3 * 1.1)::integer;
