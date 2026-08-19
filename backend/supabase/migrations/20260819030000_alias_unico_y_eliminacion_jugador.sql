-- INT-111 (delta 1): alias único entre jugadores + eliminación completa de
-- una cuenta desde el panel. Ver design.md de
-- openspec/changes/int-111-panel-jugadores-delta-1 para el porque de cada
-- decision referenciada como D1-D5 en los comentarios.

-- D1/D2: dedupe genérico por orden de alta, no una lista de ids fija. Para
-- cada grupo de profiles.nombre duplicado (role = 'jugador') se deja
-- intacto el más antiguo (row_number = 1) y a los demás se les añade
-- ' (n)'; si el resultado supera los 16 caracteres que ya impone la app
-- (INT-89), se trunca la base para que quepa el sufijo.
with duplicados as (
  select
    p.id,
    p.nombre,
    row_number() over (partition by p.nombre order by u.created_at) as posicion
  from profiles p
  join auth.users u on u.id = p.id
  where p.role = 'jugador'
)
update profiles p
set nombre = case
  when length(p.nombre) + length(' (' || d.posicion || ')') <= 16
    then p.nombre || ' (' || d.posicion || ')'
  else left(p.nombre, 16 - length(' (' || d.posicion || ')')) || ' (' || d.posicion || ')'
end
from duplicados d
where d.id = p.id
  and d.posicion > 1;

-- Índice único parcial (no un constraint de tabla: los constraints UNIQUE
-- no admiten WHERE) -- el requisito es "dos jugadores no comparten alias",
-- no "ningún perfil comparte alias con otro", así que se acota a
-- role = 'jugador' en vez de a toda la tabla.
create unique index profiles_nombre_jugador_key on profiles (nombre) where role = 'jugador';

-- D3: handle_new_user() reintenta el alias por defecto en vez de fallar.
-- Sin este cambio, el índice único de arriba convertiría cualquier
-- colisión de alta anónima (10 000 combinaciones posibles) en un alta
-- fallida -- una regresión sobre el flujo "sin fricción" de INT-75. Tope
-- de 30 intentos; si se agotan (extremadamente improbable), se cae a un
-- candidato derivado del propio id del usuario, recortado a 16 caracteres
-- -- único por construcción, sin necesidad de comprobarlo.
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
  return new;
end;
$$;

-- D5: tabla de auditoría propia para la eliminación, con la misma forma
-- que auditoria_reinicio_progreso (INT-111) -- no se reutiliza esa tabla
-- para no alterar un esquema/RPC ya archivado y en producción.
create table auditoria_eliminacion_jugador (
  id uuid primary key default gen_random_uuid(),
  admin_id uuid not null references profiles (id),
  jugador_id uuid not null,
  alias_jugador text not null,
  creado_en timestamptz not null default now()
);

alter table auditoria_eliminacion_jugador enable row level security;

create policy "auditoria_eliminacion_jugador_select_admin"
on auditoria_eliminacion_jugador
for select
to authenticated
using (is_admin());

-- D4: eliminar_jugador() borra auth.users por SQL directo (el rol postgres,
-- dueño de esta función, ya tiene DELETE sobre auth.users -- comprobado
-- contra el remoto) -- cascada real hasta profiles y de ahí hasta
-- progreso_usuario_nivel/intentos_nivel/respuestas_desafio por las FKs
-- existentes. No hace falta la API de administración de Supabase.
create function eliminar_jugador(p_jugador_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_alias text;
begin
  if not is_admin() then
    raise exception 'Solo un admin puede eliminar un jugador';
  end if;

  select nombre into v_alias
  from profiles
  where id = p_jugador_id and role = 'jugador';

  if v_alias is null then
    raise exception 'El jugador % no existe o no tiene rol de jugador', p_jugador_id;
  end if;

  insert into auditoria_eliminacion_jugador (admin_id, jugador_id, alias_jugador)
  values (auth.uid(), p_jugador_id, v_alias);

  delete from auth.users where id = p_jugador_id;
end;
$$;

revoke execute on function eliminar_jugador(uuid) from public;
grant execute on function eliminar_jugador(uuid) to authenticated;
