## ADDED Requirements

### Requirement: Breadcrumb de navegación con enlace a Temáticas
La pantalla de listado de niveles SHALL mostrar un breadcrumb "Temáticas ›
[nombre de la temática]", donde "Temáticas" enlaza a la pantalla de
listado de temáticas.

#### Scenario: Se abre el listado de niveles de una temática
- **WHEN** un admin navega a `/tematicas/:id/niveles` de una temática
  llamada "Paisajes de Europa"
- **THEN** la pantalla muestra el breadcrumb "Temáticas › Paisajes de
  Europa", con "Temáticas" enlazando a `/tematicas`

### Requirement: Subtítulo con recuento o con el contexto de desbloqueo
Cuando la temática tenga niveles, el subtítulo SHALL mostrar el número de
niveles, cuántos están activos y el total de preguntas asignadas en todos
ellos. Cuando la temática no tenga ningún nivel, el subtítulo SHALL
mostrar en su lugar las estrellas requeridas para desbloquear esa
temática y, salvo que sea la primera temática del recorrido, el nombre de
la temática inmediatamente anterior.

#### Scenario: Temática con niveles
- **WHEN** una temática tiene 6 niveles, 4 activos y un total de 25
  preguntas asignadas entre todos
- **THEN** el subtítulo muestra "6 niveles · 4 activos · 25 preguntas
  asignadas en total"

#### Scenario: Temática sin niveles, no es la primera
- **WHEN** una temática con `estrellas_requeridas = 18` y `orden = 2` no
  tiene ningún nivel todavía
- **THEN** el subtítulo menciona las 18 estrellas requeridas y el nombre
  de la temática con `orden = 1`

#### Scenario: Temática sin niveles, es la primera
- **WHEN** una temática con `orden = 1` no tiene ningún nivel todavía
- **THEN** el subtítulo no hace referencia a ninguna temática anterior

### Requirement: Listado de niveles con una fila por nivel
La pantalla SHALL mostrar una fila por cada nivel de la temática, ordenadas
por su columna `orden`, con: posición, nombre, puntaje mínimo para
superar, cantidad de preguntas asignadas en su recorrido y estado
(activo/inactivo).

#### Scenario: Listado con niveles existentes
- **WHEN** la temática tiene niveles creados
- **THEN** el listado muestra una fila por nivel en el orden de su columna
  `orden`, con su posición, nombre, puntaje mínimo, cantidad de preguntas
  en su recorrido y estado

### Requirement: Nombre por defecto cuando el nivel no tiene nombre asignado
Cuando el campo `nombre` de un nivel sea `NULL`, la fila SHALL mostrar
"Nivel N" usando el valor de `orden` del nivel en lugar de dejar el nombre
en blanco.

#### Scenario: Nivel sin nombre asignado
- **WHEN** un nivel con `orden = 3` tiene `nombre = NULL`
- **THEN** su fila muestra "Nivel 3" como nombre

### Requirement: Recuento de preguntas asignadas por nivel, resaltado si es bajo
Cada fila SHALL mostrar cuántas preguntas tiene asignadas ese nivel en su
recorrido, contando las filas de `nivel_desafios` cuyo `nivel_id`
corresponde. Cuando ese recuento sea menor que 3, la fila SHALL resaltar
visualmente el dato para llamar la atención sobre un nivel con pocas
preguntas.

#### Scenario: Nivel con preguntas suficientes
- **WHEN** un nivel tiene 6 preguntas asignadas en `nivel_desafios`
- **THEN** su fila muestra "6 preguntas" sin resaltado de aviso

#### Scenario: Nivel con menos de 3 preguntas
- **WHEN** un nivel tiene 2 preguntas asignadas en `nivel_desafios`
- **THEN** su fila muestra "2 preguntas" con resaltado de aviso

#### Scenario: Nivel recién creado sin preguntas todavía
- **WHEN** un nivel no tiene ninguna fila en `nivel_desafios`
- **THEN** su fila muestra "0 preguntas" con resaltado de aviso

### Requirement: Navegación al Recorrido de un nivel
El nombre del nivel y un botón "Recorrido" SHALL navegar a la pantalla de
Recorrido de ese nivel. El resto de la fila (asa de arrastre, botones de
posición, badge de preguntas, estado y botón eliminar) SHALL no disparar
esa navegación.

#### Scenario: Click en el nombre de un nivel
- **WHEN** un admin hace click en el nombre de un nivel
- **THEN** el panel navega a la pantalla de Recorrido de ese nivel

#### Scenario: Click en el botón "Recorrido"
- **WHEN** un admin hace click en el botón "Recorrido" de una fila
- **THEN** el panel navega a la pantalla de Recorrido de ese nivel

### Requirement: Reorden manual por arrastre
El listado SHALL permitir reordenar los niveles de la temática arrastrando
una fila a una nueva posición, persistiendo el nuevo orden completo
mediante la RPC `reordenar_niveles`, acotada a la temática actual.

#### Scenario: Arrastrar una fila a otra posición
- **WHEN** un admin arrastra la fila de un nivel a una posición distinta
  dentro del mismo listado y la suelta
- **THEN** el listado refleja el nuevo orden de inmediato y se invoca
  `reordenar_niveles` con el id de la temática y los ids de todos sus
  niveles en el nuevo orden

#### Scenario: El reorden falla en el servidor
- **WHEN** la llamada a `reordenar_niveles` tras un arrastre devuelve un
  error
- **THEN** el listado revierte visualmente al orden anterior y muestra un
  mensaje de error

### Requirement: Alta rápida de un nivel nuevo
El botón "Nuevo nivel" SHALL abrir un modal con un único campo (nombre
del nivel). Al guardar, el sistema SHALL crear el nivel en la última
posición de la temática con puntaje mínimo y umbrales de estrellas en 0,
y SHALL navegar automáticamente a la pantalla de Recorrido del nivel
recién creado.

#### Scenario: Crear un nivel nuevo
- **WHEN** un admin escribe un nombre en el modal "Nuevo nivel" y confirma
- **THEN** se crea un nivel en la temática actual, en la última posición,
  con puntaje mínimo y umbrales de estrellas en 0, y el panel navega a la
  pantalla de Recorrido de ese nivel recién creado

### Requirement: Eliminación de un nivel con confirmación explícita
El listado SHALL exigir una confirmación antes de eliminar un nivel. El
diálogo de confirmación SHALL mostrar cuántas preguntas del recorrido se
perderían, SHALL aclarar que el banco de preguntas no se ve afectado, y
tras confirmarse el borrado el sistema SHALL recompactar el `orden` de
los niveles restantes de la temática (sin huecos).

#### Scenario: Confirmar la eliminación
- **WHEN** un admin confirma la eliminación de un nivel que ocupa una
  posición intermedia del recorrido
- **THEN** el nivel se elimina junto con sus asignaciones de preguntas, el
  listado deja de mostrar esa fila, y los niveles que ocupaban posiciones
  posteriores se recolocan sin dejar huecos en `orden`

#### Scenario: Cancelar la eliminación
- **WHEN** un admin abre el diálogo de confirmación de borrado de un nivel
  y lo cancela
- **THEN** el nivel no se elimina y el diálogo se cierra

### Requirement: Estado vacío
Cuando la temática no tenga ningún nivel todavía, el listado SHALL mostrar
un estado vacío con una llamada a la acción para crear el primer nivel, en
lugar de una tabla sin filas.

#### Scenario: La temática no tiene ningún nivel creado
- **WHEN** una temática no tiene ninguna fila en `niveles`
- **THEN** el listado muestra el estado vacío con el botón para crear el
  primer nivel
