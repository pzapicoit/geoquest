## MODIFIED Requirements

### Requirement: `profiles` tiene RLS mínimo y `role` no es auto-editable

`profiles` SHALL tener Row Level Security habilitado, con una policy que
permita a un usuario autenticado leer (`select`) su propia fila y otra que
le permita actualizar (`update`) su propia fila, salvo el campo `role`.
Ningún usuario autenticado ni anónimo SHALL poder insertar ni borrar filas
de `profiles` por su cuenta, ni cambiar el `role` de su propia fila ni el
de ninguna otra.

Este requisito es un prerrequisito de seguridad de la capability
`challenge-media-storage`: sus policies de escritura comprueban
`profiles.role = 'admin'`, y esa comprobación solo es significativa si
`role` no puede editarse libremente por REST.

#### Scenario: Un usuario lee su propia fila de `profiles`

- **WHEN** un usuario autenticado hace `select` sobre `profiles` filtrando
  por su propio `id`
- **THEN** la operación se permite

#### Scenario: Un usuario edita su propio nombre o avatar

- **WHEN** un usuario autenticado hace `update` sobre su propia fila de
  `profiles`, cambiando `nombre` y/o `avatar_url` sin tocar `role`
- **THEN** la operación se permite

#### Scenario: Un usuario intenta cambiar su propio rol

- **WHEN** un usuario autenticado o una sesión anónima intenta `update`
  sobre su propia fila de `profiles`, incluyendo cambiar `role` a `admin`
- **THEN** la base de datos rechaza la operación completa (ninguna columna
  de esa fila se actualiza)

#### Scenario: Un usuario intenta editar la fila de otro

- **WHEN** un usuario autenticado intenta `update` sobre una fila de
  `profiles` cuyo `id` no coincide con su propio `auth.uid()`
- **THEN** la operación no afecta ninguna fila

#### Scenario: El alta de perfil sigue funcionando

- **WHEN** se crea un nuevo usuario en `auth.users` (alta anónima, INT-75)
- **THEN** el trigger `handle_new_user` sigue creando su fila en `profiles`
  con normalidad, porque corre como `security definer` y no está sujeto a
  estas policies

#### Scenario: La asignación manual del primer admin sigue funcionando

- **WHEN** se actualiza `role` a `admin` para una fila de `profiles` desde
  el SQL editor/dashboard de Supabase (rol `postgres`, con `bypassrls`) o
  con la clave de servicio (`service_role`)
- **THEN** la operación se permite, porque esos roles no están sujetos a
  RLS

## ADDED Requirements

### Requirement: Función auxiliar `is_admin()`

El esquema SHALL exponer una función `is_admin()` que devuelva si el
usuario autenticado actual (`auth.uid()`) tiene `profiles.role = 'admin'`,
reutilizable desde cualquier policy de RLS del esquema del juego.

#### Scenario: Se invoca `is_admin()` para un usuario con rol admin

- **WHEN** un usuario cuya fila en `profiles` tiene `role = 'admin'` invoca
  `is_admin()`
- **THEN** la función devuelve `true`

#### Scenario: Se invoca `is_admin()` para un usuario jugador

- **WHEN** un usuario cuya fila en `profiles` tiene `role = 'jugador'`
  (incluida una sesión anónima) invoca `is_admin()`
- **THEN** la función devuelve `false`

### Requirement: Lectura pública de `tematicas`, `niveles` y `nivel_desafios` para autenticados

`tematicas`, `niveles` y `nivel_desafios` SHALL tener Row Level Security
habilitado, con una policy que permita `select` a cualquier usuario
autenticado (incluida una sesión anónima), sin restricción adicional por
fila.

#### Scenario: Un jugador lee el catálogo de temáticas y niveles

- **WHEN** un usuario autenticado (o con sesión anónima) hace `select`
  sobre `tematicas`, `niveles` o `nivel_desafios`
- **THEN** la operación se permite y devuelve todas las filas

### Requirement: Escritura de contenido del juego restringida a administradores

`tematicas`, `niveles`, `desafios` y `nivel_desafios` SHALL rechazar
cualquier `insert`, `update` o `delete` de un usuario para el que
`is_admin()` devuelva `false`.

#### Scenario: Un admin crea o edita contenido

- **WHEN** un usuario con `is_admin() = true` hace `insert`, `update` o
  `delete` sobre `tematicas`, `niveles`, `desafios` o `nivel_desafios`
- **THEN** la operación se permite

#### Scenario: Un jugador intenta crear o editar contenido

- **WHEN** un usuario con `is_admin() = false` (incluida una sesión
  anónima) intenta `insert`, `update` o `delete` sobre `tematicas`,
  `niveles`, `desafios` o `nivel_desafios`
- **THEN** la operación se rechaza

### Requirement: `desafios` no es legible directamente por jugadores

`desafios` SHALL tener Row Level Security habilitado. Ningún usuario para
el que `is_admin()` devuelva `false` SHALL poder leer (`select`)
directamente la tabla `desafios`; solo `is_admin()` SHALL poder leerla. El
acceso de juego a los desafíos ocurre a través de una vista dedicada
(`desafios_para_jugar`, INT-95) que no expone `lat_real`, `lng_real` ni
`nombre_lugar`, fuera del alcance de este requisito.

#### Scenario: Un jugador intenta leer `desafios` directamente

- **WHEN** un usuario con `is_admin() = false` (incluida una sesión
  anónima) hace `select` sobre `desafios`
- **THEN** la operación no devuelve ninguna fila

#### Scenario: Un admin lee `desafios` directamente

- **WHEN** un usuario con `is_admin() = true` hace `select` sobre
  `desafios`
- **THEN** la operación se permite y devuelve las filas, incluidas
  `lat_real`, `lng_real` y `nombre_lugar`

### Requirement: Progreso de juego visible y editable solo por su propio usuario

`intentos_nivel`, `respuestas_desafio` y `progreso_usuario_nivel` SHALL
tener Row Level Security habilitado. Un usuario autenticado SHALL poder
leer y crear únicamente las filas asociadas a su propio `auth.uid()` (vía
`usuario_id` en `intentos_nivel`/`progreso_usuario_nivel`, o vía
`intento_id -> intentos_nivel.usuario_id` en `respuestas_desafio`), y no
SHALL poder leer ni crear filas de otro usuario. `intentos_nivel` y
`progreso_usuario_nivel` SHALL además permitir `update` de las propias
filas; `respuestas_desafio` no.

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

#### Scenario: Un jugador registra un intento y sus respuestas

- **WHEN** un usuario autenticado hace `insert` en `intentos_nivel` con su
  propio `usuario_id`, y luego `insert` en `respuestas_desafio` para un
  `intento_id` que le pertenece
- **THEN** ambas operaciones se permiten

#### Scenario: Un jugador intenta crear un intento a nombre de otro usuario

- **WHEN** un usuario autenticado intenta `insert` en `intentos_nivel` con
  un `usuario_id` distinto de su propio `auth.uid()`
- **THEN** la operación se rechaza

#### Scenario: Un jugador actualiza su intento y su progreso agregado

- **WHEN** un usuario autenticado hace `update` sobre su propia fila de
  `intentos_nivel` o de `progreso_usuario_nivel`
- **THEN** la operación se permite

#### Scenario: Un jugador intenta modificar una respuesta ya registrada

- **WHEN** un usuario autenticado intenta `update` sobre una fila propia de
  `respuestas_desafio`
- **THEN** la operación se rechaza, porque no existe policy de `update`
  para esta tabla
