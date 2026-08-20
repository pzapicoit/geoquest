## MODIFIED Requirements

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

El área útil SHALL ser la parte del mapa que el HUD y la hoja de resultado no
tapan: la franja que el encuadre reserva abajo SHALL cubrir la altura que la
hoja ocupa de verdad, incluido lo que crece por la barra inferior del sistema,
sin pasarse mucho. Si se queda corta, el encuadre puede dejar un pin detrás
del borde de la hoja; si sobra, aleja el mapa sin motivo.

Sobre el mapa, la pantalla SHALL mostrar una hoja de resultado con: una
miniatura de la pista original del desafío, el `nombre` del desafío junto
al rótulo de ubicación real, la distancia recorrida entre el pin del jugador
y el lugar real, y los puntos ganados en este desafío.

El rótulo de ubicación real SHALL mostrar la **ciudad** del objetivo, no el
lugar exacto: la hoja da una sola línea a ese texto, y `nombre_lugar` llega a
ser tan largo (`Parque de bomberos Hook & Ladder 8, Tribeca, Nueva York`) que
lo que se corta es precisamente dónde estaba. Cuando el desafío no tenga
ciudad registrada, el rótulo SHALL caer a `nombre_lugar`, que es el
comportamiento anterior. El mismo texto —ciudad, o `nombre_lugar` como
respaldo— SHALL rotular el pin de la ubicación real sobre el mapa, para que
mapa y hoja no nombren el sitio de dos maneras distintas.

La hoja de resultado SHALL quedarse en esa información: NO SHALL mostrar las
coordenadas del lugar real ni el máximo de puntos alcanzable, porque ninguno
de los dos hace falta para leer el resultado y ambos restan mapa visible.

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

#### Scenario: La franja reservada para la hoja cubre la hoja

- **WHEN** se muestra el revelado de una respuesta con pin colocado, con el
  desglose de puntaje visible (el caso en que la hoja es más alta)
- **THEN** la hoja de resultado cabe entera en la franja inferior que el
  encuadre reserva para ella, y la franja no es mucho más alta que la hoja

#### Scenario: Nombre del desafío y ciudad del objetivo

- **WHEN** se muestra el revelado de un desafío cuyo `nombre` es
  "Ghostbusters", cuyo `nombre_lugar` es "Parque de bomberos Hook & Ladder 8,
  Tribeca, Nueva York" y cuya `ciudad` es "Nueva York"
- **THEN** la hoja de resultado muestra "Ghostbusters" junto al rótulo de
  ubicación real "Nueva York", sin el lugar exacto ni las coordenadas

#### Scenario: Un desafío sin ciudad registrada cae al lugar exacto

- **WHEN** se muestra el revelado de un desafío cuya `ciudad` es `null` y
  cuyo `nombre_lugar` es "Naufragio del Titanic"
- **THEN** el rótulo de ubicación real muestra "Naufragio del Titanic", sin
  hueco vacío ni texto de relleno

#### Scenario: El pin real se rotula igual que la hoja

- **WHEN** se muestra el revelado de un desafío cuya `ciudad` es "Nueva York"
- **THEN** el rótulo del pin de la ubicación real sobre el mapa muestra
  también "Nueva York", el mismo texto que el rótulo de la hoja

#### Scenario: Los puntos se muestran sin el máximo alcanzable

- **WHEN** el servidor devuelve 520 puntos y un máximo alcanzable de 5000
- **THEN** la hoja de resultado muestra los 520 puntos ganados y ninguna
  referencia a ese máximo

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
