## ADDED Requirements

### Requirement: Bucket único con formatos y tamaño limitados

El sistema SHALL exponer un bucket de Supabase Storage llamado
`challenge-media` que acepte únicamente `image/jpeg`, `image/png`,
`image/webp` y `video/mp4`, con un tamaño máximo de archivo de 50 MiB.

#### Scenario: Se sube una imagen en un formato aceptado

- **WHEN** se sube un archivo `image/png` de 3 MiB al bucket
  `challenge-media`
- **THEN** el bucket acepta el archivo

#### Scenario: Se sube un archivo de un tipo no permitido

- **WHEN** se intenta subir un archivo `application/pdf` al bucket
  `challenge-media`
- **THEN** Supabase Storage rechaza la subida

#### Scenario: Se sube un archivo que excede el límite de tamaño

- **WHEN** se intenta subir un archivo de más de 50 MiB al bucket
  `challenge-media`
- **THEN** Supabase Storage rechaza la subida

### Requirement: Lectura pública del contenido de desafíos

Cualquiera, autenticado o no, SHALL poder leer cualquier objeto del bucket
`challenge-media`.

#### Scenario: Un cliente anónimo lee un archivo del bucket

- **WHEN** un cliente sin sesión hace `select`/descarga sobre un objeto de
  `challenge-media`
- **THEN** la operación se permite

### Requirement: Escritura restringida a administradores

Solo un usuario cuyo `profiles.role` sea `admin` SHALL poder crear,
actualizar o borrar objetos del bucket `challenge-media`. Cualquier otro
usuario, incluida una sesión anónima o un jugador, SHALL ser rechazado.

#### Scenario: Un admin sube un archivo

- **WHEN** un usuario autenticado con `profiles.role = 'admin'` sube un
  archivo a `challenge-media`
- **THEN** la operación se permite

#### Scenario: Un jugador intenta subir un archivo

- **WHEN** un usuario autenticado con `profiles.role = 'jugador'` (incluida
  una sesión anónima) intenta subir, actualizar o borrar un archivo en
  `challenge-media`
- **THEN** la operación se rechaza

#### Scenario: Un admin borra un archivo existente

- **WHEN** un usuario con `profiles.role = 'admin'` borra un objeto de
  `challenge-media`
- **THEN** la operación se permite

### Requirement: Convención de ruta por tipo y desafío

Cada objeto del bucket `challenge-media` SHALL guardarse bajo una ruta con
el patrón `{tipo}/{desafio_id}.{extension}`, donde `{tipo}` es `imagen` o
`video` y `{desafio_id}` es el `id` de la fila de `desafios` a la que
pertenece el archivo.

#### Scenario: Ruta de una imagen de desafío

- **WHEN** se sube la imagen del desafío con `id = <uuid>`
- **THEN** su ruta dentro del bucket es `imagen/<uuid>.<extension>`

#### Scenario: Ruta de un video de desafío

- **WHEN** se sube el video del desafío con `id = <uuid>`
- **THEN** su ruta dentro del bucket es `video/<uuid>.<extension>`
