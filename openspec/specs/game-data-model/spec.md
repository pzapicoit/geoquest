# game-data-model Specification

## Purpose
TBD - created by archiving change int-74-esquema-base-datos. Update Purpose after archive.

## Requirements

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

### Requirement: Progreso agregado por jugador y parada del camino sin recálculo histórico

El esquema SHALL mantener una fila por jugador y parada del camino (`progreso_usuario_nivel`, con columna `camino_id` en vez de `nivel_id`) con el mejor resultado obtenido, de forma que consultar el progreso de un jugador no requiera recorrer su historial completo de intentos.

#### Scenario: Se consulta el progreso de un jugador en una parada

- **WHEN** se lee `progreso_usuario_nivel` para un `usuario_id` y `camino_id` dados
- **THEN** existe como máximo una fila con el mejor puntaje, mejores estrellas y estado de desbloqueo conocidos hasta ese momento

#### Scenario: Un jugador sin intentos previos en una parada

- **WHEN** un jugador no ha intentado nunca una parada dada
- **THEN** no existe fila en `progreso_usuario_nivel` para ese par usuario/parada

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
  referenciado en `respuestas_desafio`

#### Scenario: Se borra un intento

- **WHEN** se borra una fila de `intentos_nivel`
- **THEN** sus filas asociadas en `intento_desafios` se borran en cascada

### Requirement: Estilo de ilustración por temática

`tematicas` SHALL tener una columna de texto opcional `prompt_imagen` con las
indicaciones de estilo que la generación de imágenes con IA aplica a las
preguntas de esa temática. Estar vacía SHALL ser válido y SHALL significar "sin
indicaciones propias".

La columna SHALL quedar sujeta a las policies ya vigentes de `tematicas`:
legible por cualquier usuario autenticado, escribible solo por administradores.

#### Scenario: Una temática guarda su estilo de ilustración

- **WHEN** un admin guarda una temática con un texto en `prompt_imagen`
- **THEN** la fila conserva ese texto

#### Scenario: Una temática sin estilo propio

- **WHEN** se crea una temática sin indicar `prompt_imagen`
- **THEN** la fila se crea con ese campo nulo, sin error

#### Scenario: Un jugador no puede escribir el estilo

- **WHEN** un usuario para el que `is_admin()` es `false` intenta actualizar
  `prompt_imagen` de una temática
- **THEN** la base de datos rechaza la operación, igual que con el resto de
  columnas de `tematicas`

### Requirement: Objetivo global de la temática

`tematicas` SHALL tener una columna de texto obligatoria `objetivo_global`
con la formulación fija de qué se pregunta al jugador en cualquier desafío
de esa temática (p. ej. "¿Dónde está este monumento?"). Toda fila de
`tematicas` SHALL tener este campo relleno, incluidas las temáticas creadas
antes de la existencia de esta columna.

#### Scenario: Se crea una temática sin objetivo_global

- **WHEN** un admin intenta guardar una temática nueva sin haber escrito su
  `objetivo_global`
- **THEN** la base de datos rechaza la operación

#### Scenario: Temáticas ya existentes antes de este cambio

- **WHEN** se consulta `objetivo_global` de una temática creada antes de la
  existencia de esta columna
- **THEN** el campo devuelve el texto que la migración le asignó, no `NULL`

### Requirement: Nombre corto del desafío

`desafios` SHALL tener una columna de texto obligatoria `nombre` con el
nombre corto del sujeto de la pregunta (p. ej. "Torre Eiffel", "Charles
Darwin"), independiente de `nombre_lugar` (la respuesta real que se revela
al terminar el desafío). Toda fila de `desafios` SHALL tener este campo
relleno, incluidos los desafíos creados antes de la existencia de esta
columna.

#### Scenario: Se crea un desafío sin nombre

- **WHEN** se intenta insertar un desafío sin `nombre`
- **THEN** la base de datos rechaza la operación

#### Scenario: Desafíos ya existentes antes de este cambio

- **WHEN** se consulta `nombre` de un desafío creado antes de la existencia
  de esta columna
- **THEN** el campo devuelve el texto que la migración le asignó, no `NULL`

### Requirement: Pista opcional del desafío

`desafios` SHALL tener una columna de texto opcional `pista` con una pista
adicional en modo texto sobre la pregunta. Estar vacía SHALL ser válido y
SHALL significar "sin pista adicional".

#### Scenario: Se crea un desafío sin pista

- **WHEN** se crea un desafío sin indicar `pista`
- **THEN** la fila se crea con ese campo nulo, sin error

#### Scenario: Se crea un desafío con pista

- **WHEN** un admin guarda un desafío con un texto en `pista`
- **THEN** la fila conserva ese texto

### Requirement: Esquema de inventario de comodines y marca de uso por intento

El esquema SHALL modelar el inventario de comodines como una tabla `comodines_inventario` con una fila por `(usuario_id, tipo)` de un catálogo cerrado `tipo_comodin` (`tiempo`, `pais`, `km1000`, `km500`), y SHALL añadir una columna nullable `comodin_usado` (del mismo catálogo) a la tabla de intentos, que registra qué comodín (si alguno) se ha consumido ya en ese intento.

#### Scenario: Se crea el inventario de un perfil nuevo

- **WHEN** se crea un nuevo usuario en `auth.users` y su perfil correspondiente (alta anónima, INT-75)
- **THEN** el trigger de creación de perfil inserta también las 4 filas de `comodines_inventario` para ese usuario, con cantidades `{tiempo: 1, pais: 1, km1000: 1, km500: 0}`

#### Scenario: Un intento nuevo empieza sin comodín usado

- **WHEN** se crea un intento nuevo (`iniciar_intento_parada`)
- **THEN** su columna `comodin_usado` es `NULL`

#### Scenario: Se intenta insertar un tipo de comodín fuera del catálogo

- **WHEN** se intenta insertar o actualizar una fila de `comodines_inventario` o la columna `comodin_usado` con un valor que no pertenece al catálogo `tipo_comodin`
- **THEN** la base de datos rechaza la operación

### Requirement: Campo de país por desafío

`desafios` SHALL ganar una columna `pais` (texto, nullable) con el país real del objetivo, independiente de `nombre_lugar`.

#### Scenario: Se crea un desafío sin país

- **WHEN** se inserta un desafío sin especificar `pais`
- **THEN** la base de datos acepta la fila con `pais` en `NULL`

#### Scenario: Se crea un desafío con país

- **WHEN** se inserta o actualiza un desafío especificando `pais`
- **THEN** la base de datos guarda ese valor sin validarlo contra ningún catálogo cerrado

### Requirement: Contador persistente de intentos desde el último anuncio de cadencia

`profiles` SHALL tener una columna `intentos_desde_ultimo_anuncio_cadencia integer` obligatoria con valor por defecto `0`, que cuenta intentos de parada jugados desde el último anuncio de cadencia mostrado a ese jugador (`video-ads`). Esta columna SHALL sobrevivir a reinstalar la app o cambiar de dispositivo, igual que el resto del progreso del jugador.

#### Scenario: Se crea un perfil nuevo

- **WHEN** se crea un nuevo usuario en `auth.users` y su perfil correspondiente (alta anónima, INT-75)
- **THEN** su fila de `profiles` tiene `intentos_desde_ultimo_anuncio_cadencia = 0`

#### Scenario: Perfiles ya existentes antes de este cambio

- **WHEN** se consulta `intentos_desde_ultimo_anuncio_cadencia` de un perfil creado antes de la existencia de esta columna
- **THEN** el campo devuelve `0`, no `NULL`

### Requirement: Catálogo cerrado del tipo de anuncio pendiente

El esquema SHALL exponer un enum `tipo_anuncio_pendiente` con exactamente 3 valores: `ninguno`, `desbloqueo` y `cadencia`, usado como tipo de retorno de la lógica de decisión de anuncios (`video-ads`).

#### Scenario: Se intenta usar un valor fuera del catálogo

- **WHEN** cualquier función o columna tipada como `tipo_anuncio_pendiente` intenta tomar un valor que no sea `ninguno`, `desbloqueo` o `cadencia`
- **THEN** la base de datos rechaza la operación
