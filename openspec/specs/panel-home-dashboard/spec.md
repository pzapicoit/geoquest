# panel-home-dashboard Specification

## Purpose
TBD - created by archiving change int-81-panel-home-dashboard. Update Purpose after archive.

## Requirements

### Requirement: Layout fijo con navegación lateral

La zona autenticada del panel SHALL mostrar una navegación lateral fija con
los enlaces Home, Jugadores, Ranking, Temáticas, Niveles y
Preguntas/Desafíos. Solo Home SHALL tener pantalla propia; el resto SHALL
renderizarse deshabilitado (sin navegación al hacer click).

#### Scenario: Admin autenticado ve la navegación completa

- **WHEN** un admin autenticado abre el panel
- **THEN** ve la navegación lateral con los 6 enlaces (Home, Jugadores,
  Ranking, Temáticas, Niveles, Preguntas/Desafíos)
- **AND** solo "Home" navega a una pantalla con contenido

#### Scenario: Click en un enlace de navegación sin pantalla propia

- **WHEN** el admin hace click en un enlace de la nav distinto de "Home"
- **THEN** el panel no navega a ninguna ruta (el enlace está deshabilitado)

### Requirement: Header con admin y cierre de sesión

El header SHALL mostrar el nombre del admin autenticado y una opción de
cerrar sesión que termina la sesión de Supabase y redirige a login.

#### Scenario: Header muestra el nombre del admin

- **WHEN** un admin autenticado abre el panel
- **THEN** el header muestra su nombre (`profiles.nombre`)

#### Scenario: Cerrar sesión desde el header

- **WHEN** el admin hace click en "Cerrar sesión"
- **THEN** la sesión de Supabase termina
- **AND** el panel redirige a la pantalla de login

### Requirement: Fila de tarjetas de métricas del dashboard

La pantalla Home SHALL mostrar 4 tarjetas con los valores de
`metricas_home()`: jugadores totales, jugadores activos (últimos 7 días),
partidas jugadas hoy y niveles publicados (activos). No SHALL ofrecer un
selector de rango temporal, dado que `metricas_home()` no soporta más de una
ventana.

#### Scenario: Home muestra las 4 métricas

- **WHEN** un admin abre Home
- **THEN** ve 4 tarjetas con `jugadores_totales`, `jugadores_activos_7d`,
  `partidas_hoy` y `niveles_activos` de `metricas_home()`

### Requirement: Accesos rápidos deshabilitados sin pantalla de destino

Home SHALL mostrar 3 accesos rápidos (nueva temática, nuevo nivel, nuevo
desafío), renderizados deshabilitados porque sus pantallas de destino no
existen todavía.

#### Scenario: Click en un acceso rápido

- **WHEN** el admin hace click en uno de los 3 accesos rápidos
- **THEN** el panel no navega a ninguna ruta (el acceso está deshabilitado)

### Requirement: Columna de actividad reciente

Home SHALL mostrar una columna "Actividad reciente" con los eventos de
`actividad_reciente()`, resolviendo para cada evento `nivel_superado` el
nombre legible de la temática y el número de nivel mediante lecturas
adicionales de `tematicas`/`niveles`.

#### Scenario: Home muestra actividad reciente

- **WHEN** un admin abre Home y existen eventos en `actividad_reciente()`
- **THEN** la columna "Actividad reciente" lista esos eventos ordenados por
  fecha descendente

#### Scenario: Sin actividad reciente

- **WHEN** `actividad_reciente()` no devuelve ninguna fila
- **THEN** la columna "Actividad reciente" muestra un estado vacío, no un
  error ni una lista en blanco sin explicación

### Requirement: Columna de alertas de contenido

Home SHALL mostrar una columna "Alertas de contenido" con los eventos de
`alertas_contenido()`, resolviendo el nombre legible de cada nivel/desafío
referenciado mediante lecturas adicionales de `tematicas`/`niveles`/
`desafios`.

#### Scenario: Home muestra alertas de contenido

- **WHEN** un admin abre Home y existen alertas en `alertas_contenido()`
- **THEN** la columna "Alertas de contenido" lista esas alertas con su
  nombre legible resuelto

#### Scenario: Sin alertas de contenido

- **WHEN** `alertas_contenido()` no devuelve ninguna fila
- **THEN** la columna "Alertas de contenido" muestra un estado vacío, no un
  error ni una lista en blanco sin explicación
