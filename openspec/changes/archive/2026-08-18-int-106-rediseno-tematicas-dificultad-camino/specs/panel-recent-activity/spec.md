## MODIFIED Requirements

### Requirement: Feed incluye paradas superadas de todos los jugadores

`actividad_reciente()` SHALL incluir una fila de tipo `nivel_superado` por
cada `intentos_nivel` con `superado = true`, de **todos** los jugadores, con
`ocurrido_en` igual a `intentos_nivel.fecha` y `detalle` conteniendo
`estrellas_obtenidas`, `camino_id` y `tematica_id` del intento.

#### Scenario: Un jugador supera una parada

- **WHEN** un `intentos_nivel` queda con `superado = true`
- **THEN** `actividad_reciente()` incluye una fila `nivel_superado` con
  `detalle.estrellas_obtenidas` igual al valor del intento

#### Scenario: Intento sin superar no genera actividad

- **WHEN** un `intentos_nivel` queda con `superado = false`
- **THEN** `actividad_reciente()` no incluye ninguna fila `nivel_superado`
  para ese intento
