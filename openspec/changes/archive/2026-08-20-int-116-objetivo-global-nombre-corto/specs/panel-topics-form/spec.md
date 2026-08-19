## ADDED Requirements

### Requirement: Objetivo global obligatorio

El formulario SHALL ofrecer un campo de texto obligatorio para el
`objetivo_global` de la temática, explicando que es la formulación fija de
qué se le pregunta al jugador en cualquier desafío de esa temática y que se
muestra siempre en la pantalla de juego. Al editar, SHALL precargar el
valor guardado.

#### Scenario: Guardar sin objetivo_global

- **WHEN** un admin intenta guardar una temática con el campo de objetivo
  global vacío
- **THEN** el formulario bloquea el guardado y muestra un error en ese
  campo

#### Scenario: Se edita una temática con objetivo_global guardado

- **WHEN** un admin abre el formulario de una temática con `objetivo_global`
  guardado
- **THEN** el campo aparece precargado con ese texto

#### Scenario: Se guarda el objetivo_global de una temática nueva

- **WHEN** un admin escribe "¿Dónde está este monumento?" en el campo de
  objetivo global y guarda la temática
- **THEN** ese texto queda guardado como `objetivo_global` de la temática
