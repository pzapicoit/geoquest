## MODIFIED Requirements

### Requirement: Camino como secuencia global de paradas temática+dificultad

El esquema SHALL modelar el camino de juego como una tabla `camino` independiente de `tematicas`, donde cada fila representa una posición (`orden`) que apunta a una pareja `tematica_id` + `dificultad`, un `nombre` opcional, un estado `activo`, y overrides opcionales (`preguntas_por_partida`, `segundos_por_desafio`, ambos nullable) que sustituyen a los valores de `dificultad_defaults` cuando están rellenos. `camino` SHALL NOT tener ninguna columna de umbral de estrellas ni de estrellas requeridas para desbloquear: ambos se derivan en tiempo de lectura (ver `difficulty-defaults` y `player-path`). El esquema SHALL permitir intercalar paradas de distintas temáticas y dificultades en cualquier orden, incluyendo repetir la misma pareja temática+dificultad en más de una posición.

#### Scenario: Se define un camino que intercala temáticas y dificultades

- **WHEN** el admin crea filas de `camino` con `orden` 1, 2 y 3 apuntando a "Monumentos·Fácil", "Banderas·Normal" y "Monumentos·Difícil" respectivamente
- **THEN** las tres filas coexisten sin conflicto

#### Scenario: La misma pareja temática+dificultad aparece en dos posiciones

- **WHEN** el admin crea dos filas de `camino` que apuntan ambas a "Monumentos·Fácil", con overrides distintos de `preguntas_por_partida`
- **THEN** ambas filas coexisten sin conflicto, cada una con su propio progreso y su propio override

#### Scenario: Se intenta duplicar una posición del camino

- **WHEN** se intenta insertar dos filas de `camino` con el mismo `orden`
- **THEN** la base de datos rechaza la operación

#### Scenario: Se borra una temática referenciada por el camino

- **WHEN** se borra una temática que tiene al menos una fila asociada en `camino`
- **THEN** esas filas de `camino` se borran en cascada junto con la temática

#### Scenario: Una parada sin overrides usa los valores por defecto de su dificultad

- **WHEN** una parada de `camino` tiene `dificultad = 'dificil'` y sus columnas de override en `NULL`
- **THEN** su `preguntas_por_partida` y `segundos_por_desafio` efectivos son los de la fila `'dificil'` de `dificultad_defaults`

#### Scenario: Una parada con override propio ignora el valor por defecto

- **WHEN** una parada de `camino` tiene `preguntas_por_partida` relleno con un valor propio
- **THEN** ese valor propio se usa como preguntas por partida efectivas, sin importar el valor de `dificultad_defaults` para su dificultad
