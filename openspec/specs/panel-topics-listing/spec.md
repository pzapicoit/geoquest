# panel-topics-listing Specification

## Purpose
TBD - created by archiving change int-85-panel-tematicas. Update Purpose after archive.

## Requirements

### Requirement: Enlace de navegación habilitado
La navegación lateral del panel SHALL habilitar el enlace "Temáticas" para
que navegue a la pantalla de listado, en lugar de mostrarse deshabilitado.

#### Scenario: Click en el enlace de navegación
- **WHEN** un admin autenticado hace click en "Temáticas" en la navegación
  lateral
- **THEN** el panel navega a la pantalla de listado de temáticas

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

### Requirement: Reorden manual por arrastre
El listado SHALL permitir reordenar las temáticas arrastrando una fila a
una nueva posición, persistiendo el nuevo orden completo mediante la RPC
`reordenar_tematicas`.

#### Scenario: Arrastrar una fila a otra posición
- **WHEN** un admin arrastra la fila de una temática a una posición
  distinta y la suelta
- **THEN** el listado refleja el nuevo orden de inmediato y se invoca
  `reordenar_tematicas` con los ids de todas las temáticas en el nuevo
  orden

#### Scenario: El reorden falla en el servidor
- **WHEN** la llamada a `reordenar_tematicas` tras un arrastre devuelve un
  error
- **THEN** el listado revierte visualmente al orden anterior y muestra un
  mensaje de error

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

### Requirement: Estado vacío
Cuando no exista ninguna temática, el listado SHALL mostrar un estado
vacío con una llamada a la acción para crear la primera temática, en lugar
de una tabla sin filas.

#### Scenario: No hay ninguna temática creada
- **WHEN** la tabla `tematicas` no tiene ninguna fila
- **THEN** el listado muestra el estado vacío con el botón "Crear la
  primera temática"

### Requirement: Edición inline del estado por fila
Cada fila SHALL permitir cambiar `activo` (toggle) directamente desde el listado de temáticas, persistiendo el cambio al momento sin abrir el panel lateral de edición. Mientras el toggle de una fila esté guardando, SHALL quedar deshabilitado; si el guardado falla, la fila SHALL mostrar un mensaje de error y revertir visualmente al valor anterior.

#### Scenario: Desactivar una temática desde el listado
- **WHEN** un admin desactiva el toggle de estado de una temática activa
- **THEN** la temática se guarda como inactiva sin abrir el panel lateral, y su indicador de estado pasa a "Inactiva"

#### Scenario: El guardado inline falla
- **WHEN** el cambio de estado de una fila falla al guardarse (error de red o del servidor)
- **THEN** la fila muestra un mensaje de error junto al toggle y el toggle vuelve a mostrar el valor que tenía antes del cambio
