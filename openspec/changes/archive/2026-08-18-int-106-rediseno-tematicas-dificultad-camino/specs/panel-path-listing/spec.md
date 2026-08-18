## MODIFIED Requirements

### Requirement: Listado de posiciones del camino en orden de juego
La pantalla SHALL mostrar una fila por cada posición de `camino`, ordenadas
por `orden`, con: posición, nombre de la temática, dificultad, nombre de la
parada (o un identificador por defecto si no tiene nombre propio), y
estrellas requeridas para desbloquearla.

#### Scenario: Listado con camino definido
- **WHEN** existen filas en `camino`
- **THEN** el listado muestra una fila por posición en el orden de su
  columna `orden`, con la temática, la dificultad y el nombre de la parada,
  y sus estrellas requeridas

### Requirement: Añadir una parada temática+dificultad a una nueva posición del camino
El botón "Añadir parada al camino" SHALL abrir un selector de temática y
dificultad (sin excluir combinaciones ya presentes en el camino, porque una
misma pareja temática+dificultad puede aparecer en varias posiciones con
overrides distintos). Al confirmar, SHALL insertar una fila en `camino` en
la última posición con `estrellas_requeridas = 0` y sin overrides (usa los
valores de `dificultad_defaults`).

#### Scenario: Añadir una parada nueva
- **WHEN** un admin selecciona una temática y una dificultad, con el camino
  actual en `orden` 1..3
- **THEN** se crea una fila en `camino` con `orden = 4` y
  `estrellas_requeridas = 0`, y la lista la muestra en último lugar

#### Scenario: Se puede repetir una pareja temática+dificultad ya presente
- **WHEN** un admin abre el selector de "Añadir parada al camino" y esa
  temática+dificultad ya ocupa la posición 2 del camino
- **THEN** esa combinación sigue apareciendo entre las opciones del
  selector, y añadirla crea una nueva posición independiente

### Requirement: Quitar una posición del camino sin afectar a la temática ni a sus preguntas
Cada fila SHALL ofrecer una acción "Quitar del camino" que, tras
confirmación, borre únicamente la fila de `camino` correspondiente (sin
afectar a la temática ni a los desafíos de su pool) y recompacte el
`orden` de las posiciones restantes.

#### Scenario: Quitar una posición intermedia
- **WHEN** un admin confirma "Quitar del camino" sobre la posición 2 de un
  camino de 4 posiciones
- **THEN** esa fila desaparece de `camino`, la temática y sus desafíos
  siguen intactos, y las 3 posiciones restantes quedan con `orden` 1, 2 y 3

### Requirement: Estado vacío
Cuando no exista ninguna posición en `camino` todavía, la pantalla SHALL
mostrar un estado vacío con una llamada a la acción para añadir la primera
parada al camino.

#### Scenario: El camino no tiene ninguna posición creada
- **WHEN** `camino` no tiene ninguna fila
- **THEN** la pantalla muestra un estado vacío con el botón para añadir la
  primera parada al camino

## ADDED Requirements

### Requirement: Edición de overrides opcionales por posición
Cada fila SHALL permitir editar, en un panel de detalle propio, los
overrides opcionales de esa posición (`preguntas_por_partida`,
`segundos_por_desafio`, `puntaje_minimo_superar`, `umbral_estrella_2`,
`umbral_estrella_3`), mostrando el valor de `dificultad_defaults` vigente
para su dificultad como referencia cuando el override esté vacío. La misma
validación de orden ascendente y enteros positivos que aplica a
`dificultad_defaults` SHALL aplicarse aquí.

#### Scenario: Guardar un override
- **WHEN** un admin fija `puntaje_minimo_superar = 25000` en el override de
  una posición
- **THEN** la fila de `camino` se actualiza con ese valor, y esa posición
  deja de usar el valor de `dificultad_defaults` para ese campo

#### Scenario: Vaciar un override
- **WHEN** un admin borra el valor de un override que tenía relleno y
  guarda
- **THEN** la columna correspondiente de `camino` queda en `NULL`, y esa
  posición vuelve a usar el valor de `dificultad_defaults` para su
  dificultad

#### Scenario: Overrides fuera de orden
- **WHEN** un admin introduce overrides cuyo `puntaje_minimo_superar`
  efectivo resultante sea mayor que su `umbral_estrella_2` efectivo
- **THEN** el formulario bloquea el guardado y muestra un error
