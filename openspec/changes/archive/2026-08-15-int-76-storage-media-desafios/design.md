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

### RLS mínimo en `profiles` (D5, añadido tras revisión adversarial)

La policy de escritura de Storage confía en `profiles.role = 'admin'`. Esa
confianza es falsa mientras `profiles` no tenga RLS: `profiles` vive en el
esquema `public`, expuesto por PostgREST, y sin RLS cualquier usuario
autenticado (incluida una sesión anónima) puede hacer

```
PATCH /rest/v1/profiles?id=eq.<su-propio-id>
{"role": "admin"}
```

y auto-promocionarse. Se confirmó contra el proyecto remoto: una sesión
anónima recién creada consiguió `role = 'admin'` con una sola petición REST
usando únicamente su propio JWT. A partir de ahí, esa sesión pasa también
la policy de escritura del bucket — el "solo admin" quedaba en el papel,
no en la práctica.

Por eso este cambio añade el RLS mínimo imprescindible para que la premisa
de la policy de Storage sea cierta, sin adelantar el resto de INT-77:

- `alter table public.profiles enable row level security`
- Una única policy: `profiles_select_own` (`select`, `to authenticated`,
  `using (id = auth.uid())`) — necesaria porque la propia policy de
  Storage hace `exists (select 1 from public.profiles where id =
  auth.uid() and role = 'admin')`, y esa subconsulta corre bajo el RLS del
  invocador: sin una policy de lectura de la fila propia, ni siquiera un
  admin real pasaría el check.
- **Ninguna** policy de `insert`/`update`/`delete` para `authenticated` ni
  `anon`. Con RLS activado y sin policy de escritura, Postgres deniega por
  defecto: nadie puede tocar su propia fila desde el cliente, ni para
  cambiar `nombre`/`avatar_url` ni para cambiar `role`.
- El trigger `handle_new_user` (INT-75) sigue funcionando igual: está
  declarado `security definer`, así que no pasa por RLS al insertar la
  fila de `profiles` en el alta.

Alcance explícitamente fuera de esto: policies de escritura para que un
jugador edite su propio `nombre`/`avatar_url`, y todo el RLS de
temáticas/niveles/desafíos/progreso — eso sigue siendo INT-77. Hoy no
existe ningún código (`app/`, `panel/`) que escriba en `profiles`, así que
no reabrir esa escritura no rompe nada.

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
- **`profiles.role` auto-editable sin RLS** (D5) → Mitigación aplicada en
  este mismo cambio: RLS mínimo en `profiles` (solo lectura de la fila
  propia, sin policy de escritura). Confirmado con una prueba real de
  auto-promoción antes y después del fix.

## Migration Plan

1. Migración `20260815102938_storage_challenge_media.sql` en
   `backend/supabase/migrations/`: bucket + policies de Storage.
2. Segunda migración `storage_profiles_rls_minimo` (D5): `enable row level
   security` en `profiles` + policy `profiles_select_own`.
3. `supabase db push` contra el proyecto remoto (eu-west-1).
4. `supabase db lint --linked` sobre las migraciones como gate de calidad.
5. Verificación manual: subir una imagen y un video de ejemplo con la clave
   de servicio, confirmar lectura pública anónima, confirmar que una
   escritura sin rol admin es rechazada, y confirmar que un usuario ya no
   puede auto-promocionarse a `admin` editando su propia fila.

Rollback: migración de reversa que borra las 4 policies y hace `delete from
storage.buckets where id = 'challenge-media'` (y sus objetos, si los
hubiera). No hay stack local que resetear; el rollback se aplica también
por `supabase db push` de la migración de reversa.

## Open Questions

- ¿Se necesita en algún momento transformación de imágenes (resize/webp
  automático)? Supabase lo ofrece en plan Pro vía
  `storage.image_transformation`. Fuera de alcance mientras no haga falta.
