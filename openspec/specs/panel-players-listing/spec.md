# panel-players-listing Specification

## Purpose
TBD - created by syncing change int-111-panel-jugadores. Update Purpose after archive.

## Requirements

### Requirement: Listado de jugadores en el panel
El panel SHALL mostrar una pantalla "Jugadores" con una fila por cada perfil con `role = 'jugador'`, incluyendo alias, parada más avanzada superada, puntos totales, tasa de superación de niveles y fecha de la última partida.

#### Scenario: Carga inicial del listado
- **WHEN** un admin autenticado abre la pantalla "Jugadores"
- **THEN** el panel llama a la RPC `jugadores_listado` y muestra una fila por jugador con sus datos agregados

#### Scenario: Jugador sin ninguna partida
- **WHEN** un jugador no tiene ningún `intentos_nivel` registrado
- **THEN** su fila muestra 0 puntos, sin parada superada y sin tasa de superación (no un error ni un cero engañoso presentado como "0% de acierto")

#### Scenario: Un no-admin intenta consultar el listado
- **WHEN** un usuario autenticado sin `role = 'admin'` invoca la RPC `jugadores_listado`
- **THEN** la RPC lanza una excepción y no devuelve ninguna fila

### Requirement: Búsqueda, orden y paginación en cliente
El listado SHALL permitir filtrar por alias (contiene, insensible a mayúsculas), ordenar por puntos totales, parada más avanzada, alias o tasa de superación, y paginar el resultado filtrado — todo ello aplicado en el cliente sobre el conjunto ya cargado.

#### Scenario: Buscar por alias
- **WHEN** el admin escribe un texto en el buscador
- **THEN** el listado muestra solo los jugadores cuyo alias contiene ese texto (sin distinguir mayúsculas/minúsculas) y vuelve a la primera página

#### Scenario: Ningún jugador coincide con el filtro
- **WHEN** el filtro de búsqueda no coincide con ningún jugador
- **THEN** el panel muestra un estado vacío con la opción de limpiar el filtro, en vez de una tabla vacía sin explicación

#### Scenario: Cambiar de página
- **WHEN** el admin pulsa "Siguiente" o el número de una página distinta a la actual
- **THEN** el listado muestra la porción correspondiente del conjunto filtrado/ordenado, sin volver a llamar a la RPC
