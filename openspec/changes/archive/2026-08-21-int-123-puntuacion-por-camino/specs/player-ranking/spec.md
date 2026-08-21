## MODIFIED Requirements

### Requirement: `clasificacion_global` agrega puntuación histórica entre todos los jugadores
`clasificacion_global` SHALL devolver, para cada jugador con al menos una fila en `progreso_usuario_nivel` sobre una parada existente del camino, la suma de `mejor_puntaje` (el mejor intento de cada parada) como `puntuacion`, junto con `nombre`, `avatar_url` y `niveles_superados` (conteo de `progreso_usuario_nivel.superado = true` de ese jugador sobre todas las paradas), ordenado por `puntuacion` descendente.

Repetir una parada SHALL no acumular puntuación: un jugador que juega la misma parada varias veces aporta a su total únicamente el mejor de esos intentos. Esta es la misma agregación que ya usan `clasificacion_por_camino` y `clasificacion_por_tematica`, de modo que las tres clasificaciones y el total que muestra la app miden lo mismo.

El progreso huérfano (`progreso_usuario_nivel` con `camino_id` nulo, historial de paradas que ya no están en el camino) SHALL quedar excluido, con el mismo criterio que `clasificacion_por_tematica`.

#### Scenario: Dos jugadores con puntuaciones distintas
- **WHEN** el jugador A suma 500 puntos de mejores intentos sobre sus paradas y el jugador B suma 300
- **THEN** `clasificacion_global()` devuelve a A antes que B

#### Scenario: Repetir una parada no sube la puntuación global
- **WHEN** un jugador juega tres veces la misma parada con puntajes 300, 800 y 500, y no juega ninguna otra
- **THEN** su `puntuacion` en `clasificacion_global` es 800, no 1600

#### Scenario: Mejorar una parada sí sube la puntuación global
- **WHEN** un jugador con `mejor_puntaje = 300` en una parada la repite y saca 800
- **THEN** su `puntuacion` en `clasificacion_global` sube en 500 (la diferencia), no en 800

#### Scenario: Puntuación de contenido desactivado se conserva
- **WHEN** un jugador ganó puntos jugando una parada de `camino` que después se marca `activo = false`
- **THEN** esos puntos siguen contando en su `puntuacion` de `clasificacion_global`

#### Scenario: Progreso de una parada que ya no está en el camino
- **WHEN** un jugador tiene una fila de `progreso_usuario_nivel` con `mejor_puntaje` mayor que 0 y `camino_id` nulo
- **THEN** ese puntaje no cuenta en su `puntuacion` de `clasificacion_global`

#### Scenario: Las tres clasificaciones miden lo mismo
- **WHEN** un jugador tiene progreso repartido entre varias paradas de una única temática, y esa temática cubre todo el camino
- **THEN** su `puntuacion` en `clasificacion_global` coincide con su `puntuacion` en `clasificacion_por_tematica` para esa temática
