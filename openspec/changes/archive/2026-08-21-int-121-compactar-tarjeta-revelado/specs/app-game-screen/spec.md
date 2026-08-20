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
al rótulo de ubicación real con el `nombre_lugar`, la distancia recorrida
entre el pin del jugador y el lugar real, y los puntos ganados en este
desafío.

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

#### Scenario: Nombre del desafío y lugar real

- **WHEN** se muestra el revelado de un desafío cuyo `nombre` es "Charles
  Darwin" y cuyo lugar real es "Shrewsbury, Inglaterra"
- **THEN** la hoja de resultado muestra "Charles Darwin" junto al rótulo de
  ubicación real "Shrewsbury, Inglaterra", sin las coordenadas del lugar

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

### Requirement: Avanzar desde el revelado es un acto del jugador

El revelado SHALL ofrecer un botón que continúe la partida, rotulado
"Siguiente" cuando queden desafíos por jugar y "Ver resultados" cuando el
revelado sea el del último desafío del intento. Solo pulsarlo SHALL sacar
al jugador del revelado.

Al pulsar "Siguiente", la pantalla SHALL mostrar la pista del desafío
siguiente, con el mapa sin ningún pin y sin la línea del revelado
anterior. Al pulsar "Ver resultados", la pantalla SHALL cerrar el intento
(`cerrar_intento_parada`) y, al recibir el resultado, navegar a la pantalla
de resumen del nivel en vez de volver directamente al camino de niveles.
Mientras esa llamada está en curso, "Ver resultados" SHALL quedar
deshabilitado para no cerrar el mismo intento dos veces; si falla, la
pantalla SHALL avisar del fallo y conservar el revelado en pantalla para
reintentar.

Ese botón SHALL ser la única acción de la hoja de resultado: bajo él no
SHALL haber ninguna otra, para no gastar altura de hoja en algo que no sea
seguir jugando.

#### Scenario: Avanzar al siguiente desafío

- **WHEN** el jugador está en el revelado del desafío 1 de 3 y pulsa
  "Siguiente"
- **THEN** la pantalla muestra la pista del desafío 2 de 3 y el mapa vuelve
  a no tener ningún pin ni línea

#### Scenario: El revelado no avanza solo

- **WHEN** la secuencia del revelado termina y el jugador no pulsa nada
- **THEN** la pantalla sigue mostrando el resultado, sin avanzar al desafío
  siguiente ni cerrar el intento

#### Scenario: Revelado del último desafío cierra el intento

- **WHEN** el revelado es el del último desafío del intento y el jugador
  pulsa "Ver resultados"
- **THEN** la pantalla llama a `cerrar_intento_parada` con ese intento y,
  al recibir el resultado, navega a la pantalla de resumen del nivel

#### Scenario: Cerrar el intento falla al pulsar "Ver resultados"

- **WHEN** la llamada a `cerrar_intento_parada` disparada por "Ver
  resultados" falla
- **THEN** la pantalla avisa del fallo, mantiene el revelado del último
  desafío en pantalla y vuelve a habilitar "Ver resultados"

#### Scenario: El revelado no ofrece repetir la animación

- **WHEN** se muestra el revelado, con o sin pin colocado
- **THEN** bajo el botón de continuar no hay ninguna acción para relanzar la
  secuencia del revelado

### Requirement: El revelado muestra el desglose del bonus por rapidez
La hoja de resultado del revelado SHALL mostrar, cuando corresponde a una
respuesta con pin colocado, el puntaje de precisión y, si es mayor que 0,
el bonus por rapidez por separado (p. ej. "+80 por rapidez"), además del
total. Cuando el bonus es 0, la hoja SHALL mostrar solo el puntaje de
precisión, sin una línea de bonus vacía o en cero.

Precisión y bonus SHALL compartir una misma línea, distinguibles entre sí,
en vez de ocupar dos líneas apiladas. Si con el tamaño de fuente del sistema
no caben en una línea, SHALL replegarse a dos antes que recortar cualquiera
de los dos textos.

#### Scenario: El revelado muestra un bonus por rapidez positivo
- **WHEN** se muestra el revelado de una respuesta con pin colocado cuyo
  `puntos_bonus` es mayor que 0
- **THEN** la hoja de resultado muestra, en una sola línea, el puntaje de
  precisión y el valor de `puntos_bonus` como bonus por rapidez, además del
  total

#### Scenario: El revelado no muestra una línea de bonus si no hubo bonus
- **WHEN** se muestra el revelado de una respuesta con pin colocado cuyo
  `puntos_bonus` es 0 (tiempo agotado o respuesta en el suelo de precisión)
- **THEN** la hoja de resultado muestra el puntaje de precisión sin ninguna
  línea de bonus
