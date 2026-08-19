# panel-player-progress-reset Specification

## Purpose
TBD - created by syncing change int-111-panel-jugadores. Update Purpose after archive.

## Requirements

### Requirement: Reinicio total del progreso de un jugador
Un admin SHALL poder reiniciar el progreso completo de un jugador desde el listado de jugadores. El reinicio SHALL borrar de forma atómica el progreso por nivel (`progreso_usuario_nivel`) y el historial de partidas (`intentos_nivel` y, en cascada, `respuestas_desafio`) de ese jugador, sin afectar a su cuenta, alias ni acceso.

#### Scenario: Reinicio exitoso
- **WHEN** un admin confirma el reinicio de progreso de un jugador con partidas e intentos registrados
- **THEN** la RPC `reiniciar_progreso_jugador` borra sus filas de `progreso_usuario_nivel` e `intentos_nivel` (y por cascada las de `respuestas_desafio`), y el listado refleja al jugador con 0 puntos y sin parada superada
- **AND** la cuenta del jugador (`profiles`/`auth.users`), su alias y su capacidad de volver a jugar no cambian

#### Scenario: Un no-admin intenta reiniciar progreso
- **WHEN** un usuario autenticado sin `role = 'admin'` invoca la RPC `reiniciar_progreso_jugador`
- **THEN** la RPC lanza una excepción y no borra ningún dato

#### Scenario: Intento de reiniciar una cuenta que no es de un jugador
- **WHEN** se invoca `reiniciar_progreso_jugador` con el id de un perfil cuyo `role` no es `jugador` (p. ej. un admin)
- **THEN** la RPC lanza una excepción y no borra ningún dato

### Requirement: Confirmación explícita antes de reiniciar
El panel SHALL exigir que el admin teclee el alias exacto del jugador en un modal de confirmación antes de habilitar la acción de reinicio, dado que la operación es irreversible.

#### Scenario: El botón de confirmar permanece deshabilitado
- **WHEN** el admin abre el modal de reinicio y el texto introducido no coincide exactamente con el alias del jugador
- **THEN** el botón "Reiniciar progreso" permanece deshabilitado

#### Scenario: El alias coincide
- **WHEN** el texto introducido coincide exactamente con el alias del jugador
- **THEN** el botón "Reiniciar progreso" se habilita y, al pulsarlo, se invoca la RPC de reinicio

### Requirement: Auditoría del reinicio
Cada reinicio de progreso SHALL quedar registrado con qué admin lo ejecutó, sobre qué jugador (incluyendo el alias en el momento del reinicio) y cuándo, de forma que sea consultable ante una incidencia.

#### Scenario: Registro de auditoría al reiniciar
- **WHEN** la RPC `reiniciar_progreso_jugador` completa un reinicio
- **THEN** se inserta una fila en `auditoria_reinicio_progreso` con el id del admin, el id y alias del jugador en ese momento, y la fecha, antes de que se borren sus datos de progreso

#### Scenario: La auditoría sobrevive a un jugador eliminado
- **WHEN** la cuenta de un jugador con reinicios previos se elimina más adelante por otra vía
- **THEN** las filas de `auditoria_reinicio_progreso` de esos reinicios permanecen consultables, con el alias que quedó registrado en su momento
