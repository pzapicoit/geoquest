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
- Habilitar RLS mínimo en `profiles` (solo lectura de la fila propia, sin
  policy de escritura para `authenticated`/`anon`): sin esto, la policy de
  escritura del bucket que comprueba `profiles.role = 'admin'` es papel
  mojado, porque cualquier usuario puede auto-promocionarse editando su
  propia fila por REST (hallazgo de la revisión adversarial de este mismo
  cambio, confirmado contra el proyecto remoto).

## Capabilities

### New Capabilities
- `challenge-media-storage`: bucket de Storage para el contenido de los
  desafíos (imagen/video), sus políticas de acceso público de lectura /
  admin de escritura, y la convención de organización de archivos.

### Modified Capabilities
- `game-data-model`: añade RLS mínimo a `profiles` (lectura de la fila
  propia; ninguna policy de escritura para `authenticated`/`anon`), como
  prerrequisito de seguridad para que la escritura admin-only del bucket
  de Storage sea real y no solo nominal. No toca la jerarquía de
  temáticas/niveles/desafíos ni el resto del esquema (eso sigue siendo
  INT-77).

## Impact

- Nueva migración en `backend/supabase/migrations/` (bucket + policies de
  Storage).
- Segunda migración: `alter table profiles enable row level security` +
  policy de solo-lectura de la fila propia. No afecta al trigger
  `handle_new_user` (INT-75), que es `security definer` y no está sujeto a
  RLS.
- `backend/supabase/config.toml` (referencia de `file_size_limit` global ya
  existente; no requiere cambios si el bucket define su propio límite).
- No afecta código de `app/` ni `panel/` en este cambio: ninguno de los dos
  lee o escribe `profiles` hoy vía cliente Supabase (solo Auth), así que el
  RLS mínimo no rompe nada existente. Deja el bucket listo para que un
  futuro cambio (subida desde panel de admin, INT-80) lo use.
- Sigue sin depender del RLS completo de las tablas del juego (INT-77): lo
  añadido aquí es el mínimo en `profiles` necesario para que la policy de
  escritura del bucket sea efectiva, no la cobertura completa de
  temáticas/niveles/desafíos/progreso.
