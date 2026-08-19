## ADDED Requirements

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
