## ADDED Requirements

### Requirement: Eliminación completa de la cuenta de un jugador
Un admin SHALL poder eliminar por completo la cuenta de un jugador desde el listado de jugadores. La eliminación SHALL borrar la cuenta de autenticación del jugador y, en cascada, su perfil y todos sus datos de juego (progreso, intentos, respuestas).

#### Scenario: Eliminación exitosa
- **WHEN** un admin confirma la eliminación de un jugador
- **THEN** la RPC `eliminar_jugador` borra su `auth.users` (y en cascada `profiles`, `progreso_usuario_nivel`, `intentos_nivel`, `respuestas_desafio`)
- **AND** el jugador deja de aparecer en el listado de jugadores

#### Scenario: Un no-admin intenta eliminar un jugador
- **WHEN** un usuario autenticado sin `role = 'admin'` invoca la RPC `eliminar_jugador`
- **THEN** la RPC lanza una excepción y no borra ningún dato

#### Scenario: Intento de eliminar una cuenta que no es de un jugador
- **WHEN** se invoca `eliminar_jugador` con el id de un perfil cuyo `role` no es `jugador`
- **THEN** la RPC lanza una excepción y no borra ningún dato

### Requirement: Confirmación explícita antes de eliminar
El panel SHALL exigir que el admin teclee el alias exacto del jugador en un modal de confirmación antes de habilitar la acción de eliminar, con un texto que deje claro que se pierde la cuenta entera (no solo el progreso), dado que la operación es irreversible.

#### Scenario: El botón de confirmar permanece deshabilitado
- **WHEN** el admin abre el modal de eliminación y el texto introducido no coincide exactamente con el alias del jugador
- **THEN** el botón "Eliminar jugador" permanece deshabilitado

#### Scenario: El alias coincide
- **WHEN** el texto introducido coincide exactamente con el alias del jugador
- **THEN** el botón "Eliminar jugador" se habilita y, al pulsarlo, se invoca la RPC de eliminación

### Requirement: Auditoría de la eliminación
Cada eliminación SHALL quedar registrada con qué admin la ejecutó, sobre qué jugador (incluyendo su alias en el momento de la eliminación) y cuándo.

#### Scenario: Registro de auditoría al eliminar
- **WHEN** la RPC `eliminar_jugador` completa una eliminación
- **THEN** se inserta una fila en `auditoria_eliminacion_jugador` con el id del admin, el id y alias del jugador en ese momento, y la fecha, antes de borrar su cuenta

#### Scenario: La fila de auditoría no depende de que el jugador siga existiendo
- **WHEN** se consulta `auditoria_eliminacion_jugador` después de una eliminación
- **THEN** la fila es legible por sí sola (alias en `alias_jugador`), sin necesitar un join contra `profiles` que ya no tiene esa fila
