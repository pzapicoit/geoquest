# question-difficulty Specification

## Purpose
TBD - created by archiving change int-106-rediseno-tematicas-dificultad-camino. Update Purpose after archive.

## Requirements

### Requirement: Catálogo cerrado de 5 dificultades
El sistema SHALL modelar la dificultad de una pregunta como un tipo enumerado cerrado con exactamente 5 valores: Fácil, Normal, Intermedio, Difícil y Muy difícil. El admin SHALL no poder crear, renombrar ni borrar valores de dificultad desde el panel ni desde ninguna API.

#### Scenario: Se consultan las dificultades disponibles
- **WHEN** el panel necesita ofrecer el catálogo de dificultades (selector de preguntas, pantalla de valores por defecto, constructor del camino)
- **THEN** obtiene exactamente los 5 valores fijos, en el mismo orden de menor a mayor dificultad

#### Scenario: Se intenta usar un valor de dificultad inexistente
- **WHEN** se intenta guardar una pregunta o una posición del camino con un valor de dificultad que no es uno de los 5 del catálogo
- **THEN** la base de datos rechaza la operación

### Requirement: Toda pregunta tiene una dificultad obligatoria
`desafios` SHALL tener una columna `dificultad` no nula. Toda pregunta nueva o editada SHALL exigir un valor de dificultad válido del catálogo cerrado.

#### Scenario: Se crea una pregunta sin indicar dificultad
- **WHEN** se intenta insertar un desafío sin especificar `dificultad`
- **THEN** la base de datos rechaza la operación

#### Scenario: Se crea una pregunta con dificultad válida
- **WHEN** se inserta un desafío con `dificultad = 'facil'`
- **THEN** la fila se guarda con esa dificultad

#### Scenario: Preguntas ya existentes antes de este cambio
- **WHEN** se consulta una pregunta creada antes de la existencia de la columna `dificultad`
- **THEN** su `dificultad` es `'normal'`, asignada por la migración como punto de partida neutro, editable después por un admin

### Requirement: Selector de dificultad obligatorio en el formulario de preguntas
El formulario de preguntas del panel SHALL ofrecer un selector obligatorio con los 5 valores del catálogo, y SHALL bloquear el guardado si no se elige ninguno.

#### Scenario: Guardar sin elegir dificultad
- **WHEN** un admin intenta guardar una pregunta nueva sin seleccionar ninguna dificultad
- **THEN** el formulario bloquea el guardado y muestra un error en ese campo

#### Scenario: Editar una pregunta migrada
- **WHEN** un admin abre para editar una pregunta creada antes de este cambio
- **THEN** el selector muestra "Normal" preseleccionada, editable como cualquier otra pregunta
