## ADDED Requirements

### Requirement: El camino recarga su progreso al volver de jugar

La Home SHALL volver a leer `camino_jugador` y los puntos totales del
jugador al volver de la pantalla de juego de un nivel (desde el resumen
del nivel, ya sea "Continuar" o "Volver al camino"), en vez de conservar
los datos con los que se cargó antes de entrar a jugar.

#### Scenario: Vuelve con un nivel recién superado

- **WHEN** el jugador entra a jugar un nivel bloqueado en el camino,
  lo supera y pulsa "Continuar" en el resumen
- **THEN** la Home muestra ese nivel como superado, con sus estrellas y
  cualquier desbloqueo nuevo, sin necesidad de reabrir la app

#### Scenario: Vuelve sin terminar el nivel

- **WHEN** el jugador entra a jugar un nivel y sale antes de terminarlo
- **THEN** la Home recarga igualmente su progreso al volver
