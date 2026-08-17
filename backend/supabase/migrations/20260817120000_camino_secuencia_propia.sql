-- INT-98: el camino pasa a ser una secuencia propia (independiente de la
-- agrupacion por tematica) y el desbloqueo pasa de "estrellas acumuladas en
-- la tematica" a "estrellas acumuladas en el camino". Ver design.md de
-- openspec/changes/int-98-camino-secuencia-propia.

-- 1. Tabla camino: una fila por posicion de la secuencia global, apuntando a
-- un nivel concreto. orden es deferrable (D1 de INT-87) para poder
-- reordenar varias filas -- incluyendo intercambios -- en una sola llamada.
create table camino (
  id uuid primary key default gen_random_uuid(),
  orden integer not null,
  nivel_id uuid not null references niveles (id) on delete cascade,
  estrellas_requeridas integer not null default 0 check (estrellas_requeridas >= 0),
  created_at timestamptz not null default now(),
  constraint camino_orden_key unique (orden) deferrable initially immediate
);

create index camino_nivel_id_idx on camino (nivel_id);

-- 2. RLS de camino: mismo patron que tematicas/niveles/nivel_desafios
-- (lectura publica para autenticados, escritura solo admin).
alter table public.camino enable row level security;

create policy "camino_select_authenticated"
on public.camino
for select
to authenticated
using (true);

create policy "camino_admin_insert"
on public.camino
for insert
to authenticated
with check (is_admin());

create policy "camino_admin_update"
on public.camino
for update
to authenticated
using (is_admin())
with check (is_admin());

create policy "camino_admin_delete"
on public.camino
for delete
to authenticated
using (is_admin());

-- 3. niveles.preguntas_por_partida: NULL = se juegan todas las preguntas
-- del recorrido (comportamiento actual); INT-95 lo usara para elegir un
-- subconjunto al azar.
alter table niveles add column preguntas_por_partida integer;

-- 4. tematicas.estrellas_requeridas queda sin consumidor: el umbral de
-- desbloqueo pasa a vivir en camino.estrellas_requeridas, por posicion.
alter table tematicas drop column estrellas_requeridas;

-- 5. Seed inicial del camino a partir del contenido existente, en el mismo
-- orden en que se juega hoy (tematica, luego nivel dentro de ella). Umbral
-- en 0: el admin lo reconfigura desde la nueva pantalla "Camino" del panel.
insert into camino (orden, nivel_id, estrellas_requeridas)
select row_number() over (order by t.orden, n.orden), n.id, 0
from niveles n
join tematicas t on t.id = n.tematica_id;

-- 6. reordenar_camino: mismo patron que reordenar_tematicas (D2 de INT-87).
create function reordenar_camino(ids_en_orden uuid[])
returns void
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_input integer;
  v_distinct integer;
  v_current integer;
  v_match integer;
begin
  if not is_admin() then
    raise exception 'Solo un admin puede reordenar el camino';
  end if;

  v_input := coalesce(array_length(ids_en_orden, 1), 0);
  select count(distinct x) into v_distinct from unnest(ids_en_orden) x;
  select count(*) into v_current from camino;
  select count(*) into v_match from camino c where c.id = any(ids_en_orden);

  if v_input <> v_distinct or v_input <> v_current or v_match <> v_current then
    raise exception 'ids_en_orden debe contener exactamente las % posiciones existentes del camino, sin duplicados (recibidos %)',
      v_current, v_input;
  end if;

  set constraints camino_orden_key deferred;

  update camino c
  set orden = pos.posicion
  from unnest(ids_en_orden) with ordinality as pos(id, posicion)
  where c.id = pos.id;
end;
$$;

-- 7. cerrar_intento_nivel: la seccion de puntaje/estrellas (INT-79, D1-D5)
-- no cambia. Lo que cambia es el desbloqueo (antes D6/D7): ya no hay
-- "siguiente nivel de la tematica" ni "siguiente tematica por estrellas",
-- sino un unico calculo sobre el camino.
create or replace function cerrar_intento_nivel(p_intento_id uuid)
returns intentos_nivel
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_nivel_id uuid;
  v_puntaje_minimo integer;
  v_umbral_estrella_2 integer;
  v_umbral_estrella_3 integer;
  v_total_desafios integer;
  v_respondidos integer;
  v_puntaje integer;
  v_superado boolean;
  v_estrellas smallint;
  v_estrellas_acumuladas_camino integer;
  v_intento intentos_nivel;
begin
  select ni.nivel_id, n.puntaje_minimo_superar, n.umbral_estrella_2, n.umbral_estrella_3
  into v_nivel_id, v_puntaje_minimo, v_umbral_estrella_2, v_umbral_estrella_3
  from intentos_nivel ni
  join niveles n on n.id = ni.nivel_id
  where ni.id = p_intento_id;

  if not found then
    raise exception 'El intento % no existe o no pertenece al usuario autenticado', p_intento_id;
  end if;

  select count(*) into v_total_desafios
  from nivel_desafios
  where nivel_id = v_nivel_id;

  select count(distinct rd.desafio_id), coalesce(sum(rd.puntos), 0)
  into v_respondidos, v_puntaje
  from respuestas_desafio rd
  join nivel_desafios nd
    on nd.desafio_id = rd.desafio_id
   and nd.nivel_id = v_nivel_id
  where rd.intento_id = p_intento_id;

  if v_respondidos < v_total_desafios then
    raise exception 'El intento % no tiene respuesta para todos los desafios del nivel (% de %)',
      p_intento_id, v_respondidos, v_total_desafios;
  end if;

  v_superado := v_puntaje >= v_puntaje_minimo;

  v_estrellas := case
    when not v_superado then 0
    when v_puntaje >= v_umbral_estrella_3 then 3
    when v_puntaje >= v_umbral_estrella_2 then 2
    else 1
  end;

  update intentos_nivel
  set puntaje_total = v_puntaje,
      superado = v_superado,
      estrellas_obtenidas = v_estrellas
  where id = p_intento_id
  returning * into v_intento;

  if not found then
    raise exception 'El intento % ya no existe', p_intento_id;
  end if;

  insert into progreso_usuario_nivel (
    usuario_id, nivel_id, superado, mejor_puntaje, mejores_estrellas, desbloqueado
  )
  values (auth.uid(), v_nivel_id, v_superado, v_puntaje, v_estrellas, true)
  on conflict (usuario_id, nivel_id) do update set
    superado = progreso_usuario_nivel.superado or excluded.superado,
    mejor_puntaje = greatest(progreso_usuario_nivel.mejor_puntaje, excluded.mejor_puntaje),
    mejores_estrellas = greatest(progreso_usuario_nivel.mejores_estrellas, excluded.mejores_estrellas),
    desbloqueado = true,
    actualizado_en = now();

  if v_superado then
    -- Lock de asesoramiento por usuario: bajo READ COMMITTED, dos intentos
    -- del mismo usuario cerrandose a la vez podrian leer la suma de
    -- estrellas del camino sin ver el upsert del otro (D7 de INT-79, misma
    -- razon, ahora a nivel de usuario en vez de usuario+tematica).
    perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text, 0));

    select coalesce(sum(pun.mejores_estrellas), 0) into v_estrellas_acumuladas_camino
    from progreso_usuario_nivel pun
    join camino c on c.nivel_id = pun.nivel_id
    where pun.usuario_id = auth.uid();

    -- Desbloquea de una vez todas las posiciones del camino cuyo umbral ya
    -- se alcance, no solo "la siguiente": no se exige haber completado la
    -- posicion anterior (decision de producto, ver design.md).
    insert into progreso_usuario_nivel (usuario_id, nivel_id, desbloqueado)
    select auth.uid(), c.nivel_id, true
    from camino c
    where c.estrellas_requeridas <= v_estrellas_acumuladas_camino
    on conflict (usuario_id, nivel_id) do update set
      desbloqueado = true,
      actualizado_en = now();
  end if;

  return v_intento;
end;
$$;

revoke execute on function cerrar_intento_nivel(uuid) from public;
grant execute on function cerrar_intento_nivel(uuid) to authenticated;
