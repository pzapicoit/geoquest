-- INT-76: bucket de Storage para el contenido de los desafíos (imagen/video).
--
-- Un único bucket `challenge-media` (D1 de design.md de
-- openspec/changes/int-76-storage-media-desafios): límite de tamaño y tipos
-- MIME compartidos entre imagen y video, sin distinción por tipo porque el
-- issue pide un solo bucket y 50 MiB no supone problema real para imágenes.
--
-- Lectura pública, escritura restringida a profiles.role = 'admin' (D2):
-- reutiliza el rol ya creado en INT-74, sin tabla ni claim nuevos.

-- 1. Bucket
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'challenge-media',
  'challenge-media',
  true,
  52428800, -- 50 MiB
  array['image/jpeg', 'image/png', 'image/webp', 'video/mp4']
);

-- 2. Lectura pública (cualquiera, con o sin sesión)
create policy "challenge_media_public_read"
on storage.objects
for select
to public
using (bucket_id = 'challenge-media');

-- 3. Escritura solo para admin (D2: sesiones anónimas tienen profiles.role
-- = 'jugador' por defecto, así que el CHECK las excluye igual que a
-- cualquier jugador autenticado)
create policy "challenge_media_admin_insert"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'challenge-media'
  and exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin'
  )
);

create policy "challenge_media_admin_update"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'challenge-media'
  and exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin'
  )
)
with check (
  bucket_id = 'challenge-media'
  and exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin'
  )
);

create policy "challenge_media_admin_delete"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'challenge-media'
  and exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin'
  )
);
