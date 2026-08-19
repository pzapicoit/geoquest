## MODIFIED Requirements

### Requirement: Acciones de creación y edición habilitadas
El botón "Nueva pregunta" SHALL navegar a `/preguntas/nueva`, el botón "Generar
con IA" SHALL navegar a `/preguntas/generar-ia`, y la acción "Editar" de cada
fila SHALL navegar a `/preguntas/{id}/editar`.

#### Scenario: Click en "Nueva pregunta"
- **WHEN** un admin hace click en el botón "Nueva pregunta"
- **THEN** el panel navega a `/preguntas/nueva`

#### Scenario: Click en "Generar con IA"
- **WHEN** un admin hace click en el botón "Generar con IA"
- **THEN** el panel navega a `/preguntas/generar-ia`

#### Scenario: Click en "Editar" de una fila
- **WHEN** un admin hace click en la acción "Editar" de una pregunta con
  `id = <uuid>`
- **THEN** el panel navega a `/preguntas/<uuid>/editar`
