-- INT-77: RLS del resto del esquema del juego (profiles ya lo tenia desde
-- INT-76) + nueva policy de update en profiles. Ver design.md de
-- openspec/changes/int-77-politicas-rls para el porque de cada decision
-- referenciada abajo.

-- Funcion auxiliar reutilizable en las policies de esta migracion.
-- `security invoker` (no `definer`): solo necesita ver la propia fila del
-- invocador, y profiles_select_own (INT-76) ya se lo permite.
create function is_admin()
returns boolean
language sql
stable
security invoker
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles
    where id = auth.uid()
      and role = 'admin'
  );
$$;

-- tematicas / niveles / nivel_desafios: lectura publica para cualquier
-- autenticado (incluida sesion anonima), escritura solo admin.
alter table public.tematicas enable row level security;
alter table public.niveles enable row level security;
alter table public.nivel_desafios enable row level security;

create policy "tematicas_select_authenticated"
on public.tematicas
for select
to authenticated
using (true);

create policy "tematicas_admin_insert"
on public.tematicas
for insert
to authenticated
with check (is_admin());

create policy "tematicas_admin_update"
on public.tematicas
for update
to authenticated
using (is_admin())
with check (is_admin());

create policy "tematicas_admin_delete"
on public.tematicas
for delete
to authenticated
using (is_admin());

create policy "niveles_select_authenticated"
on public.niveles
for select
to authenticated
using (true);

create policy "niveles_admin_insert"
on public.niveles
for insert
to authenticated
with check (is_admin());

create policy "niveles_admin_update"
on public.niveles
for update
to authenticated
using (is_admin())
with check (is_admin());

create policy "niveles_admin_delete"
on public.niveles
for delete
to authenticated
using (is_admin());

create policy "nivel_desafios_select_authenticated"
on public.nivel_desafios
for select
to authenticated
using (true);

create policy "nivel_desafios_admin_insert"
on public.nivel_desafios
for insert
to authenticated
with check (is_admin());

create policy "nivel_desafios_admin_update"
on public.nivel_desafios
for update
to authenticated
using (is_admin())
with check (is_admin());

create policy "nivel_desafios_admin_delete"
on public.nivel_desafios
for delete
to authenticated
using (is_admin());

-- desafios: sin policy de lectura para jugadores a proposito (evita ver
-- lat_real/lng_real/nombre_lugar antes de responder; ese acceso llega via
-- la vista desafios_para_jugar de INT-95, fuera de esta migracion). Si se
-- permite select a is_admin(): gestionar contenido sin poder leerlo de
-- vuelta no cumple el objetivo del ticket, y el riesgo de exponer esta
-- tabla a un admin ya verificado es nulo.
alter table public.desafios enable row level security;

create policy "desafios_admin_select"
on public.desafios
for select
to authenticated
using (is_admin());

create policy "desafios_admin_insert"
on public.desafios
for insert
to authenticated
with check (is_admin());

create policy "desafios_admin_update"
on public.desafios
for update
to authenticated
using (is_admin())
with check (is_admin());

create policy "desafios_admin_delete"
on public.desafios
for delete
to authenticated
using (is_admin());

-- intentos_nivel: visible/editable solo por su propio usuario.
alter table public.intentos_nivel enable row level security;

create policy "intentos_nivel_select_own"
on public.intentos_nivel
for select
to authenticated
using (usuario_id = auth.uid());

create policy "intentos_nivel_insert_own"
on public.intentos_nivel
for insert
to authenticated
with check (usuario_id = auth.uid());

create policy "intentos_nivel_update_own"
on public.intentos_nivel
for update
to authenticated
using (usuario_id = auth.uid())
with check (usuario_id = auth.uid());

-- respuestas_desafio: select/insert propios, sin update (D5 de INT-74: es
-- historial inmutable, y el unique(intento_id, desafio_id) ya impide
-- volver a responder el mismo desafio dentro de un intento). No tiene
-- usuario_id propio, la pertenencia se resuelve via
-- intento_id -> intentos_nivel.usuario_id.
alter table public.respuestas_desafio enable row level security;

create policy "respuestas_desafio_select_own"
on public.respuestas_desafio
for select
to authenticated
using (
  exists (
    select 1
    from public.intentos_nivel
    where intentos_nivel.id = respuestas_desafio.intento_id
      and intentos_nivel.usuario_id = auth.uid()
  )
);

create policy "respuestas_desafio_insert_own"
on public.respuestas_desafio
for insert
to authenticated
with check (
  exists (
    select 1
    from public.intentos_nivel
    where intentos_nivel.id = respuestas_desafio.intento_id
      and intentos_nivel.usuario_id = auth.uid()
  )
);

-- progreso_usuario_nivel: visible/editable solo por su propio usuario.
alter table public.progreso_usuario_nivel enable row level security;

create policy "progreso_usuario_nivel_select_own"
on public.progreso_usuario_nivel
for select
to authenticated
using (usuario_id = auth.uid());

create policy "progreso_usuario_nivel_insert_own"
on public.progreso_usuario_nivel
for insert
to authenticated
with check (usuario_id = auth.uid());

create policy "progreso_usuario_nivel_update_own"
on public.progreso_usuario_nivel
for update
to authenticated
using (usuario_id = auth.uid())
with check (usuario_id = auth.uid());

-- profiles: nueva policy de update de la propia fila (profiles_select_own
-- de INT-76 no se toca). El with check compara `role` contra el valor ya
-- almacenado via subconsulta -- una sentencia no ve, dentro de si misma,
-- las filas que ella misma esta modificando (comportamiento estandar de
-- Postgres) -- asi que nadie puede auto-promocionarse. Se descarta un
-- trigger before update porque tambien bloquearia la asignacion manual del
-- primer admin desde el SQL editor/dashboard; postgres/service_role tienen
-- bypassrls y no pasan por esta policy, asi que ese camino sigue intacto.
create policy "profiles_update_own"
on public.profiles
for update
to authenticated
using (id = auth.uid())
with check (
  id = auth.uid()
  and role = (select p.role from public.profiles p where p.id = auth.uid())
);
