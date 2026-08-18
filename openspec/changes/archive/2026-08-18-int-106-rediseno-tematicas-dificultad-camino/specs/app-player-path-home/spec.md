## MODIFIED Requirements

### Requirement: Toque en parada desbloqueada navega al nivel
La app SHALL iniciar la navegación hacia la pantalla de juego de una parada
cuando el jugador la toque y su posición traiga `desbloqueado = true`
(superada o actual), identificándola por su `camino_id`.

#### Scenario: El jugador toca la parada actual
- **WHEN** un jugador toca la parada cuya posición trae
  `es_actual = true`
- **THEN** la app navega hacia la pantalla de juego del `camino_id` de
  esa posición

#### Scenario: El jugador toca una parada ya superada
- **WHEN** un jugador toca una parada cuya posición trae
  `superado = true`
- **THEN** la app navega hacia la pantalla de juego del `camino_id` de
  esa posición, permitiendo rejugarla

### Requirement: Botón fijo para jugar la parada actual
La Home SHALL mostrar un botón fijo sobre el camino, siempre visible,
que navegue a la pantalla de juego de la parada `es_actual` cuando
exista una. Si ninguna posición trae `es_actual = true` (camino
completo), el botón no SHALL mostrarse.

#### Scenario: Hay una parada actual
- **WHEN** una posición del camino trae `es_actual = true`
- **THEN** la Home muestra un botón fijo que, al tocarlo, navega a la
  pantalla de juego del `camino_id` de esa posición

#### Scenario: Camino completo sin parada actual
- **WHEN** ninguna posición del camino trae `es_actual = true`
- **THEN** la Home no muestra el botón fijo de jugar
