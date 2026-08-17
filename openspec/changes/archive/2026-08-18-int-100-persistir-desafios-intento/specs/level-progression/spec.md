## MODIFIED Requirements

### Requirement: Agregación de puntaje del intento vía `intento_desafios`

El sistema SHALL exponer una RPC que, al cerrar un `intento_nivel`, sume
`puntos` de `respuestas_desafio` restringido a los desafíos que forman
parte de la selección persistida de ese intento (`intento_desafios`),
ignorando cualquier respuesta cuyo `desafio_id` no esté en esa selección.

#### Scenario: Se cierra un intento con respuestas válidas de su selección

- **WHEN** se cierra un intento cuyas respuestas corresponden todas a
  desafíos de su selección persistida en `intento_desafios`
- **THEN** el puntaje agregado es la suma de los `puntos` de esas
  respuestas

#### Scenario: Una respuesta corresponde a un desafío ajeno a la selección del intento

- **WHEN** el intento tiene una respuesta a un `desafio_id` que no está en
  su selección persistida (`intento_desafios`)
- **THEN** esa respuesta no se cuenta en el puntaje agregado del cierre

#### Scenario: El nivel tenía `preguntas_por_partida` menor que el total asignado

- **WHEN** se cierra un intento de un nivel con `preguntas_por_partida = 5`
  y 8 desafíos asignados en `nivel_desafios`, habiendo respondido los 5
  desafíos de su selección persistida
- **THEN** el puntaje agregado es la suma de esas 5 respuestas, sin exigir
  ni contar los 3 desafíos no seleccionados para ese intento

### Requirement: El cierre exige que el intento esté completo

El sistema SHALL rechazar el cierre de un `intento_nivel` si no existe una
respuesta en `respuestas_desafio` para cada desafío de la selección
persistida de ese intento (`intento_desafios`). El sistema SHALL además
rechazar el cierre si el intento no tiene ninguna fila en
`intento_desafios` (por haberse creado sin pasar por
`iniciar_intento_nivel`, o por ser anterior a la existencia de esa tabla),
en vez de tratarlo como un intento vacío ya completo.

#### Scenario: Intento con todos los desafíos de su selección respondidos

- **WHEN** se cierra un intento con exactamente una respuesta por cada
  desafío de su selección persistida en `intento_desafios`
- **THEN** el cierre procede y calcula el resultado

#### Scenario: Intento incompleto

- **WHEN** se intenta cerrar un intento al que le falta responder al menos
  un desafío de su selección persistida
- **THEN** la llamada se rechaza y no se modifica ninguna fila

#### Scenario: El nivel tenía `preguntas_por_partida` menor que el total asignado

- **WHEN** se cierra un intento de un nivel con `preguntas_por_partida = 5`
  y 8 desafíos asignados en `nivel_desafios`, habiendo respondido
  exactamente los 5 desafíos de su selección persistida
- **THEN** el cierre procede, sin exigir respuesta para los 3 desafíos no
  seleccionados para ese intento

#### Scenario: Un desafío de la selección se desactiva a mitad de partida

- **WHEN** un desafío que forma parte de la selección persistida de un
  intento se desactiva (`activo = false`) después de arrancar el intento,
  y el jugador lo responde igualmente junto con el resto de su selección
- **THEN** el cierre procede con normalidad, contando esa respuesta como
  parte del intento completo

#### Scenario: Intento sin selección persistida

- **WHEN** se intenta cerrar un `intento_nivel` que no tiene ninguna fila
  en `intento_desafios`
- **THEN** la llamada se rechaza y no se modifica ninguna fila, aunque no
  existan respuestas registradas para ese intento
