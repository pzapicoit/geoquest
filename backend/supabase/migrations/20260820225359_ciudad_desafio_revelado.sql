-- INT-122 (D1, D2, D3): la ciudad real del objetivo como dato propio, y el
-- revelado de `responder_desafio` la entrega junto al resto de la ubicación.
--
-- Por qué una columna nueva y no reaprovechar `nombre_lugar`: ese campo carga
-- hoy con dos papeles, el punto exacto de la respuesta y su ubicación en el
-- mapa administrativo, y sus valores reales van de 'Coliseo de Roma, Italia' a
-- 'Parque de bomberos Hook & Ladder 8, Tribeca, Nueva York'. La hoja del
-- revelado le da una sola línea (INT-121), así que lo que se trunca es
-- justamente dónde estaba el objetivo. Y `nombre_lugar` tiene tres consumidores
-- vivos que quieren el punto concreto, no la ciudad: las etiquetas de las
-- alertas de contenido del panel, la deduplicación de candidatos de la
-- generación con IA y la búsqueda del listado de preguntas.
--
-- Nullable a propósito, y `NULL` es un valor legítimo, no un dato pendiente:
-- hay objetivos sin ciudad real -- aguas internacionales, parajes despoblados,
-- o una respuesta que es un país entero -- y forzar un valor obligaría a
-- inventarlo. La app cae a `nombre_lugar` cuando falta.
--
-- No hacen falta policies nuevas (D3): `desafios` no tiene policy de select
-- para jugadores desde INT-77 (solo is_admin()), así que añadir una columna a
-- la tabla no la expone a nadie. La disciplina que sí importa es no meterla en
-- `desafios_para_jugar` ni en el jsonb de `iniciar_intento_parada`: la ciudad
-- nombra el sitio que el jugador tiene que deducir del mapa, así que antes de
-- responder ES la respuesta.

alter table desafios add column ciudad text;

comment on column desafios.ciudad is
  'Ciudad real del objetivo, independiente de nombre_lugar (el punto exacto) y de pais. Es lo que la app rotula al revelar la respuesta. Null = sin ciudad real aplicable; la app cae a nombre_lugar.';

-- `create or replace` basta y no hace falta drop (D2): la firma no cambia --
-- la función ya devuelve jsonb desde INT-93 -- y añadir una clave al objeto no
-- es un cambio de tipo de retorno. Esto la diferencia de INT-93, que sí
-- necesitó drop porque pasaba de devolver una fila a devolver jsonb.
--
-- El cuerpo se copia íntegro de 20260818122000_dificultad_camino_rpcs_vistas
-- (la definición vigente), porque `create or replace` lo sustituye completo:
-- omitir cualquier parte -- el bonus por rapidez, el desglose de puntaje, la
-- validación del pin nulo -- sería una regresión silenciosa. Las únicas
-- diferencias respecto a esa versión son las tres líneas de `ciudad`.
--
-- La ciudad viaja tal cual está en la columna, `NULL` incluido: distinguir "sin
-- ciudad" de "ciudad vacía" es lo que le permite a la app decidir qué rotular.
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
  v_ciudad text;
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

  select lat_real, lng_real, nombre_lugar, ciudad
  into v_lat_real, v_lng_real, v_nombre_lugar, v_ciudad
  from desafios
  where id = p_desafio_id;

  if not found then
    raise exception 'El desafio % no existe', p_desafio_id;
  end if;

  select coalesce(c.segundos_por_desafio, dd.segundos_por_desafio)
  into v_segundos_por_desafio
  from intentos_nivel it
  join camino c on c.id = it.camino_id
  join dificultad_defaults dd on dd.dificultad = c.dificultad
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
    'ciudad', v_ciudad,
    'puntos_maximos', calcular_puntaje(0, 0, coalesce(v_segundos_por_desafio, 60)),
    'puntos_distancia', v_puntos_distancia,
    'puntos_bonus', v_puntos_bonus
  );
end;
$$;
