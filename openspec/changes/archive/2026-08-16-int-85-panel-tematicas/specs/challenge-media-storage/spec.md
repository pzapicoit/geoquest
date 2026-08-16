## ADDED Requirements

### Requirement: Convención de ruta para portadas de temática
Además de la convención existente para desafíos
(`{tipo}/{desafio_id}.{extension}`), el bucket `challenge-media` SHALL
aceptar portadas de temática guardadas bajo la ruta
`tematicas/{tematica_id}.{extension}`, sujetas a los mismos límites de
formato y tamaño (`image/jpeg`, `image/png`, `image/webp`, hasta 50 MiB) y
a las mismas políticas de acceso (lectura pública, escritura solo admin)
ya vigentes para el bucket.

#### Scenario: Ruta de la portada de una temática
- **WHEN** se sube la portada de la temática con `id = <uuid>`
- **THEN** su ruta dentro del bucket `challenge-media` es
  `tematicas/<uuid>.<extension>`

#### Scenario: Un admin sube una portada de temática
- **WHEN** un usuario con `profiles.role = 'admin'` sube un archivo bajo
  `tematicas/` en `challenge-media`
- **THEN** la operación se permite, igual que para el resto del bucket

#### Scenario: Un jugador intenta subir una portada de temática
- **WHEN** un usuario con `profiles.role = 'jugador'` (incluida una sesión
  anónima) intenta subir un archivo bajo `tematicas/` en `challenge-media`
- **THEN** la operación se rechaza, igual que para el resto del bucket
