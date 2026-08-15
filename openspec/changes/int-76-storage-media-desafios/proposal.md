## Why

El banco de desafíos (`desafios`, INT-74) ya modela `imagen_url` y `video_url`
para desafíos de tipo imagen/video, pero no existe ningún sitio donde alojar
esos archivos ni una política que diga quién puede subirlos y quién puede
leerlos. Sin esto no se puede cargar contenido real de desafíos ni construir
las URLs que la app consumirá.

## What Changes

- Crear el bucket `challenge-media` en Supabase Storage vía migración SQL
  (insert en `storage.buckets`), con límite de tamaño y tipos MIME permitidos
  a nivel de bucket.
- Definir políticas RLS sobre `storage.objects` para ese bucket: lectura
  pública (`select`) y escritura (`insert`/`update`/`delete`) restringida a
  usuarios cuyo `profiles.role = 'admin'`.
- Definir y documentar la convención de carpetas/nombres dentro del bucket
  (`{tipo}/{desafio_id}.{ext}`) para que las URLs sean predecibles.
- Documentar los límites concretos de tamaño/formato aceptados para imagen y
  video.
- Verificar subida y lectura de un archivo de ejemplo de cada tipo contra el
  bucket remoto, dejando constancia del resultado.

## Capabilities

### New Capabilities
- `challenge-media-storage`: bucket de Storage para el contenido de los
  desafíos (imagen/video), sus políticas de acceso público de lectura /
  admin de escritura, y la convención de organización de archivos.

### Modified Capabilities
(ninguna — no cambian requisitos de `game-data-model` ni de otras specs
existentes; esto añade una capability nueva sobre Storage)

## Impact

- Nueva migración en `backend/supabase/migrations/` (bucket + policies).
- `backend/supabase/config.toml` (referencia de `file_size_limit` global ya
  existente; no requiere cambios si el bucket define su propio límite).
- No afecta código de `app/` ni `panel/` en este cambio: solo deja el bucket
  listo para que un futuro cambio (subida desde panel de admin, INT-80) lo
  use.
- No depende de RLS de tablas del juego (INT-77): las políticas de Storage
  son un sistema RLS aparte, sobre `storage.objects`.
