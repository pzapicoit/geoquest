-- INT-75: alta sin fricción (sesión anónima) y vínculo de dispositivo.
--
-- profiles quedó sin trigger de creación a propósito en INT-74; este es ese
-- trigger. Cubre tanto altas anónimas como con email/contraseña: ambas
-- reciben nombre por defecto y rol 'jugador' (default de la columna); las
-- cuentas admin se dan de alta aparte, sin pasar por este camino. Ver D3 y D6
-- de openspec/changes/int-75-registro-anonimo/design.md.

alter table profiles
  add column device_id uuid;

create function handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, nombre, device_id)
  values (
    new.id,
    'Jugador' || lpad((floor(random() * 10000))::int::text, 4, '0'),
    nullif(new.raw_user_meta_data ->> 'device_id', '')::uuid
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();
