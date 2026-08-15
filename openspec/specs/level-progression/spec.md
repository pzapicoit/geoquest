# level-progression Specification

## Purpose
TBD - created by archiving change int-79-superacion-nivel-estrellas. Update Purpose after archive.

## Requirements

### Requirement: Agregación de puntaje del intento vía `nivel_desafios`
El sistema SHALL exponer una RPC que, al cerrar un `intento_nivel`, sume
`puntos` de `respuestas_desafio` restringido a los desafíos asignados al
nivel del intento a través de `nivel_desafios`, ignorando cualquier
respuesta cuyo `desafio_id` no esté asignado a ese nivel.

#### Scenario: Se cierra un intento con respuestas válidas del nivel
- **WHEN** se cierra un intento cuyas respuestas corresponden todas a
  desafíos asignados al nivel del intento
- **THEN** el puntaje agregado es la suma de los `puntos` de esas
  respuestas

#### Scenario: Una respuesta corresponde a un desafío ajeno al nivel
- **WHEN** el intento tiene una respuesta a un `desafio_id` que no está
  asignado al nivel del intento vía `nivel_desafios`
- **THEN** esa respuesta no se cuenta en el puntaje agregado del cierre

### Requirement: El cierre exige que el intento esté completo
El sistema SHALL rechazar el cierre de un `intento_nivel` si no existe una
respuesta en `respuestas_desafio` para cada desafío asignado al nivel del
intento vía `nivel_desafios`.

#### Scenario: Intento con todos los desafíos respondidos
- **WHEN** se cierra un intento con exactamente una respuesta por cada
  desafío del nivel según `nivel_desafios`
- **THEN** el cierre procede y calcula el resultado

#### Scenario: Intento incompleto
- **WHEN** se intenta cerrar un intento al que le falta responder al menos
  un desafío asignado al nivel
- **THEN** la llamada se rechaza y no se modifica ninguna fila

### Requirement: Decisión de superación y cálculo de estrellas
El sistema SHALL marcar un intento como `superado` cuando su puntaje
agregado sea mayor o igual que `puntaje_minimo_superar` del nivel, y en ese
caso SHALL calcular `estrellas_obtenidas` entre 1 y 3 según los umbrales
`umbral_estrella_1/2/3` del nivel, garantizando al menos 1 estrella siempre
que el intento esté superado.

#### Scenario: Puntaje por debajo del mínimo
- **WHEN** el puntaje agregado es menor que `puntaje_minimo_superar`
- **THEN** el intento queda `superado = false` con `estrellas_obtenidas = 0`

#### Scenario: Puntaje que supera el mínimo pero no llega al primer umbral de estrella
- **WHEN** el puntaje agregado es mayor o igual que `puntaje_minimo_superar`
  pero menor que `umbral_estrella_1`
- **THEN** el intento queda `superado = true` con `estrellas_obtenidas = 1`

#### Scenario: Puntaje que alcanza el tercer umbral
- **WHEN** el puntaje agregado es mayor o igual que `umbral_estrella_3`
- **THEN** el intento queda `superado = true` con `estrellas_obtenidas = 3`

### Requirement: Persistencia del resultado en el propio intento
El sistema SHALL escribir `puntaje_total`, `superado` y
`estrellas_obtenidas` en la fila de `intentos_nivel` correspondiente al
cierre.

#### Scenario: Se cierra un intento
- **WHEN** un intento se cierra con éxito
- **THEN** su fila en `intentos_nivel` queda con `puntaje_total`,
  `superado` y `estrellas_obtenidas` iguales al resultado calculado

### Requirement: Progreso agregado nunca empeora al rejugar
El sistema SHALL actualizar `progreso_usuario_nivel` para el usuario y
nivel del intento cerrado de forma que `mejor_puntaje` y
`mejores_estrellas` sean siempre el máximo entre el valor previamente
guardado y el resultado del nuevo intento, y `superado` permanezca en
`true` una vez alcanzado, sin importar el resultado de intentos
posteriores.

#### Scenario: Primer intento de un nivel
- **WHEN** un usuario cierra su primer intento de un nivel, sin fila previa
  en `progreso_usuario_nivel`
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

### Requirement: Desbloqueo del siguiente nivel de la temática
El sistema SHALL desbloquear (marcar `desbloqueado = true` en
`progreso_usuario_nivel`) el siguiente nivel de la misma temática, según
`orden`, cuando el intento cerrado quede `superado`, si dicho nivel existe.

#### Scenario: Se supera un nivel con siguiente nivel en la temática
- **WHEN** se cierra un intento con `superado = true` y existe un nivel con
  `orden` inmediatamente superior en la misma `tematica_id`
- **THEN** ese siguiente nivel queda `desbloqueado = true` en
  `progreso_usuario_nivel` para ese usuario

#### Scenario: Se supera el último nivel de una temática
- **WHEN** se cierra un intento con `superado = true` para el nivel con el
  `orden` más alto de su temática
- **THEN** no se crea ni modifica ninguna fila de desbloqueo de nivel para
  esa temática

#### Scenario: El nivel no queda superado
- **WHEN** se cierra un intento con `superado = false`
- **THEN** no se desbloquea ningún nivel adicional

### Requirement: Desbloqueo de la siguiente temática por estrellas acumuladas
El sistema SHALL desbloquear el primer nivel (`orden = 1`) de la siguiente
temática (según `orden` de `tematicas`) cuando la suma de
`mejores_estrellas` del usuario entre los niveles de la temática actual sea
mayor o igual que `estrellas_requeridas` de la siguiente temática.

#### Scenario: Estrellas acumuladas alcanzan el requisito
- **WHEN** tras cerrar un intento, la suma de `mejores_estrellas` del
  usuario en los niveles de la temática actual es mayor o igual que
  `estrellas_requeridas` de la siguiente temática
- **THEN** el primer nivel de la siguiente temática queda
  `desbloqueado = true` en `progreso_usuario_nivel` para ese usuario

#### Scenario: Estrellas acumuladas insuficientes
- **WHEN** tras cerrar un intento, la suma de `mejores_estrellas` del
  usuario en los niveles de la temática actual es menor que
  `estrellas_requeridas` de la siguiente temática
- **THEN** no se desbloquea ningún nivel de la siguiente temática

#### Scenario: No existe siguiente temática
- **WHEN** la temática del nivel cerrado es la de `orden` más alto
- **THEN** no se intenta desbloquear ninguna temática adicional

### Requirement: Rejugar un nivel superado no penaliza el progreso
El sistema SHALL permitir cerrar cualquier número de intentos sobre un
mismo nivel, incluyendo niveles ya superados, sin que un resultado peor en
un intento posterior reduzca `superado`, `mejor_puntaje`,
`mejores_estrellas` ni `desbloqueado` ya alcanzados.

#### Scenario: Se rejuega un nivel ya superado y se falla
- **WHEN** un usuario con un nivel ya `superado = true` en
  `progreso_usuario_nivel` cierra un nuevo intento de ese nivel que no
  alcanza `puntaje_minimo_superar`
- **THEN** `progreso_usuario_nivel` conserva `superado = true` y sus
  `mejor_puntaje`/`mejores_estrellas` previos
