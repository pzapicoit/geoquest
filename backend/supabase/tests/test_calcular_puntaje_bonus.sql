-- Verificacion del bonus por rapidez de calcular_puntaje (INT-99, D4 de
-- design.md de openspec/changes/int-99-temporizador-desafio).
--
-- Mismo patron que test_calcular_puntaje.sql: script autonomo sin pgTAP,
-- seguro contra el remoto porque calcular_puntaje es una funcion pura sin
-- efectos secundarios. Ejecutar tras aplicar la migracion, p.ej.:
--   supabase db execute --linked -f backend/supabase/tests/test_calcular_puntaje_bonus.sql
do $$
declare
  v_max_con_bonus integer;
  v_tiempo_agotado integer;
  v_piso_con_tiempo_cero integer;
  v_intermedio integer;
  v_distancia_intermedio integer;
  v_bonus_mas_tiempo integer;
  v_bonus_menos_tiempo integer;
  v_tiempo_excedido integer;
begin
  -- Maximo puntaje posible: distancia 0, tiempo 0 -> MAX + BONUS_MAX.
  v_max_con_bonus := calcular_puntaje(0, 0, 60);
  if v_max_con_bonus <> 5500 then
    raise exception 'calcular_puntaje(0, 0, 60) deberia ser 5500, fue %', v_max_con_bonus;
  end if;

  -- Precision perfecta pero tiempo agotado: el bonus es 0, queda en MAX.
  v_tiempo_agotado := calcular_puntaje(0, 60, 60);
  if v_tiempo_agotado <> 5000 then
    raise exception 'calcular_puntaje(0, 60, 60) deberia ser 5000, fue %', v_tiempo_agotado;
  end if;

  -- Suelo de precision, instantaneo: sin acierto que premiar, el bonus es 0.
  v_piso_con_tiempo_cero := calcular_puntaje(20015, 0, 60);
  if v_piso_con_tiempo_cero <> 50 then
    raise exception 'calcular_puntaje(20015, 0, 60) deberia ser 50, fue %', v_piso_con_tiempo_cero;
  end if;

  -- Intermedio: con acierto parcial y tiempo restante, el bonus es > 0 y el
  -- total supera al componente de distancia solo.
  v_distancia_intermedio := calcular_puntaje_por_distancia(1000);
  v_intermedio := calcular_puntaje(1000, 30, 60);
  if v_intermedio <= v_distancia_intermedio then
    raise exception
      'calcular_puntaje(1000, 30, 60) deberia superar el componente de distancia (%), fue %',
      v_distancia_intermedio, v_intermedio;
  end if;
  if v_intermedio > v_distancia_intermedio + 500 then
    raise exception
      'calcular_puntaje(1000, 30, 60) no deberia superar el componente de distancia + BONUS_MAX (%), fue %',
      v_distancia_intermedio + 500, v_intermedio;
  end if;

  -- A menos tiempo transcurrido (mas tiempo restante), el bonus no baja.
  v_bonus_mas_tiempo := calcular_puntaje(500, 10, 60) - calcular_puntaje_por_distancia(500);
  v_bonus_menos_tiempo := calcular_puntaje(500, 50, 60) - calcular_puntaje_por_distancia(500);
  if v_bonus_mas_tiempo < v_bonus_menos_tiempo then
    raise exception
      'el bonus con mas tiempo restante (%) no deberia ser menor que con menos tiempo restante (%)',
      v_bonus_mas_tiempo, v_bonus_menos_tiempo;
  end if;

  -- segundos_transcurridos por encima de segundos_por_desafio (no deberia
  -- ocurrir tras el clamp del trigger, pero la funcion no debe devolver un
  -- bonus negativo si algun llamador se salta el clamp).
  v_tiempo_excedido := calcular_puntaje(0, 120, 60);
  if v_tiempo_excedido <> 5000 then
    raise exception 'calcular_puntaje(0, 120, 60) deberia quedarse en 5000 (bonus 0), fue %', v_tiempo_excedido;
  end if;

  raise notice 'calcular_puntaje (bonus por rapidez): 6 casos OK';
end $$;
