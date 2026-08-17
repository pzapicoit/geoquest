-- INT-101: calcular_puntaje pasa de decaimiento lineal con corte duro a
-- exponencial con suelo. Ver design.md de
-- openspec/changes/int-101-curva-puntuacion-exponencial para el porque de
-- cada decision.
--
-- Constantes (unico dial de ajuste; ver proposal.md para la tabla de
-- referencia distancia -> puntaje):
--   v_max  = 5000  -- puntaje en d = 0
--   v_piso = 50    -- minimo, nunca se baja de ahi (antipodas, ~20015 km)
--   v_k    = 1500  -- km de escala: cada v_k, la parte ganable se divide por e
--
-- Mismo nombre y firma que la version de INT-78 (create or replace):
-- responder_desafio, el trigger respuestas_desafio_antes_de_insertar y
-- puntos_maximos del revelado (INT-95, calcular_puntaje(0)) no se tocan.
create or replace function calcular_puntaje(distancia_km double precision)
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
