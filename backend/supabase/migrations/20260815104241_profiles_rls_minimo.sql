-- INT-76 (D5): RLS minimo en profiles.
--
-- Hallazgo de la revision adversarial de int-76-storage-media-desafios:
-- las policies de escritura del bucket challenge-media confian en
-- profiles.role = 'admin', pero sin RLS en profiles cualquier usuario
-- autenticado (incluida una sesion anonima) puede auto-promocionarse con
-- un PATCH /rest/v1/profiles sobre su propia fila. Confirmado contra el
-- proyecto remoto antes de este fix.
--
-- Alcance deliberadamente minimo: solo lo necesario para que esa premisa
-- sea cierta. El resto de RLS del esquema del juego sigue siendo INT-77.

alter table public.profiles enable row level security;

-- Necesaria para que la propia policy de storage.objects
-- (challenge_media_admin_*) pueda leer la fila del invocador: esa
-- subconsulta corre bajo el RLS de quien llama, no como security definer.
create policy "profiles_select_own"
on public.profiles
for select
to authenticated
using (id = auth.uid());

-- Sin policy de insert/update/delete para authenticated/anon: con RLS
-- activado y ninguna policy que lo permita, la base de datos deniega por
-- defecto. Nadie puede tocar su propia fila desde el cliente, ni siquiera
-- para editar nombre/avatar_url (eso llegara cuando haga falta, INT-77).
--
-- El trigger handle_new_user (INT-75) sigue funcionando: esta declarado
-- security definer, asi que no pasa por RLS al insertar en el alta.
