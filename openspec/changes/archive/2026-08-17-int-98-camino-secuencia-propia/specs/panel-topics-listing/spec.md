## MODIFIED Requirements

### Requirement: Listado de temáticas con una fila por temática
La pantalla de listado SHALL mostrar una fila por cada temática existente,
ordenadas por su columna `orden`, con: miniatura de portada, nombre,
cantidad de niveles y estado (activo/inactivo).

#### Scenario: Listado con temáticas existentes
- **WHEN** existen temáticas creadas
- **THEN** el listado muestra una fila por temática en el orden de su
  columna `orden`, con su portada, nombre, cantidad de niveles y estado

## REMOVED Requirements

### Requirement: Requisito de estrellas relativo a la temática anterior
**Reason**: `tematicas.estrellas_requeridas` se elimina del esquema; el
desbloqueo deja de depender de la temática anterior y pasa a depender de la
posición de cada nivel en el camino.
**Migration**: El umbral de estrellas para desbloquear contenido se
gestiona ahora por posición del camino desde la nueva pantalla "Camino" del
panel (`panel-path-listing`), no desde el listado de temáticas.
