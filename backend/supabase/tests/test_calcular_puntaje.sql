-- Verificacion de la curva de distancia (INT-101), aislada en
-- calcular_puntaje_por_distancia desde INT-99 para que calcular_puntaje
-- pueda combinarla con el bonus por tiempo (ver
-- test_calcular_puntaje_bonus.sql). El cuerpo de la curva no cambia, solo
-- su nombre -- los mismos casos y umbrales de antes siguen valiendo.
--
-- No es un framework de tests instalado (no hay pgTAP en el proyecto, ver
-- architecture.md); es un script autonomo y seguro de ejecutar contra el
-- remoto porque calcular_puntaje_por_distancia es una funcion pura sin
-- efectos secundarios. Ejecutar tras aplicar la migracion, p.ej.:
--   supabase db execute --linked -f backend/supabase/tests/test_calcular_puntaje.sql
-- o pasando la connection string del proyecto a psql.
do $$
declare
  v_casos double precision[][] := array[
    array[0, 5000],
    array[50, 4838],
    array[200, 4382],
    array[500, 3597],
    array[1000, 2591],
    array[2000, 1355],
    array[5000, 227],
    array[20015, 50]
  ];
  v_distancia double precision;
  v_esperado double precision;
  v_obtenido integer;
  v_anterior integer := null;
  v_i integer;
begin
  for v_i in 1 .. array_length(v_casos, 1) loop
    v_distancia := v_casos[v_i][1];
    v_esperado := v_casos[v_i][2];
    v_obtenido := calcular_puntaje_por_distancia(v_distancia);

    if abs(v_obtenido - v_esperado) > 1 then
      raise exception 'calcular_puntaje(%) = % (esperado ~%)', v_distancia, v_obtenido, v_esperado;
    end if;

    if v_anterior is not null and v_obtenido > v_anterior then
      raise exception
        'calcular_puntaje deberia decrecer: d=% dio % pero una distancia menor dio %',
        v_distancia, v_obtenido, v_anterior;
    end if;

    if v_obtenido < 50 or v_obtenido > 5000 then
      raise exception 'calcular_puntaje(%) = % fuera de rango [50, 5000]', v_distancia, v_obtenido;
    end if;

    v_anterior := v_obtenido;
  end loop;

  if calcular_puntaje_por_distancia(0) <> 5000 then
    raise exception 'calcular_puntaje_por_distancia(0) deberia ser exactamente 5000, fue %', calcular_puntaje_por_distancia(0);
  end if;

  raise notice 'calcular_puntaje_por_distancia: % casos OK', array_length(v_casos, 1);
end $$;
