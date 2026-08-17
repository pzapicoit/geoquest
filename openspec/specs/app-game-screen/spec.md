# app-game-screen Specification

## Purpose

La pantalla donde se juega a GeoQuest. Arranca un intento real del nivel,
enseña la pista de cada desafío, deja adivinar sobre el mapa mundial y manda
la respuesta al servidor, llevando la cuenta del progreso y del puntaje del
intento hasta que el jugador termina o abandona.
## Requirements
### Requirement: Entrar a la pantalla de juego arranca un intento real

Al montarse, la pantalla de juego del nivel SHALL llamar a la RPC
`iniciar_intento_nivel` con el `nivel_id` de la parada tocada, y usar el
`intento_id` y la lista de desafíos de la respuesta para su contenido. La
pantalla SHALL mostrar un estado de carga mientras la llamada está en
curso.

#### Scenario: La pantalla arranca el intento al abrirse

- **WHEN** el jugador toca una parada desbloqueada del camino y se abre la
  pantalla de juego
- **THEN** la app llama a `iniciar_intento_nivel(nivel_id)` y, al recibir
  respuesta, deja de mostrar el estado de carga y muestra la pista del
  primer desafío recibido

#### Scenario: Arrancar el intento falla

- **WHEN** la llamada a `iniciar_intento_nivel` falla (sin red, nivel
  inactivo u otro error)
- **THEN** la pantalla muestra un mensaje de error y una opción para
  reintentar, sin dejar ningún estado de carga colgado

#### Scenario: El intento no tiene desafíos disponibles

- **WHEN** `iniciar_intento_nivel` responde correctamente pero con una
  lista de desafíos vacía
- **THEN** la pantalla muestra un mensaje explicando que el nivel no
  tiene desafíos disponibles, con opción de reintentar, en vez de
  fallar al intentar mostrar un desafío inexistente

### Requirement: Toast de pista muestra el contenido según el tipo de desafío

La pantalla SHALL mostrar el contenido del desafío actual en una tarjeta
superpuesta (toast) sobre un fondo oscurecido, eligiendo qué mostrar según
el campo `tipo` del desafío: una imagen a buen tamaño cuando `tipo` es
`imagen`, un vídeo reproduciéndose cuando `tipo` es `video`, o el texto de
la pregunta en tamaño grande cuando `tipo` es `pregunta_texto`.

El toast SHALL llevar una cabecera que identifique el tipo de pista y su
número dentro del intento, un botón de cerrar en esa cabecera, un pie
explicativo de qué se le pide al jugador, y el botón "Listo, voy a
adivinar". Tocar el fondo oscurecido SHALL cerrar el toast igual que
cualquiera de sus botones de cierre.

#### Scenario: Desafío de tipo imagen

- **WHEN** el desafío actual tiene `tipo = 'imagen'`
- **THEN** el toast muestra `imagen_url` a buen tamaño y no intenta
  reproducir ningún vídeo ni mostrar texto de pregunta

#### Scenario: Desafío de tipo video

- **WHEN** el desafío actual tiene `tipo = 'video'`
- **THEN** el toast reproduce `video_url`

#### Scenario: El video de un desafío no puede reproducirse

- **WHEN** el desafío actual tiene `tipo = 'video'` y la reproducción
  falla al inicializarse (URL rota, sin red)
- **THEN** el toast muestra un aviso de que el vídeo no está disponible,
  en vez de quedarse en una pantalla en negro sin explicación

#### Scenario: Desafío de tipo pregunta de texto

- **WHEN** el desafío actual tiene `tipo = 'pregunta_texto'`
- **THEN** el toast muestra `texto_pregunta` en tamaño grande

#### Scenario: Cabecera del toast según el tipo

- **WHEN** se muestra el toast del tercer desafío de un intento y su `tipo`
  es `video`
- **THEN** la cabecera del toast lo identifica como pista de vídeo y como
  la número 3

#### Scenario: Cerrar tocando el fondo

- **WHEN** el toast está abierto y el jugador toca el fondo oscurecido
  fuera de la tarjeta
- **THEN** el toast se cierra y la pantalla queda en la fase de adivinar

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

### Requirement: Cerrar el toast revela el estado de mapa a pantalla completa

La pantalla SHALL ofrecer un botón para cerrar el toast ("Listo, voy a
adivinar"). Al tocarlo, el toast SHALL dejar de mostrarse y la pantalla
SHALL pasar a la fase de adivinar: el mapa mundial a pantalla completa con
sus controles de zoom, la indicación de qué hacer, el botón "Confirmar" y
el botón de reabrir la pista.

#### Scenario: Cerrar el toast

- **WHEN** el jugador toca "Listo, voy a adivinar"
- **THEN** el toast deja de mostrarse y la pantalla queda en la fase de
  adivinar sobre el mapa a pantalla completa

#### Scenario: Indicación de qué hacer sin pin colocado

- **WHEN** la pantalla está en la fase de adivinar y no hay ningún pin
  colocado
- **THEN** se muestra la indicación de tocar el mapa para colocar el pin

#### Scenario: Indicación con pin colocado

- **WHEN** hay un pin colocado
- **THEN** la indicación pasa a decir que se puede tocar para ajustarlo y
  muestra las coordenadas del pin en grados con su hemisferio

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

El encuadre de los dos pines SHALL ser el más cercano que los deje a ambos
dentro del área útil. Cuanto más acertada sea la respuesta, más de cerca
SHALL quedar el mapa, hasta el tope de acercar: dos pines separados por unas
decenas de kilómetros SHALL verse como dos pines distintos, no como uno solo.

Que los dos pines se vean SHALL tener prioridad sobre cualquier otra regla de
encuadre: con una respuesta tan lejana que no quepa en el encuadre de juego,
el revelado SHALL alejar por debajo de él lo justo para mostrar los dos,
aunque eso deje franjas de fondo mientras dura.

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

#### Scenario: Una respuesta muy acertada acerca el mapa

- **WHEN** el pin del jugador y la ubicación real distan unas decenas de
  kilómetros
- **THEN** la cámara acerca hasta el tope y los dos pines se ven separados en
  pantalla, en vez de quedarse en un encuadre donde se solapan

#### Scenario: Una respuesta muy lejana enseña igualmente los dos pines

- **WHEN** el pin del jugador y la ubicación real están en extremos opuestos
  del mundo, tan separados que no caben en el encuadre con el que se juega
- **THEN** el encuadre aleja por debajo de ese encuadre lo justo para que los
  dos pines queden visibles, y el jugador ve ambos aunque aparezcan franjas
  de fondo

#### Scenario: El encuadre alejado no sobrevive al desafío

- **WHEN** el jugador avanza al desafío siguiente desde un revelado que había
  alejado por debajo del encuadre de juego
- **THEN** el mapa vuelve al encuadre de partida, con el mundo cubriendo el
  área visible

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

### Requirement: Reabrir la pista del desafío actual

En la fase de adivinar, la pantalla SHALL ofrecer un botón flotante para
volver a abrir el toast de la pista del desafío actual. Reabrir la pista
SHALL conservar el pin ya colocado y el encuadre del mapa.

#### Scenario: Reabrir la pista

- **WHEN** el jugador toca el botón de ver la pista
- **THEN** vuelve a mostrarse el toast con el contenido del desafío actual

#### Scenario: Reabrir la pista no pierde el pin

- **WHEN** el jugador coloca un pin, reabre la pista y la cierra otra vez
- **THEN** el pin sigue colocado en el mismo sitio y "Confirmar" sigue
  habilitado

### Requirement: Salir del nivel pide confirmación

La pantalla SHALL ofrecer un botón de salir (X), visible en todo momento.
Pulsarlo SHALL abrir un aviso que explique que se pierde el intento
completo, incluidos los puntos ya conseguidos, con una opción de seguir
jugando y otra de salir. Solo la opción de salir SHALL abandonar la
pantalla y volver al camino de niveles.

#### Scenario: Pedir salir y arrepentirse

- **WHEN** el jugador pulsa la X y luego elige seguir jugando
- **THEN** el aviso se cierra y la pantalla sigue en el mismo desafío, con
  el pin y el puntaje intactos

#### Scenario: Salir y perder el intento

- **WHEN** el jugador pulsa la X y confirma que quiere salir
- **THEN** la pantalla vuelve al camino de niveles

#### Scenario: El aviso dice cuántos puntos se pierden

- **WHEN** el jugador lleva 1200 puntos acumulados en el intento y pulsa
  la X
- **THEN** el aviso menciona esos 1200 puntos como lo que va a perder

