-- INT-78: calculo de distancia y puntaje al responder un desafio. Ver
-- design.md de openspec/changes/int-78-calcular-distancia-puntaje para el
-- porque de cada decision referenciada como D1-D4 en los comentarios.

-- 1.2 Distancia en km entre dos coordenadas (D1: Haversine, sin PostGIS).
create function calcular_distancia_km(
  lat1 double precision,
  lng1 double precision,
  lat2 double precision,
  lng2 double precision
)
returns double precision
language sql
immutable
security invoker
as $$
  select 2 * 6371 * asin(
    sqrt(
      power(sin(radians(lat2 - lat1) / 2), 2)
      + cos(radians(lat1)) * cos(radians(lat2))
        * power(sin(radians(lng2 - lng1) / 2), 2)
    )
  );
$$;

-- 1.3 Puntaje a partir de la distancia (D2: decaimiento lineal con umbral,
-- no exponencial -- el issue pide un cero exacto, no una asintota).
-- Constantes de partida sin validar con playtesting, aisladas aqui para
-- ajustarse sin tocar responder_desafio ni el trigger de mas abajo.
create function calcular_puntaje(distancia_km double precision)
returns integer
language sql
immutable
security invoker
as $$
  select greatest(
    0,
    round(
      5000 * (1 - distancia_km / 2000.0)
    )
  )::integer;
$$;

-- 2.1 RPC que registra la respuesta de un jugador a un desafio (D3: una
-- unica funcion security definer en vez de RPC invoker + helper separado).
-- security definer porque necesita leer desafios.lat_real/lng_real, que
-- RLS (INT-77) esconde de los jugadores; por eso valida a mano la
-- pertenencia del intento en vez de apoyarse en la policy de insert de
-- respuestas_desafio, que aqui no se ejecuta.
create function responder_desafio(
  p_intento_id uuid,
  p_desafio_id uuid,
  p_lat_adivinada double precision,
  p_lng_adivinada double precision
)
returns respuestas_desafio
language plpgsql
security definer
set search_path = public
as $$
declare
  v_lat_real double precision;
  v_lng_real double precision;
  v_distancia_km double precision;
  v_respuesta respuestas_desafio;
begin
  if not exists (
    select 1
    from intentos_nivel
    where id = p_intento_id
      and usuario_id = auth.uid()
  ) then
    raise exception 'El intento % no pertenece al usuario autenticado', p_intento_id;
  end if;

  select lat_real, lng_real
  into v_lat_real, v_lng_real
  from desafios
  where id = p_desafio_id;

  if not found then
    raise exception 'El desafio % no existe', p_desafio_id;
  end if;

  v_distancia_km := calcular_distancia_km(v_lat_real, v_lng_real, p_lat_adivinada, p_lng_adivinada);

  insert into respuestas_desafio (
    intento_id, desafio_id, lat_adivinada, lng_adivinada, distancia_km, puntos
  )
  values (
    p_intento_id,
    p_desafio_id,
    p_lat_adivinada,
    p_lng_adivinada,
    v_distancia_km,
    calcular_puntaje(v_distancia_km)
  )
  returning * into v_respuesta;

  return v_respuesta;
end;
$$;

-- 2.2 Solo authenticated (incluye sesiones anonimas de INT-75) puede
-- llamar la RPC; se revoca de public porque Postgres concede execute a
-- public por defecto en funciones nuevas.
revoke execute on function responder_desafio(uuid, uuid, double precision, double precision) from public;
grant execute on function responder_desafio(uuid, uuid, double precision, double precision) to authenticated;

-- 2.3 / 2.4 Trigger que recalcula distancia_km/puntos en cualquier insert
-- sobre respuestas_desafio, ignorando lo que llegue en esas columnas (D4:
-- la RLS de INT-77 sigue permitiendo un insert directo sin pasar por la
-- RPC, y esta es la garantia de que el dato guardado es siempre el
-- calculo del servidor). security definer por el mismo motivo que 2.1:
-- lee desafios.lat_real/lng_real, que el jugador no puede leer por RLS.
create function respuestas_desafio_calcular_antes_de_insertar()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_lat_real double precision;
  v_lng_real double precision;
  v_distancia_km double precision;
begin
  select lat_real, lng_real
  into v_lat_real, v_lng_real
  from desafios
  where id = new.desafio_id;

  if not found then
    raise exception 'El desafio % no existe', new.desafio_id;
  end if;

  v_distancia_km := calcular_distancia_km(v_lat_real, v_lng_real, new.lat_adivinada, new.lng_adivinada);

  new.distancia_km := v_distancia_km;
  new.puntos := calcular_puntaje(v_distancia_km);

  return new;
end;
$$;

create trigger respuestas_desafio_antes_de_insertar
before insert on respuestas_desafio
for each row
execute function respuestas_desafio_calcular_antes_de_insertar();
