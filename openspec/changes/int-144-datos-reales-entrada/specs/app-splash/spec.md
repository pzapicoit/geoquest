## ADDED Requirements

### Requirement: El consejo de carga describe la mecánica real del juego
El splash SHALL mostrar, mientras carga, un consejo elegido al azar de una lista fija de consejos que describen la mecánica real de GeoQuest: colocar el pin en el mapa, la puntuación por distancia, el bonus por rapidez, las estrellas que desbloquean paradas y los comodines. No SHALL mostrar consejos de mecánicas que el juego no tiene, como desbloquear preguntas por proximidad física o GPS.

#### Scenario: El splash muestra un consejo
- **WHEN** el splash se está mostrando mientras se resuelve la sesión
- **THEN** se ve uno de los consejos de la lista de mecánica real

#### Scenario: Ningún consejo habla de proximidad física
- **WHEN** se revisa la lista de consejos de carga
- **THEN** ninguno pide acercarse físicamente a un lugar ni menciona distancias en metros al jugador
