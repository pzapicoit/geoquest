## 1. Migración SQL

- [x] 1.1 Crear migración `backend/supabase/migrations/<timestamp>_storage_challenge_media.sql`
- [x] 1.2 Insertar el bucket `challenge-media` en `storage.buckets` con
      `public = true`, `file_size_limit = 52428800` (50 MiB) y
      `allowed_mime_types = ARRAY['image/jpeg','image/png','image/webp','video/mp4']`
- [x] 1.3 Crear policy `challenge_media_public_read` (`select` para `public`,
      filtrando por `bucket_id = 'challenge-media'`)
- [x] 1.4 Crear policies `challenge_media_admin_insert` / `_update` /
      `_delete` (para `authenticated`, exigiendo fila en `public.profiles`
      con `id = auth.uid()` y `role = 'admin'`)
- [x] 1.5 Comentarios de cabecera en la migración referenciando INT-76 y
      las decisiones D1-D4 de `design.md`

## 2. Aplicar y verificar en el proyecto remoto

- [x] 2.1 `supabase db push` contra el proyecto remoto
- [x] 2.2 `supabase db lint` sobre las migraciones (gate de calidad backend) —
      via `--linked` (sin Docker, remote-first)
- [x] 2.3 Subir una imagen de ejemplo (`imagen/<uuid>.jpg`) con la clave de
      servicio y confirmar que se acepta
- [x] 2.4 Subir un video de ejemplo (`video/<uuid>.mp4`) con la clave de
      servicio y confirmar que se acepta
- [x] 2.5 Confirmar lectura pública anónima de ambos archivos de ejemplo
- [x] 2.6 Confirmar que una subida sin rol admin (jugador/anónimo) es
      rechazada — sesión anónima real (`profiles.role = 'jugador'`),
      subida rechazada con RLS violation. Simétricamente, se confirmó que
      un usuario real promovido a `profiles.role = 'admin'` sí puede subir
      y borrar (vía su propio JWT, no con la clave de servicio, que se
      salta RLS y no prueba la policy). Ambos usuarios de prueba borrados
      tras la verificación
- [x] 2.7 Confirmar que un archivo de tipo o tamaño no permitido es
      rechazado — `text/plain` rechazado (`InvalidMimeType`) y archivo de
      51 MiB rechazado (`EntityTooLarge`)
- [x] 2.8 Borrar los archivos de ejemplo subidos para la verificación —
      confirmado con lectura pública devolviendo 404 tras el borrado

## 3. Documentación

- [x] 3.1 Actualizar `.devplugin/architecture.md`: estado del módulo
      `backend/` (Storage configurado en INT-76)
