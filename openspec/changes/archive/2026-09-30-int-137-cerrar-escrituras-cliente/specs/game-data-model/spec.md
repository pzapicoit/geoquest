## RENAMED Requirements

- FROM: `### Requirement: Progreso de juego visible y editable solo por su propio usuario`
- TO: `### Requirement: Progreso de juego visible solo por su propio usuario y escrito solo vía RPC`

## MODIFIED Requirements

### Requirement: Progreso de juego visible solo por su propio usuario y escrito solo vía RPC

`intentos_nivel`, `respuestas_desafio` y `progreso_usuario_nivel` SHALL
tener Row Level Security habilitado. Un usuario autenticado SHALL poder
leer únicamente las filas asociadas a su propio `auth.uid()` (vía
`usuario_id` en `intentos_nivel`/`progreso_usuario_nivel`, o vía
`intento_id -> intentos_nivel.usuario_id` en `respuestas_desafio`), y no
SHALL poder leer las de otro usuario.

Los roles `anon` y `authenticated` SHALL NOT poder ejecutar `insert`,
`update`, `delete` ni `truncate` directamente sobre `intentos_nivel`,
`respuestas_desafio`, `progreso_usuario_nivel` ni `intento_desafios`: no
SHALL existir ninguna policy de escritura para ellos y sus privilegios de
escritura sobre esas tablas SHALL estar revocados. Toda escritura legítima
SHALL hacerse a través de RPC `security definer` (`iniciar_intento_parada`,
`responder_desafio`, `marcar_desafio_mostrado`, `cerrar_intento_parada`,
`usar_comodin`), que derivan el usuario de `auth.uid()` y nunca de un
parámetro. Un administrador con `is_admin() = true` no gana por ello
escritura directa sobre estas tablas; sus operaciones (reinicio de progreso,
eliminación de jugador) siguen pasando por sus RPC propias.

#### Scenario: Un jugador lee su propio progreso

- **WHEN** un usuario autenticado hace `select` sobre `intentos_nivel`,
  `respuestas_desafio` o `progreso_usuario_nivel` filtrando por sus propias
  filas
- **THEN** la operación se permite

#### Scenario: Un jugador intenta leer el progreso de otro usuario

- **WHEN** un usuario autenticado hace `select` sobre `intentos_nivel`,
  `respuestas_desafio` o `progreso_usuario_nivel` para filas de otro
  `usuario_id`
- **THEN** la operación no devuelve esas filas

#### Scenario: Un jugador intenta inflar su progreso agregado

- **WHEN** un usuario autenticado intenta `update` o `insert` directo sobre
  `progreso_usuario_nivel` con su propio `usuario_id` (por ejemplo,
  `mejor_puntaje` muy alto, `mejores_estrellas = 3` o `desbloqueado = true`)
- **THEN** la operación se rechaza y el progreso no cambia

#### Scenario: Un jugador intenta alterar su intento

- **WHEN** un usuario autenticado intenta `update` directo sobre una fila
  propia de `intentos_nivel` (por ejemplo, `puntaje_total`,
  `estrellas_obtenidas` o poner `comodin_usado` a `NULL`)
- **THEN** la operación se rechaza y la fila no cambia

#### Scenario: Un jugador intenta crear un intento o una respuesta directamente

- **WHEN** un usuario autenticado intenta `insert` directo en
  `intentos_nivel` o en `respuestas_desafio`, incluso con su propio
  `usuario_id` o para un `intento_id` que le pertenece
- **THEN** la operación se rechaza, sin que la respuesta devuelva distancia
  ni ningún dato derivado de la coordenada real

#### Scenario: Un jugador intenta modificar una respuesta ya registrada

- **WHEN** un usuario autenticado intenta `update` o `delete` sobre una
  fila propia de `respuestas_desafio`
- **THEN** la operación se rechaza

#### Scenario: Las RPC de juego siguen escribiendo a nombre de quien llama

- **WHEN** un usuario autenticado completa una partida usando solo
  `iniciar_intento_parada`, `marcar_desafio_mostrado`, `responder_desafio` y
  `cerrar_intento_parada`
- **THEN** se crean y actualizan sus filas de `intentos_nivel`,
  `intento_desafios`, `respuestas_desafio` y `progreso_usuario_nivel`, todas
  con su propio `auth.uid()`

#### Scenario: Una RPC no actúa sobre un intento ajeno

- **WHEN** un usuario autenticado llama a `cerrar_intento_parada` con el
  `intento_id` de otro usuario
- **THEN** la llamada falla y no cambia ninguna fila de `intentos_nivel` ni
  de `progreso_usuario_nivel`

### Requirement: Selección de desafíos persistida por intento

El esquema SHALL registrar, para cada `intento_nivel`, exactamente qué
desafíos le tocaron y en qué orden, mediante una tabla `intento_desafios`
(`intento_id`, `desafio_id`, `orden`, `mostrado_en`) con clave primaria
compuesta (`intento_id`, `desafio_id`) y una restricción de unicidad sobre
(`intento_id`, `orden`). Un usuario autenticado SHALL poder leer únicamente
las filas de `intento_desafios` cuyo `intento_id` pertenezca a un
`intento_nivel` propio (vía `intentos_nivel.usuario_id`), y no SHALL poder
crearlas, actualizarlas ni borrarlas directamente, ni leer las de un intento
ajeno. La selección la escribe únicamente `iniciar_intento_parada`, y la
única actualización permitida es la de la RPC `marcar_desafio_mostrado`
(`challenge-timer`), que corre con sus propias comprobaciones de pertenencia
y solo puede fijar `mostrado_en` una vez por fila.

#### Scenario: Se persiste la selección de un intento nuevo

- **WHEN** `iniciar_intento_parada` crea un `intento_nivel` y su selección
- **THEN** cada fila de `intento_desafios` queda asociada a exactamente un
  `desafio_id` y una posición (`orden`) dentro de ese intento, con
  `mostrado_en` en `NULL`

#### Scenario: Se intenta duplicar un desafío dentro del mismo intento

- **WHEN** se intenta insertar dos filas de `intento_desafios` con el mismo
  `intento_id` y el mismo `desafio_id`
- **THEN** la base de datos rechaza la operación

#### Scenario: Se intenta poner dos desafíos en la misma posición del mismo intento

- **WHEN** se intenta insertar dos filas de `intento_desafios` con el mismo
  `intento_id` y el mismo `orden`
- **THEN** la base de datos rechaza la operación

#### Scenario: Un jugador lee la selección de su propio intento

- **WHEN** un usuario autenticado hace `select` sobre `intento_desafios`
  filtrando por un `intento_id` cuyo `intentos_nivel.usuario_id` es el suyo
- **THEN** la operación se permite

#### Scenario: Un jugador intenta leer la selección de un intento ajeno

- **WHEN** un usuario autenticado hace `select` sobre `intento_desafios`
  para un `intento_id` cuyo `intentos_nivel.usuario_id` no es el suyo
- **THEN** la operación no devuelve esas filas

#### Scenario: Un jugador intenta escribir la selección de un intento directamente

- **WHEN** un usuario autenticado intenta `insert`, `update` o `delete`
  directo sobre `intento_desafios`, sea de un intento propio o ajeno, sin
  pasar por `iniciar_intento_parada` ni `marcar_desafio_mostrado`
- **THEN** la operación se rechaza

#### Scenario: Se borra un desafío referenciado por una selección persistida

- **WHEN** se intenta borrar un `desafio_id` que tiene al menos una fila en
  `intento_desafios`
- **THEN** la base de datos rechaza el borrado, igual que si estuviera
  referenciado en `respuestas_desafio`

#### Scenario: Se borra un intento

- **WHEN** se borra una fila de `intentos_nivel`
- **THEN** sus filas asociadas en `intento_desafios` se borran en cascada
