## ADDED Requirements

### Requirement: `alertas_contenido` solo accesible a admin

`alertas_contenido()` SHALL rechazar la llamada si el usuario autenticado
no tiene `profiles.role = 'admin'`, sin devolver ninguna fila.

#### Scenario: Un jugador invoca `alertas_contenido`

- **WHEN** un usuario autenticado sin rol `admin` invoca
  `alertas_contenido()`
- **THEN** la llamada se rechaza

### Requirement: Alerta de nivel con tasa de superación baja

`alertas_contenido()` SHALL incluir una fila de tipo `nivel_baja_tasa` por
cada nivel `activo` cuya tasa de superación (`intentos_nivel.superado =
true` sobre el total de `intentos_nivel` de ese nivel, considerando
intentos de todos los jugadores) sea menor que 40%, y SHALL excluir
cualquier nivel con menos de 5 `intentos_nivel` registrados en total,
para evitar falsos positivos por muestra pequeña.

#### Scenario: Nivel con tasa de superación baja y muestra suficiente

- **WHEN** un nivel activo tiene 10 intentos registrados de distintos
  jugadores y menos de 4 quedaron `superado = true`
- **THEN** `alertas_contenido()` incluye una fila `nivel_baja_tasa` para
  ese nivel

#### Scenario: Nivel con tasa baja pero muestra insuficiente

- **WHEN** un nivel activo tiene solo 2 intentos registrados y ninguno
  quedó `superado = true`
- **THEN** `alertas_contenido()` no incluye ninguna fila para ese nivel

#### Scenario: Nivel inactivo con tasa de superación baja

- **WHEN** un nivel con `activo = false` tendría una tasa de superación
  baja según sus intentos históricos
- **THEN** `alertas_contenido()` no incluye ninguna fila para ese nivel

### Requirement: Alerta de desafío con datos incompletos

`alertas_contenido()` SHALL incluir una fila de tipo
`desafio_incompleto` por cada desafío `activo` cuyo campo de contenido
correspondiente a su `tipo` (`imagen_url`, `video_url` o
`texto_pregunta`) sea `NULL` o quede vacío tras `trim()`, o cuyas
coordenadas sean exactamente `lat_real = 0` y `lng_real = 0`.

#### Scenario: Desafío de tipo imagen sin URL

- **WHEN** un desafío `activo` de `tipo = 'imagen'` tiene `imagen_url`
  vacía tras `trim()`
- **THEN** `alertas_contenido()` incluye una fila `desafio_incompleto`
  para ese desafío

#### Scenario: Desafío con coordenadas sin establecer

- **WHEN** un desafío `activo` tiene `lat_real = 0` y `lng_real = 0`
- **THEN** `alertas_contenido()` incluye una fila `desafio_incompleto`
  para ese desafío, sin importar si su campo de contenido está completo

#### Scenario: Desafío completo

- **WHEN** un desafío `activo` tiene su campo de contenido no vacío según
  su `tipo` y coordenadas distintas de `(0, 0)`
- **THEN** `alertas_contenido()` no incluye ninguna fila para ese desafío

#### Scenario: Desafío inactivo con datos incompletos

- **WHEN** un desafío con `activo = false` tiene su campo de contenido
  vacío según su `tipo`
- **THEN** `alertas_contenido()` no incluye ninguna fila para ese desafío
