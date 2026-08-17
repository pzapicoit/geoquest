## MODIFIED Requirements

### Requirement: RPC `iniciar_intento_nivel` arranca una partida con sus desafíos

El sistema SHALL exponer una RPC `iniciar_intento_nivel(nivel_id)` que cree
un `intento_nivel` para el usuario autenticado actual sobre el nivel dado y
devuelva, en una sola respuesta, el `intento_id` creado junto con la lista
de desafíos de esa partida (mismas columnas que `desafios_para_jugar`).
Cuando `niveles.preguntas_por_partida` sea `NULL`, la lista SHALL incluir
todos los desafíos asignados al nivel en `nivel_desafios`. Cuando tenga un
valor, la lista SHALL contener esa cantidad de desafíos elegidos al azar
entre los asignados al nivel. La RPC SHALL además persistir esa misma
selección, en el mismo orden en que se devuelve, en `intento_desafios`
antes de responder, de forma que quede fijada para ese intento
independientemente de cambios posteriores en `nivel_desafios` o en
`desafios.activo`.

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

#### Scenario: La selección devuelta queda persistida para el intento

- **WHEN** un usuario autenticado llama a `iniciar_intento_nivel` y recibe
  una lista de `N` desafíos para el `intento_id` devuelto
- **THEN** `intento_desafios` contiene exactamente `N` filas para ese
  `intento_id`, una por cada desafío devuelto, con un `orden` que refleja
  el orden en que se devolvieron

#### Scenario: La selección persistida sobrevive a cambios posteriores de `nivel_desafios`/`activo`

- **WHEN** después de llamar a `iniciar_intento_nivel`, un admin desactiva
  uno de los desafíos devueltos o lo desasigna del nivel en
  `nivel_desafios`
- **THEN** la fila correspondiente en `intento_desafios` para ese intento
  no cambia
