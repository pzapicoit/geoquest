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

#### Scenario: La parada tenía `preguntas_por_partida` efectivo menor que el total del pool
- **WHEN** se cierra un intento de una parada cuyo `preguntas_por_partida`
  efectivo es 5 y su pool de temática+dificultad tiene 8 desafíos activos,
  habiendo respondido los 5 desafíos de su selección persistida
- **THEN** el puntaje agregado es la suma de esas 5 respuestas, sin exigir
  ni contar los desafíos del pool no seleccionados para ese intento

### Requirement: El cierre exige que el intento esté completo
El sistema SHALL rechazar el cierre de un `intento_nivel` si no existe una
respuesta en `respuestas_desafio` para cada desafío de la selección
persistida de ese intento (`intento_desafios`). El sistema SHALL además
rechazar el cierre si el intento no tiene ninguna fila en
`intento_desafios` (por haberse creado sin pasar por
`iniciar_intento_parada`, o por ser anterior a la existencia de esa tabla),
en vez de tratarlo como un intento vacío ya completo.

#### Scenario: Intento con todos los desafíos de su selección respondidos
- **WHEN** se cierra un intento con exactamente una respuesta por cada
  desafío de su selección persistida en `intento_desafios`
- **THEN** el cierre procede y calcula el resultado

#### Scenario: Intento incompleto
- **WHEN** se intenta cerrar un intento al que le falta responder al menos
  un desafío de su selección persistida
- **THEN** la llamada se rechaza y no se modifica ninguna fila

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

### Requirement: Decisión de superación y cálculo de estrellas
El sistema SHALL marcar un intento como `superado` cuando su puntaje
agregado sea mayor o igual que el `puntaje_minimo_superar` efectivo de la
parada (override propio, o el de `dificultad_defaults` para su dificultad
si no tiene override), y en ese caso SHALL calcular `estrellas_obtenidas`
entre 1 y 3 según los umbrales efectivos `umbral_estrella_1/2/3` de la
parada (`umbral_estrella_1` siempre igual al `puntaje_minimo_superar`
efectivo), garantizando al menos 1 estrella siempre que el intento esté
superado.

#### Scenario: Puntaje por debajo del mínimo
- **WHEN** el puntaje agregado es menor que el `puntaje_minimo_superar`
  efectivo de la parada
- **THEN** el intento queda `superado = false` con `estrellas_obtenidas = 0`

#### Scenario: Puntaje que supera el mínimo pero no llega al primer umbral de estrella
- **WHEN** el puntaje agregado es mayor o igual que el
  `puntaje_minimo_superar` efectivo pero menor que el `umbral_estrella_1`
  efectivo
- **THEN** el intento queda `superado = true` con `estrellas_obtenidas = 1`

#### Scenario: Puntaje que alcanza el tercer umbral
- **WHEN** el puntaje agregado es mayor o igual que el `umbral_estrella_3`
  efectivo de la parada
- **THEN** el intento queda `superado = true` con `estrellas_obtenidas = 3`

### Requirement: Progreso agregado nunca empeora al rejugar
El sistema SHALL actualizar `progreso_usuario_nivel` para el usuario y la
parada (`camino_id`) del intento cerrado de forma que `mejor_puntaje` y
`mejores_estrellas` sean siempre el máximo entre el valor previamente
guardado y el resultado del nuevo intento, y `superado` permanezca en
`true` una vez alcanzado, sin importar el resultado de intentos
posteriores.

#### Scenario: Primer intento de una parada
- **WHEN** un usuario cierra su primer intento de una parada, sin fila
  previa en `progreso_usuario_nivel`
- **THEN** se crea la fila con `mejor_puntaje`/`mejores_estrellas`/
  `superado` iguales al resultado de ese intento

#### Scenario: Rejugar con un resultado peor
- **WHEN** un usuario ya tiene un `progreso_usuario_nivel` con
  `mejor_puntaje`/`mejores_estrellas` de un intento anterior, y cierra un
  nuevo intento con un puntaje o estrellas menores
- **THEN** `mejor_puntaje` y `mejores_estrellas` conservan el valor previo,
  más alto

#### Scenario: Rejugar con un resultado mejor
- **WHEN** un usuario ya tiene un `progreso_usuario_nivel` guardado y
  cierra un nuevo intento con un puntaje o estrellas mayores
- **THEN** `mejor_puntaje` y/o `mejores_estrellas` se actualizan al nuevo
  valor, más alto

### Requirement: Desbloqueo de posiciones del camino por estrellas acumuladas
El sistema SHALL, al cerrar un intento con `superado = true`, recalcular la
suma de `mejores_estrellas` del usuario sobre todas las paradas de
`camino`, y SHALL desbloquear (`desbloqueado = true` en
`progreso_usuario_nivel`) todas las posiciones de `camino` cuyo
`estrellas_requeridas` sea menor o igual que esa suma, sin exigir que el
usuario haya completado la posición inmediatamente anterior del camino.

#### Scenario: Las estrellas acumuladas alcanzan varias posiciones a la vez
- **WHEN** tras cerrar un intento, la suma de `mejores_estrellas` del
  usuario sobre las paradas del camino alcanza el `estrellas_requeridas` de
  las posiciones 4 y 5, que antes estaban bloqueadas
- **THEN** ambas posiciones quedan `desbloqueado = true` en
  `progreso_usuario_nivel` para ese usuario en la misma operación

#### Scenario: Las estrellas acumuladas no alcanzan la siguiente posición
- **WHEN** tras cerrar un intento, la suma de `mejores_estrellas` del
  usuario sobre las paradas del camino es menor que `estrellas_requeridas`
  de la siguiente posición bloqueada
- **THEN** ninguna posición adicional del camino se desbloquea

#### Scenario: El intento cerrado no queda superado
- **WHEN** se cierra un intento con `superado = false`
- **THEN** no se recalcula ni modifica ningún desbloqueo de posiciones del
  camino

### Requirement: Rejugar una parada superada no penaliza el progreso
El sistema SHALL permitir cerrar cualquier número de intentos sobre una
misma parada, incluyendo paradas ya superadas, sin que un resultado peor en
un intento posterior reduzca `superado`, `mejor_puntaje`,
`mejores_estrellas` ni `desbloqueado` ya alcanzados.

#### Scenario: Se rejuega una parada ya superada y se falla
- **WHEN** un usuario con una parada ya `superado = true` en
  `progreso_usuario_nivel` cierra un nuevo intento de esa parada que no
  alcanza su `puntaje_minimo_superar` efectivo
- **THEN** `progreso_usuario_nivel` conserva `superado = true` y sus
  `mejor_puntaje`/`mejores_estrellas` previos

### Requirement: Respuesta de cierre enriquecida para el resumen de la parada

El sistema SHALL devolver, al cerrar un `intento_nivel`, además del
resultado del propio intento (`puntaje_total`, `superado`,
`estrellas_obtenidas`), el `puntaje_minimo_superar` efectivo de la parada y
el `mejor_puntaje` que el usuario tenía registrado en
`progreso_usuario_nivel` para esa parada (`camino_id`) **antes** de este
cierre. El sistema SHALL capturar ese mejor puntaje previo antes de que el
propio cierre actualice `progreso_usuario_nivel`, y SHALL devolverlo vacío
cuando el usuario no tuviera ninguna fila previa en `progreso_usuario_nivel`
para esa parada.

#### Scenario: Cierre con un resultado anterior registrado

- **WHEN** un usuario con `mejor_puntaje = 1820` en `progreso_usuario_nivel`
  para una parada cierra un nuevo intento de esa parada con `puntaje_total =
  2140`
- **THEN** la respuesta del cierre incluye `puntaje_total = 2140` y el
  mejor puntaje previo de 1820, sin importar que
  `progreso_usuario_nivel.mejor_puntaje` quede actualizado a 2140 en la
  misma operación

#### Scenario: Cierre sin resultado anterior

- **WHEN** un usuario sin ninguna fila previa en `progreso_usuario_nivel`
  para una parada cierra su primer intento de esa parada
- **THEN** la respuesta del cierre incluye el mejor puntaje previo vacío,
  no cero

#### Scenario: La respuesta incluye el mínimo efectivo de la parada

- **WHEN** se cierra un intento de una parada cuyo `puntaje_minimo_superar`
  efectivo es 1500
- **THEN** la respuesta del cierre incluye ese mismo valor, sin importar
  si el intento quedó superado o no
