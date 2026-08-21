-- INT-128, corrección de 20260821220000.
--
-- Esa migración decidía "este jugador tiene contraseña" con
-- `auth.users.encrypted_password is not null`. Es falso: GoTrue **no** deja ese
-- campo a null en las altas anónimas, así que la condición se cumplía para todo
-- el mundo. Consecuencias, comprobadas contra el remoto:
--
--  * el trigger rechazaba renombrar a un usuario anónimo recién creado, y como
--    el alta de un jugador es "sesión anónima -> apodo -> contraseña" (D6),
--    NINGÚN jugador podía registrarse;
--  * `estado_apodo` respondía 'con_contrasena' para cualquier invitado, así que
--    la pantalla habría pedido una contraseña que ese perfil no tiene.
--
-- Lo que de verdad distingue a un jugador con credenciales es tener una
-- contraseña **no vacía**, que es justo lo que le pone `updateUser` al
-- convertirse (D8).

create or replace function estado_apodo(p_alias text)
returns text
language plpgsql
security definer
stable
set search_path = public
as $$
declare
  v_coincidencias integer;
  v_alguna_con_credenciales boolean;
begin
  select
    count(*),
    coalesce(bool_or(coalesce(u.encrypted_password, '') <> ''), false)
    into v_coincidencias, v_alguna_con_credenciales
  from profiles p
  join auth.users u on u.id = p.id
  where p.role = 'jugador'
    and lower(btrim(p.nombre)) = lower(btrim(coalesce(p_alias, '')));

  if v_coincidencias = 0 then
    return 'libre';
  elsif v_alguna_con_credenciales then
    return 'con_contrasena';
  else
    return 'sin_contrasena';
  end if;
end;
$$;

create or replace function impide_renombrar_jugador_con_credenciales()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.nombre is distinct from old.nombre
    and exists (
      select 1
      from auth.users u
      where u.id = old.id
        and coalesce(u.encrypted_password, '') <> ''
    )
  then
    raise exception
      'El apodo de un jugador con contraseña no se puede cambiar: su identidad de acceso deriva del apodo';
  end if;

  return new;
end;
$$;
