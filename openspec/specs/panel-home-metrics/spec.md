# panel-home-metrics Specification

## Purpose
TBD - created by archiving change int-87-rpcs-vistas-panel. Update Purpose after archive.

## Requirements

### Requirement: `metricas_home` solo accesible a admin

`metricas_home()` SHALL rechazar la llamada si el usuario autenticado no
tiene `profiles.role = 'admin'`, sin devolver ningún dato.

#### Scenario: Un jugador invoca `metricas_home`

- **WHEN** un usuario autenticado sin rol `admin` invoca `metricas_home()`
- **THEN** la llamada se rechaza

### Requirement: `metricas_home` agrega datos de todos los jugadores

`metricas_home()` SHALL devolver: `jugadores_totales` (conteo de
`profiles` con `role = 'jugador'`), `jugadores_activos_7d` (conteo
distinto de jugadores con al menos un `intentos_nivel` en los últimos 7
días), `partidas_hoy` (conteo de `intentos_nivel` cuya `fecha` cae en el
día actual) y `paradas_activas` (conteo de `camino` con `activo = true`),
considerando las filas de **todos** los jugadores, no solo las del admin
que invoca la función.

#### Scenario: Un admin consulta las métricas

- **WHEN** un admin invoca `metricas_home()`
- **THEN** `jugadores_totales` cuenta todas las filas de `profiles` con
  `role = 'jugador'`, sin importar cuál de ellas generó los intentos que
  el propio admin haya podido jugar

#### Scenario: Jugador activo en los últimos 7 días

- **WHEN** un jugador tiene un `intentos_nivel` con `fecha` dentro de los
  últimos 7 días
- **THEN** ese jugador cuenta una sola vez en `jugadores_activos_7d`,
  aunque tenga varios intentos en ese rango

#### Scenario: Partidas jugadas hoy

- **WHEN** existen `intentos_nivel` cuya `fecha` cae en el día actual,
  creados por distintos jugadores
- **THEN** `partidas_hoy` cuenta cada uno de esos intentos, sin agrupar
  por jugador

#### Scenario: Paradas activas

- **WHEN** existen paradas de `camino` con `activo = true` y con
  `activo = false`
- **THEN** `paradas_activas` cuenta solo las primeras
