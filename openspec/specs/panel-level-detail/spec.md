# panel-level-detail Specification

## Purpose
TBD - created by syncing change int-84-panel-nivel-recorrido. Update Purpose after archive.

## Requirements

### Requirement: Breadcrumb informativo del nivel
La pantalla de detalle de un nivel SHALL mostrar un breadcrumb "Temáticas >
[temática] > [nivel]" con el nombre de la temática y el nombre/número del
nivel, sin enlaces navegables mientras no existan las pantallas de listado
de temáticas y niveles.

#### Scenario: Se abre el detalle de un nivel
- **WHEN** un admin abre `/niveles/<uuid>` de un nivel perteneciente a la
  temática "Paisajes" con `orden = 3` y sin `nombre`
- **THEN** el breadcrumb muestra "Temáticas > Paisajes > Nivel 3"

### Requirement: Tarjeta de configuración del nivel editable
La pantalla SHALL ofrecer una tarjeta "Configuración del nivel" con campos
editables para el nombre del nivel, el puntaje mínimo para superarlo y los
umbrales de puntaje para 1, 2 y 3 estrellas, y SHALL bloquear el guardado si
no se cumple `puntaje_minimo_superar <= umbral_estrella_1 <= umbral_estrella_2
<= umbral_estrella_3`.

#### Scenario: Guardar una configuración válida
- **WHEN** un admin edita el nombre y los umbrales de un nivel manteniendo
  el orden ascendente exigido y pulsa "Guardar"
- **THEN** la fila de `niveles` se actualiza con los nuevos valores

#### Scenario: Umbrales fuera de orden
- **WHEN** un admin introduce un `umbral_estrella_2` menor que
  `umbral_estrella_1`
- **THEN** el formulario bloquea el guardado y muestra un error indicando
  que los umbrales deben ser ascendentes

### Requirement: Contador de preguntas del recorrido
La pantalla SHALL mostrar un contador "X preguntas en este recorrido" con el
número de filas de `nivel_desafios` asignadas a este nivel.

#### Scenario: El nivel tiene tres preguntas asignadas
- **WHEN** un nivel tiene 3 filas en `nivel_desafios`
- **THEN** el contador muestra "3 preguntas en este recorrido"

### Requirement: Lista ordenada y arrastrable de preguntas del recorrido
La pantalla SHALL listar las preguntas asignadas al nivel ordenadas por
`orden`, cada una mostrando su posición, miniatura (imagen real para
`tipo = 'imagen'`, ícono para `video`/`pregunta_texto`), nombre del lugar y
badge de tipo, y SHALL permitir reordenarlas arrastrando una fila a una
nueva posición.

#### Scenario: Se arrastra una pregunta a otra posición
- **WHEN** un admin arrastra la pregunta en la posición 3 hasta la posición
  1 de la lista
- **THEN** la lista muestra esa pregunta en primer lugar y persiste el nuevo
  `orden` de todas las filas afectadas de `nivel_desafios` del nivel

### Requirement: Quitar una pregunta del recorrido sin borrarla del banco
Cada fila SHALL ofrecer una acción "Quitar del recorrido" que, tras
confirmación, borre únicamente la fila de `nivel_desafios` correspondiente
(dejando la pregunta intacta en el banco) y renumere el `orden` de las
filas restantes de ese nivel para que quede contiguo.

#### Scenario: Quitar una pregunta del recorrido
- **WHEN** un admin confirma "Quitar del recorrido" sobre la pregunta en la
  posición 2 de un recorrido de 4 preguntas
- **THEN** esa fila desaparece de `nivel_desafios` para este nivel, la
  pregunta sigue existiendo en el banco de `desafios`, y las 3 preguntas
  restantes quedan con `orden` 1, 2 y 3

### Requirement: Añadir una pregunta existente del banco al recorrido
El botón "Añadir pregunta existente" SHALL abrir un buscador/selector sobre
las preguntas del banco que excluya las ya asignadas a este nivel; al
seleccionar una, SHALL insertarla en `nivel_desafios` en la última posición
del orden actual del nivel.

#### Scenario: Añadir una pregunta no asignada
- **WHEN** un admin busca y selecciona una pregunta del banco que no está
  asignada a este nivel, con el recorrido actual en `orden` 1..3
- **THEN** se crea una fila en `nivel_desafios` para esa pregunta con
  `orden = 4` y la lista la muestra en último lugar

#### Scenario: El selector no ofrece preguntas ya asignadas
- **WHEN** un admin abre el selector de "Añadir pregunta existente" de un
  nivel que ya tiene asignada la pregunta "Torre Eiffel"
- **THEN** "Torre Eiffel" no aparece entre las opciones del selector

### Requirement: Crear pregunta nueva desde el nivel
El botón "Crear pregunta nueva" SHALL navegar a `/preguntas/nueva`.

#### Scenario: Click en "Crear pregunta nueva"
- **WHEN** un admin hace click en "Crear pregunta nueva" desde el detalle de
  un nivel
- **THEN** el panel navega a `/preguntas/nueva`

### Requirement: Estado vacío del recorrido
Cuando el nivel no tenga ninguna pregunta asignada, la pantalla SHALL
mostrar un estado vacío explicativo con llamadas a la acción para añadir una
pregunta existente o crear una nueva, en lugar de la lista y el contador.

#### Scenario: Nivel recién creado sin preguntas
- **WHEN** un admin abre el detalle de un nivel sin ninguna fila en
  `nivel_desafios`
- **THEN** la pantalla muestra un estado vacío con acciones para "Añadir
  pregunta existente" y "Crear pregunta nueva"
