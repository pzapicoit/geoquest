-- INT-95: vista segura de desafios para jugar y arranque de intento. Ver
-- design.md de openspec/changes/int-95-vista-desafios-intento para el
-- porque de cada decision referenciada como D1-D5 en los comentarios.

-- 1.2/1.3 Vista de contenido de juego (D1: SIN security_invoker -- se crea
-- con el rol de migracion, que es dueno de `desafios` y no esta sujeto a
-- su RLS, para poder exponer un subconjunto seguro a quien no puede leer
-- la tabla directamente). Nunca expone lat_real/lng_real/nombre_lugar.
create view desafios_para_jugar as
select id, tipo, imagen_url, video_url, texto_pregunta, activo
from desafios;

grant select on desafios_para_jugar to authenticated;

-- 2.1-2.6 RPC que arranca una partida: valida el nivel, crea el intento
-- del usuario actual y selecciona sus desafios (D2: security invoker --a
-- diferencia de responder_desafio, nada de lo que toca esta funcion es
-- sensible: niveles/nivel_desafios ya son de lectura publica,
-- desafios_para_jugar ya esta concedida a authenticated arriba, y el
-- insert en intentos_nivel ya lo permite la policy intentos_nivel_insert_own
-- para la propia fila).
create function iniciar_intento_nivel(p_nivel_id uuid)
returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_activo boolean;
  v_limite integer;
  v_intento intentos_nivel;
  v_desafios jsonb;
begin
  -- 2.2 (D5): validacion explicita, igual que D3 de
  -- int-78-calcular-distancia-puntaje -- no hay policy que impida arrancar
  -- un intento sobre un nivel inexistente o inactivo, asi que se comprueba
  -- a mano antes de insertar nada.
  select activo, preguntas_por_partida
  into v_activo, v_limite
  from niveles
  where id = p_nivel_id;

  if not found or not v_activo then
    raise exception 'El nivel % no existe o no esta activo', p_nivel_id;
  end if;

  -- 2.3: usuario_id sale de auth.uid(), nunca de un parametro -- la propia
  -- firma de la funcion no deja manipularlo.
  insert into intentos_nivel (usuario_id, nivel_id)
  values (auth.uid(), p_nivel_id)
  returning * into v_intento;

  -- 2.4 (D3): una unica consulta que selecciona y ordena a la vez. Cuando
  -- v_limite es NULL, `random()` no se evalua (queda NULL para todas las
  -- filas) y el limit no recorta nada -- se devuelven todas ordenadas por
  -- nivel_desafios.orden. Cuando tiene valor, se ordena al azar y se
  -- recorta a esa cantidad: seleccion y orden de presentacion quedan
  -- aleatorios a la vez. Se excluyen desafios inactivos.
  select coalesce(jsonb_agg(s), '[]'::jsonb)
  into v_desafios
  from (
    select d.id, d.tipo, d.imagen_url, d.video_url, d.texto_pregunta, d.activo
    from nivel_desafios nd
    join desafios_para_jugar d on d.id = nd.desafio_id
    where nd.nivel_id = p_nivel_id
      and d.activo
    order by case when v_limite is not null then random() end, nd.orden
    limit coalesce(v_limite, 2147483647)
  ) s;

  -- 2.5 (D4): una unica respuesta jsonb en vez de un setof que repetiria
  -- intento_id en cada fila.
  return jsonb_build_object(
    'intento_id', v_intento.id,
    'desafios', v_desafios
  );
end;
$$;

-- 2.6: se revoca de public porque Postgres concede execute a public por
-- defecto en funciones nuevas, igual que 2.2 de int-78-calcular-distancia-puntaje.
revoke execute on function iniciar_intento_nivel(uuid) from public;
grant execute on function iniciar_intento_nivel(uuid) to authenticated;
