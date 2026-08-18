## MODIFIED Requirements

### Requirement: Selección de desafíos persistida por intento

El esquema SHALL registrar, para cada `intento_nivel`, exactamente qué
desafíos le tocaron y en qué orden, mediante una tabla `intento_desafios`
(`intento_id`, `desafio_id`, `orden`, `mostrado_en`) con clave primaria
compuesta (`intento_id`, `desafio_id`) y una restricción de unicidad sobre
(`intento_id`, `orden`). Un usuario autenticado SHALL poder leer y crear
únicamente las filas de `intento_desafios` cuyo `intento_id` pertenezca a un
`intento_nivel` propio (vía `intentos_nivel.usuario_id`), y no SHALL poder
actualizarlas directamente ni leer o crear filas de un intento ajeno. La
única excepción a la prohibición de actualizar es la RPC
`marcar_desafio_mostrado` (`challenge-timer`), que corre con sus propias
comprobaciones de pertenencia y solo puede fijar `mostrado_en` una vez por
fila.

#### Scenario: Se persiste la selección de un intento nuevo

- **WHEN** se crea un `intento_nivel` y se insertan filas de
  `intento_desafios` para ese `intento_id`
- **THEN** cada fila queda asociada a exactamente un `desafio_id` y una
  posición (`orden`) dentro de ese intento, con `mostrado_en` en `NULL`

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

#### Scenario: Un jugador intenta registrar selección para un intento ajeno

- **WHEN** un usuario autenticado intenta `insert` en `intento_desafios`
  para un `intento_id` cuyo `intentos_nivel.usuario_id` no es el suyo
- **THEN** la operación se rechaza

#### Scenario: Un jugador intenta actualizar `intento_desafios` directamente

- **WHEN** un usuario autenticado intenta `update` sobre una fila propia de
  `intento_desafios` sin pasar por `marcar_desafio_mostrado`
- **THEN** la operación se rechaza

#### Scenario: Se borra un desafío referenciado por una selección persistida

- **WHEN** se intenta borrar un `desafio_id` que tiene al menos una fila en
  `intento_desafios`
- **THEN** la base de datos rechaza el borrado, igual que si estuviera
  referenciado en `nivel_desafios` o en `respuestas_desafio`

#### Scenario: Se borra un intento

- **WHEN** se borra una fila de `intentos_nivel`
- **THEN** sus filas asociadas en `intento_desafios` se borran en cascada
