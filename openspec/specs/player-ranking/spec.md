# player-ranking Specification

## Purpose
TBD - created by archiving change int-109-clasificacion-global-camino-tematica. Update Purpose after archive.

## Requirements

### Requirement: `clasificacion_global` accesible a cualquier jugador autenticado
El sistema SHALL exponer una función `clasificacion_global(p_limite integer default 50)` invocable por cualquier usuario `authenticated`, sin requerir rol `admin`.

#### Scenario: Un jugador sin rol admin invoca `clasificacion_global`
- **WHEN** un usuario autenticado con `profiles.role = 'jugador'` invoca `clasificacion_global()`
- **THEN** la llamada se acepta y devuelve resultados

### Requirement: `clasificacion_global` agrega puntuación histórica entre todos los jugadores
`clasificacion_global` SHALL devolver, para cada jugador con al menos una fila en `respuestas_desafio`, la suma histórica de `puntos` (vía `intentos_nivel.usuario_id`) como `puntuacion`, junto con `nombre`, `avatar_url` y `niveles_superados` (conteo de `progreso_usuario_nivel.superado = true` de ese jugador sobre todas las paradas), ordenado por `puntuacion` descendente.

#### Scenario: Dos jugadores con puntuaciones distintas
- **WHEN** el jugador A tiene 500 puntos acumulados en `respuestas_desafio` y el jugador B tiene 300
- **THEN** `clasificacion_global()` devuelve a A antes que B

#### Scenario: Puntuación de contenido desactivado se conserva
- **WHEN** un jugador ganó puntos jugando una parada de `camino` que después se marca `activo = false`
- **THEN** esos puntos siguen contando en su `puntuacion` de `clasificacion_global`

### Requirement: Clasificaciones devuelven top N acotado, no la tabla completa
`clasificacion_global`, `clasificacion_por_camino` y `clasificacion_por_tematica` SHALL limitar las filas devueltas a `p_limite`, acotado en servidor al rango `[1, 100]` (`least(greatest(p_limite, 1), 100)`) sin importar el valor recibido.

#### Scenario: Se pide un límite mayor que el tope permitido
- **WHEN** se invoca `clasificacion_global(p_limite := 999999)` habiendo más de 100 jugadores con puntuación
- **THEN** se devuelven como máximo 100 filas del top

#### Scenario: Se pide un límite menor o igual a cero
- **WHEN** se invoca `clasificacion_global(p_limite := 0)`
- **THEN** se devuelve al menos 1 fila del top (el límite efectivo nunca es menor que 1)

### Requirement: Empates comparten posición, orden de emisión determinista
En las tres funciones, `posicion` SHALL calcularse como `rank()` sobre `puntuacion` descendente, de modo que dos jugadores con la misma puntuación compartan el mismo valor de `posicion`. El orden de las filas devueltas SHALL ser determinista, usando `usuario_id` como desempate para decidir qué filas caen dentro de `p_limite` cuando hay empate en el borde.

#### Scenario: Dos jugadores empatados en puntuación
- **WHEN** el jugador A y el jugador B tienen exactamente la misma `puntuacion` en `clasificacion_global`
- **THEN** ambos aparecen con el mismo valor de `posicion`

#### Scenario: Empate justo en el borde del límite
- **WHEN** varios jugadores empatan en la puntuación que corresponde a la última posición dentro de `p_limite`
- **THEN** llamadas repetidas con los mismos datos devuelven siempre el mismo subconjunto de esos jugadores empatados, en el mismo orden

### Requirement: La fila de quien llama siempre se incluye
Cada una de las tres funciones SHALL incluir en su resultado la fila correspondiente al usuario que invoca la función (`auth.uid()`), marcada con `es_usuario_actual = true`, con su `posicion` real, incluso cuando esa posición cae fuera de las primeras `p_limite` filas.

#### Scenario: El jugador que llama queda fuera del top N
- **WHEN** un jugador cuya `puntuacion` lo sitúa en la posición 250 invoca `clasificacion_global(p_limite := 50)`
- **THEN** el resultado incluye 50 filas del top más una fila adicional para ese jugador, con `posicion = 250` y `es_usuario_actual = true`

#### Scenario: El jugador que llama está dentro del top N
- **WHEN** un jugador cuya `puntuacion` lo sitúa en la posición 10 invoca `clasificacion_global(p_limite := 50)`
- **THEN** esa fila aparece una sola vez dentro de las 50, con `es_usuario_actual = true`

### Requirement: Jugador sin puntuación agregable
Si el usuario que invoca una de las tres funciones no tiene ninguna fila agregable para esa clasificación, la función SHALL devolver igualmente su fila con `puntuacion = 0` (y contadores dependientes en 0) y `posicion = null`, en vez de omitirla o calcular una posición estimada.

#### Scenario: Jugador que nunca respondió ningún desafío
- **WHEN** un jugador sin ninguna fila en `respuestas_desafio` invoca `clasificacion_global()`
- **THEN** su fila aparece con `puntuacion = 0`, `niveles_superados = 0` y `posicion = null`

### Requirement: `clasificacion_por_camino` clasifica por mejor puntaje de una parada
El sistema SHALL exponer `clasificacion_por_camino(p_camino_id uuid, p_limite integer default 50)`, que devuelve el ranking de jugadores por su `progreso_usuario_nivel.mejor_puntaje` para esa `camino_id` concreta, junto con `superado` (booleano) de ese jugador en esa parada.

#### Scenario: Ranking de una parada con varios jugadores
- **WHEN** tres jugadores tienen `progreso_usuario_nivel` para la misma `camino_id` con distinto `mejor_puntaje`
- **THEN** `clasificacion_por_camino` los ordena de mayor a menor `mejor_puntaje`

#### Scenario: `camino_id` inexistente
- **WHEN** se invoca `clasificacion_por_camino` con un `p_camino_id` que no existe en `camino`
- **THEN** la función devuelve el conjunto vacío para el ranking, sin lanzar una excepción (la fila propia del llamante sigue las reglas del jugador sin puntuación agregable)

### Requirement: `clasificacion_por_tematica` agrega todas las paradas de una temática
El sistema SHALL exponer `clasificacion_por_tematica(p_tematica_id uuid, p_limite integer default 50)`, que devuelve el ranking de jugadores sumando `progreso_usuario_nivel.mejor_puntaje` sobre todas las filas de `camino` cuyo `tematica_id` coincide con el parámetro, junto con `niveles_superados` (conteo de `superado = true` dentro de esa temática).

#### Scenario: Jugador con progreso en varias paradas de la misma temática
- **WHEN** un jugador tiene `progreso_usuario_nivel` en dos paradas distintas que comparten `tematica_id`
- **THEN** su `puntuacion` en `clasificacion_por_tematica` es la suma de `mejor_puntaje` de ambas paradas

#### Scenario: `tematica_id` inexistente
- **WHEN** se invoca `clasificacion_por_tematica` con un `p_tematica_id` que no existe en `tematicas`
- **THEN** la función devuelve el conjunto vacío para el ranking, sin lanzar una excepción

### Requirement: No se filtra el detalle de intentos o respuestas de otros jugadores
Ninguna de las tres funciones SHALL exponer columnas de `intentos_nivel` o `respuestas_desafio` de otro jugador distintas de las puntuaciones agregadas ya definidas (`puntuacion`, `niveles_superados`/`superado`); en particular, nunca exponen filas individuales de intento o de respuesta, ni coordenadas, ni tiempos de respuesta de otro jugador.

#### Scenario: Un jugador consulta cualquiera de las tres clasificaciones
- **WHEN** un jugador autenticado invoca `clasificacion_global`, `clasificacion_por_camino` o `clasificacion_por_tematica`
- **THEN** el resultado solo contiene `usuario_id`, `nombre`, `avatar_url`, `posicion`, `es_usuario_actual` y la puntuación/contadores agregados de esa función, nunca una fila de `intentos_nivel` o `respuestas_desafio` ajena
