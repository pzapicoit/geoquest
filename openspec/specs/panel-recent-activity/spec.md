# panel-recent-activity Specification

## Purpose
TBD - created by archiving change int-81-panel-home-dashboard. Update Purpose after archive.

## Requirements

### Requirement: `actividad_reciente` solo accesible a admin

`actividad_reciente()` SHALL rechazar la llamada si el usuario autenticado no
tiene `profiles.role = 'admin'`, sin devolver ninguna fila.

#### Scenario: Un jugador invoca `actividad_reciente`

- **WHEN** un usuario autenticado sin rol `admin` invoca
  `actividad_reciente()`
- **THEN** la llamada se rechaza

### Requirement: Feed incluye altas de jugador de todos los usuarios

`actividad_reciente()` SHALL incluir una fila de tipo `nuevo_registro` por
cada `profiles` con `role = 'jugador'` dado de alta, con `ocurrido_en` igual
a `auth.users.created_at` de ese usuario, considerando altas de **todos**
los jugadores, no solo las asociadas al admin que invoca.

#### Scenario: Nuevo jugador dado de alta

- **WHEN** un usuario se registra y su `profiles.role` queda en `jugador`
- **THEN** `actividad_reciente()` incluye una fila `nuevo_registro` para ese
  jugador, con `ocurrido_en` igual a la fecha de alta en `auth.users`

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

### Requirement: Feed ordenado por fecha descendente y acotado por límite

`actividad_reciente(p_limite integer default 20)` SHALL devolver como máximo
`p_limite` filas, ordenadas por `ocurrido_en` descendente (la actividad más
reciente primero), combinando altas y niveles superados en un único orden
cronológico.

#### Scenario: Más eventos que el límite

- **WHEN** existen más de `p_limite` eventos combinados (altas + niveles
  superados) en el histórico
- **THEN** `actividad_reciente()` devuelve exactamente `p_limite` filas, las
  más recientes según `ocurrido_en`

#### Scenario: Altas y niveles superados intercalados

- **WHEN** existen altas de jugador y niveles superados con fechas
  intercaladas entre sí
- **THEN** `actividad_reciente()` los devuelve en un único orden
  cronológico descendente, sin agrupar por tipo
