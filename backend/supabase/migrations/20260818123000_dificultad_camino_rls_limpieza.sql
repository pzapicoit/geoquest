-- INT-106: RLS de las tablas nuevas y limpieza final. Cuarta y ultima de
-- cuatro migraciones. Las policies de niveles/nivel_desafios no se tocan
-- explicitamente -- se dropean solas junto con sus tablas al final de este
-- fichero. Las policies de tematicas/desafios/camino no cambian de
-- contenido (nunca mencionaron niveles/nivel_desafios en su USING/WITH
-- CHECK), asi que no hace falta reescribirlas.

-- 4.1 RLS de dificultad_defaults: lectura publica para autenticados,
-- escritura (update) solo admin. Sin policy de insert/delete: el catalogo
-- ya viene sembrado con sus 5 filas (migracion de esquema) y el trigger
-- dificultad_defaults_no_delete bloquea cualquier intento de borrado
-- ademas -- defensa en profundidad, no solo RLS.
alter table public.dificultad_defaults enable row level security;

create policy "dificultad_defaults_select_authenticated"
on public.dificultad_defaults
for select
to authenticated
using (true);

create policy "dificultad_defaults_admin_update"
on public.dificultad_defaults
for update
to authenticated
using (is_admin())
with check (is_admin());

-- 4.2 confirmacion de que ninguna referencia activa queda pendiente antes
-- del drop de 4.3 -- si esto fallara, seria un bug de las migraciones
-- anteriores, no un caso esperado.
do $$
begin
  if exists (select 1 from information_schema.columns where table_name = 'camino' and column_name = 'nivel_id') then
    raise exception 'INT-106: camino.nivel_id todavia existe -- revisar la migracion de datos antes de borrar niveles';
  end if;
  if exists (select 1 from information_schema.columns where table_name = 'intentos_nivel' and column_name = 'nivel_id') then
    raise exception 'INT-106: intentos_nivel.nivel_id todavia existe -- revisar la migracion de datos antes de borrar niveles';
  end if;
  if exists (select 1 from information_schema.columns where table_name = 'progreso_usuario_nivel' and column_name = 'nivel_id') then
    raise exception 'INT-106: progreso_usuario_nivel.nivel_id todavia existe -- revisar la migracion de datos antes de borrar niveles';
  end if;
end $$;

-- 4.3 drop de nivel_desafios y niveles -- sus policies RLS se van con ellas.
drop table nivel_desafios;
drop table niveles;
