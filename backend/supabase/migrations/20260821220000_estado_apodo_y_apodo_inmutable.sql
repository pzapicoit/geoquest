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
  -- `bool_or` en vez de quedarse con una fila: el indice unico de alias es
  -- exacto, asi que pueden convivir "Pablo" y "pablo" dados de alta antes de
  -- este cambio. Si CUALQUIERA de ellos tiene credenciales, el apodo se trata
  -- como accesible con contraseña -- que es el unico camino por el que alguien
  -- puede entrar de verdad.
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
