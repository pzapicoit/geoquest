## MODIFIED Requirements

### Requirement: Listado de temáticas con una fila por temática
La pantalla de listado SHALL mostrar una fila por cada temática existente,
ordenadas por su columna `orden`, con: miniatura de portada, nombre,
cantidad de paradas en el camino que la referencian y estado
(activo/inactivo).

#### Scenario: Listado con temáticas existentes
- **WHEN** existen temáticas creadas
- **THEN** el listado muestra una fila por temática en el orden de su
  columna `orden`, con su portada, nombre, cantidad de paradas del camino y
  estado

### Requirement: Eliminación de una temática con confirmación explícita
El listado SHALL exigir una confirmación antes de eliminar una temática, y
el diálogo de confirmación SHALL advertir que se eliminan en cascada las
paradas del camino que la referencian y el progreso de jugadores registrado
en ellas, aclarando explícitamente que el banco de preguntas no se ve
afectado. Si la temática todavía tiene desafíos asociados, el listado SHALL
rechazar el borrado y explicar que hay que borrar o reasignar esas
preguntas primero.

#### Scenario: Confirmar la eliminación
- **WHEN** un admin confirma la eliminación de una temática sin desafíos
  propios que tiene 8 paradas en el camino
- **THEN** la temática y esas 8 paradas se eliminan, junto con el progreso
  de jugadores asociado a ellas, y el listado deja de mostrar esa fila

#### Scenario: Cancelar la eliminación
- **WHEN** un admin abre el diálogo de confirmación de borrado y pulsa
  "Cancelar"
- **THEN** la temática no se elimina y el diálogo se cierra

#### Scenario: La temática todavía tiene preguntas
- **WHEN** un admin intenta eliminar una temática que todavía tiene
  desafíos asociados
- **THEN** el borrado se rechaza y el panel explica que hay que borrar o
  reasignar esas preguntas antes de poder eliminar la temática

## REMOVED Requirements

### Requirement: Recuento de niveles por temática

**Reason**: `niveles` desaparece como entidad — el recuento equivalente (paradas del camino que referencian esta temática) se fusiona en el requirement "Listado de temáticas con una fila por temática".

**Migration**: No aplica.

### Requirement: Enlace del nombre habilitado hacia el listado de niveles

**Reason**: `panel-levels-listing` se retira — no hay pantalla de destino a la que enlazar.

**Migration**: No aplica.
