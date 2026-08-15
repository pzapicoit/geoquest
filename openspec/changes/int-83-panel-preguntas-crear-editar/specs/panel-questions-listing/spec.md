## REMOVED Requirements

### Requirement: Acciones deshabilitadas hasta que exista su pantalla
**Reason**: La pantalla de creación/edición ya existe (INT-83).
**Migration**: Ver el nuevo requisito "Acciones de creación y edición
habilitadas" en esta misma capability.

## ADDED Requirements

### Requirement: Acciones de creación y edición habilitadas
El botón "Nueva pregunta" SHALL navegar a `/preguntas/nueva`, y la acción
"Editar" de cada fila SHALL navegar a `/preguntas/{id}/editar`.

#### Scenario: Click en "Nueva pregunta"
- **WHEN** un admin hace click en el botón "Nueva pregunta"
- **THEN** el panel navega a `/preguntas/nueva`

#### Scenario: Click en "Editar" de una fila
- **WHEN** un admin hace click en la acción "Editar" de una pregunta con
  `id = <uuid>`
- **THEN** el panel navega a `/preguntas/<uuid>/editar`
