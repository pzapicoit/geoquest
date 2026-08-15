## Context

`desafios` (INT-74) tiene `imagen_url` y `video_url` como texto libre, sin
ningún sitio real donde vivan esos archivos. Supabase Storage guarda buckets
en `storage.buckets` y sus permisos como policies RLS normales sobre
`storage.objects` — es el mismo mecanismo de policies que el resto del
esquema, así que encaja con el enfoque remote-first ya establecido: todo por
migración SQL, nada por el dashboard a mano.

El issue pide explícitamente **un** bucket (`challenge-media`), no uno por
tipo de contenido.

## Goals / Non-Goals

**Goals:**
- Bucket `challenge-media` creado por migración, con lectura pública y
  escritura restringida a `profiles.role = 'admin'`.
- Límite de tamaño y lista de MIME types aceptados, forzados por Supabase
  Storage a nivel de bucket (no por trigger custom).
- Convención de carpeta/nombre documentada y predecible a partir del
  `tipo` y `id` de un desafío.
- Verificación manual de subida/lectura contra el proyecto remoto.

**Non-Goals:**
- Enforcement automático de duración de video o de límites de tamaño
  *distintos* para imagen vs. video dentro del mismo bucket (requeriría un
  trigger sobre `storage.objects` inspeccionando `metadata`). Se documenta
  como convención a respetar por quien sube contenido, no como constraint de
  base de datos.
- Flujo de subida desde el panel de administración (INT-80) — este cambio
  solo dejar el bucket listo para que ese flujo lo use.
- RLS de las tablas del juego (`desafios`, etc. — INT-77). Las policies de
  Storage son un sistema aparte sobre `storage.objects` y no dependen de
  ello.

## Decisions

### Un único bucket con límite compartido

Se crea un solo bucket `challenge-media` (según el issue), con
`file_size_limit` fijado al mayor de los dos casos de uso — video — y
`allowed_mime_types` cubriendo ambos formatos:

- Imágenes: `image/jpeg`, `image/png`, `image/webp`
- Video: `video/mp4`
- `file_size_limit`: 50 MiB (`52428800` bytes) — coincide con el límite
  global ya declarado en `backend/supabase/config.toml` (`[storage]
  file_size_limit = "50MiB"`), así que no hace falta tocar ese fichero.

Alternativa descartada: dos buckets (`challenge-images` /
`challenge-videos`) para poder poner límites distintos por tipo. Se
descarta porque el issue pide un bucket concreto y porque, en la práctica,
un límite superior compartido (50 MiB) no supone ningún problema real para
imágenes — nadie va a subir una imagen de 50 MiB por error sin que se note
en revisión de contenido.

### Policies sobre `storage.objects`, no sobre el bucket

Supabase Storage no tiene una "policy de bucket" separada: el control de
acceso se hace con RLS normal sobre `storage.objects`, filtrando por
`bucket_id`. Se crean 4 policies:

- `challenge_media_public_read` — `select` para `public`, sin restricción
  adicional más que `bucket_id = 'challenge-media'`.
- `challenge_media_admin_insert` / `_update` / `_delete` — para
  `authenticated`, exigiendo que exista una fila en `public.profiles` con
  `id = auth.uid()` y `role = 'admin'`.

Esto reutiliza `profiles.role`, ya creado en INT-74, sin introducir un rol o
tabla nueva solo para Storage.

### Convención de carpeta y nombre: `{tipo}/{desafio_id}.{ext}`

- `imagen/<desafio_id>.jpg|png|webp`
- `video/<desafio_id>.mp4`

Un desafío tiene como máximo un archivo (la exclusividad ya la garantiza el
`CHECK` de `desafios`), así que el `id` del desafío como nombre de archivo
identifica el objeto de forma única y hace trivial construir la URL pública
a partir de la fila (`storage/v1/object/public/challenge-media/{tipo}/{id}.{ext}`).

Flujo esperado (para cuando exista un cliente que suba, INT-80): se crea
primero la fila en `desafios` para obtener su `id`, se sube el archivo a la
ruta correspondiente, y se actualiza `imagen_url`/`video_url` con la URL
pública resultante. Este cambio no implementa ese flujo, solo dejar el
bucket y la convención listos para él.

### Migración SQL, no dashboard

Igual que el resto del esquema: la creación del bucket y las policies viven
en una migración versionada (`insert into storage.buckets`, `create policy
... on storage.objects`), aplicada con `supabase db push`. Nada se crea a
mano en el dashboard, para que `supabase db reset --linked` siga
reconstruyendo el proyecto al completo desde las migraciones.

## Risks / Trade-offs

- **No hay límite de duración para video** → Mitigación: fuera de alcance
  automatizado; se documenta como convención (clips cortos, ~30s) a revisar
  en curación de contenido manual hasta que haga falta algo más estricto.
- **Un límite de tamaño único (50 MiB) es generoso para imágenes** →
  Mitigación: aceptable para un proyecto de este tamaño; si en el futuro se
  quiere apretar, un trigger `before insert` sobre `storage.objects` puede
  inspeccionar `metadata->>'mimetype'` y `metadata->>'size'` sin tocar el
  esquema de `desafios`.
- **No existe todavía ningún cliente que suba archivos** → Mitigación: la
  verificación de este cambio se hace con una subida de prueba manual
  (`supabase-js` o `curl` con la clave de servicio) contra el proyecto
  remoto, no con un test automatizado — coherente con cómo se verificaron
  INT-73/74 (infraestructura sin código de aplicación).

## Migration Plan

1. Nueva migración `NNNNNNNNNNNNNN_storage_challenge_media.sql` en
   `backend/supabase/migrations/`.
2. `supabase db push` contra el proyecto remoto (eu-west-1).
3. `supabase db lint` sobre las migraciones como gate de calidad.
4. Verificación manual: subir una imagen y un video de ejemplo con la clave
   de servicio, confirmar lectura pública anónima y confirmar que una
   escritura sin rol admin es rechazada.

Rollback: migración de reversa que borra las 4 policies y hace `delete from
storage.buckets where id = 'challenge-media'` (y sus objetos, si los
hubiera). No hay stack local que resetear; el rollback se aplica también
por `supabase db push` de la migración de reversa.

## Open Questions

- ¿Se necesita en algún momento transformación de imágenes (resize/webp
  automático)? Supabase lo ofrece en plan Pro vía
  `storage.image_transformation`. Fuera de alcance mientras no haga falta.
