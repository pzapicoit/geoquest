## MODIFIED Requirements

### Requirement: Layout fijo con navegación lateral

La zona autenticada del panel SHALL mostrar una navegación lateral fija con
los enlaces Home, Jugadores, Ranking, Temáticas y Preguntas/Desafíos.
Home, Temáticas y Preguntas/Desafíos SHALL navegar a su pantalla propia;
Jugadores y Ranking SHALL renderizarse deshabilitados (sin navegación al
hacer click) hasta que tengan pantalla propia. La navegación SHALL no
incluir un enlace "Niveles": los niveles no tienen una pantalla de listado
fuera del contexto de una temática (ver `/tematicas/:id/niveles` en
`panel-levels-listing`).

#### Scenario: Admin autenticado ve la navegación vigente

- **WHEN** un admin autenticado abre el panel
- **THEN** ve la navegación lateral con 5 enlaces (Home, Jugadores,
  Ranking, Temáticas, Preguntas/Desafíos), sin "Niveles"
- **AND** Home, Temáticas y Preguntas/Desafíos navegan a su pantalla
  propia

#### Scenario: Click en un enlace de navegación sin pantalla propia

- **WHEN** el admin hace click en "Jugadores" o "Ranking"
- **THEN** el panel no navega a ninguna ruta (el enlace está deshabilitado)
