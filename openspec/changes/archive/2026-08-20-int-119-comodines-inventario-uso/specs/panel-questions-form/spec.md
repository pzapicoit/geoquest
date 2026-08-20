## ADDED Requirements

### Requirement: Campo opcional de país en el formulario de preguntas

El formulario de preguntas del panel SHALL incluir un campo opcional `pais` (país real del objetivo), independiente del campo de lugar real (`nombre_lugar`), que no bloquea el guardado si se deja vacío.

#### Scenario: Se guarda una pregunta sin país

- **WHEN** un admin guarda una pregunta sin rellenar el campo `pais`
- **THEN** la pregunta se guarda con normalidad, con `pais` vacío

#### Scenario: Se guarda una pregunta con país

- **WHEN** un admin rellena el campo `pais` y guarda la pregunta
- **THEN** la pregunta se guarda con ese país
