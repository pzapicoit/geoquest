# app-game-screen Specification

## Purpose

La pantalla donde se juega a GeoQuest. Arranca un intento real del nivel,
enseña la pista de cada desafío, deja adivinar sobre el mapa mundial y manda
la respuesta al servidor, llevando la cuenta del progreso y del puntaje del
intento hasta que el jugador termina o abandona.
## Requirements
### Requirement: Entrar a la pantalla de juego arranca un intento real

Al montarse, la pantalla de juego de la parada SHALL llamar a la RPC
`iniciar_intento_parada` con el `camino_id` de la parada tocada, y usar el
`intento_id` y la lista de desafíos de la respuesta para su contenido. La
pantalla SHALL mostrar un estado de carga mientras la llamada está en
curso.

#### Scenario: La pantalla arranca el intento al abrirse

- **WHEN** el jugador toca una parada desbloqueada del camino y se abre la
  pantalla de juego
- **THEN** la app llama a `iniciar_intento_parada(camino_id)` y, al recibir
  respuesta, deja de mostrar el estado de carga y muestra la pista del
  primer desafío recibido

#### Scenario: Arrancar el intento falla

- **WHEN** la llamada a `iniciar_intento_parada` falla (sin red, parada
  inactiva u otro error)
- **THEN** la pantalla muestra un mensaje de error y una opción para
  reintentar, sin dejar ningún estado de carga colgado

#### Scenario: El intento no tiene desafíos disponibles

- **WHEN** `iniciar_intento_parada` responde correctamente pero con una
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

#### Scenario: Repetir la animación

- **WHEN** el jugador pulsa la acción de repetir la animación
- **THEN** la secuencia vuelve a correr desde el principio, con los
  contadores otra vez desde 0, sin llamar de nuevo a `responder_desafio` ni
  a `cerrar_intento_parada`, y sin alterar el puntaje acumulado del intento

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

### Requirement: Cuenta atrás visible durante la fase de adivinar
La pantalla SHALL mostrar, en la capa fija del HUD, una barra de cuenta
atrás con etiqueta `m:ss` para el desafío actual, inicializada al
`segundos_por_desafio` efectivo de la parada en curso (override propio, o
el de `dificultad_defaults` para su dificultad si no tiene override). La
barra SHALL marcar el desafío como mostrado (RPC `marcar_desafio_mostrado`)
en el instante en que se vuelve el actual —al arrancar el intento para el
primero, al pulsar "Siguiente" para los demás— y SHALL seguir corriendo con
el toast de pista abierto, igual que el resto del HUD. La barra SHALL
mostrarse en teal mientras quede más de la mitad del tiempo, en ámbar entre
la mitad y la zona crítica, y en rojo dentro de la zona crítica. Al
avanzar a un desafío nuevo, la cuenta atrás SHALL reiniciarse a los
segundos completos efectivos de la parada.

El tiempo restante SHALL derivarse del instante de fin del desafío
—calculado una vez, al volverse el actual, como el momento en que arrancó
más los segundos efectivos de la parada— y no de acumular avisos
periódicos. El relleno de la barra SHALL actualizarse en cada fotograma,
de modo que cambie también entre un segundo y el siguiente, mientras que la
etiqueta SHALL seguir mostrando segundos enteros. Cuando dejen de
entregarse fotogramas (la app pasa a segundo plano) y vuelvan a entregarse,
el tiempo restante SHALL corresponder al tiempo real transcurrido, no al
número de fotogramas o avisos perdidos.

El desafío SHALL considerarse en **zona crítica** de tiempo cuando quede
menos de una quinta parte de los segundos efectivos de la parada o menos de
5 segundos, lo que ocurra antes. La barra y el marco de aviso periférico
SHALL usar esta misma condición, para que no haya dos umbrales rojos
distintos.

Nada de esto cambia el cálculo del tiempo transcurrido ni del bonus por
rapidez, que siguen siendo del servidor: el reloj del cliente es
presentación.

#### Scenario: La cuenta atrás arranca con el desafío
- **WHEN** se muestra el primer desafío de un intento en una parada cuyo
  `segundos_por_desafio` efectivo es 60
- **THEN** la barra muestra "1:00" en teal y llama a
  `marcar_desafio_mostrado` para ese desafío

#### Scenario: La cuenta atrás cambia de color al bajar el tiempo
- **WHEN** quedan menos de la mitad de los segundos efectivos de la parada
- **THEN** la barra pasa a ámbar

#### Scenario: La cuenta atrás se pone roja cerca del final
- **WHEN** el desafío entra en zona crítica de tiempo
- **THEN** la barra pasa a rojo

#### Scenario: Zona crítica en una dificultad de pocos segundos
- **WHEN** una parada tiene 10 segundos efectivos por desafío y quedan 4
- **THEN** la barra está en rojo, aunque quede más de una quinta parte del
  tiempo, porque el suelo de 5 segundos manda

#### Scenario: La barra avanza entre un segundo y el siguiente
- **WHEN** pasa medio segundo desde el último segundo entero
- **THEN** el relleno de la barra ha cambiado respecto al del segundo
  entero anterior

#### Scenario: La etiqueta no cambia dentro del mismo segundo
- **WHEN** pasa medio segundo desde el último segundo entero
- **THEN** la etiqueta sigue mostrando el mismo `m:ss`

#### Scenario: Volver de segundo plano no regala tiempo
- **WHEN** transcurren 8 segundos de reloj real sin que se entregue ningún
  fotograma y luego se entrega uno, en un desafío de 60 segundos
- **THEN** el tiempo restante es 52 segundos, no 60

#### Scenario: La cuenta atrás sigue corriendo con la pista abierta
- **WHEN** el jugador tiene el toast de pista abierto
- **THEN** la cuenta atrás sigue descontando, visible por encima del toast

#### Scenario: Avanzar a un desafío nuevo reinicia la cuenta atrás
- **WHEN** el jugador pulsa "Siguiente" desde el revelado y pasa al
  desafío siguiente
- **THEN** la cuenta atrás vuelve a mostrar los segundos completos
  efectivos de la parada y llama a `marcar_desafio_mostrado` para el nuevo
  desafío

### Requirement: Comportamiento al agotar el tiempo
Cuando la cuenta atrás llega a 0 con un pin colocado, la pantalla SHALL
disparar la misma acción que "Confirmar" automáticamente, sin necesitar que
el jugador toque nada. Cuando llega a 0 sin ningún pin colocado, la
pantalla SHALL llamar a `responder_desafio` sin coordenadas y entrar en el
revelado del desafío con 0 puntos. En ese revelado sin pin, la pantalla
SHALL mostrar únicamente la ubicación real y los puntos (0), sin pin del
jugador, sin línea entre pines y sin contador de distancia.

#### Scenario: El tiempo se agota con un pin ya colocado
- **WHEN** la cuenta atrás llega a 0 y el jugador ya había colocado un pin
- **THEN** la pantalla envía esas coordenadas a `responder_desafio` igual
  que si el jugador hubiera pulsado "Confirmar", y entra en el revelado

#### Scenario: El tiempo se agota sin ningún pin colocado
- **WHEN** la cuenta atrás llega a 0 y no hay ningún pin colocado
- **THEN** la pantalla llama a `responder_desafio` sin coordenadas y entra
  en el revelado de ese desafío con 0 puntos

#### Scenario: El revelado sin pin no muestra distancia
- **WHEN** se muestra el revelado de un desafío respondido sin pin
- **THEN** la hoja de resultado muestra la ubicación real y 0 puntos, sin
  pin del jugador, sin línea y sin ninguna cifra de distancia

#### Scenario: Agotar el tiempo en el último desafío del intento
- **WHEN** el tiempo se agota (con o sin pin) en el último desafío del
  intento
- **THEN** el botón del revelado sigue rotulado "Ver resultados", igual
  que en cualquier otro revelado del último desafío

### Requirement: El revelado muestra el desglose del bonus por rapidez
La hoja de resultado del revelado SHALL mostrar, cuando corresponde a una
respuesta con pin colocado, el puntaje de precisión y, si es mayor que 0,
el bonus por rapidez por separado (p. ej. "+80 por rapidez"), además del
total. Cuando el bonus es 0, la hoja SHALL mostrar solo el puntaje de
precisión, sin una línea de bonus vacía o en cero.

#### Scenario: El revelado muestra un bonus por rapidez positivo
- **WHEN** se muestra el revelado de una respuesta con pin colocado cuyo
  `puntos_bonus` es mayor que 0
- **THEN** la hoja de resultado muestra el puntaje de precisión y una línea
  de bonus con el valor de `puntos_bonus`, además del total

#### Scenario: El revelado no muestra una línea de bonus si no hubo bonus
- **WHEN** se muestra el revelado de una respuesta con pin colocado cuyo
  `puntos_bonus` es 0 (tiempo agotado o respuesta en el suelo de precisión)
- **THEN** la hoja de resultado muestra el puntaje de precisión sin ninguna
  línea de bonus

### Requirement: Marco de aviso al entrar en tiempo crítico
La pantalla SHALL mostrar, mientras el desafío actual esté en zona crítica
de tiempo, un borde rojo fino siguiendo el contorno de la pantalla, por
encima del mapa y por debajo del HUD. El borde SHALL tener las esquinas
redondeadas y SHALL quedar metido unos píxeles hacia dentro del área
visible, de modo que ningún tramo suyo caiga fuera de la esquina
redondeada del dispositivo y quede cortado, sea cual sea el radio de esa
esquina. El grosor SHALL ser el suficiente para verse con el mapa a
pantalla completa sin dejar de leerse como un borde.

El marco SHALL aparecer con un fundido corto al cruzar el umbral, SHALL ser
incapaz de recibir toques —el mapa y los controles que queden debajo siguen
respondiendo con normalidad— y SHALL desaparecer al confirmar la respuesta,
al agotarse el tiempo y mientras haya un revelado en pantalla.

El movimiento del marco SHALL limitarse a un latido de opacidad lento y de
poca amplitud, nunca un parpadeo, y SHALL suprimirse cuando el sistema pida
reducir animaciones, dejando el marco fijo.

#### Scenario: El tiempo entra en zona crítica
- **WHEN** al desafío actual le queda menos de una quinta parte de su
  tiempo (o menos de 5 segundos)
- **THEN** aparece el marco rojo en el canto de la pantalla, a la vez que
  la barra del HUD se pone roja

#### Scenario: El marco no se corta en las esquinas del dispositivo
- **WHEN** hay marco en pantalla
- **THEN** su contorno es redondeado y no llega a tocar el borde del área
  visible, así que cabe entero dentro de una pantalla con esquinas
  redondeadas

#### Scenario: Con tiempo de sobra no hay marco
- **WHEN** al desafío actual le queda más de una quinta parte de su tiempo
  y más de 5 segundos
- **THEN** no hay ningún marco en pantalla

#### Scenario: El marco no se come los toques
- **WHEN** el desafío está en zona crítica y el jugador toca el mapa en un
  punto que cae sobre el marco
- **THEN** el mapa coloca el pin en ese punto igual que sin marco

#### Scenario: Confirmar apaga el marco
- **WHEN** el desafío está en zona crítica y el jugador confirma su
  respuesta
- **THEN** el marco desaparece y no vuelve durante el revelado

#### Scenario: Agotarse el tiempo apaga el marco
- **WHEN** la cuenta atrás del desafío llega a 0
- **THEN** el marco desaparece junto con la barra de cuenta atrás

#### Scenario: El desafío siguiente arranca sin marco
- **WHEN** el jugador avanza desde el revelado a un desafío nuevo
- **THEN** la cuenta atrás vuelve a los segundos completos y no hay marco
  hasta que ese desafío entre en zona crítica

#### Scenario: Sistema con animaciones reducidas
- **WHEN** el sistema pide reducir animaciones y el desafío entra en zona
  crítica
- **THEN** el marco se muestra fijo, sin latido de opacidad

### Requirement: Bandeja de comodines sobre el mapa

La pantalla de juego SHALL mostrar una bandeja de comodines plegada por defecto sobre el mapa, que se despliega en una fila con los 4 tipos y su cantidad al tocarla, y se repliega al tocarla de nuevo o tocar fuera.

#### Scenario: La bandeja empieza plegada

- **WHEN** se entra en la fase de adivinar de un desafío
- **THEN** la bandeja de comodines se muestra plegada (solo una pestaña visible)

#### Scenario: Se despliega la bandeja

- **WHEN** el jugador toca la pestaña plegada
- **THEN** la bandeja se despliega mostrando los 4 tipos con su cantidad actual

### Requirement: Estado de cada comodín en la bandeja

Cada comodín de la bandeja SHALL mostrarse deshabilitado cuando no quede inventario de ese tipo o cuando ya se haya usado un comodín en el intento en curso. Para el tipo `pais`, cuya disponibilidad depende de un dato del desafío (`desafios.pais`) que el cliente no conoce hasta consumir el comodín, la falta de dato SHALL resolverse como un rechazo normal al tocarlo (sin descontar inventario ni marcar el intento), no como un deshabilitado previo.

#### Scenario: Comodín sin inventario

- **WHEN** el jugador no tiene unidades de un tipo de comodín
- **THEN** ese comodín se muestra atenuado y no se puede tocar

#### Scenario: Ya se usó un comodín en este intento

- **WHEN** el jugador ya consumió un comodín (de cualquier tipo) en el intento en curso
- **THEN** el resto de comodines se muestran deshabilitados para el resto de desafíos de ese intento, aunque tengan inventario

#### Scenario: Comodín país sin dato disponible

- **WHEN** el jugador toca el comodín `pais` en un desafío que no tiene país registrado
- **THEN** el sistema rechaza el consumo con un aviso claro, sin descontar inventario ni marcar el intento como comodín-usado
- **AND** el icono no se muestra deshabilitado de antemano, porque el cliente no puede saber la disponibilidad hasta tocarlo

### Requirement: Overlay de radio en el mapa

Al consumir un comodín `km1000` o `km500`, el mapa SHALL dibujar un círculo centrado en la posición real del objetivo con el radio correspondiente.

#### Scenario: Se consume un comodín de radio

- **WHEN** el jugador consume `km1000` o `km500` con éxito
- **THEN** el mapa dibuja un círculo del radio correspondiente centrado en la posición real del objetivo, visible mientras el jugador sigue en la fase de adivinar de ese desafío

