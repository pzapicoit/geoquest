# panel-questions-listing Specification

## Purpose
TBD - created by syncing change int-82-panel-preguntas-listado. Update Purpose after archive.

## Requirements

### Requirement: Enlace de navegación habilitado
La navegación lateral del panel SHALL habilitar el enlace
"Preguntas/Desafíos" para que navegue a la pantalla de listado, en lugar de
mostrarse deshabilitado.

#### Scenario: Click en el enlace de navegación
- **WHEN** un admin autenticado hace click en "Preguntas/Desafíos" en la
  navegación lateral
- **THEN** el panel navega a la pantalla de listado de preguntas

### Requirement: Listado del banco de desafíos, una fila por desafío
La pantalla de listado SHALL mostrar una fila por cada desafío del banco,
con: miniatura (imagen real para `tipo = 'imagen'`, ícono para
`video`/`pregunta_texto`), nombre del lugar, badge de tipo, badge de
dificultad y estado (activo/inactivo).

#### Scenario: Se muestra la dificultad de cada desafío
- **WHEN** un desafío del banco tiene `dificultad = 'dificil'`
- **THEN** su fila muestra el badge "Difícil"

#### Scenario: Desafíos migrados sin dificultad propia asignada aún
- **WHEN** un desafío creado antes de este cambio conserva `dificultad = 'normal'`
  por la migración
- **THEN** su fila muestra el badge "Normal", editable como cualquier otro

### Requirement: Búsqueda por lugar o texto de la pregunta
El listado SHALL ofrecer un buscador que filtre los desafíos cuyo
`nombre_lugar` o `texto_pregunta` contenga el texto buscado
(case-insensitive), combinable con el resto de filtros.

#### Scenario: Búsqueda por nombre de lugar
- **WHEN** un admin escribe "eiffel" en el buscador
- **THEN** el listado muestra solo los desafíos cuyo `nombre_lugar` o
  `texto_pregunta` contiene "eiffel" (sin distinguir mayúsculas/minúsculas)

### Requirement: Filtros combinables por temática, dificultad, tipo y estado
El listado SHALL ofrecer filtros combinables por temática, dificultad,
tipo de contenido (imagen/vídeo/pregunta de texto) y estado
(activo/inactivo), aplicados todos a la vez sobre el resultado de la
búsqueda.

#### Scenario: Combinar filtro de tipo y estado
- **WHEN** un admin filtra por tipo "Imagen" y estado "Activo"
- **THEN** el listado muestra solo desafíos activos de tipo imagen

#### Scenario: Filtrar por dificultad
- **WHEN** un admin filtra por dificultad "Muy difícil"
- **THEN** el listado muestra solo los desafíos con `dificultad = 'muy_dificil'`

### Requirement: Paginación
El listado SHALL paginar los resultados filtrados, mostrando el rango
actual (p.ej. "Mostrando 1–10 de 34") y controles para navegar entre
páginas.

#### Scenario: Cambiar de filtros reinicia la paginación
- **WHEN** un admin está en una página distinta de la primera y cambia
  cualquier filtro o el texto de búsqueda
- **THEN** el listado vuelve a la primera página del nuevo resultado

### Requirement: Estado vacío con CTA
El listado SHALL mostrar un estado vacío explicativo con una acción para
limpiar filtros cuando no hay ningún desafío que coincida con la
búsqueda/filtros activos; cuando el banco no tiene ningún desafío en
absoluto, SHALL mostrar un estado vacío distinto con una llamada a la
acción para crear la primera pregunta.

#### Scenario: Sin resultados por filtros
- **WHEN** los filtros/búsqueda activos no coinciden con ningún desafío,
  pero el banco no está vacío
- **THEN** el listado muestra un estado vacío con una acción para limpiar
  filtros

#### Scenario: Banco de desafíos completamente vacío
- **WHEN** el banco de desafíos no tiene ninguna fila
- **THEN** el listado muestra un estado vacío con una llamada a la acción
  para crear la primera pregunta

### Requirement: Eliminar un desafío del banco
Cada fila SHALL ofrecer una acción "Eliminar" que, tras confirmación,
borre el desafío del banco. Si la base de datos rechaza el borrado por
estar el desafío referenciado (con historial de respuestas de jugadores),
el listado SHALL mostrar un mensaje explicando que no se puede eliminar por
estar en uso, sin mostrar el error crudo de la base de datos.

#### Scenario: Eliminar un desafío sin referencias
- **WHEN** un admin confirma "Eliminar" sobre un desafío sin respuestas
  registradas
- **THEN** el desafío se borra y desaparece del listado

#### Scenario: Eliminar un desafío referenciado
- **WHEN** un admin confirma "Eliminar" sobre un desafío que tiene
  respuestas de jugadores registradas
- **THEN** el borrado se rechaza y el listado muestra un mensaje indicando
  que no se puede eliminar por estar en uso, y la fila permanece en el
  listado

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

### Requirement: Edición inline de dificultad y estado por fila
Cada fila SHALL permitir cambiar `dificultad` (selector) y `activo` (toggle) directamente desde el listado, persistiendo el cambio al momento sin navegar al formulario completo. Mientras un campo de una fila esté guardando, ese control SHALL quedar deshabilitado; si el guardado falla, la fila SHALL mostrar un mensaje de error y revertir visualmente al valor anterior.

#### Scenario: Cambiar la dificultad desde el listado
- **WHEN** un admin cambia el selector de dificultad de una fila de "Fácil" a "Difícil"
- **THEN** la fila guarda el cambio sin recargar el listado ni navegar a otra pantalla, y el badge de dificultad pasa a reflejar "Difícil"

#### Scenario: Cambiar el estado activo/inactivo desde el listado
- **WHEN** un admin desactiva el toggle de estado de una pregunta activa
- **THEN** la pregunta se guarda como inactiva y su indicador de estado pasa a "Inactivo"

#### Scenario: El guardado inline falla
- **WHEN** el cambio de dificultad o estado de una fila falla al guardarse (error de red o del servidor)
- **THEN** la fila muestra un mensaje de error junto al control afectado y el control vuelve a mostrar el valor que tenía antes del cambio
