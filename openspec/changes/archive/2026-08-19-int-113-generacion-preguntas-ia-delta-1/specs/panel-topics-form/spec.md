## ADDED Requirements

### Requirement: Prompt de imagen de la temática

El formulario de temática SHALL ofrecer un campo de texto multilínea opcional
para el prompt de imagen de esa temática, explicando que la generación con IA lo
aplicará a todas las ilustraciones de sus preguntas. Al editar, SHALL precargar
el valor guardado; vacío SHALL guardarse como sin indicaciones.

#### Scenario: Se guarda el prompt de una temática

- **WHEN** un admin escribe "la ilustración es la bandera del país sobre fondo
  neutro, sin escena alrededor" y guarda la temática
- **THEN** ese texto queda guardado en la temática

#### Scenario: Se edita una temática que ya tiene prompt

- **WHEN** un admin abre el formulario de una temática con prompt guardado
- **THEN** el campo aparece precargado con ese texto

#### Scenario: El campo es opcional

- **WHEN** un admin guarda una temática dejando el campo vacío
- **THEN** la temática se guarda sin bloquear el formulario
