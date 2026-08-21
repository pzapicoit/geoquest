-- INT-124: test de desplazar_centro_radio, la geometria del centro que
-- emiten los comodines de radio. Ver design.md de
-- openspec/changes/int-124-circulo-radio-desplazado (D1-D3) para el porque.
--
-- No hay pgTAP en el proyecto (ver architecture.md): script autonomo. Es
-- seguro contra el remoto sin BEGIN/ROLLBACK -- a diferencia de
-- test_clasificacion.sql -- porque desplazar_centro_radio no lee ni escribe
-- ninguna tabla: recibe la coordenada como argumento. Justo por eso la
-- geometria se saco de usar_comodin, que si escribe (descuenta inventario y
-- marca el intento) y por tanto no es testeable por esta via.
--
-- Ejecutar tras aplicar la migracion, p.ej.:
--   supabase db query --linked -f supabase/tests/test_desplazar_centro_radio.sql
-- (desde backend/; el CLI 2.111 renombro "db execute" a "db query", asi que
-- la linea de los tests anteriores ya no funciona tal cual)
-- o pasando la connection string del proyecto a psql.
--
-- El test es estadistico en un solo punto (la media de d/R); todo lo demas
-- son invariantes duras que un error en la formula rompe en la primera
-- iteracion.
do $$
declare
  -- Objetivos elegidos por lo que rompen: el ecuador como caso base, una
  -- latitud media como caso normal de juego, el antimeridiano para la
  -- normalizacion de longitud, y casi-polo para el clamp de asin y el cruce
  -- del polo (a lat 89.5 el desplazamiento maximo de km1000, 450 km, pasa
  -- por encima del polo: es el caso que hunde a la aproximacion en grados).
  v_objetivos double precision[][] := array[
    array[0, 0],
    array[40.4168, -3.7038],
    array[-33.8688, 179.9],
    array[89.5, 20],
    array[-89.5, -170]
  ];
  v_radios double precision[] := array[500, 150];
  c_muestras constant integer := 2000;
  c_min constant double precision := 0.35;
  c_max constant double precision := 0.9;
  c_epsilon_km constant double precision := 0.01;
  v_lat_obj double precision;
  v_lng_obj double precision;
  v_radio double precision;
  v_centro jsonb;
  v_lat double precision;
  v_lng double precision;
  v_distancia double precision;
  v_fraccion double precision;
  v_suma_fracciones double precision := 0;
  v_total integer := 0;
  v_media double precision;
  v_o integer;
  v_r integer;
  v_i integer;
  -- Cuadrantes respecto del objetivo, solo para la latitud media (v_o = 2):
  -- en el antimeridiano y junto a los polos el signo de la diferencia de
  -- longitud no separa cuadrantes de forma util.
  v_ne integer := 0;
  v_nw integer := 0;
  v_se integer := 0;
  v_sw integer := 0;
  v_delta_lng double precision;
  v_centro_a jsonb;
  v_centro_b jsonb;
begin
  for v_o in 1 .. array_length(v_objetivos, 1) loop
    v_lat_obj := v_objetivos[v_o][1];
    v_lng_obj := v_objetivos[v_o][2];

    for v_r in 1 .. array_length(v_radios, 1) loop
      v_radio := v_radios[v_r];

      for v_i in 1 .. c_muestras loop
        v_centro := desplazar_centro_radio(v_lat_obj, v_lng_obj, v_radio);
        v_lat := (v_centro->>'lat')::double precision;
        v_lng := (v_centro->>'lng')::double precision;

        -- Invariante 1: el objetivo cae dentro del circulo y lejos del
        -- centro, medido con la misma esfera con la que se puntua.
        v_distancia := calcular_distancia_km(v_lat, v_lng, v_lat_obj, v_lng_obj);
        if v_distancia > c_max * v_radio + c_epsilon_km then
          raise exception
            'objetivo (%, %) fuera del circulo: d=% km con R=% km (max %)',
            v_lat_obj, v_lng_obj, v_distancia, v_radio, c_max * v_radio;
        end if;
        if v_distancia < c_min * v_radio - c_epsilon_km then
          raise exception
            'objetivo (%, %) demasiado cerca del centro: d=% km con R=% km (min %)',
            v_lat_obj, v_lng_obj, v_distancia, v_radio, c_min * v_radio;
        end if;

        -- Invariante 2: coordenada emitida normalizada, tambien cruzando el
        -- antimeridiano o por encima de un polo.
        if v_lng < -180 or v_lng >= 180 then
          raise exception
            'longitud % fuera de [-180, 180) para objetivo (%, %) con R=%',
            v_lng, v_lat_obj, v_lng_obj, v_radio;
        end if;
        if v_lat < -90 or v_lat > 90 then
          raise exception
            'latitud % fuera de [-90, 90] para objetivo (%, %) con R=%',
            v_lat, v_lat_obj, v_lng_obj, v_radio;
        end if;

        v_fraccion := v_distancia / v_radio;
        v_suma_fracciones := v_suma_fracciones + v_fraccion;
        v_total := v_total + 1;

        if v_o = 2 then
          v_delta_lng := v_lng - v_lng_obj;
          if v_lat > v_lat_obj and v_delta_lng > 0 then v_ne := v_ne + 1;
          elsif v_lat > v_lat_obj and v_delta_lng < 0 then v_nw := v_nw + 1;
          elsif v_lat < v_lat_obj and v_delta_lng > 0 then v_se := v_se + 1;
          elsif v_lat < v_lat_obj and v_delta_lng < 0 then v_sw := v_sw + 1;
          end if;
        end if;
      end loop;
    end loop;
  end loop;

  -- Invariante 3: cada llamada sortea de nuevo. Dos centros identicos con
  -- 2 * 10^9 posiciones posibles serian una funcion cacheada (p.ej. marcada
  -- stable o immutable por error), no mala suerte.
  v_centro_a := desplazar_centro_radio(40.4168, -3.7038, 500);
  v_centro_b := desplazar_centro_radio(40.4168, -3.7038, 500);
  if v_centro_a = v_centro_b then
    raise exception
      'dos llamadas seguidas devolvieron el mismo centro (%): el sorteo no se repite',
      v_centro_a;
  end if;

  -- Invariante 4: el rumbo cubre las cuatro direcciones. Con 4000 muestras
  -- (dos radios) cada cuadrante deberia llevarse ~1000; se exige solo un
  -- 10% para que el test no sea fragil, pero un rumbo constante o con signo
  -- fijo cae a cero en dos cuadrantes.
  if least(v_ne, v_nw, v_se, v_sw) < c_muestras / 10 then
    raise exception
      'rumbos mal repartidos: NE=% NW=% SE=% SW=% (minimo exigido %)',
      v_ne, v_nw, v_se, v_sw, c_muestras / 10;
  end if;

  -- Invariante 5: la media de d/R delata el sesgo. Con muestreo uniforme por
  -- area en [0.35, 0.9] vale exactamente
  --   (2 / (3 * (b^2 - a^2))) * (b^3 - a^3) = 0.6653...
  -- Olvidar la raiz cuadrada (uniforme en la distancia, no en el area) la
  -- dejaria en 0.625, fuera de la tolerancia.
  v_media := v_suma_fracciones / v_total;
  if abs(v_media - 0.6653) > 0.03 then
    raise exception
      'media de d/R = % sobre % muestras (esperado ~0.6653): distribucion sesgada',
      v_media, v_total;
  end if;

  raise notice
    'desplazar_centro_radio: % muestras OK (% objetivos x % radios), media d/R = %',
    v_total, array_length(v_objetivos, 1), array_length(v_radios, 1), round(v_media::numeric, 4);
end $$;
