## ADDED Requirements

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
