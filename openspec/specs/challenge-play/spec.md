# challenge-play Specification

## Purpose
TBD - created by archiving change int-95-vista-desafios-intento. Update Purpose after archive.

## Requirements

### Requirement: Vista `desafios_para_jugar` expone solo contenido de juego

El sistema SHALL exponer una vista `desafios_para_jugar` con, para cada
desafío, `id`, `tipo`, `imagen_url`, `video_url`, `texto_pregunta` y
`activo`. La vista SHALL ser legible por cualquier usuario autenticado
(incluida una sesión anónima), y SHALL no incluir en ningún caso
`lat_real`, `lng_real` ni `nombre_lugar`.

#### Scenario: Un jugador lee la vista de desafíos para jugar

- **WHEN** un usuario autenticado (o con sesión anónima) hace `select`
  sobre `desafios_para_jugar`
- **THEN** la operación se permite y devuelve `id`, `tipo`, `imagen_url`,
  `video_url`, `texto_pregunta` y `activo` de cada desafío

#### Scenario: La vista nunca expone la ubicación real

- **WHEN** se inspeccionan las columnas devueltas por `desafios_para_jugar`
- **THEN** ninguna fila incluye `lat_real`, `lng_real` ni `nombre_lugar`,
  por ninguna vía (ni siquiera con nombre de columna distinto)

### Requirement: RPC `iniciar_intento_nivel` arranca una partida con sus desafíos

El sistema SHALL exponer una RPC `iniciar_intento_nivel(nivel_id)` que cree
un `intento_nivel` para el usuario autenticado actual sobre el nivel dado y
devuelva, en una sola respuesta, el `intento_id` creado junto con la lista
de desafíos de esa partida (mismas columnas que `desafios_para_jugar`).
Cuando `niveles.preguntas_por_partida` sea `NULL`, la lista SHALL incluir
todos los desafíos asignados al nivel en `nivel_desafios`. Cuando tenga un
valor, la lista SHALL contener esa cantidad de desafíos elegidos al azar
entre los asignados al nivel.

#### Scenario: Nivel sin límite de preguntas por partida

- **WHEN** un usuario autenticado llama a `iniciar_intento_nivel` para un
  nivel con `preguntas_por_partida = NULL` y 8 desafíos asignados
- **THEN** la respuesta incluye un `intento_id` nuevo y los 8 desafíos
  asignados al nivel

#### Scenario: Nivel con límite de preguntas por partida

- **WHEN** un usuario autenticado llama a `iniciar_intento_nivel` para un
  nivel con `preguntas_por_partida = 5` y 8 desafíos asignados
- **THEN** la respuesta incluye un `intento_id` nuevo y exactamente 5 de
  esos 8 desafíos, elegidos al azar

#### Scenario: Nivel inexistente o inactivo

- **WHEN** se llama a `iniciar_intento_nivel` con un `nivel_id` que no
  existe, o que existe pero tiene `activo = false`
- **THEN** la llamada falla y no se crea ninguna fila en `intentos_nivel`

#### Scenario: El intento creado pertenece a quien llama, no a un parámetro

- **WHEN** un usuario autenticado llama a `iniciar_intento_nivel`
- **THEN** la fila de `intentos_nivel` creada tiene `usuario_id` igual al
  `auth.uid()` de quien llamó, sin que la función acepte ningún parámetro
  para elegir otro usuario

#### Scenario: La respuesta no expone la ubicación real de ningún desafío

- **WHEN** se inspecciona la respuesta de `iniciar_intento_nivel`
- **THEN** ningún desafío de la lista incluye `lat_real`, `lng_real` ni
  `nombre_lugar`
