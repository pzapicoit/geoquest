## ADDED Requirements

### Requirement: Campo opcional de ciudad en el formulario de preguntas

El formulario de preguntas del panel SHALL incluir un campo opcional `ciudad` (ciudad real del objetivo), independiente del campo de lugar real (`nombre_lugar`) y del de país (`pais`), que no bloquea el guardado si se deja vacío.

El campo SHALL indicar que es lo que la app muestra al jugador al revelar la respuesta, para que el admin entienda por qué merece la pena rellenarlo y qué se lee si lo deja vacío.

#### Scenario: Se guarda una pregunta sin ciudad

- **WHEN** un admin guarda una pregunta sin rellenar el campo `ciudad`
- **THEN** la pregunta se guarda con normalidad, con `ciudad` vacía

#### Scenario: Se guarda una pregunta con ciudad

- **WHEN** un admin rellena el campo `ciudad` y guarda la pregunta
- **THEN** la pregunta se guarda con esa ciudad

#### Scenario: Se edita una pregunta que ya tiene ciudad

- **WHEN** un admin abre para editar una pregunta cuya `ciudad` es "Nueva York"
- **THEN** el campo `ciudad` aparece relleno con "Nueva York"

#### Scenario: Se vacía la ciudad de una pregunta que la tenía

- **WHEN** un admin borra el contenido del campo `ciudad` de una pregunta que la tenía y guarda
- **THEN** la pregunta queda con `ciudad` vacía, y no con una cadena en blanco que la app leería como ciudad válida
