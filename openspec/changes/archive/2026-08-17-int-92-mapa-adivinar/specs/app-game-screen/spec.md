## MODIFIED Requirements

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
el mapa, visible tanto en la fase de adivinar como con el toast de pista
abierto. Esa capa SHALL contener el progreso dentro del intento actual como
"Desafío X de N" (X = posición del desafío mostrado, N = total de desafíos
del intento), el nombre del nivel que se está jugando, una barra segmentada
con un segmento por desafío del intento que distinga los ya respondidos,
el actual y los pendientes, y el puntaje acumulado del intento.

El puntaje mostrado SHALL ser la suma de los puntos devueltos por el
servidor para los desafíos ya respondidos en este intento.

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

## ADDED Requirements

### Requirement: Confirmar envía la respuesta y avanza al siguiente desafío

La pantalla SHALL mostrar un botón "Confirmar" deshabilitado mientras no
haya pin colocado. Al pulsarlo, SHALL enviar las coordenadas del pin a la
RPC `responder_desafio` con el `intento_id` del intento en curso y el `id`
del desafío actual, sumar al puntaje del intento los puntos que devuelva
el servidor, y pasar al siguiente desafío mostrando su pista con el pin
del mapa vacío.

Mientras la llamada está en curso, el botón SHALL quedar deshabilitado
para no enviar la misma respuesta dos veces.

Tras responder el último desafío del intento, la pantalla SHALL volver al
camino de niveles.

#### Scenario: Confirmar sin pin

- **WHEN** la pantalla está en la fase de adivinar y no hay pin colocado
- **THEN** el botón "Confirmar" está deshabilitado y pulsarlo no llama a
  `responder_desafio`

#### Scenario: Confirmar con pin

- **WHEN** hay un pin colocado y el jugador pulsa "Confirmar"
- **THEN** se llama a `responder_desafio` con el intento en curso, el
  desafío actual y las coordenadas del pin

#### Scenario: Avanzar al siguiente desafío

- **WHEN** el jugador confirma el desafío 1 de 3 y el servidor devuelve
  1200 puntos
- **THEN** el puntaje del intento pasa a 1200, la pantalla muestra la
  pista del desafío 2 de 3, y el mapa vuelve a no tener ningún pin

#### Scenario: Confirmar el último desafío

- **WHEN** el jugador confirma el último desafío del intento
- **THEN** la pantalla vuelve al camino de niveles

#### Scenario: Enviar la respuesta falla

- **WHEN** la llamada a `responder_desafio` falla (sin red, error del
  servidor)
- **THEN** la pantalla avisa del fallo, conserva el pin colocado y vuelve
  a habilitar "Confirmar" para reintentar, sin avanzar de desafío ni
  cambiar el puntaje

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
