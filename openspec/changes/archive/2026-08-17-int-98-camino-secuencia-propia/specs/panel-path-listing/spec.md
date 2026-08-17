## ADDED Requirements

### Requirement: Enlace de navegación habilitado para "Camino"
La navegación lateral del panel SHALL habilitar el enlace "Camino" para
que navegue a la pantalla de gestión de la secuencia global del camino.

#### Scenario: Click en el enlace de navegación
- **WHEN** un admin autenticado hace click en "Camino" en la navegación
  lateral
- **THEN** el panel navega a la pantalla de gestión del camino

### Requirement: Listado de posiciones del camino en orden de juego
La pantalla SHALL mostrar una fila por cada posición de `camino`, ordenadas
por `orden`, con: posición, nombre de la temática y del nivel al que
apunta, y estrellas requeridas para desbloquearla.

#### Scenario: Listado con camino definido
- **WHEN** existen filas en `camino`
- **THEN** el listado muestra una fila por posición en el orden de su
  columna `orden`, con la temática y el nivel al que apunta y sus
  estrellas requeridas

### Requirement: Añadir un nivel existente a una nueva posición del camino
El botón "Añadir nivel al camino" SHALL abrir un selector de niveles
agrupados por temática que excluya los niveles ya presentes en alguna
posición de `camino`. Al confirmar, SHALL insertar una fila en `camino` en
la última posición con `estrellas_requeridas = 0`.

#### Scenario: Añadir un nivel no asignado
- **WHEN** un admin selecciona un nivel que no está en ninguna posición del
  camino, con el camino actual en `orden` 1..3
- **THEN** se crea una fila en `camino` para ese nivel con `orden = 4` y
  `estrellas_requeridas = 0`, y la lista la muestra en último lugar

#### Scenario: El selector no ofrece niveles ya presentes en el camino
- **WHEN** un admin abre el selector de "Añadir nivel al camino" y un nivel
  ya ocupa la posición 2 del camino
- **THEN** ese nivel no aparece entre las opciones del selector

### Requirement: Reorden manual por arrastre
El listado SHALL permitir reordenar las posiciones del camino arrastrando
una fila a una nueva posición, persistiendo el nuevo orden completo
mediante la RPC `reordenar_camino`.

#### Scenario: Arrastrar una fila a otra posición
- **WHEN** un admin arrastra la fila de una posición del camino a un lugar
  distinto del listado y la suelta
- **THEN** el listado refleja el nuevo orden de inmediato y se invoca
  `reordenar_camino` con los ids de todas las posiciones en el nuevo orden

#### Scenario: El reorden falla en el servidor
- **WHEN** la llamada a `reordenar_camino` tras un arrastre devuelve un
  error
- **THEN** el listado revierte visualmente al orden anterior y muestra un
  mensaje de error

### Requirement: Editar el umbral de estrellas de una posición
Cada fila SHALL permitir editar `estrellas_requeridas` de esa posición
directamente desde el listado, y SHALL bloquear valores negativos.

#### Scenario: Editar un umbral válido
- **WHEN** un admin edita `estrellas_requeridas` de una posición a un
  número entero no negativo y confirma
- **THEN** la fila de `camino` se actualiza con el nuevo valor

#### Scenario: Se intenta un valor negativo
- **WHEN** un admin intenta guardar `estrellas_requeridas` con un valor
  negativo
- **THEN** el formulario bloquea el guardado y muestra un error

### Requirement: Quitar una posición del camino sin borrar el nivel
Cada fila SHALL ofrecer una acción "Quitar del camino" que, tras
confirmación, borre únicamente la fila de `camino` correspondiente
(dejando el nivel intacto en su temática) y recompacte el `orden` de las
posiciones restantes.

#### Scenario: Quitar una posición intermedia
- **WHEN** un admin confirma "Quitar del camino" sobre la posición 2 de un
  camino de 4 posiciones
- **THEN** esa fila desaparece de `camino`, el nivel sigue existiendo en su
  temática, y las 3 posiciones restantes quedan con `orden` 1, 2 y 3

### Requirement: Estado vacío
Cuando no exista ninguna posición en `camino` todavía, la pantalla SHALL
mostrar un estado vacío con una llamada a la acción para añadir el primer
nivel al camino.

#### Scenario: El camino no tiene ninguna posición creada
- **WHEN** `camino` no tiene ninguna fila
- **THEN** la pantalla muestra un estado vacío con el botón para añadir el
  primer nivel al camino
