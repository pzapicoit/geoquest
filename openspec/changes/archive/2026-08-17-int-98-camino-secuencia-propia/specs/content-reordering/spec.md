## MODIFIED Requirements

### Requirement: Reorden solo-admin

Las RPC `reordenar_tematicas`, `reordenar_niveles`, `reordenar_preguntas_nivel` y `reordenar_camino` SHALL rechazar la llamada
si el usuario autenticado no tiene `profiles.role = 'admin'`, sin modificar
ninguna fila.

#### Scenario: Un jugador intenta reordenar temáticas

- **WHEN** un usuario autenticado sin rol `admin` invoca
  `reordenar_tematicas`
- **THEN** la llamada se rechaza y ninguna fila de `tematicas` cambia su
  `orden`

#### Scenario: Un jugador intenta reordenar el camino

- **WHEN** un usuario autenticado sin rol `admin` invoca
  `reordenar_camino`
- **THEN** la llamada se rechaza y ninguna fila de `camino` cambia su
  `orden`

### Requirement: El reorden no falla por conflicto transitorio de unicidad

Reasignar `orden` a varias filas en una sola llamada, incluyendo intercambios de posición entre filas, SHALL completarse sin violar el
constraint `unique` de `orden` (o `(tematica_id, orden)` /
`(nivel_id, orden)` / `orden` de `camino`, según la tabla), sin importar el
orden en que las filas se actualicen internamente.

#### Scenario: Dos temáticas intercambian posición

- **WHEN** un admin invoca `reordenar_tematicas` con un array que
  intercambia la posición de dos temáticas existentes (la que tenía
  `orden = 1` pasa a `orden = 2` y viceversa)
- **THEN** la llamada se completa sin error y ambas filas quedan con el
  `orden` esperado

#### Scenario: Dos posiciones del camino intercambian orden

- **WHEN** un admin invoca `reordenar_camino` con un array que intercambia
  la posición de dos filas existentes de `camino`
- **THEN** la llamada se completa sin error y ambas filas quedan con el
  `orden` esperado

## ADDED Requirements

### Requirement: `reordenar_camino` exige el conjunto completo de posiciones

`reordenar_camino(ids_en_orden uuid[])` SHALL exigir que `ids_en_orden`
contenga exactamente los mismos ids de fila que existen hoy en `camino` —
ni de más ni de menos — antes de modificar ningún `orden`.

#### Scenario: Se reordena con el listado completo

- **WHEN** un admin invoca `reordenar_camino` con un array que contiene
  todos los ids de fila de `camino` en un orden distinto al actual
- **THEN** cada fila queda con `orden` igual a la posición (1-based) de su
  id dentro del array

#### Scenario: Falta un id existente en el array

- **WHEN** un admin invoca `reordenar_camino` con un array que omite el id
  de una posición existente del camino
- **THEN** la llamada se rechaza y ninguna fila cambia su `orden`

#### Scenario: El array incluye un id que no existe

- **WHEN** un admin invoca `reordenar_camino` con un array que incluye un
  uuid que no corresponde a ninguna fila de `camino`
- **THEN** la llamada se rechaza y ninguna fila cambia su `orden`
