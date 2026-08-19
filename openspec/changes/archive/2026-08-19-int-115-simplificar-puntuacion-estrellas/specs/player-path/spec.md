## ADDED Requirements

### Requirement: `estrellas_requeridas` se deriva del `orden` de la posición, nunca se almacena
`camino_jugador` SHALL calcular `estrellas_requeridas` de cada posición
mediante `estrellas_requeridas_por_orden(orden)` en el momento de la
lectura, sin leer ni depender de ninguna columna almacenada en `camino`.
Esa función SHALL calcular el valor como `floor((orden - 1) × 3 × 0.6)`,
de forma que la posición de `orden` 1 exija siempre 0 estrellas y el
requisito crezca con la posición.

#### Scenario: La posición 1 de todo camino exige 0 estrellas
- **WHEN** se consulta `camino_jugador` para la posición de `orden = 1` de
  cualquier camino
- **THEN** su `estrellas_requeridas` es 0

#### Scenario: Insertar una parada recoloca el requisito de las posiciones siguientes
- **WHEN** se inserta una nueva posición en el lugar 4 de un camino de 9,
  desplazando el `orden` de las antiguas posiciones 4 a 9 a 5-10
- **THEN** al consultar `camino_jugador` de nuevo, cada una de esas
  posiciones desplazadas (ahora 5 a 10) muestra el `estrellas_requeridas`
  correspondiente a su nuevo `orden`, sin ninguna escritura adicional
  sobre `camino`

#### Scenario: Reordenar el camino recalcula el requisito de cada posición afectada
- **WHEN** se reordena el camino con `reordenar_camino`, cambiando el
  `orden` de varias posiciones
- **THEN** `camino_jugador` refleja de inmediato el `estrellas_requeridas`
  recalculado para cada posición según su `orden` nuevo, en la misma
  consulta, sin ningún backfill previo
