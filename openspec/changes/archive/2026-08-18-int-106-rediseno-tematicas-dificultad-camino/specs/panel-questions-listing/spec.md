## MODIFIED Requirements

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

## REMOVED Requirements

### Requirement: Detalle de niveles al pasar el cursor o abrir

**Reason**: Sin curación manual no existe un conjunto de "niveles donde se usa" que detallar — la dificultad ya es visible directamente como badge en la fila.

**Migration**: No aplica.

### Requirement: Filtro de desafíos sin asignar

**Reason**: Toda pregunta activa de una temática+dificultad está automáticamente disponible para cualquier parada del camino que resuelva esa pareja — ya no existe el concepto de "sin asignar".

**Migration**: No aplica.
