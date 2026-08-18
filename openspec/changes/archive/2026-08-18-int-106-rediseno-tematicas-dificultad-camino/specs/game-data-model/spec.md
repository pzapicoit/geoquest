## MODIFIED Requirements

### Requirement: Jerarquía temática → desafío, con dificultad y camino como resolución automática

El esquema SHALL modelar la jerarquía temáticas → desafíos como dos entidades relacionadas: `tematicas` y `desafios` (con FK obligatoria `tematica_id` a su temática y una `dificultad` del catálogo cerrado — ver `question-difficulty`). No SHALL existir ninguna entidad "nivel" ni tabla de curación manual de preguntas: la pareja temática+dificultad de un desafío basta para que participe en el sorteo de cualquier parada de `camino` que apunte a esa misma pareja.

#### Scenario: Un desafío pertenece a una sola temática

- **WHEN** se crea un desafío
- **THEN** su fila exige un `tematica_id` que referencia una fila existente de `tematicas`

#### Scenario: Se intenta borrar una temática que todavía tiene desafíos

- **WHEN** se intenta borrar una temática que tiene al menos un desafío con ese `tematica_id`
- **THEN** la base de datos rechaza el borrado, igual que hoy el banco de preguntas nunca se ve afectado por borrar una temática — el admin debe borrar o reasignar antes esos desafíos

#### Scenario: Un desafío participa automáticamente en el sorteo de su pool

- **WHEN** se crea un desafío `activo` con `tematica_id` y `dificultad` dados
- **THEN** queda disponible de inmediato para el sorteo de cualquier parada de `camino` que resuelva esa misma pareja temática+dificultad, sin ninguna asignación manual adicional

### Requirement: Progreso agregado por jugador y parada del camino sin recálculo histórico

El esquema SHALL mantener una fila por jugador y parada del camino (`progreso_usuario_nivel`, con columna `camino_id` en vez de `nivel_id`) con el mejor resultado obtenido, de forma que consultar el progreso de un jugador no requiera recorrer su historial completo de intentos.

#### Scenario: Se consulta el progreso de un jugador en una parada

- **WHEN** se lee `progreso_usuario_nivel` para un `usuario_id` y `camino_id` dados
- **THEN** existe como máximo una fila con el mejor puntaje, mejores estrellas y estado de desbloqueo conocidos hasta ese momento

#### Scenario: Un jugador sin intentos previos en una parada

- **WHEN** un jugador no ha intentado nunca una parada dada
- **THEN** no existe fila en `progreso_usuario_nivel` para ese par usuario/parada

### Requirement: Lectura pública de `tematicas` y `camino` para autenticados

`tematicas` y `camino` SHALL tener Row Level Security habilitado, con una policy que permita `select` a cualquier usuario autenticado (incluida una sesión anónima), sin restricción adicional por fila.

#### Scenario: Un jugador lee el catálogo de temáticas

- **WHEN** un usuario autenticado (o con sesión anónima) hace `select` sobre `tematicas`
- **THEN** la operación se permite y devuelve todas las filas

#### Scenario: Un jugador lee la secuencia del camino

- **WHEN** un usuario autenticado (o con sesión anónima) hace `select` sobre `camino`
- **THEN** la operación se permite y devuelve todas las filas

### Requirement: Escritura de contenido del juego restringida a administradores

`tematicas`, `desafios` y `camino` SHALL rechazar cualquier `insert`, `update` o `delete` de un usuario para el que `is_admin()` devuelva `false`.

#### Scenario: Un admin crea o edita contenido

- **WHEN** un usuario con `is_admin() = true` hace `insert`, `update` o `delete` sobre `tematicas`, `desafios` o `camino`
- **THEN** la operación se permite

#### Scenario: Un jugador intenta crear o editar contenido

- **WHEN** un usuario con `is_admin() = false` (incluida una sesión anónima) intenta `insert`, `update` o `delete` sobre `tematicas`, `desafios` o `camino`
- **THEN** la operación se rechaza

### Requirement: Camino como secuencia global de paradas temática+dificultad

El esquema SHALL modelar el camino de juego como una tabla `camino` independiente de `tematicas`, donde cada fila representa una posición (`orden`) que apunta a una pareja `tematica_id` + `dificultad`, define su propio `estrellas_requeridas` para desbloquearse, un `nombre` opcional, un estado `activo`, y overrides opcionales (`preguntas_por_partida`, `segundos_por_desafio`, `puntaje_minimo_superar`, `umbral_estrella_2`, `umbral_estrella_3`, todos nullable) que sustituyen a los valores de `dificultad_defaults` cuando están rellenos. El esquema SHALL permitir intercalar paradas de distintas temáticas y dificultades en cualquier orden, incluyendo repetir la misma pareja temática+dificultad en más de una posición.

#### Scenario: Se define un camino que intercala temáticas y dificultades

- **WHEN** el admin crea filas de `camino` con `orden` 1, 2 y 3 apuntando a "Monumentos·Fácil", "Banderas·Normal" y "Monumentos·Difícil" respectivamente
- **THEN** las tres filas coexisten sin conflicto

#### Scenario: La misma pareja temática+dificultad aparece en dos posiciones

- **WHEN** el admin crea dos filas de `camino` que apuntan ambas a "Monumentos·Fácil", con overrides distintos de `puntaje_minimo_superar`
- **THEN** ambas filas coexisten sin conflicto, cada una con su propio progreso y su propio override

#### Scenario: Se intenta duplicar una posición del camino

- **WHEN** se intenta insertar dos filas de `camino` con el mismo `orden`
- **THEN** la base de datos rechaza la operación

#### Scenario: Se borra una temática referenciada por el camino

- **WHEN** se borra una temática que tiene al menos una fila asociada en `camino`
- **THEN** esas filas de `camino` se borran en cascada junto con la temática

#### Scenario: Una parada sin overrides usa los valores por defecto de su dificultad

- **WHEN** una parada de `camino` tiene `dificultad = 'dificil'` y todas sus columnas de override en `NULL`
- **THEN** su `preguntas_por_partida`, `segundos_por_desafio`, `puntaje_minimo_superar`, `umbral_estrella_2` y `umbral_estrella_3` efectivos son los de la fila `'dificil'` de `dificultad_defaults`

#### Scenario: Una parada con override propio ignora el valor por defecto

- **WHEN** una parada de `camino` tiene `puntaje_minimo_superar` relleno con un valor propio
- **THEN** ese valor propio se usa como mínimo efectivo, sin importar el valor de `dificultad_defaults` para su dificultad

## REMOVED Requirements

### Requirement: Asignación de desafíos a niveles con orden propio y reutilización

**Reason**: `nivel_desafios` desaparece junto con `niveles` — ya no hay curación manual de qué preguntas pertenecen a una parada. La pertenencia de un desafío a un pool se resuelve automáticamente por su `tematica_id` + `dificultad`.

**Migration**: Ver `challenge-play` (`iniciar_intento_parada`) para cómo se resuelve ahora la selección de preguntas de una parada.

### Requirement: `niveles` admite un nombre editable opcional

**Reason**: `niveles` desaparece como tabla; el nombre editable opcional de una parada pasa a ser `camino.nombre`, ya incluido en el requirement "Camino como secuencia global de paradas temática+dificultad".

**Migration**: Cada fila de `camino` migrada desde un nivel con `nombre` conserva ese mismo valor en `camino.nombre`.

### Requirement: Cada nivel define cuántas preguntas se juegan por partida

**Reason**: `niveles` desaparece; el número de preguntas por partida pasa a vivir en `dificultad_defaults` (por dificultad) con override opcional en `camino` (por parada), ver `difficulty-defaults`.

**Migration**: Cada fila de `camino` migrada desde un nivel con `preguntas_por_partida` propio conserva ese valor como override explícito.
