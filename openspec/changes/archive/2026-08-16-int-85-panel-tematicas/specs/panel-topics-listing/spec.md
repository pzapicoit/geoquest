## ADDED Requirements

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
requisito de estrellas, cantidad de niveles y estado (activo/inactivo).

#### Scenario: Listado con temáticas existentes
- **WHEN** existen temáticas creadas
- **THEN** el listado muestra una fila por temática en el orden de su
  columna `orden`, con su portada, nombre, requisito de estrellas,
  cantidad de niveles y estado

### Requirement: Requisito de estrellas relativo a la temática anterior
Cada fila SHALL mostrar las estrellas requeridas en la temática
inmediatamente anterior (según `orden`) para desbloquear la temática de esa
fila, o "Sin requisito" cuando la fila es la primera (`orden = 1`).

#### Scenario: Temática que no es la primera
- **WHEN** una temática tiene `orden = 3` y `estrellas_requeridas = 24`
- **THEN** su fila muestra "24 estrellas" como requisito, referido a la
  temática con `orden = 2`

#### Scenario: Primera temática del recorrido
- **WHEN** una temática tiene `orden = 1`
- **THEN** su fila muestra "Sin requisito" en vez de un número de estrellas

### Requirement: Recuento de niveles por temática
Cada fila SHALL mostrar cuántos niveles pertenecen a esa temática, contando
las filas de `niveles` cuyo `tematica_id` corresponde.

#### Scenario: Temática con niveles
- **WHEN** una temática tiene 8 niveles asociados
- **THEN** su fila muestra "8 niveles"

#### Scenario: Temática sin niveles todavía
- **WHEN** una temática recién creada no tiene ningún nivel asociado
- **THEN** su fila muestra "0 niveles"

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
el diálogo de confirmación SHALL advertir que se eliminan en cascada sus
niveles, las asignaciones de preguntas a esos niveles y el progreso de
jugadores registrado en ellos, aclarando explícitamente que el banco de
preguntas no se ve afectado.

#### Scenario: Confirmar la eliminación
- **WHEN** un admin confirma la eliminación de una temática con 8 niveles
- **THEN** la temática y sus 8 niveles se eliminan, junto con las
  asignaciones de preguntas y el progreso de jugadores asociados a esos
  niveles, y el listado deja de mostrar esa fila

#### Scenario: Cancelar la eliminación
- **WHEN** un admin abre el diálogo de confirmación de borrado y pulsa
  "Cancelar"
- **THEN** la temática no se elimina y el diálogo se cierra

### Requirement: Enlace del nombre deshabilitado hasta que exista el listado de niveles
El nombre de cada fila SHALL mostrarse sin navegación funcional (marcado
como "Próximamente") mientras no exista la pantalla de listado de niveles
de una temática.

#### Scenario: Click en el nombre de una temática
- **WHEN** un admin hace click en el nombre de una temática en el listado
- **THEN** el panel no navega a ninguna pantalla, y el nombre muestra una
  indicación de "Próximamente"

### Requirement: Estado vacío
Cuando no exista ninguna temática, el listado SHALL mostrar un estado
vacío con una llamada a la acción para crear la primera temática, en lugar
de una tabla sin filas.

#### Scenario: No hay ninguna temática creada
- **WHEN** la tabla `tematicas` no tiene ninguna fila
- **THEN** el listado muestra el estado vacío con el botón "Crear la
  primera temática"
