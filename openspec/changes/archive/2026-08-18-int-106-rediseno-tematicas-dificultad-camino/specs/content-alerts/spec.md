## MODIFIED Requirements

### Requirement: Alerta de parada con tasa de superación baja

`alertas_contenido()` SHALL incluir una fila de tipo `nivel_baja_tasa` por
cada parada de `camino` `activo` cuya tasa de superación (`intentos_nivel.superado =
true` sobre el total de `intentos_nivel` de esa parada, considerando
intentos de todos los jugadores) sea menor que 40%, y SHALL excluir
cualquier parada con menos de 5 `intentos_nivel` registrados en total,
para evitar falsos positivos por muestra pequeña.

#### Scenario: Parada con tasa de superación baja y muestra suficiente

- **WHEN** una parada activa tiene 10 intentos registrados de distintos
  jugadores y menos de 4 quedaron `superado = true`
- **THEN** `alertas_contenido()` incluye una fila `nivel_baja_tasa` para
  esa parada

#### Scenario: Parada con tasa baja pero muestra insuficiente

- **WHEN** una parada activa tiene solo 2 intentos registrados y ninguno
  quedó `superado = true`
- **THEN** `alertas_contenido()` no incluye ninguna fila para esa parada

#### Scenario: Parada inactiva con tasa de superación baja

- **WHEN** una parada con `activo = false` tendría una tasa de superación
  baja según sus intentos históricos
- **THEN** `alertas_contenido()` no incluye ninguna fila para esa parada
