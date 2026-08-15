## ADDED Requirements

### Requirement: Reorden solo-admin

Las RPC `reordenar_tematicas`, `reordenar_niveles` y
`reordenar_preguntas_nivel` SHALL rechazar la llamada si el usuario
autenticado no tiene `profiles.role = 'admin'`, sin modificar ninguna fila.

#### Scenario: Un jugador intenta reordenar temáticas

- **WHEN** un usuario autenticado sin rol `admin` invoca
  `reordenar_tematicas`
- **THEN** la llamada se rechaza y ninguna fila de `tematicas` cambia su
  `orden`

### Requirement: `reordenar_tematicas` exige el conjunto completo de temáticas

`reordenar_tematicas(ids_en_orden uuid[])` SHALL exigir que `ids_en_orden`
contenga exactamente los mismos ids que existen hoy en `tematicas` — ni de
más ni de menos — antes de modificar ningún `orden`.

#### Scenario: Se reordena con el listado completo

- **WHEN** un admin invoca `reordenar_tematicas` con un array que contiene
  todos los ids de `tematicas` en un orden distinto al actual
- **THEN** cada fila queda con `orden` igual a la posición (1-based) de su
  id dentro del array

#### Scenario: Falta un id existente en el array

- **WHEN** un admin invoca `reordenar_tematicas` con un array que omite el
  id de una temática existente
- **THEN** la llamada se rechaza y ninguna fila cambia su `orden`

#### Scenario: El array incluye un id que no existe

- **WHEN** un admin invoca `reordenar_tematicas` con un array que incluye
  un uuid que no corresponde a ninguna fila de `tematicas`
- **THEN** la llamada se rechaza y ninguna fila cambia su `orden`

### Requirement: `reordenar_niveles` está acotado a una temática

`reordenar_niveles(p_tematica_id uuid, ids_en_orden uuid[])` SHALL exigir
que `ids_en_orden` contenga exactamente los ids de los niveles que hoy
pertenecen a `p_tematica_id` — ni de más ni de menos — y SHALL dejar
intacto el `orden` de los niveles de cualquier otra temática.

#### Scenario: Se reordenan los niveles de una temática

- **WHEN** un admin invoca `reordenar_niveles` con el id de una temática y
  un array con todos los ids de sus niveles en otro orden
- **THEN** esos niveles quedan con `orden` igual a su posición en el array
- **AND** los niveles de cualquier otra temática conservan su `orden`

#### Scenario: El array incluye un nivel de otra temática

- **WHEN** un admin invoca `reordenar_niveles` con un array que incluye el
  id de un nivel que pertenece a una temática distinta de `p_tematica_id`
- **THEN** la llamada se rechaza y ninguna fila cambia su `orden`

### Requirement: `reordenar_preguntas_nivel` reordena las asignaciones de un nivel

`reordenar_preguntas_nivel(p_nivel_id uuid, ids_en_orden uuid[])` SHALL
recibir en `ids_en_orden` los `desafio_id` de las filas de
`nivel_desafios` que hoy pertenecen a `p_nivel_id`, exigir que coincidan
exactamente con las existentes, y reasignar `orden` según su posición en
el array.

#### Scenario: Se reordenan los desafíos de un nivel

- **WHEN** un admin invoca `reordenar_preguntas_nivel` con el id de un
  nivel y un array con los `desafio_id` de todas sus asignaciones en otro
  orden
- **THEN** cada fila de `nivel_desafios` de ese nivel queda con `orden`
  igual a la posición de su `desafio_id` en el array

#### Scenario: El array no incluye todas las asignaciones del nivel

- **WHEN** un admin invoca `reordenar_preguntas_nivel` con un array al que
  le falta el `desafio_id` de alguna asignación existente del nivel
- **THEN** la llamada se rechaza y ninguna fila cambia su `orden`

### Requirement: El reorden no falla por conflicto transitorio de unicidad

Reasignar `orden` a varias filas en una sola llamada, incluyendo
intercambios de posición entre filas, SHALL completarse sin violar el
constraint `unique` de `orden` (o `(tematica_id, orden)` /
`(nivel_id, orden)` según la tabla), sin importar el orden en que las
filas se actualicen internamente.

#### Scenario: Dos temáticas intercambian posición

- **WHEN** un admin invoca `reordenar_tematicas` con un array que
  intercambia la posición de dos temáticas existentes (la que tenía
  `orden = 1` pasa a `orden = 2` y viceversa)
- **THEN** la llamada se completa sin error y ambas filas quedan con el
  `orden` esperado
