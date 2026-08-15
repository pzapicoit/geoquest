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

## 4. RLS mínimo en `profiles` (D5 — cierre de hallazgo de la revisión adversarial)

- [x] 4.1 Confirmar de forma empírica, contra el proyecto remoto, que una
      sesión anónima puede auto-promocionarse a `role = 'admin'` vía REST
      antes del fix (reproducir el hallazgo) — confirmado: `PATCH
      /rest/v1/profiles` con el JWT propio cambió `role` a `admin`
- [x] 4.2 Crear migración `backend/supabase/migrations/20260815104241_profiles_rls_minimo.sql`
- [x] 4.3 `alter table public.profiles enable row level security`
- [x] 4.4 Policy `profiles_select_own` (`select`, `to authenticated`,
      `using (id = auth.uid())`)
- [x] 4.5 Ninguna policy de `insert`/`update`/`delete` para
      `authenticated`/`anon` (deniega por defecto)
- [x] 4.6 `supabase db push` + `supabase db lint --linked` — sin errores
- [x] 4.7 Repetir la prueba de auto-promoción del 4.1 y confirmar que ahora
      se rechaza — `PATCH` devuelve `200` con `[]` (0 filas afectadas por
      RLS); `role` confirmado como `jugador` tras el intento (vía clave de
      servicio)
- [x] 4.8 Confirmar que un admin real sigue pudiendo escribir en el bucket
      (la subconsulta de la policy de Storage sigue viendo su propia fila
      gracias a `profiles_select_own`) — confirmado, subida aceptada con
      el JWT propio del usuario promovido
- [x] 4.9 Confirmar que el trigger `handle_new_user` (INT-75) sigue creando
      perfiles con normalidad en una alta anónima nueva — confirmado, fila
      creada con `role = 'jugador'` por defecto
- [x] 4.10 Limpiar usuarios de prueba creados durante esta verificación —
      3 usuarios de prueba borrados con la API admin de Auth
