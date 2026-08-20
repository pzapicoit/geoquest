## MODIFIED Requirements

### Requirement: Nombre del lugar

El formulario SHALL ofrecer un campo de texto libre obligatorio para el
nombre del lugar, etiquetado de forma que quede claro que es la respuesta
real que se revela al jugador al terminar el desafío — no el nombre de la
pregunta (ese es el campo `nombre`, primero en el formulario).

#### Scenario: Nombre del lugar vacío al guardar

- **WHEN** un admin intenta guardar sin haber escrito el nombre del lugar
- **THEN** el formulario muestra un error en ese campo y bloquea el
  guardado

### Requirement: Validación de campos obligatorios según el tipo

El formulario SHALL bloquear el guardado y señalar los campos con error
cuando falte el contenido obligatorio para el tipo elegido (imagen, vídeo
o texto), el nombre corto de la pregunta, el nombre del lugar, o
coordenadas válidas.

#### Scenario: Tipo imagen sin archivo

- **WHEN** un admin intenta guardar con tipo "Imagen" sin haber
  seleccionado ningún archivo (ni existir uno previo en edición)
- **THEN** el formulario bloquea el guardado y muestra un error en el
  campo de imagen

#### Scenario: Nombre corto vacío

- **WHEN** un admin intenta guardar sin haber escrito el nombre corto de la
  pregunta
- **THEN** el formulario bloquea el guardado y muestra un error en ese
  campo

## ADDED Requirements

### Requirement: Nombre corto de la pregunta

El formulario SHALL ofrecer, como primer campo, un texto libre obligatorio
para el nombre corto de la pregunta (p. ej. "Torre Eiffel", "Charles
Darwin"), usado como identificador de esa pregunta en el panel y mostrado
también al jugador junto al objetivo global de la temática.

#### Scenario: Se escribe el nombre corto

- **WHEN** un admin escribe "Torre Eiffel" en el campo de nombre
- **THEN** ese texto queda listo para guardarse como `nombre` del desafío

#### Scenario: Preguntas ya existentes antes de este cambio

- **WHEN** un admin abre para editar una pregunta creada antes de la
  existencia de `desafios.nombre`
- **THEN** el campo aparece precargado con el valor que la migración le
  asignó, editable como cualquier otra pregunta

### Requirement: Pista opcional

El formulario SHALL ofrecer un campo de texto libre opcional para la pista
adicional del desafío, indicando que por ahora no se muestra en ningún
sitio salvo este propio formulario.

#### Scenario: Se guarda una pregunta sin pista

- **WHEN** un admin guarda una pregunta sin escribir nada en el campo de
  pista
- **THEN** la pregunta se guarda con `pista` nula, sin bloquear el
  guardado

#### Scenario: Se guarda una pregunta con pista

- **WHEN** un admin escribe un texto en el campo de pista y guarda
- **THEN** la pregunta se guarda con ese texto en `pista`
