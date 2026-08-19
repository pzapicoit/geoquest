## MODIFIED Requirements

### Requirement: Decisión de superación y cálculo de estrellas
El sistema SHALL marcar un intento como `superado` cuando su puntaje
agregado sea mayor o igual que el mínimo devuelto por `umbrales_parada`
para la dificultad de la parada y el número real de desafíos de la
selección persistida del intento (`intento_desafios`), y en ese caso SHALL
calcular `estrellas_obtenidas` entre 1 y 3 según los umbrales `umbral_estrella_2`/`umbral_estrella_3`
de esa misma llamada (`umbral_estrella_1` siempre igual al mínimo
efectivo), garantizando al menos 1 estrella siempre que el intento esté
superado. El sistema SHALL usar el número de desafíos efectivamente
persistidos en `intento_desafios` para ese intento, no el
`preguntas_por_partida` vigente en `camino`/`dificultad_defaults` en el
momento del cierre, de forma que un cambio de configuración posterior al
inicio del intento no altere su resultado.

#### Scenario: Puntaje por debajo del mínimo
- **WHEN** el puntaje agregado es menor que el mínimo efectivo de la parada
- **THEN** el intento queda `superado = false` con `estrellas_obtenidas = 0`

#### Scenario: Puntaje que supera el mínimo pero no llega al primer umbral de estrella
- **WHEN** el puntaje agregado es mayor o igual que el mínimo efectivo
  pero menor que el `umbral_estrella_1` efectivo
- **THEN** el intento queda `superado = true` con `estrellas_obtenidas = 1`

#### Scenario: Puntaje que alcanza el tercer umbral
- **WHEN** el puntaje agregado es mayor o igual que el `umbral_estrella_3`
  efectivo de la parada
- **THEN** el intento queda `superado = true` con `estrellas_obtenidas = 3`

### Requirement: Desbloqueo de posiciones del camino por estrellas acumuladas
El sistema SHALL, al cerrar un intento con `superado = true`, recalcular la
suma de `mejores_estrellas` del usuario sobre todas las paradas de
`camino`, y SHALL desbloquear (`desbloqueado = true` en
`progreso_usuario_nivel`) todas las posiciones de `camino` cuyo
`estrellas_requeridas_por_orden(orden)` sea menor o igual que esa suma, sin
exigir que el usuario haya completado la posición inmediatamente anterior
del camino.

#### Scenario: Las estrellas acumuladas alcanzan varias posiciones a la vez
- **WHEN** tras cerrar un intento, la suma de `mejores_estrellas` del
  usuario sobre las paradas del camino alcanza el requisito derivado de
  las posiciones 4 y 5, que antes estaban bloqueadas
- **THEN** ambas posiciones quedan `desbloqueado = true` en
  `progreso_usuario_nivel` para ese usuario en la misma operación

#### Scenario: Las estrellas acumuladas no alcanzan la siguiente posición
- **WHEN** tras cerrar un intento, la suma de `mejores_estrellas` del
  usuario sobre las paradas del camino es menor que el requisito derivado
  de la siguiente posición bloqueada
- **THEN** ninguna posición adicional del camino se desbloquea

#### Scenario: El intento cerrado no queda superado
- **WHEN** se cierra un intento con `superado = false`
- **THEN** no se recalcula ni modifica ningún desbloqueo de posiciones del
  camino

### Requirement: Respuesta de cierre enriquecida para el resumen de la parada

El sistema SHALL devolver, al cerrar un `intento_nivel`, además del
resultado del propio intento (`puntaje_total`, `superado`,
`estrellas_obtenidas`), el mínimo efectivo de la parada, el máximo
alcanzable efectivo (`puntaje_maximo`, derivado del número de desafíos
persistidos y `puntaje_maximo_por_desafio()`), y el `mejor_puntaje` que el
usuario tenía registrado en `progreso_usuario_nivel` para esa parada
(`camino_id`) **antes** de este cierre. El sistema SHALL capturar ese
mejor puntaje previo antes de que el propio cierre actualice
`progreso_usuario_nivel`, y SHALL devolverlo vacío cuando el usuario no
tuviera ninguna fila previa en `progreso_usuario_nivel` para esa parada.

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

- **WHEN** se cierra un intento de una parada cuyo mínimo efectivo
  es 1500
- **THEN** la respuesta del cierre incluye ese mismo valor, sin importar
  si el intento quedó superado o no

#### Scenario: La respuesta incluye el máximo alcanzable del intento

- **WHEN** se cierra un intento cuya selección persistida en
  `intento_desafios` tiene 4 desafíos
- **THEN** la respuesta del cierre incluye `puntaje_maximo` igual a
  `4 × puntaje_maximo_por_desafio()`, sin importar si el intento quedó
  superado o no
