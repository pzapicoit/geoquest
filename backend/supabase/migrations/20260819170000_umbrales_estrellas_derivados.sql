-- INT-115: los umbrales de estrellas y el desbloqueo de posiciones dejan de
-- ser enteros absolutos tecleados a mano y pasan a derivarse de
-- preguntas_por_partida (via calcular_puntaje) y de orden respectivamente.
-- Ver design.md de openspec/changes/int-115-simplificar-puntuacion-estrellas
-- para el porque de cada decision (D1-D6).

-- 1.1 (D2) puntaje_maximo_por_desafio: el 60 es arbitrario -- con distancia
-- 0 y tiempo transcurrido 0, calcular_puntaje da el mismo resultado (5500)
-- para cualquier segundos_por_desafio > 0, porque la fraccion de tiempo
-- restante siempre da 1. Ningun literal 5500 debe aparecer en el resto del
-- codigo: todo lo que necesite el maximo por desafio pasa por esta funcion.
create function puntaje_maximo_por_desafio()
returns integer
language sql
immutable
as $$
  select calcular_puntaje(0, 0, 60);
$$;

-- 1.2 (D2) estrellas_requeridas_por_orden: formula fija, sin dependencia de
-- ninguna constante de puntuacion. orden 1 siempre da 0.
create function estrellas_requeridas_por_orden(p_orden integer)
returns integer
language sql
immutable
as $$
  select floor((p_orden - 1) * 3 * 0.6)::integer;
$$;

-- 1.3 (D2) umbrales_parada: porcentajes fijos por dificultad, constantes en
-- codigo (no en tabla) -- la tercera estrella es siempre la mas exigente y
-- se endurece con la dificultad. floor en los tres umbrales para que el
-- porcentaje anunciado nunca exija mas de lo que dice.
create function umbrales_parada(p_dificultad dificultad, p_preguntas_por_partida integer)
returns table(maximo integer, minimo integer, umbral_estrella_2 integer, umbral_estrella_3 integer)
language sql
immutable
as $$
  with porcentajes as (
    select
      case p_dificultad
        when 'facil' then 0.45
        when 'normal' then 0.50
        when 'intermedio' then 0.55
        when 'dificil' then 0.58
        when 'muy_dificil' then 0.62
      end as pct_minimo,
      case p_dificultad
        when 'facil' then 0.65
        when 'normal' then 0.68
        when 'intermedio' then 0.72
        when 'dificil' then 0.76
        when 'muy_dificil' then 0.80
      end as pct_estrella_2,
      case p_dificultad
        when 'facil' then 0.82
        when 'normal' then 0.85
        when 'intermedio' then 0.88
        when 'dificil' then 0.91
        when 'muy_dificil' then 0.94
      end as pct_estrella_3
  ),
  base as (
    select
      p_preguntas_por_partida * puntaje_maximo_por_desafio() as maximo,
      pct_minimo, pct_estrella_2, pct_estrella_3
    from porcentajes
  )
  select
    maximo,
    floor(maximo * pct_minimo)::integer as minimo,
    floor(maximo * pct_estrella_2)::integer as umbral_estrella_2,
    floor(maximo * pct_estrella_3)::integer as umbral_estrella_3
  from base;
$$;

-- 1.4/1.5 lectura publica para autenticados, igual que dificultad_defaults/
-- camino (de donde salen los argumentos de estas funciones).
grant execute on function puntaje_maximo_por_desafio() to authenticated;
grant execute on function estrellas_requeridas_por_orden(integer) to authenticated;
grant execute on function umbrales_parada(dificultad, integer) to authenticated;

-- 2.1/2.2/2.3 (D1) cerrar_intento_parada: los umbrales se resuelven sobre
-- v_total_desafios (el numero real de desafios persistidos de ESTE
-- intento en intento_desafios), no sobre el preguntas_por_partida vigente
-- en camino/dificultad_defaults -- asi un cambio de configuracion
-- posterior al inicio del intento no altera retroactivamente su
-- resultado. Se anade puntaje_maximo a la respuesta.
create or replace function cerrar_intento_parada(p_intento_id uuid)
returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_camino_id uuid;
  v_dificultad dificultad;
  v_total_desafios integer;
  v_respondidos integer;
  v_puntaje integer;
  v_puntaje_maximo integer;
  v_puntaje_minimo integer;
  v_umbral_estrella_2 integer;
  v_umbral_estrella_3 integer;
  v_superado boolean;
  v_estrellas smallint;
  v_mejor_puntaje_anterior integer;
  v_estrellas_acumuladas_camino integer;
begin
  select ni.camino_id, c.dificultad
  into v_camino_id, v_dificultad
  from intentos_nivel ni
  join camino c on c.id = ni.camino_id
  where ni.id = p_intento_id;

  if not found then
    raise exception 'El intento % no existe o no pertenece al usuario autenticado', p_intento_id;
  end if;

  select count(*) into v_total_desafios
  from intento_desafios
  where intento_id = p_intento_id;

  if v_total_desafios = 0 then
    raise exception 'El intento % no tiene desafios asignados en intento_desafios (parada sin desafios, intento creado sin pasar por iniciar_intento_parada, o anterior a esta migracion)', p_intento_id;
  end if;

  select maximo, minimo, umbral_estrella_2, umbral_estrella_3
  into v_puntaje_maximo, v_puntaje_minimo, v_umbral_estrella_2, v_umbral_estrella_3
  from umbrales_parada(v_dificultad, v_total_desafios);

  select count(distinct rd.desafio_id), coalesce(sum(rd.puntos), 0)
  into v_respondidos, v_puntaje
  from respuestas_desafio rd
  join intento_desafios idf
    on idf.desafio_id = rd.desafio_id
   and idf.intento_id = p_intento_id
  where rd.intento_id = p_intento_id;

  if v_respondidos < v_total_desafios then
    raise exception 'El intento % no tiene respuesta para todos los desafios de la parada (% de %)',
      p_intento_id, v_respondidos, v_total_desafios;
  end if;

  v_superado := v_puntaje >= v_puntaje_minimo;

  v_estrellas := case
    when not v_superado then 0
    when v_puntaje >= v_umbral_estrella_3 then 3
    when v_puntaje >= v_umbral_estrella_2 then 2
    else 1
  end;

  select mejor_puntaje into v_mejor_puntaje_anterior
  from progreso_usuario_nivel
  where usuario_id = auth.uid() and camino_id = v_camino_id;

  update intentos_nivel
  set puntaje_total = v_puntaje,
      superado = v_superado,
      estrellas_obtenidas = v_estrellas
  where id = p_intento_id;

  if not found then
    raise exception 'El intento % ya no existe', p_intento_id;
  end if;

  insert into progreso_usuario_nivel (
    usuario_id, camino_id, superado, mejor_puntaje, mejores_estrellas, desbloqueado
  )
  values (auth.uid(), v_camino_id, v_superado, v_puntaje, v_estrellas, true)
  on conflict (usuario_id, camino_id) do update set
    superado = progreso_usuario_nivel.superado or excluded.superado,
    mejor_puntaje = greatest(progreso_usuario_nivel.mejor_puntaje, excluded.mejor_puntaje),
    mejores_estrellas = greatest(progreso_usuario_nivel.mejores_estrellas, excluded.mejores_estrellas),
    desbloqueado = true,
    actualizado_en = now();

  if v_superado then
    -- Lock de asesoramiento por usuario: bajo READ COMMITTED, dos intentos
    -- del mismo usuario cerrandose a la vez podrian leer la suma de
    -- estrellas del camino sin ver el upsert del otro (D7 de INT-79).
    perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text, 0));

    select coalesce(sum(pun.mejores_estrellas), 0) into v_estrellas_acumuladas_camino
    from progreso_usuario_nivel pun
    where pun.usuario_id = auth.uid();

    insert into progreso_usuario_nivel (usuario_id, camino_id, desbloqueado)
    select auth.uid(), c.id, true
    from camino c
    where estrellas_requeridas_por_orden(c.orden) <= v_estrellas_acumuladas_camino
    on conflict (usuario_id, camino_id) do update set
      desbloqueado = true,
      actualizado_en = now();
  end if;

  return jsonb_build_object(
    'puntaje_total', v_puntaje,
    'superado', v_superado,
    'estrellas_obtenidas', v_estrellas,
    'puntaje_minimo_superar', v_puntaje_minimo,
    'puntaje_maximo', v_puntaje_maximo,
    'mejor_puntaje_anterior', v_mejor_puntaje_anterior
  );
end;
$$;

-- 2.4 (D6) camino_jugador: CREATE OR REPLACE basta -- el nombre y orden de
-- columnas no cambian, solo la expresion que produce estrellas_requeridas
-- (antes columna, ahora estrellas_requeridas_por_orden(orden)).
create or replace view camino_jugador
with (security_invoker = false)
as
with estrellas_acumuladas as (
  select coalesce(sum(pun.mejores_estrellas), 0) as total
  from progreso_usuario_nivel pun
  join camino c on c.id = pun.camino_id
  where pun.usuario_id = auth.uid()
)
select
  c.id as camino_id,
  c.orden,
  estrellas_requeridas_por_orden(c.orden) as estrellas_requeridas,
  c.dificultad,
  c.nombre,
  t.id as tematica_id,
  t.nombre as tematica_nombre,
  coalesce(pun.superado, false) as superado,
  coalesce(pun.mejores_estrellas, 0) as estrellas_obtenidas,
  ea.total as estrellas_acumuladas_usuario,
  coalesce(pun.desbloqueado, false)
    or estrellas_requeridas_por_orden(c.orden) <= ea.total as desbloqueado,
  coalesce(
    c.orden = min(case when not coalesce(pun.superado, false) then c.orden end)
      over (),
    false
  ) as es_actual
from camino c
join tematicas t on t.id = c.tematica_id
left join progreso_usuario_nivel pun
  on pun.camino_id = c.id and pun.usuario_id = auth.uid()
cross join estrellas_acumuladas ea
order by c.orden;

-- 2.5 (D4) camino_panel: camino_jugador es por-usuario (auth.uid()), no
-- sirve para el listado del admin. Vista nueva de solo lectura, misma RLS
-- efectiva que camino/tematicas hoy (select para cualquier autenticado):
-- security_invoker = true para que respete esa RLS en vez de heredar los
-- privilegios del owner de la vista.
create view camino_panel
with (security_invoker = true)
as
select
  c.id,
  c.orden,
  c.tematica_id,
  t.nombre as tematica_nombre,
  c.dificultad,
  c.nombre,
  c.activo,
  c.preguntas_por_partida,
  c.segundos_por_desafio,
  estrellas_requeridas_por_orden(c.orden) as estrellas_requeridas
from camino c
join tematicas t on t.id = c.tematica_id
order by c.orden;

-- 3.1/3.2 con las funciones/vistas de arriba ya cubriendo su lectura, se
-- retiran las columnas almacenadas. Sus checks de orden ascendente
-- desaparecen solos junto con las columnas que referencian.
alter table dificultad_defaults
  drop column puntaje_minimo_superar,
  drop column umbral_estrella_2,
  drop column umbral_estrella_3;

alter table camino
  drop column puntaje_minimo_superar,
  drop column umbral_estrella_2,
  drop column umbral_estrella_3,
  drop column estrellas_requeridas;
