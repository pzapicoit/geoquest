## MODIFIED Requirements

### Requirement: Toast de pista muestra el contenido según el tipo de desafío

La pantalla SHALL mostrar el contenido del desafío actual en una tarjeta
superpuesta (toast) sobre un fondo oscurecido, eligiendo qué mostrar según
el campo `tipo` del desafío: una imagen a buen tamaño cuando `tipo` es
`imagen`, un vídeo reproduciéndose cuando `tipo` es `video`, o el texto de
la pregunta en tamaño grande cuando `tipo` es `pregunta_texto`.

El toast SHALL llevar una cabecera que identifique el tipo de pista y su
número dentro del intento, un botón de cerrar en esa cabecera, el
`objetivo_global` de la temática de la parada, un pie explicativo de qué
se le pide al jugador, y el botón "Listo, voy a adivinar". El toast SHALL
NOT mostrar el `nombre` del desafío — revelaría la respuesta antes de que
el jugador adivine; `nombre` se muestra en la tarjeta de revelado (ver
`El revelado muestra el resultado del desafío respondido`). Tocar el fondo
oscurecido SHALL cerrar el toast igual que cualquiera de sus botones de
cierre.

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

#### Scenario: El toast muestra el objetivo global de la temática, sin el nombre del desafío

- **WHEN** se muestra el toast de un desafío cuyo `nombre` es "Torre
  Eiffel" en una parada cuya temática tiene `objetivo_global = '¿Dónde
  está este monumento?'`
- **THEN** el toast muestra ese `objetivo_global`, para cualquiera de los
  tres tipos de contenido (imagen, vídeo o pregunta de texto), sin
  mostrar en ningún sitio el texto "Torre Eiffel"

#### Scenario: Cerrar tocando el fondo

- **WHEN** el toast está abierto y el jugador toca el fondo oscurecido
  fuera de la tarjeta
- **THEN** el toast se cierra y la pantalla queda en la fase de adivinar

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
miniatura de la pista original del desafío, el `nombre` del desafío junto
al rótulo de ubicación real con el `nombre_lugar` y sus coordenadas, la
distancia recorrida entre el pin del jugador y el lugar real, y los puntos
ganados en este desafío junto al máximo alcanzable.

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

#### Scenario: Nombre del desafío, lugar real y coordenadas

- **WHEN** se muestra el revelado de un desafío cuyo `nombre` es "Charles
  Darwin" y cuyo lugar real es "Shrewsbury, Inglaterra"
- **THEN** la hoja de resultado muestra "Charles Darwin" junto al rótulo de
  ubicación real "Shrewsbury, Inglaterra" y sus coordenadas en grados con
  su hemisferio

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
