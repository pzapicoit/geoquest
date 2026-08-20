-- INT-119: comodines -- inventario por jugador, uso limitado a 1 por intento
-- y concesion por video publicitario con tope diario. Ver design.md de
-- openspec/changes/int-119-comodines-inventario-uso (D1-D7) para el porque
-- de cada decision referenciada en los comentarios.

-- 1. Catalogo cerrado de tipos de comodin (D1).
create type tipo_comodin as enum ('tiempo', 'pais', 'km1000', 'km500');

-- 2. Inventario como filas (usuario_id, tipo) en vez de columnas fijas (D1):
-- un tipo nuevo en el futuro solo pide una fila de catalogo, no una
-- migracion de columnas. RLS solo de lectura/propia: la escritura real pasa
-- siempre por las funciones security definer de mas abajo, nunca por REST
-- directo -- igual que profiles con role (INT-76).
create table comodines_inventario (
  usuario_id uuid not null references profiles (id) on delete cascade,
  tipo tipo_comodin not null,
  cantidad integer not null default 0 check (cantidad >= 0),
  primary key (usuario_id, tipo)
);

alter table public.comodines_inventario enable row level security;

create policy "comodines_inventario_select_own"
on public.comodines_inventario
for select
to authenticated
using (usuario_id = auth.uid());

-- Sin policy de insert/update/delete para authenticated/anon: el sembrado
-- vive en handle_new_user (security definer) y el consumo/concesion en
-- usar_comodin/conceder_comodin_por_anuncio (tambien security definer).

-- 3. Marca de que comodin (si alguno) se ha consumido ya en este intento
-- (D2): una columna nullable expresa la invariante "como mucho 1 por
-- intento" directamente y permite un update atomico mas abajo.
alter table intentos_nivel add column comodin_usado tipo_comodin;

-- 4. Pais real del objetivo (D4): no hay dataset de fronteras por pais
-- disponible (el asset del mapa es solo costa/relleno, sin atribucion por
-- pais), asi que no se puede derivar geometricamente -- se guarda como
-- contenido, igual que nombre_lugar.
alter table desafios add column pais text;

-- 5. Tope diario de concesiones por anuncio (D6): una fila por usuario y
-- dia, no un log de eventos -- mas simple de consultar y de resetear.
create table comodines_concesiones_anuncio (
  usuario_id uuid not null references profiles (id) on delete cascade,
  fecha date not null,
  cantidad integer not null default 0 check (cantidad >= 0),
  primary key (usuario_id, fecha)
);

alter table public.comodines_concesiones_anuncio enable row level security;

create policy "comodines_concesiones_select_own"
on public.comodines_concesiones_anuncio
for select
to authenticated
using (usuario_id = auth.uid());

-- 6. Sembrado del inventario inicial (D1): 1 unidad de tiempo/pais/km1000,
-- 0 de km500 -- el mismo trigger que ya crea el perfil en el alta (INT-75),
-- sin tocar su logica de generacion de alias.
create or replace function handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_candidato text;
  v_intento integer := 0;
begin
  loop
    v_intento := v_intento + 1;
    v_candidato := 'Jugador' || lpad((floor(random() * 10000))::int::text, 4, '0');
    exit when v_intento >= 30
      or not exists (select 1 from public.profiles where nombre = v_candidato and role = 'jugador');
  end loop;

  if exists (select 1 from public.profiles where nombre = v_candidato and role = 'jugador') then
    v_candidato := left('Jugador' || replace(new.id::text, '-', ''), 16);
  end if;

  insert into public.profiles (id, nombre, device_id)
  values (
    new.id,
    v_candidato,
    nullif(new.raw_user_meta_data ->> 'device_id', '')::uuid
  );

  insert into public.comodines_inventario (usuario_id, tipo, cantidad)
  values
    (new.id, 'tiempo', 1),
    (new.id, 'pais', 1),
    (new.id, 'km1000', 1),
    (new.id, 'km500', 0);

  return new;
end;
$$;

-- 7. Lectura del inventario propio para pintar el pill/pantalla de
-- Comodines (agregado por tipo, siempre las 4 filas aunque cantidad sea 0).
create function mis_comodines()
returns table (tipo tipo_comodin, cantidad integer)
language sql
security invoker
set search_path = public
stable
as $$
  select tipo, cantidad
  from comodines_inventario
  where usuario_id = auth.uid()
  order by tipo;
$$;

revoke execute on function mis_comodines() from public;
grant execute on function mis_comodines() to authenticated;

-- 8. Consumo de un comodin (D5): valida antes de tocar nada, decrementa
-- inventario y marca el intento de forma atomica -- cualquier
-- raise exception revierte los update previos dentro de la misma funcion.
create function usar_comodin(p_intento_id uuid, p_desafio_id uuid, p_tipo tipo_comodin)
returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_pais text;
  v_lat double precision;
  v_lng double precision;
  v_actualizado integer;
begin
  -- El desafio debe pertenecer a este intento del propio usuario y no estar
  -- respondido todavia -- no hace falta un flag de "intento abierto" aparte.
  if not exists (
    select 1
    from intentos_nivel it
    join intento_desafios idf on idf.intento_id = it.id
    where it.id = p_intento_id
      and it.usuario_id = auth.uid()
      and idf.desafio_id = p_desafio_id
      and not exists (
        select 1 from respuestas_desafio rd
        where rd.intento_id = p_intento_id and rd.desafio_id = p_desafio_id
      )
  ) then
    raise exception 'intento_o_desafio_invalido';
  end if;

  -- D4: para "pais", comprobar disponibilidad de dato ANTES de decrementar
  -- inventario -- una pregunta sin pais registrado no debe costarle el
  -- comodin al jugador.
  if p_tipo = 'pais' then
    select d.pais into v_pais from desafios d where d.id = p_desafio_id;
    if v_pais is null then
      raise exception 'pais_no_disponible';
    end if;
  end if;

  update comodines_inventario
  set cantidad = cantidad - 1
  where usuario_id = auth.uid() and tipo = p_tipo and cantidad > 0
  returning cantidad into v_actualizado;

  if v_actualizado is null then
    raise exception 'sin_comodines_disponibles';
  end if;

  update intentos_nivel
  set comodin_usado = p_tipo
  where id = p_intento_id and usuario_id = auth.uid() and comodin_usado is null;

  if not found then
    -- Ya se uso otro comodin en este intento (posible carrera entre dos
    -- llamadas casi simultaneas): revertir implicitamente al abortar la
    -- transaccion de esta funcion.
    raise exception 'comodin_ya_usado_en_este_intento';
  end if;

  case p_tipo
    when 'tiempo' then
      return jsonb_build_object('tipo', p_tipo, 'extra_segundos', 15);
    when 'pais' then
      return jsonb_build_object('tipo', p_tipo, 'pais', v_pais);
    when 'km1000', 'km500' then
      select d.lat_real, d.lng_real into v_lat, v_lng from desafios d where d.id = p_desafio_id;
      return jsonb_build_object(
        'tipo', p_tipo,
        'lat', v_lat,
        'lng', v_lng,
        'radio_km', case p_tipo when 'km1000' then 1000 else 500 end
      );
  end case;
end;
$$;

revoke execute on function usar_comodin(uuid, uuid, tipo_comodin) from public;
grant execute on function usar_comodin(uuid, uuid, tipo_comodin) to authenticated;

-- 9. Concesion por anuncio (D6): sin verificacion server-side del
-- visionado en esta v1 -- se confia en que la app solo llama aqui tras el
-- callback de recompensa del SDK. El tope diario es la unica mitigacion de
-- abuso; anadir verificacion mas adelante no cambia este contrato.
create function conceder_comodin_por_anuncio(p_tope_diario integer default 5)
returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_tipo tipo_comodin;
  v_tipos constant tipo_comodin[] := array['tiempo', 'pais', 'km1000', 'km500'];
  v_concedidas_hoy integer;
begin
  insert into comodines_concesiones_anuncio (usuario_id, fecha, cantidad)
  values (auth.uid(), current_date, 0)
  on conflict (usuario_id, fecha) do nothing;

  select cantidad into v_concedidas_hoy
  from comodines_concesiones_anuncio
  where usuario_id = auth.uid() and fecha = current_date
  for update;

  if v_concedidas_hoy >= p_tope_diario then
    raise exception 'tope_diario_alcanzado';
  end if;

  v_tipo := v_tipos[1 + floor(random() * array_length(v_tipos, 1))::int];

  update comodines_inventario
  set cantidad = cantidad + 1
  where usuario_id = auth.uid() and tipo = v_tipo;

  update comodines_concesiones_anuncio
  set cantidad = cantidad + 1
  where usuario_id = auth.uid() and fecha = current_date;

  return jsonb_build_object('tipo', v_tipo);
end;
$$;

revoke execute on function conceder_comodin_por_anuncio(integer) from public;
grant execute on function conceder_comodin_por_anuncio(integer) to authenticated;
