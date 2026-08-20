## ADDED Requirements

### Requirement: Contador persistente de intentos desde el último anuncio de cadencia

`profiles` SHALL tener una columna `intentos_desde_ultimo_anuncio_cadencia integer` obligatoria con valor por defecto `0`, que cuenta intentos de parada jugados desde el último anuncio de cadencia mostrado a ese jugador (`video-ads`). Esta columna SHALL sobrevivir a reinstalar la app o cambiar de dispositivo, igual que el resto del progreso del jugador.

#### Scenario: Se crea un perfil nuevo

- **WHEN** se crea un nuevo usuario en `auth.users` y su perfil correspondiente (alta anónima, INT-75)
- **THEN** su fila de `profiles` tiene `intentos_desde_ultimo_anuncio_cadencia = 0`

#### Scenario: Perfiles ya existentes antes de este cambio

- **WHEN** se consulta `intentos_desde_ultimo_anuncio_cadencia` de un perfil creado antes de la existencia de esta columna
- **THEN** el campo devuelve `0`, no `NULL`

### Requirement: Catálogo cerrado del tipo de anuncio pendiente

El esquema SHALL exponer un enum `tipo_anuncio_pendiente` con exactamente 3 valores: `ninguno`, `desbloqueo` y `cadencia`, usado como tipo de retorno de la lógica de decisión de anuncios (`video-ads`).

#### Scenario: Se intenta usar un valor fuera del catálogo

- **WHEN** cualquier función o columna tipada como `tipo_anuncio_pendiente` intenta tomar un valor que no sea `ninguno`, `desbloqueo` o `cadencia`
- **THEN** la base de datos rechaza la operación
