## ADDED Requirements

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
