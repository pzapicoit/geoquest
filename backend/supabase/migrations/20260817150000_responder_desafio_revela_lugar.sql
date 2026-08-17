-- INT-93: responder_desafio revela el lugar del desafio respondido. Ver
-- design.md de openspec/changes/int-93-revelar-respuesta para el porque de
-- cada decision referenciada como D1-D14 en los comentarios.

-- 1.2 (D1): el tipo de retorno pasa de la fila de respuestas_desafio a
-- jsonb, y eso Postgres no lo admite con `create or replace`. El unico
-- llamante es la app, que se despliega despues de esta migracion (ver
-- Migration Plan del design).
drop function responder_desafio(uuid, uuid, double precision, double precision);

-- 1.3/1.4 La misma funcion de INT-78 --security definer para poder leer
-- desafios.lat_real/lng_real, que RLS (INT-77) esconde del jugador, y
-- validacion a mano de la pertenencia del intento porque con definer no se
-- ejecuta la policy de insert de respuestas_desafio-- que ademas devuelve el
-- revelado del desafio que se acaba de responder.
--
-- D2: el revelado viaja solo en la respuesta a la propia jugada, y no hace
-- falta ninguna comprobacion nueva para que sea irrepetible: el
-- `unique (intento_id, desafio_id)` de respuestas_desafio hace fallar el
-- insert de mas abajo si ese desafio ya estaba respondido en este intento.
-- Conocer la ubicacion real cuesta, por tanto, gastar la unica respuesta que
-- el intento le puede dar a ese desafio.
create function responder_desafio(
  p_intento_id uuid,
  p_desafio_id uuid,
  p_lat_adivinada double precision,
  p_lng_adivinada double precision
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

  select lat_real, lng_real, nombre_lugar
  into v_lat_real, v_lng_real, v_nombre_lugar
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

  -- La fila registrada entera (distancia_km y puntos incluidos) mas los
  -- campos del revelado, en un unico objeto plano: quien ya leia
  -- `distancia_km`/`puntos` de la respuesta los sigue encontrando donde
  -- estaban. D3: puntos_maximos sale de calcular_puntaje(0) en vez de una
  -- constante repetida en la app -- la curva de INT-78 esta sin validar con
  -- playtesting y se va a mover.
  return to_jsonb(v_respuesta) || jsonb_build_object(
    'lat_real', v_lat_real,
    'lng_real', v_lng_real,
    'nombre_lugar', v_nombre_lugar,
    'puntos_maximos', calcular_puntaje(0)
  );
end;
$$;

-- 1.5 Se revoca de public porque Postgres concede execute a public por
-- defecto en cada funcion nueva, igual que 2.2 de INT-78.
revoke execute on function responder_desafio(uuid, uuid, double precision, double precision) from public;
grant execute on function responder_desafio(uuid, uuid, double precision, double precision) to authenticated;

-- D14: el trigger respuestas_desafio_antes_de_insertar y las funciones
-- calcular_distancia_km/calcular_puntaje no se tocan. El calculo del
-- servidor y su garantia frente a inserts directos siguen siendo los de
-- INT-78.
