## MODIFIED Requirements

### Requirement: Reorden solo-admin

Las RPC `reordenar_tematicas` y `reordenar_camino` SHALL rechazar la llamada
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
constraint `unique` de `orden` (o `(tematica_id, orden)` / `orden` de
`camino`, según la tabla), sin importar el orden en que las filas se
actualicen internamente.

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

## REMOVED Requirements

### Requirement: `reordenar_niveles` está acotado a una temática

**Reason**: `niveles` desaparece como tabla — ya no hay niveles independientes que reordenar dentro de una temática.

**Migration**: No aplica; reordenar las paradas del camino ya lo cubre `reordenar_camino`.

### Requirement: `reordenar_preguntas_nivel` reordena las asignaciones de un nivel

**Reason**: `nivel_desafios` desaparece — ya no hay curación manual de preguntas por nivel que reordenar.

**Migration**: No aplica; el orden de las preguntas dentro de una partida se sortea al azar en `iniciar_intento_parada`.
