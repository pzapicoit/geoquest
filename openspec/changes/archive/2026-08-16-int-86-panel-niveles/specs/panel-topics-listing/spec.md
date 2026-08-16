## MODIFIED Requirements

### Requirement: Enlace del nombre habilitado hacia el listado de niveles
El nombre de cada fila SHALL enlazar a la pantalla de listado de niveles de
esa temática (`/tematicas/:id/niveles`).

#### Scenario: Click en el nombre de una temática
- **WHEN** un admin hace click en el nombre de una temática en el listado
- **THEN** el panel navega a la pantalla de listado de niveles de esa
  temática
