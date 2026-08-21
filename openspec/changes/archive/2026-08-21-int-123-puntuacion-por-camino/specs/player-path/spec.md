## ADDED Requirements

### Requirement: Puntuación del mejor intento expuesta por parada
El sistema SHALL incluir en cada fila de `camino_jugador` la puntuación del
mejor intento del jugador sobre esa parada, como `mejor_puntaje`, tomada de
`progreso_usuario_nivel.mejor_puntaje` y con `0` cuando el jugador no tiene
fila de progreso para esa parada.

Esta columna SHALL ser la única fuente de la puntuación del jugador que
consume la app: ni el total ni el acumulado por parada se calculan sumando
`respuestas_desafio`.

#### Scenario: Parada con varios intentos jugados
- **WHEN** un jugador ha cerrado tres intentos sobre la misma parada, con
  puntajes 300, 800 y 500
- **THEN** esa fila de `camino_jugador` trae `mejor_puntaje = 800`, no la
  suma de los tres

#### Scenario: Parada nunca jugada
- **WHEN** un jugador consulta `camino_jugador` sin ninguna fila de
  `progreso_usuario_nivel` para una parada
- **THEN** esa fila trae `mejor_puntaje = 0`, igual que ya trae
  `superado = false` y `estrellas_obtenidas = 0`

#### Scenario: Repetir una parada no puede bajar su mejor marca
- **WHEN** un jugador que ya tenía `mejor_puntaje = 800` en una parada
  vuelve a jugarla y saca 200
- **THEN** esa fila de `camino_jugador` sigue trayendo `mejor_puntaje = 800`

### Requirement: Total del jugador derivable de la propia vista
El sistema SHALL permitir obtener el total de puntos del jugador sumando
`mejor_puntaje` sobre las filas que devuelve `camino_jugador`, sin ninguna
consulta adicional. Como `camino_jugador` solo contiene posiciones
existentes de `camino`, el progreso huérfano (`progreso_usuario_nivel` con
`camino_id` nulo, historial de paradas que ya no están en el camino) SHALL
quedar fuera de ese total.

#### Scenario: El total sale de una sola consulta
- **WHEN** un cliente lee `camino_jugador` para pintar la Home
- **THEN** dispone del total de puntos del jugador sin consultar
  `respuestas_desafio` ni ninguna otra tabla

#### Scenario: Progreso de una parada que ya no está en el camino
- **WHEN** un jugador tiene progreso con puntaje sobre una parada que se
  eliminó del camino (`progreso_usuario_nivel.camino_id` nulo)
- **THEN** ese puntaje no aparece en ninguna fila de `camino_jugador` y no
  cuenta en el total derivado de la vista
