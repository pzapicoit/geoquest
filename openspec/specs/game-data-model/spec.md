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

`profiles` SHALL tener Row Level Security habilitado, con una única policy
que permita a un usuario autenticado leer (`select`) su propia fila. Ningún
usuario autenticado ni anónimo SHALL poder insertar, actualizar o borrar
filas de `profiles` por su cuenta — en particular, ningún usuario SHALL
poder cambiar su propio `role`.

Este requisito es un prerrequisito de seguridad de la capability
`challenge-media-storage`: sus policies de escritura comprueban
`profiles.role = 'admin'`, y esa comprobación solo es significativa si
`role` no puede editarse libremente por REST.

#### Scenario: Un usuario lee su propia fila de `profiles`

- **WHEN** un usuario autenticado hace `select` sobre `profiles` filtrando
  por su propio `id`
- **THEN** la operación se permite

#### Scenario: Un usuario intenta cambiar su propio rol

- **WHEN** un usuario autenticado o una sesión anónima intenta `update`
  sobre su propia fila de `profiles`, incluyendo cambiar `role` a `admin`
- **THEN** la base de datos rechaza la operación

#### Scenario: El alta de perfil sigue funcionando

- **WHEN** se crea un nuevo usuario en `auth.users` (alta anónima, INT-75)
- **THEN** el trigger `handle_new_user` sigue creando su fila en `profiles`
  con normalidad, porque corre como `security definer` y no está sujeto a
  estas policies
