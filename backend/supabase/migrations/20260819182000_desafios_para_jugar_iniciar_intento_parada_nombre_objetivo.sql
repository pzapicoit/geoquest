-- INT-116: desafios_para_jugar expone el nuevo nombre corto del desafio;
-- iniciar_intento_parada expone ademas el objetivo_global de la tematica de
-- la parada (constante para todos los desafios del intento, ver design.md
-- D4 -- viaja una sola vez en la respuesta, junto a segundos_por_desafio,
-- no repetido por desafio).
--
-- `nombre` se anade al FINAL de la lista de columnas, no junto a `tipo`:
-- `create or replace view` no admite reordenar/renombrar columnas ya
-- existentes (mismo limite documentado en 20260818122000 para
-- camino_jugador/metricas_home), solo anadir nuevas al final.
create or replace view desafios_para_jugar as
select id, tipo, imagen_url, video_url, texto_pregunta, activo, tematica_id, dificultad, nombre
from desafios;

create or replace function iniciar_intento_parada(p_camino_id uuid)
returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_activo boolean;
  v_tematica_id uuid;
  v_dificultad dificultad;
  v_limite integer;
  v_segundos_por_desafio integer;
  v_objetivo_global text;
  v_pool_disponible integer;
  v_intento intentos_nivel;
  v_desafios jsonb;
begin
  select c.activo, c.tematica_id, c.dificultad,
         coalesce(c.preguntas_por_partida, dd.preguntas_por_partida),
         coalesce(c.segundos_por_desafio, dd.segundos_por_desafio),
         t.objetivo_global
  into v_activo, v_tematica_id, v_dificultad, v_limite, v_segundos_por_desafio, v_objetivo_global
  from camino c
  join dificultad_defaults dd on dd.dificultad = c.dificultad
  join tematicas t on t.id = c.tematica_id
  where c.id = p_camino_id;

  if not found or not v_activo then
    raise exception 'La parada % no existe o no esta activa', p_camino_id;
  end if;

  select count(*) into v_pool_disponible
  from desafios_para_jugar d
  where d.tematica_id = v_tematica_id
    and d.dificultad = v_dificultad
    and d.activo;

  if v_pool_disponible < v_limite then
    raise exception 'La parada % exige % preguntas activas pero su pool de tematica+dificultad solo tiene %',
      p_camino_id, v_limite, v_pool_disponible;
  end if;

  insert into intentos_nivel (usuario_id, camino_id)
  values (auth.uid(), p_camino_id)
  returning * into v_intento;

  with sorteo as materialized (
    select d.id, d.tipo, d.nombre, d.imagen_url, d.video_url, d.texto_pregunta, d.activo,
           random() as azar
    from desafios_para_jugar d
    where d.tematica_id = v_tematica_id
      and d.dificultad = v_dificultad
      and d.activo
  ),
  seleccion as materialized (
    select id, tipo, nombre, imagen_url, video_url, texto_pregunta, activo,
           row_number() over (order by azar) as orden
    from sorteo
    order by azar
    limit v_limite
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
           'nombre', s.nombre,
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
    'objetivo_global', v_objetivo_global,
    'desafios', v_desafios
  );
end;
$$;
