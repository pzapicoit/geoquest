# game-data-model Specification

## Purpose
TBD - created by archiving change int-74-esquema-base-datos. Update Purpose after archive.

## Requirements

### Requirement: Jerarquía temática → nivel → desafío

El esquema SHALL modelar la jerarquía temáticas → niveles → desafíos como
tres entidades relacionadas: `tematicas`, `niveles` (con FK a su temática) y
`desafios` (banco independiente, sin FK fija a ningún nivel).

#### Scenario: Un nivel pertenece a una sola temática

- **WHEN** se crea un nivel
- **THEN** su fila exige un `tematica_id` que referencia una fila existente
  de `tematicas`
- **AND** borrar esa temática borra en cascada sus niveles

#### Scenario: Un desafío no depende de ningún nivel

- **WHEN** se crea un desafío en el banco
- **THEN** su fila no contiene ninguna referencia a un nivel concreto
- **AND** puede existir sin estar asignado a ningún nivel todavía

### Requirement: Asignación de desafíos a niveles con orden propio y reutilización

La tabla `nivel_desafios` SHALL asignar desafíos del banco a niveles
concretos, permitiendo que el mismo desafío se reutilice en varios niveles
con un orden independiente en cada uno.

#### Scenario: La misma pregunta se usa en dos niveles distintos

- **WHEN** un desafío se asigna al nivel A en la posición 2 y al nivel B en
  la posición 5
- **THEN** ambas asignaciones coexisten sin conflicto

#### Scenario: Se intenta asignar el mismo desafío dos veces al mismo nivel

- **WHEN** se intenta insertar una segunda fila con el mismo `nivel_id` y
  `desafio_id`
- **THEN** la base de datos rechaza la operación

#### Scenario: Se intenta poner dos desafíos en la misma posición de un nivel

- **WHEN** se intenta insertar dos filas con el mismo `nivel_id` y el mismo
  `orden`
- **THEN** la base de datos rechaza la operación

### Requirement: Exclusividad de contenido según el tipo de desafío

Cada fila de `desafios` SHALL tener exactamente una de `imagen_url`,
`video_url` o `texto_pregunta` rellena, según su `tipo`, y las otras dos
SHALL ser `NULL`.

#### Scenario: Se crea un desafío de tipo imagen

- **WHEN** se inserta un desafío con `tipo = 'imagen'` e `imagen_url` no nula
- **THEN** la base de datos acepta la fila si `video_url` y `texto_pregunta`
  son `NULL`

#### Scenario: Un desafío de tipo imagen trae también un video

- **WHEN** se intenta insertar un desafío con `tipo = 'imagen'` y
  `video_url` no nula
- **THEN** la base de datos rechaza la operación

#### Scenario: Un desafío de tipo texto no trae el texto de la pregunta

- **WHEN** se intenta insertar un desafío con `tipo = 'pregunta_texto'` y
  `texto_pregunta` nula
- **THEN** la base de datos rechaza la operación

### Requirement: Registro de intentos y respuestas por desafío

Un intento de nivel (`intentos_nivel`) SHALL agrupar las respuestas
(`respuestas_desafio`) que un jugador da a cada desafío de ese intento, sin
límite de intentos por nivel.

#### Scenario: Un intento agrupa varias respuestas

- **WHEN** un jugador responde a los desafíos de un nivel dentro de un mismo
  intento
- **THEN** cada respuesta queda vinculada a ese `intento_id`
- **AND** un mismo desafío no puede responderse dos veces dentro del mismo
  intento

#### Scenario: Un jugador puede rejugar un nivel ya superado

- **WHEN** un jugador vuelve a jugar un nivel que ya superó antes
- **THEN** el esquema permite crear un nuevo `intento_nivel` para ese
  jugador y ese nivel, independiente de los intentos previos

### Requirement: Progreso agregado por jugador y nivel sin recálculo histórico

El esquema SHALL mantener una fila por jugador y nivel
(`progreso_usuario_nivel`) con el mejor resultado obtenido, de forma que
consultar el progreso de un jugador no requiera recorrer su historial
completo de intentos.

#### Scenario: Se consulta el progreso de un jugador en un nivel

- **WHEN** se lee `progreso_usuario_nivel` para un `usuario_id` y `nivel_id`
  dados
- **THEN** existe como máximo una fila con el mejor puntaje, mejores
  estrellas y estado de desbloqueo conocidos hasta ese momento

#### Scenario: Un jugador sin intentos previos en un nivel

- **WHEN** un jugador no ha intentado nunca un nivel dado
- **THEN** no existe fila en `progreso_usuario_nivel` para ese par
  usuario/nivel

### Requirement: Cada usuario tiene un perfil con rol

Todo usuario de `auth.users` SHALL poder tener una fila correspondiente en
`profiles`, identificada por el mismo `id`, con un `role` que sea `admin` o
`jugador`.

#### Scenario: Un perfil se identifica con el usuario de Auth

- **WHEN** se crea una fila en `profiles`
- **THEN** su `id` referencia una fila existente de `auth.users`
- **AND** borrar ese usuario de Auth borra en cascada su perfil

#### Scenario: Un perfil con rol inválido

- **WHEN** se intenta insertar o actualizar un perfil con un `role` distinto
  de `admin` o `jugador`
- **THEN** la base de datos rechaza la operación

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

### Requirement: `niveles` admite un nombre editable opcional

`niveles` SHALL tener una columna `nombre` de tipo texto, opcional
(nullable, sin valor por defecto), independiente de `orden`. Los niveles
existentes sin `nombre` SHALL seguir identificándose por su `orden` en
cualquier pantalla que ya lo hiciera así.

#### Scenario: Se asigna un nombre a un nivel existente

- **WHEN** se actualiza un nivel existente estableciendo `nombre = 'Costas
  del Mediterráneo'`
- **THEN** la fila queda con ese `nombre` sin afectar a su `orden` ni a sus
  asignaciones en `nivel_desafios`

#### Scenario: Un nivel sin nombre asignado

- **WHEN** se crea o consulta un nivel cuyo `nombre` nunca se ha establecido
- **THEN** la columna `nombre` es `NULL` y el nivel sigue siendo válido e
  identificable por `tematica_id` + `orden`

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

### Requirement: Selección de desafíos persistida por intento

El esquema SHALL registrar, para cada `intento_nivel`, exactamente qué
desafíos le tocaron y en qué orden, mediante una tabla `intento_desafios`
(`intento_id`, `desafio_id`, `orden`) con clave primaria compuesta
(`intento_id`, `desafio_id`) y una restricción de unicidad sobre
(`intento_id`, `orden`). Un usuario autenticado SHALL poder leer y crear
únicamente las filas de `intento_desafios` cuyo `intento_id` pertenezca a un
`intento_nivel` propio (vía `intentos_nivel.usuario_id`), y no SHALL poder
actualizarlas ni leer o crear filas de un intento ajeno.

#### Scenario: Se persiste la selección de un intento nuevo

- **WHEN** se crea un `intento_nivel` y se insertan filas de
  `intento_desafios` para ese `intento_id`
- **THEN** cada fila queda asociada a exactamente un `desafio_id` y una
  posición (`orden`) dentro de ese intento

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

#### Scenario: Se borra un desafío referenciado por una selección persistida

- **WHEN** se intenta borrar un `desafio_id` que tiene al menos una fila en
  `intento_desafios`
- **THEN** la base de datos rechaza el borrado, igual que si estuviera
  referenciado en `nivel_desafios` o `respuestas_desafio`

#### Scenario: Se borra un intento

- **WHEN** se borra una fila de `intentos_nivel`
- **THEN** sus filas asociadas en `intento_desafios` se borran en cascada
