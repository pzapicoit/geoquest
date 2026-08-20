## MODIFIED Requirements

### Requirement: Vista `desafios_para_jugar` expone solo contenido de juego

El sistema SHALL exponer una vista `desafios_para_jugar` con, para cada
desafío, `id`, `tipo`, `nombre`, `imagen_url`, `video_url`,
`texto_pregunta` y `activo`. La vista SHALL ser legible por cualquier
usuario autenticado (incluida una sesión anónima), y SHALL no incluir en
ningún caso `lat_real`, `lng_real`, `nombre_lugar` ni `ciudad`.

`ciudad` entra en esa lista por el mismo motivo que `nombre_lugar`: nombra
el sitio que el jugador tiene que deducir del mapa. Antes de responder es
la respuesta; después es el revelado.

#### Scenario: Un jugador lee la vista de desafíos para jugar

- **WHEN** un usuario autenticado (o con sesión anónima) hace `select`
  sobre `desafios_para_jugar`
- **THEN** la operación se permite y devuelve `id`, `tipo`, `nombre`,
  `imagen_url`, `video_url`, `texto_pregunta` y `activo` de cada desafío

#### Scenario: La vista nunca expone la ubicación real

- **WHEN** se inspeccionan las columnas devueltas por `desafios_para_jugar`
- **THEN** ninguna fila incluye `lat_real`, `lng_real`, `nombre_lugar` ni
  `ciudad`, por ninguna vía (ni siquiera con nombre de columna distinto)

### Requirement: RPC `iniciar_intento_parada` arranca una partida con sus desafíos

El sistema SHALL exponer una RPC `iniciar_intento_parada(p_camino_id uuid)` que cree un `intento_nivel` para el usuario autenticado actual sobre la parada de `camino` dada y devuelva, en una sola respuesta, el `intento_id` creado, el `objetivo_global` de la temática de esa parada, junto con la lista de desafíos de esa partida (mismas columnas que `desafios_para_jugar`, incluido `nombre`). La RPC SHALL resolver la temática y dificultad efectivas de la parada (override o valor de `dificultad_defaults`) y sortear `preguntas_por_partida` desafíos elegidos al azar entre todos los desafíos `activo` cuyo `tematica_id` y `dificultad` coincidan con los de la parada. La RPC SHALL además persistir esa misma selección, en el mismo orden en que se devuelve, en `intento_desafios` antes de responder, de forma que quede fijada para ese intento independientemente de cambios posteriores en `desafios.dificultad`, `desafios.tematica_id` o `desafios.activo`.

Dentro de esa misma transacción, la RPC SHALL recalcular las condiciones de anuncio de desbloqueo y de cadencia (`video-ads`) para este intento y actualizar `profiles.intentos_desde_ultimo_anuncio_cadencia` del usuario en consecuencia: sin tocarlo si hay desbloqueo, reseteándolo a 0 si toca cadencia sin desbloqueo, o incrementándolo en 1 en cualquier otro caso.

#### Scenario: Se sortea sobre el pool de temática+dificultad de la parada

- **WHEN** un usuario autenticado llama a `iniciar_intento_parada` para una parada cuya dificultad efectiva tiene `preguntas_por_partida = 5`, y existen 12 desafíos `activo` con esa misma temática y dificultad
- **THEN** la respuesta incluye un `intento_id` nuevo y exactamente 5 de esos 12 desafíos, elegidos al azar

#### Scenario: La respuesta incluye el objetivo global de la temática de la parada

- **WHEN** un usuario autenticado llama a `iniciar_intento_parada` para una parada cuya temática tiene `objetivo_global = '¿Dónde está este monumento?'`
- **THEN** la respuesta incluye ese mismo texto como `objetivo_global`, una sola vez, no repetido por cada desafío de la lista

#### Scenario: Parada inexistente o inactiva

- **WHEN** se llama a `iniciar_intento_parada` con un `p_camino_id` que no existe, o que existe pero tiene `activo = false`
- **THEN** la llamada falla y no se crea ninguna fila en `intentos_nivel`

#### Scenario: El intento creado pertenece a quien llama, no a un parámetro

- **WHEN** un usuario autenticado llama a `iniciar_intento_parada`
- **THEN** la fila de `intentos_nivel` creada tiene `usuario_id` igual al `auth.uid()` de quien llamó, sin que la función acepte ningún parámetro para elegir otro usuario

#### Scenario: La respuesta no expone la ubicación real de ningún desafío

- **WHEN** se inspecciona la respuesta de `iniciar_intento_parada`
- **THEN** ningún desafío de la lista incluye `lat_real`, `lng_real`, `nombre_lugar` ni `ciudad`

#### Scenario: La selección devuelta queda persistida para el intento

- **WHEN** un usuario autenticado llama a `iniciar_intento_parada` y recibe una lista de `N` desafíos para el `intento_id` devuelto
- **THEN** `intento_desafios` contiene exactamente `N` filas para ese `intento_id`, una por cada desafío devuelto, con un `orden` que refleja el orden en que se devolvieron

#### Scenario: La selección persistida sobrevive a cambios posteriores del pool

- **WHEN** después de llamar a `iniciar_intento_parada`, un admin desactiva uno de los desafíos devueltos, o le cambia la `dificultad`, o lo mueve a otra `tematica_id`
- **THEN** la fila correspondiente en `intento_desafios` para ese intento no cambia

#### Scenario: Pool insuficiente para el número de preguntas exigido

- **WHEN** se llama a `iniciar_intento_parada` para una parada cuya dificultad efectiva exige más preguntas de las que existen activas en su temática+dificultad
- **THEN** la llamada falla y no se crea ninguna fila en `intentos_nivel`

#### Scenario: Arranca un intento de desbloqueo

- **WHEN** un usuario autenticado llama a `iniciar_intento_parada` para una parada de `orden > 1` en la que no tiene ningún intento previo
- **THEN** el intento se crea con normalidad y `profiles.intentos_desde_ultimo_anuncio_cadencia` del usuario queda exactamente igual que antes de la llamada

#### Scenario: Arranca un intento de cadencia sin solape

- **WHEN** un usuario autenticado cuyo contador de cadencia está en 2 llama a `iniciar_intento_parada` para una parada que ya jugó antes
- **THEN** el intento se crea con normalidad y `profiles.intentos_desde_ultimo_anuncio_cadencia` del usuario queda en 0 tras la llamada

#### Scenario: Arranca un intento sin desbloqueo ni cadencia

- **WHEN** un usuario autenticado cuyo contador de cadencia está en 0 o 1 llama a `iniciar_intento_parada` para una parada que ya jugó antes
- **THEN** el intento se crea con normalidad y `profiles.intentos_desde_ultimo_anuncio_cadencia` del usuario se incrementa en 1 tras la llamada
