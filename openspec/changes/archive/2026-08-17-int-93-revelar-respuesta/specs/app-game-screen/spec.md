## MODIFIED Requirements

### Requirement: Progreso y puntaje del intento visibles

La pantalla SHALL mostrar el progreso y el puntaje en una capa fija sobre
el mapa, visible en la fase de adivinar, con el toast de pista abierto y
durante el revelado del resultado. Esa capa SHALL contener el progreso
dentro del intento actual como "Desafío X de N" (X = posición del desafío
mostrado, N = total de desafíos del intento), el nombre del nivel que se
está jugando, una barra segmentada con un segmento por desafío del intento
que distinga los ya respondidos, el actual y los pendientes, y el puntaje
acumulado del intento.

El puntaje mostrado SHALL ser la suma de los puntos devueltos por el
servidor para los desafíos ya respondidos en este intento. Durante el
revelado de una respuesta, el puntaje SHALL subir progresivamente hasta
incluir los puntos de esa respuesta, y el segmento del desafío revelado
SHALL pasar a marcarse como respondido.

#### Scenario: Progreso con varios desafíos

- **WHEN** el intento tiene 6 desafíos y se muestra el primero
- **THEN** la pantalla muestra el texto de progreso "Desafío 1 de 6" y una
  barra de 6 segmentos con el primero marcado como actual

#### Scenario: Puntaje al recién arrancar el intento

- **WHEN** el intento se acaba de crear y todavía no se ha resuelto
  ningún desafío
- **THEN** la pantalla muestra el puntaje acumulado del intento como 0

#### Scenario: El progreso sigue visible con la pista abierta

- **WHEN** el toast de pista está abierto
- **THEN** el progreso, el nombre del nivel y el puntaje siguen visibles
  por encima del toast

#### Scenario: El nivel no tiene nombre

- **WHEN** el nivel que se está jugando no tiene nombre propio
- **THEN** la capa de progreso muestra el nombre de su temática en su
  lugar, sin dejar un hueco vacío

#### Scenario: El puntaje total incorpora la respuesta revelada

- **WHEN** el jugador llevaba 1200 puntos y termina el revelado de una
  respuesta de 800 puntos
- **THEN** el puntaje de la capa de progreso muestra 2000 y el segmento del
  desafío revelado queda marcado como respondido

## REMOVED Requirements

### Requirement: Confirmar envía la respuesta y avanza al siguiente desafío
**Reason**: Confirmar deja de avanzar al desafío siguiente: ahora entra en
la fase de revelado del resultado, y el avance pasa a ser un acto explícito
del jugador desde ese revelado.
**Migration**: Sustituido por "Confirmar envía la respuesta y revela el
resultado" (envío y entrada en el revelado) y "Avanzar desde el revelado es
un acto del jugador" (avance al desafío siguiente y vuelta al camino tras el
último). El envío a `responder_desafio` y el trato de sus fallos no cambian.

## ADDED Requirements

### Requirement: Confirmar envía la respuesta y revela el resultado

La pantalla SHALL mostrar un botón "Confirmar" deshabilitado mientras no
haya pin colocado. Al pulsarlo, SHALL enviar las coordenadas del pin a la
RPC `responder_desafio` con el `intento_id` del intento en curso y el `id`
del desafío actual y, con la respuesta del servidor, SHALL entrar en la
fase de revelado de ese desafío en vez de avanzar al siguiente.

Mientras la llamada está en curso, el botón SHALL quedar deshabilitado
para no enviar la misma respuesta dos veces.

#### Scenario: Confirmar sin pin

- **WHEN** la pantalla está en la fase de adivinar y no hay pin colocado
- **THEN** el botón "Confirmar" está deshabilitado y pulsarlo no llama a
  `responder_desafio`

#### Scenario: Confirmar con pin

- **WHEN** hay un pin colocado y el jugador pulsa "Confirmar"
- **THEN** se llama a `responder_desafio` con el intento en curso, el
  desafío actual y las coordenadas del pin

#### Scenario: Confirmar entra en el revelado

- **WHEN** el servidor responde a "Confirmar"
- **THEN** la pantalla pasa a la fase de revelado del desafío respondido,
  conservando el pin del jugador donde estaba y sin mostrar todavía la
  pista del desafío siguiente

#### Scenario: Enviar la respuesta falla

- **WHEN** la llamada a `responder_desafio` falla (sin red, error del
  servidor)
- **THEN** la pantalla avisa del fallo, conserva el pin colocado y vuelve
  a habilitar "Confirmar" para reintentar, sin entrar en el revelado ni
  cambiar el puntaje

### Requirement: El revelado muestra el resultado del desafío respondido

Tras confirmar, la pantalla SHALL revelar el resultado sobre el mismo mapa,
con una secuencia que arranca sola: aparece el pin de la ubicación real
junto al pin del jugador, la cámara encuadra los dos pines con margen para
que ninguno quede tapado, se traza la línea punteada entre ellos y, a
continuación, suben los contadores desde 0 hasta sus valores finales — la
distancia en kilómetros primero y los puntos ganados después.

Sobre el mapa, la pantalla SHALL mostrar una hoja de resultado con: una
miniatura de la pista original del desafío, el rótulo de ubicación real con
el nombre del lugar y sus coordenadas, la distancia recorrida entre el pin
del jugador y el lugar real, y los puntos ganados en este desafío junto al
máximo alcanzable.

La distancia y los puntos mostrados SHALL ser los que devuelve el servidor,
sin recalcularse en la app.

#### Scenario: Secuencia del revelado

- **WHEN** el servidor responde a "Confirmar" con una distancia de 247 km y
  520 puntos
- **THEN** aparece el pin de la ubicación real, la cámara encuadra los dos
  pines, se traza la línea punteada entre ellos y los contadores acaban en
  247 km y 520 puntos

#### Scenario: Nombre del lugar y coordenadas reales

- **WHEN** se muestra el revelado de un desafío cuyo lugar real es "Coliseo
  de Roma"
- **THEN** la hoja de resultado muestra ese nombre como ubicación real,
  junto a sus coordenadas en grados con su hemisferio

#### Scenario: Puntos sobre el máximo alcanzable

- **WHEN** el servidor devuelve 520 puntos y un máximo alcanzable de 5000
- **THEN** la hoja de resultado presenta los 520 puntos ganados como parte
  de ese máximo

#### Scenario: Miniatura de una pista de imagen

- **WHEN** el desafío revelado es de tipo `imagen`
- **THEN** la miniatura de la hoja de resultado muestra la imagen de la
  pista

#### Scenario: Miniatura de una pista sin imagen

- **WHEN** el desafío revelado es de tipo `video` o `pregunta_texto`
- **THEN** la miniatura muestra un distintivo del tipo de pista, sin dejar
  un hueco vacío ni intentar cargar una imagen que no existe

#### Scenario: El mapa no acepta gestos durante el revelado

- **WHEN** el jugador arrastra, pellizca o toca el mapa durante el revelado
- **THEN** el encuadre y los dos pines se mantienen como los deja la
  secuencia, y el pin del jugador no se mueve de donde lo confirmó

### Requirement: Avanzar desde el revelado es un acto del jugador

El revelado SHALL ofrecer un botón que continúe la partida, rotulado
"Siguiente" cuando queden desafíos por jugar y "Ver resultados" cuando el
revelado sea el del último desafío del intento. Solo pulsarlo SHALL sacar
al jugador del revelado.

Al pulsar "Siguiente", la pantalla SHALL mostrar la pista del desafío
siguiente, con el mapa sin ningún pin y sin la línea del revelado anterior.
Al pulsar "Ver resultados", la pantalla SHALL volver al camino de niveles.

El revelado SHALL ofrecer además una acción para repetir la animación, que
relance la secuencia completa desde el principio sin volver a llamar al
servidor.

#### Scenario: Avanzar al siguiente desafío

- **WHEN** el jugador está en el revelado del desafío 1 de 3 y pulsa
  "Siguiente"
- **THEN** la pantalla muestra la pista del desafío 2 de 3 y el mapa vuelve
  a no tener ningún pin ni línea

#### Scenario: El revelado no avanza solo

- **WHEN** la secuencia del revelado termina y el jugador no pulsa nada
- **THEN** la pantalla sigue mostrando el resultado, sin avanzar al desafío
  siguiente ni volver al camino

#### Scenario: Revelado del último desafío

- **WHEN** el revelado es el del último desafío del intento
- **THEN** el botón de continuar se rotula "Ver resultados" y pulsarlo
  devuelve al jugador al camino de niveles

#### Scenario: Repetir la animación

- **WHEN** el jugador pulsa la acción de repetir la animación
- **THEN** la secuencia vuelve a correr desde el principio, con los
  contadores otra vez desde 0, sin llamar de nuevo a `responder_desafio` y
  sin alterar el puntaje acumulado del intento
