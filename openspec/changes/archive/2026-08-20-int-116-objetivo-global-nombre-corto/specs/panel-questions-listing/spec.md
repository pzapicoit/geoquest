## MODIFIED Requirements

### Requirement: Listado del banco de desafíos, una fila por desafío

La pantalla de listado SHALL mostrar una fila por cada desafío del banco,
con: miniatura (imagen real para `tipo = 'imagen'`, ícono para
`video`/`pregunta_texto`), `nombre` del desafío, badge de tipo, badge de
dificultad y estado (activo/inactivo).

#### Scenario: Se muestra la dificultad de cada desafío

- **WHEN** un desafío del banco tiene `dificultad = 'dificil'`
- **THEN** su fila muestra el badge "Difícil"

#### Scenario: Desafíos migrados sin dificultad propia asignada aún

- **WHEN** un desafío creado antes de este cambio conserva `dificultad = 'normal'`
  por la migración
- **THEN** su fila muestra el badge "Normal", editable como cualquier otro

#### Scenario: La fila identifica la pregunta por su nombre

- **WHEN** se muestra la fila de un desafío cuyo `nombre` es "Torre Eiffel"
- **THEN** la fila muestra "Torre Eiffel" como identificador, no
  `nombre_lugar` ni `texto_pregunta`

### Requirement: Búsqueda por lugar o texto de la pregunta

El listado SHALL ofrecer un buscador que filtre los desafíos cuyo
`nombre` o `nombre_lugar` contenga el texto buscado (case-insensitive),
combinable con el resto de filtros.

#### Scenario: Búsqueda por nombre de la pregunta

- **WHEN** un admin escribe "eiffel" en el buscador y existe un desafío con
  `nombre = 'Torre Eiffel'`
- **THEN** el listado muestra ese desafío entre los resultados

#### Scenario: Búsqueda por el lugar real revelado

- **WHEN** un admin escribe "roma" en el buscador y existe un desafío cuyo
  `nombre_lugar` contiene "Roma" aunque su `nombre` no la mencione
- **THEN** el listado muestra ese desafío entre los resultados
