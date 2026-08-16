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
La pantalla de listado SHALL mostrar una fila por cada desafío del banco
(no una fila por asignación a nivel), con: miniatura (imagen real para
`tipo = 'imagen'`, ícono para `video`/`pregunta_texto`), nombre del lugar,
badge de tipo, estado (activo/inactivo) y un indicador de en cuántos
niveles se usa.

#### Scenario: Un desafío se usa en varios niveles
- **WHEN** un desafío del banco está asignado a 2 niveles distintos vía
  `nivel_desafios`
- **THEN** aparece en el listado una única vez, con el indicador de uso
  mostrando 2 niveles

#### Scenario: Un desafío no está asignado a ningún nivel
- **WHEN** un desafío del banco no tiene ninguna fila en `nivel_desafios`
- **THEN** su indicador de uso muestra que no está asignado a ningún nivel

### Requirement: Detalle de niveles al pasar el cursor o abrir
El indicador de uso de cada fila SHALL exponer, al pasar el cursor o al
abrirlo, el detalle de en qué temática y nivel concretos se usa ese
desafío (nombre de la temática y número/nombre del nivel para cada
asignación).

#### Scenario: Se abre el detalle de un desafío usado en varios niveles
- **WHEN** un admin abre el detalle del indicador de uso de un desafío
  asignado a los niveles "Paisajes · Nivel 3" y "Patrimonio · Nivel 2"
- **THEN** el detalle lista ambas combinaciones de temática y nivel

### Requirement: Búsqueda por lugar o texto de la pregunta
El listado SHALL ofrecer un buscador que filtre los desafíos cuyo
`nombre_lugar` o `texto_pregunta` contenga el texto buscado
(case-insensitive), combinable con el resto de filtros.

#### Scenario: Búsqueda por nombre de lugar
- **WHEN** un admin escribe "eiffel" en el buscador
- **THEN** el listado muestra solo los desafíos cuyo `nombre_lugar` o
  `texto_pregunta` contiene "eiffel" (sin distinguir mayúsculas/minúsculas)

### Requirement: Filtros combinables por temática, nivel, tipo y estado
El listado SHALL ofrecer filtros combinables por temática, nivel (acotado
a las temáticas y niveles donde algún desafío está efectivamente asignado),
tipo de contenido (imagen/vídeo/pregunta de texto) y estado
(activo/inactivo), aplicados todos a la vez sobre el resultado de la
búsqueda.

#### Scenario: Combinar filtro de tipo y estado
- **WHEN** un admin filtra por tipo "Imagen" y estado "Activo"
- **THEN** el listado muestra solo desafíos activos de tipo imagen

### Requirement: Filtro de desafíos sin asignar
El listado SHALL ofrecer un filtro adicional que muestre únicamente los
desafíos del banco que no están asignados a ningún nivel.

#### Scenario: Filtrar por sin asignar
- **WHEN** un admin activa el filtro "Sin asignar a ningún nivel"
- **THEN** el listado muestra solo los desafíos sin ninguna fila en
  `nivel_desafios`, independientemente de los demás filtros

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
estar el desafío referenciado (asignado a algún nivel o con historial de
respuestas de jugadores), el listado SHALL mostrar un mensaje explicando
que no se puede eliminar por estar en uso, sin mostrar el error crudo de
la base de datos.

#### Scenario: Eliminar un desafío sin referencias
- **WHEN** un admin confirma "Eliminar" sobre un desafío sin asignaciones
  ni respuestas registradas
- **THEN** el desafío se borra y desaparece del listado

#### Scenario: Eliminar un desafío referenciado
- **WHEN** un admin confirma "Eliminar" sobre un desafío que está asignado
  a un nivel o tiene respuestas de jugadores registradas
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
