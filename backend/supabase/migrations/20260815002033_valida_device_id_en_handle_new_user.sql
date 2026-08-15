-- INT-75: hallazgo de revisión adversarial sobre 20260814235903.
--
-- `raw_user_meta_data ->> 'device_id'` venía sin validar antes de castear a
-- uuid: un valor no-uuid (cliente bugueado, llamada directa a la API) hacía
-- fallar el cast y con él el insert completo en auth.users, bloqueando el
-- alta. Se sustituye handle_new_user() por una versión que solo castea
-- cuando el valor tiene forma de UUID; si no, guarda device_id como null en
-- vez de reventar la transacción.

create or replace function handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  device_id_bruto text := new.raw_user_meta_data ->> 'device_id';
  device_id_valido uuid;
begin
  if device_id_bruto ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    device_id_valido := device_id_bruto::uuid;
  end if;

  insert into public.profiles (id, nombre, device_id)
  values (
    new.id,
    'Jugador' || lpad((floor(random() * 10000))::int::text, 4, '0'),
    device_id_valido
  );
  return new;
end;
$$;
