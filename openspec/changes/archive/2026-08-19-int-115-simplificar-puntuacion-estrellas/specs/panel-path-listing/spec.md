## MODIFIED Requirements

### Requirement: Listado de posiciones del camino en orden de juego
La pantalla SHALL mostrar una fila por cada posición de `camino`, ordenadas
por `orden`, con: posición, nombre de la temática, dificultad, nombre de la
parada (o un identificador por defecto si no tiene nombre propio), y
estrellas requeridas para desbloquearla. `estrellas_requeridas` SHALL
mostrarse siempre en solo lectura, derivada de la posición (`orden`) de esa
fila, sin ningún campo editable asociado.

#### Scenario: Listado con camino definido
- **WHEN** existen filas en `camino`
- **THEN** el listado muestra una fila por posición en el orden de su
  columna `orden`, con la temática, la dificultad, el nombre de la parada,
  y sus estrellas requeridas derivadas de esa posición

#### Scenario: Insertar una parada recoloca las estrellas requeridas mostradas
- **WHEN** un admin añade una parada en una posición intermedia del camino,
  desplazando el `orden` de las posiciones siguientes
- **THEN** el listado muestra, para cada posición desplazada, las
  estrellas requeridas recalculadas según su nuevo `orden`, sin que el
  admin edite ningún valor

### Requirement: Añadir una parada temática+dificultad a una nueva posición del camino
El botón "Añadir parada al camino" SHALL abrir un selector de temática y
dificultad (sin excluir combinaciones ya presentes en el camino, porque una
misma pareja temática+dificultad puede aparecer en varias posiciones con
overrides distintos). Al confirmar, SHALL insertar una fila en `camino` en
la última posición, sin overrides. Sus estrellas requeridas para
desbloquearse SHALL quedar determinadas automáticamente por esa posición
(`estrellas_requeridas_por_orden`), sin que la creación fije ningún valor
explícito.

#### Scenario: Añadir una parada nueva
- **WHEN** un admin selecciona una temática y una dificultad, con el camino
  actual en `orden` 1..3
- **THEN** se crea una fila en `camino` con `orden = 4`, y la lista la
  muestra en último lugar con las estrellas requeridas correspondientes a
  la posición 4

#### Scenario: Se puede repetir una pareja temática+dificultad ya presente
- **WHEN** un admin abre el selector de "Añadir parada al camino" y esa
  temática+dificultad ya ocupa la posición 2 del camino
- **THEN** esa combinación sigue apareciendo entre las opciones del
  selector, y añadirla crea una nueva posición independiente

### Requirement: Edición de overrides opcionales por posición
Cada fila SHALL permitir editar, en un panel de detalle propio, los
overrides opcionales de esa posición (`preguntas_por_partida`,
`segundos_por_desafio`), mostrando el valor de `dificultad_defaults`
vigente para su dificultad como referencia cuando el override esté vacío.
La misma validación de enteros positivos que aplica a `dificultad_defaults`
SHALL aplicarse aquí. El panel de detalle SHALL mostrar, junto a estos dos
campos, el bloque informativo de umbrales derivados de esta posición (ver
"Bloque informativo de umbrales derivados por posición").

#### Scenario: Guardar un override
- **WHEN** un admin fija `preguntas_por_partida = 6` en el override de una
  posición
- **THEN** la fila de `camino` se actualiza con ese valor, y esa posición
  deja de usar el valor de `dificultad_defaults` para ese campo

#### Scenario: Vaciar un override
- **WHEN** un admin borra el valor de un override que tenía relleno y
  guarda
- **THEN** la columna correspondiente de `camino` queda en `NULL`, y esa
  posición vuelve a usar el valor de `dificultad_defaults` para su
  dificultad

## ADDED Requirements

### Requirement: Bloque informativo de umbrales derivados por posición
Cada fila de posición del camino SHALL mostrar un bloque de solo lectura
con: el máximo alcanzable de esa parada, sus tres umbrales (★1 al superar,
★2, ★3) en puntos y en porcentaje del máximo, y con cuántas estrellas se
desbloquea junto con su posición dentro del camino total (p. ej. "posición
4 de 9"). El bloque SHALL recalcularse en vivo mientras se edita
`preguntas_por_partida` en el panel de overrides de esa posición, antes de
guardar, sin necesidad de recargar la pantalla.

#### Scenario: El bloque muestra el máximo y los tres umbrales de una posición
- **WHEN** un admin abre el panel de detalle de una posición del camino
- **THEN** ve el máximo alcanzable de esa parada y sus tres umbrales en
  puntos y porcentaje, junto con el número de estrellas requeridas y su
  posición dentro del camino total

#### Scenario: El bloque se recalcula al editar preguntas por partida, antes de guardar
- **WHEN** un admin cambia el override de `preguntas_por_partida` de una
  posición en el panel de detalle, sin haber pulsado todavía "Guardar
  overrides"
- **THEN** el máximo alcanzable y los tres umbrales mostrados se actualizan
  para reflejar ese nuevo valor

## REMOVED Requirements

### Requirement: Editar el umbral de estrellas de una posición
**Reason**: `estrellas_requeridas` deja de ser un valor almacenado y
editable: pasa a derivarse automáticamente de la posición (`orden`) de la
parada dentro del camino, para que insertar, borrar o reordenar posiciones
recoloque el requisito de desbloqueo de toda la cadena sin intervención
manual.
**Migration**: Ninguna acción del admin. El listado sigue mostrando las
estrellas requeridas de cada posición, ahora en solo lectura y calculadas
automáticamente a partir de su posición en el camino.
