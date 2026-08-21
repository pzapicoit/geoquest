-- INT-124: los comodines de radio devolvian la coordenada real del objetivo
-- como centro del circulo, asi que clavar el pin en el centro daba distancia
-- ~0: el comodin no acotaba la zona, resolvia el desafio (y con ello rompia
-- el balance de puntuacion y el ranking, porque el bonus por rapidez se
-- multiplicaba sobre una precision perfecta).
--
-- Ahora el centro se desplaza al azar respecto del objetivo dentro de la
-- corona [0.35*R, 0.9*R]: el objetivo queda siempre DENTRO del circulo y
-- nunca cerca del centro. El contrato del RPC no cambia (sigue siendo
-- {tipo, lat, lng, radio_km}), asi que la app no se toca.
--
-- La geometria vive aparte, en desplazar_centro_radio, porque usar_comodin
-- escribe (descuenta inventario, marca el intento) y en este proyecto los
-- tests de base de datos son scripts autonomos que solo son seguros contra
-- el remoto si la funcion bajo prueba no tiene efectos secundarios -- ver
-- backend/supabase/tests/test_desplazar_centro_radio.sql.

create or replace function desplazar_centro_radio(
  p_lat double precision,
  p_lng double precision,
  p_radio_km double precision
)
returns jsonb
language plpgsql
volatile
security invoker
set search_path = public
as $$
declare
  -- La misma esfera que calcular_distancia_km (Haversine) y que
  -- circulo_radio.dart en la app: el margen del 35%-90% tiene que medirse
  -- con la misma metrica con la que luego se puntua la respuesta.
  c_radio_tierra_km constant double precision := 6371;
  -- Corona donde cae el objetivo, en fraccion del radio del circulo. El
  -- techo (0.9) mete el objetivo dentro con margen holgado; el suelo (0.35)
  -- evita el sorteo afortunado que lo deja casi en el centro y vuelve a
  -- convertir el comodin en un revelado.
  c_fraccion_min constant double precision := 0.35;
  c_fraccion_max constant double precision := 0.9;
  v_fraccion double precision;
  v_rumbo double precision;
  v_angular double precision;
  v_lat_rad double precision;
  v_seno_lat double precision;
  v_coseno_lat double precision;
  v_lat_destino double precision;
  v_lng_destino double precision;
begin
  -- sqrt(a^2 + u*(b^2 - a^2)) reparte la distancia uniforme por AREA en la
  -- corona [a*R, b*R]. Sin la raiz, el objetivo se concentraria cerca del
  -- centro, porque el area crece con el cuadrado del radio.
  v_fraccion := sqrt(
    c_fraccion_min * c_fraccion_min
    + random() * (c_fraccion_max * c_fraccion_max - c_fraccion_min * c_fraccion_min)
  );
  v_rumbo := 2 * pi() * random();
  v_angular := v_fraccion * p_radio_km / c_radio_tierra_km;

  v_lat_rad := radians(p_lat);
  v_seno_lat := sin(v_lat_rad);
  v_coseno_lat := cos(v_lat_rad);

  -- Destino esferico (punto + rumbo + distancia angular), la misma formula
  -- que _destino en app/lib/mapa/circulo_radio.dart. Exacta a proposito: la
  -- aproximacion en grados (delta_lng = d / (111 * cos lat)) se desmorona en
  -- latitudes altas justo con desplazamientos de 500 km. El clamp del
  -- argumento de asin replica el .clamp(-1, 1) del cliente y evita un error
  -- de dominio por redondeo con el objetivo cerca de un polo.
  v_lat_destino := asin(greatest(-1, least(1,
    v_seno_lat * cos(v_angular)
    + v_coseno_lat * sin(v_angular) * cos(v_rumbo)
  )));
  v_lng_destino := radians(p_lng) + atan2(
    sin(v_rumbo) * sin(v_angular) * v_coseno_lat,
    cos(v_angular) - v_seno_lat * sin(v_lat_destino)
  );

  v_lat_destino := degrees(v_lat_destino);
  v_lng_destino := degrees(v_lng_destino);
  -- Normaliza a [-180, 180) igual que Mercator.normalizarLongitud en el
  -- cliente, sin el operador % (Postgres no lo define para double precision).
  v_lng_destino := v_lng_destino - 360 * floor((v_lng_destino + 180) / 360);

  return jsonb_build_object('lat', v_lat_destino, 'lng', v_lng_destino);
end;
$$;

-- Sin grant a authenticated a proposito: es un detalle interno de
-- usar_comodin, que al ser security definer la ejecuta con los privilegios
-- del propietario. El cliente no tiene por que poder llamarla.
revoke execute on function desplazar_centro_radio(double precision, double precision, double precision) from public;

-- Identica a la version de 20260820170100_corrige_lint_usar_comodin.sql
-- salvo la rama de radio: mismas validaciones, mismo descuento de
-- inventario, misma marca de comodin_usado y mismo raise final inalcanzable
-- que calla al analisis estatico de plpgsql_check.
create or replace function usar_comodin(p_intento_id uuid, p_desafio_id uuid, p_tipo tipo_comodin)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_pais text;
  v_lat double precision;
  v_lng double precision;
  v_radio_km double precision;
  v_centro jsonb;
  v_actualizado integer;
begin
  if not exists (
    select 1
    from intentos_nivel it
    join intento_desafios idf on idf.intento_id = it.id
    where it.id = p_intento_id
      and it.usuario_id = auth.uid()
      and idf.desafio_id = p_desafio_id
      and not exists (
        select 1 from respuestas_desafio rd
        where rd.intento_id = p_intento_id and rd.desafio_id = p_desafio_id
      )
  ) then
    raise exception 'intento_o_desafio_invalido';
  end if;

  if p_tipo = 'pais' then
    select d.pais into v_pais from desafios d where d.id = p_desafio_id;
    if v_pais is null then
      raise exception 'pais_no_disponible';
    end if;
  end if;

  update comodines_inventario
  set cantidad = cantidad - 1
  where usuario_id = auth.uid() and tipo = p_tipo and cantidad > 0
  returning cantidad into v_actualizado;

  if v_actualizado is null then
    raise exception 'sin_comodines_disponibles';
  end if;

  update intentos_nivel
  set comodin_usado = p_tipo
  where id = p_intento_id and usuario_id = auth.uid() and comodin_usado is null;

  if not found then
    raise exception 'comodin_ya_usado_en_este_intento';
  end if;

  case p_tipo
    when 'tiempo' then
      return jsonb_build_object('tipo', p_tipo);
    when 'pais' then
      return jsonb_build_object('tipo', p_tipo, 'pais', v_pais);
    when 'km1000', 'km500' then
      select d.lat_real, d.lng_real into v_lat, v_lng from desafios d where d.id = p_desafio_id;
      v_radio_km := case p_tipo when 'km1000' then 500 else 150 end;
      -- INT-124: lo que sale hacia el cliente es el centro desplazado, no
      -- lat_real/lng_real. La coordenada real no vuelve a viajar en este
      -- payload.
      v_centro := desplazar_centro_radio(v_lat, v_lng, v_radio_km);
      return jsonb_build_object(
        'tipo', p_tipo,
        'lat', v_centro->'lat',
        'lng', v_centro->'lng',
        'radio_km', v_radio_km
      );
  end case;

  raise exception 'tipo_comodin_desconocido';
end;
$$;
