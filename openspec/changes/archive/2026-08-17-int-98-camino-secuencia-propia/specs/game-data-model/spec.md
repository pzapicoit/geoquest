## ADDED Requirements

### Requirement: Camino como secuencia global ordenada de niveles
El esquema SHALL modelar el camino de juego como una tabla `camino`
independiente de `tematicas`, donde cada fila representa una posición
(`orden`) que apunta a un `nivel_id` concreto y define su propio
`estrellas_requeridas` para desbloquearse, permitiendo intercalar niveles
de distintas temáticas en cualquier orden.

#### Scenario: Se define un camino que intercala temáticas
- **WHEN** el admin crea filas de `camino` con `orden` 1, 2 y 3 apuntando a
  un nivel de la temática "Monumentos", uno de "Banderas" y otro de
  "Monumentos" respectivamente
- **THEN** las tres filas coexisten sin conflicto, independientemente de
  las temáticas de sus niveles

#### Scenario: Se intenta duplicar una posición del camino
- **WHEN** se intenta insertar dos filas de `camino` con el mismo `orden`
- **THEN** la base de datos rechaza la operación

#### Scenario: Se borra un nivel referenciado por el camino
- **WHEN** se borra un nivel que tiene una fila asociada en `camino`
- **THEN** esa fila de `camino` se borra en cascada junto con el nivel

### Requirement: Cada nivel define cuántas preguntas se juegan por partida
`niveles` SHALL tener una columna `preguntas_por_partida` de tipo entero,
opcional (nullable, sin valor por defecto). Cuando sea `NULL`, una partida
usa todas las preguntas asignadas al nivel en `nivel_desafios`.

#### Scenario: Nivel sin preguntas_por_partida definido
- **WHEN** un nivel tiene `preguntas_por_partida = NULL` y 8 preguntas
  asignadas en `nivel_desafios`
- **THEN** el esquema no impone ningún límite sobre cuántas preguntas se
  juegan de ese nivel

#### Scenario: Nivel con preguntas_por_partida definido
- **WHEN** un nivel tiene `preguntas_por_partida = 5`
- **THEN** el valor queda disponible para que la lógica de arranque de
  intento (`INT-95`) seleccione ese número de preguntas al azar

## MODIFIED Requirements

### Requirement: Lectura pública de `tematicas`, `niveles`, `nivel_desafios` y `camino` para autenticados

`tematicas`, `niveles`, `nivel_desafios` y `camino` SHALL tener Row Level
Security habilitado, con una policy que permita `select` a cualquier
usuario autenticado (incluida una sesión anónima), sin restricción
adicional por fila.

#### Scenario: Un jugador lee el catálogo de temáticas y niveles
- **WHEN** un usuario autenticado (o con sesión anónima) hace `select`
  sobre `tematicas`, `niveles` o `nivel_desafios`
- **THEN** la operación se permite y devuelve todas las filas

#### Scenario: Un jugador lee la secuencia del camino
- **WHEN** un usuario autenticado (o con sesión anónima) hace `select`
  sobre `camino`
- **THEN** la operación se permite y devuelve todas las filas

### Requirement: Escritura de contenido del juego restringida a administradores

`tematicas`, `niveles`, `desafios`, `nivel_desafios` y `camino` SHALL
rechazar cualquier `insert`, `update` o `delete` de un usuario para el que
`is_admin()` devuelva `false`.

#### Scenario: Un admin crea o edita contenido
- **WHEN** un usuario con `is_admin() = true` hace `insert`, `update` o
  `delete` sobre `tematicas`, `niveles`, `desafios`, `nivel_desafios` o
  `camino`
- **THEN** la operación se permite

#### Scenario: Un jugador intenta crear o editar contenido
- **WHEN** un usuario con `is_admin() = false` (incluida una sesión
  anónima) intenta `insert`, `update` o `delete` sobre `tematicas`,
  `niveles`, `desafios`, `nivel_desafios` o `camino`
- **THEN** la operación se rechaza
