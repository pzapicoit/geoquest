-- INT-128: el jugador pasa a tener apodo y contraseña. Ver design.md de
-- openspec/changes/int-128-apodo-y-contrasena (D2, D4, D5) para el porque de
-- cada decision referenciada abajo.
--
-- Contexto imprescindible para leer esto (D2): la contraseña necesita un
-- identificador y no queremos ninguno real, asi que la identidad de Auth de
-- cada jugador es SINTETICA y se DERIVA de su apodo, en el cliente:
--
--     sha256(apodo recortado y en minusculas) en hexadecimal || '@geoquest.invalid'
--
-- De ahi que en el panel de Auth los usuarios aparezcan como cadenas
-- hexadecimales: no es un dato roto. El dominio `.invalid` esta reservado por
-- la RFC 2606 y no puede enrutar correo, asi que ese buzon no existe ni puede
-- existir. En el producto no hay email en ningun punto: ni envio, ni
-- verificacion, ni recuperacion.

-- D5: la pantalla de acceso necesita saber que hacer ANTES de intentar nada.
-- `signInWithPassword` responde `Invalid login credentials` tanto si el usuario
-- no existe como si la contraseña es incorrecta -- a proposito, para no filtrar
-- que cuentas existen -- y con eso la pantalla no puede distinguir "ese apodo
-- no es tuyo" de "te has equivocado de contraseña".
--
-- Devuelve el estado y SOLO el estado: nunca la identidad sintetica, ni el id
-- del jugador, ni nada de su progreso. La enumeracion que permite es la que ya
-- permite la pantalla de Clasificacion, donde los apodos estan a la vista; lo
-- unico nuevo que revela es si un apodo tiene contraseña, que por si solo no
-- abre ningun camino.
create function estado_apodo(p_alias text)
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
  -- Comparacion insensible a mayusculas y a espacios sobrantes, igual que la
  -- identidad sintetica de D2: si el hash se calcula sobre el apodo en
  -- minusculas, "Pablo" y "pablo" comparten identidad de acceso y tienen que
  -- responder lo mismo aqui.
  --
  -- `bool_or` y `count` en vez de quedarse con una fila: mas abajo esta
  -- migracion deduplica los alias que solo difieren en mayusculas y hace que la
  -- unicidad pase a ser insensible a ellas, asi que a partir de aqui solo puede
  -- haber una coincidencia. Se deja escrito de forma que un duplicado
  -- inesperado no elija fila al azar: si CUALQUIERA tiene credenciales, el
  -- apodo se trata como accesible con contraseña, que es el unico camino por el
  -- que alguien puede entrar de verdad.
  select count(*), coalesce(bool_or(u.encrypted_password is not null), false)
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

-- La pantalla de acceso la consulta antes de tener la sesion del jugador al
-- que quiere entrar, y en el primer arranque antes de tener ninguna, asi que
-- hace falta `anon` ademas de `authenticated`.
revoke execute on function estado_apodo(text) from public;
grant execute on function estado_apodo(text) to anon, authenticated;

-- La identidad de acceso es sha256 del apodo EN MINUSCULAS (D2), pero el
-- indice unico de alias de INT-111 es exacto (`on profiles (nombre)`), asi que
-- hasta ahora podian convivir "Pablo" y "pablo" como dos jugadores distintos.
-- Con contraseñas eso deja de ser una rareza cosmetica y pasa a ser una
-- perdida de cuenta: los dos derivan la MISMA identidad, el primero que se
-- ponga contraseña se la queda, y el segundo no puede entrar nunca mas en su
-- perfil -- ni recuperarlo, porque no hay recuperacion de contraseña.
--
-- Se arregla en dos pasos: deduplicar lo que ya exista y hacer que la unicidad
-- pase a ser insensible a mayusculas, para que no pueda repetirse.

-- Mismo criterio que el dedupe de INT-111, pero agrupando por
-- lower(btrim(nombre)): se conserva el alias del jugador mas antiguo de cada
-- grupo y a los demas se les añade un sufijo numerado, recortando la base si
-- hace falta para no pasar de los 16 caracteres que impone la app.
with duplicados as (
  select
    p.id,
    p.nombre,
    row_number() over (
      partition by lower(btrim(p.nombre)) order by u.created_at
    ) as posicion
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

-- El indice exacto queda cubierto por el insensible a mayusculas (si
-- lower(btrim(x)) es unico, x tambien lo es), asi que se sustituye en vez de
-- acumular dos indices haciendo el mismo trabajo.
drop index profiles_nombre_jugador_key;
create unique index profiles_nombre_jugador_key
on profiles (lower(btrim(nombre)))
where role = 'jugador';

-- El generador de alias por defecto comprobaba la disponibilidad con `=`, que
-- con el indice de arriba ya no basta: un candidato que solo difiera en
-- mayusculas de uno existente pasaria la comprobacion y reventaria el insert,
-- convirtiendo un alta sin friccion (INT-75) en un alta fallida. Se replica en
-- la comprobacion el mismo criterio que impone el indice.
--
-- Se parte de la version vigente (INT-119, que ademas siembra el inventario de
-- comodines) y solo se cambian las dos comprobaciones.
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
      or not exists (
        select 1 from public.profiles
        where lower(btrim(nombre)) = lower(btrim(v_candidato)) and role = 'jugador'
      );
  end loop;

  if exists (
    select 1 from public.profiles
    where lower(btrim(nombre)) = lower(btrim(v_candidato)) and role = 'jugador'
  ) then
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

-- D4: si la identidad de acceso deriva del apodo, renombrar a un jugador que ya
-- tiene contraseña lo deja fuera de su cuenta -- el hash que calcularia el
-- cliente dejaria de ser el suyo. Y lo deja fuera EN SILENCIO: no se enteraria
-- hasta intentar entrar desde otro movil, cuando ya no hay nada que hacer.
--
-- Por eso se impide en la base y no en la app. Hoy no hay ningun camino que
-- renombre (el panel solo lee `profiles`), asi que esto no rompe nada de lo que
-- existe: esta aqui para el dia que alguien añada un "editar apodo" sin tener
-- presente esta consecuencia.
--
-- El alta SI puede renombrar, porque ocurre antes de que exista la contraseña:
-- registrarse es sesion anonima -> `updateNickname` -> `updateUser` con
-- identidad y contraseña (D6). En el paso del renombrado todavia no hay
-- credenciales, asi que este trigger no se interpone.
create function impide_renombrar_jugador_con_credenciales()
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
        and u.encrypted_password is not null
    )
  then
    raise exception
      'El apodo de un jugador con contraseña no se puede cambiar: su identidad de acceso deriva del apodo';
  end if;

  return new;
end;
$$;

create trigger profiles_apodo_inmutable_con_credenciales
before update of nombre on profiles
for each row
execute function impide_renombrar_jugador_con_credenciales();
