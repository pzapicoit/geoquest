## MODIFIED Requirements

### Requirement: Vista única del camino con progreso del jugador
El sistema SHALL exponer una vista `camino_jugador` que devuelva, en una
sola consulta, todas las posiciones de `camino` en orden (`orden`
ascendente), cada una con su temática, dificultad y nombre de la parada, y
el progreso del usuario autenticado sobre esa parada (`superado`,
`estrellas_obtenidas`).

#### Scenario: El jugador consulta su camino
- **WHEN** un jugador autenticado consulta `camino_jugador`
- **THEN** recibe una fila por cada posición existente en `camino`, ordenadas
  por `orden`, cada una con la temática, la dificultad y el nombre de la
  parada de esa posición

### Requirement: Posiciones nunca jugadas devuelven progreso vacío
El sistema SHALL incluir en `camino_jugador` toda posición del camino
aunque el jugador no tenga ninguna fila en `progreso_usuario_nivel` para
esa parada (`camino_id`), mostrando `superado = false` y
`estrellas_obtenidas = 0` en ese caso.

#### Scenario: Jugador sin ningún intento cerrado
- **WHEN** un jugador que nunca cerró un intento consulta `camino_jugador`
- **THEN** todas las posiciones aparecen en el resultado, con
  `superado = false` y `estrellas_obtenidas = 0`

#### Scenario: El jugador ya jugó algunas posiciones pero no todas
- **WHEN** un jugador tiene `progreso_usuario_nivel` solo para algunas de las
  paradas del camino
- **THEN** las posiciones sin fila de progreso aparecen igualmente, con
  `superado = false` y `estrellas_obtenidas = 0`, junto a las que sí tienen
  progreso

### Requirement: Desbloqueo recalculado sobre estrellas acumuladas del camino
El sistema SHALL marcar `desbloqueado = true` en `camino_jugador` para toda
posición cuyo `estrellas_requeridas` sea menor o igual que la suma de
`mejores_estrellas` del jugador sobre todas las paradas del camino, sin
importar si esa posición ya tiene una fila en `progreso_usuario_nivel` con
`desbloqueado` grabado.

#### Scenario: Posición con umbral cero y jugador sin progreso previo
- **WHEN** una posición del camino tiene `estrellas_requeridas = 0` y el
  jugador no tiene ninguna fila en `progreso_usuario_nivel`
- **THEN** esa posición aparece con `desbloqueado = true`

#### Scenario: Posición cuyo umbral ya fue alcanzado y grabado
- **WHEN** una posición tiene `desbloqueado = true` grabado en
  `progreso_usuario_nivel` para el jugador
- **THEN** esa posición aparece con `desbloqueado = true` en
  `camino_jugador`

#### Scenario: Posición cuyo umbral todavía no se alcanza
- **WHEN** la suma de `mejores_estrellas` del jugador sobre el camino es
  menor que el `estrellas_requeridas` de una posición, y esa posición no
  tiene `desbloqueado = true` grabado
- **THEN** esa posición aparece con `desbloqueado = false`

### Requirement: Estrellas acumuladas del jugador expuestas por fila
El sistema SHALL incluir en cada fila de `camino_jugador` el total de
`mejores_estrellas` del jugador sumado sobre todas las paradas del camino,
como `estrellas_acumuladas_usuario`.

#### Scenario: Se consulta el camino con progreso parcial
- **WHEN** un jugador con estrellas acumuladas en varias posiciones
  superadas consulta `camino_jugador`
- **THEN** todas las filas devueltas traen el mismo valor de
  `estrellas_acumuladas_usuario`, igual a esa suma total
