## Why

Jugando en un iPhone real aparecen tres fallos de la cámara del mapa que
comparten causa: los límites de zoom se fijaron en INT-92 pensando en el
mockup, no en la mano de un jugador.

- Alejando se puede encoger el mundo hasta que deja de cubrir la pantalla y
  asoman franjas del color de fondo arriba y abajo. El mapa se ve *cortado*.
- El tope de acercar (14× la escala inicial, ~3,4 km por píxel) se queda
  corto para afinar un pin, y arrastra al revelado: dos pines separados por
  pocos kilómetros salen encimados porque el encuadre choca contra ese tope.
- En el extremo contrario, dos pines en continentes distintos dan un encuadre
  que ya es el mínimo, así que la cámara no se mueve y la animación del
  revelado —que es la recompensa de la jugada— no se percibe.

A esto se suma que la app rota a apaisado, un modo para el que no hay ningún
diseño y que además vuelve inestable la garantía de que el mundo cubra la
altura, porque la altura cambia de eje.

Van juntos porque son la misma decisión —la pantalla es vertical y el mapa
siempre la cubre; dentro de eso el zoom llega más lejos— y porque los tres
límites viven en las mismas constantes de `MapaMundiController`: tocarlos por
separado sería invalidar tres veces el mismo suite de tests.

## What Changes

- La app se fija en orientación vertical en las tres capas que deciden
  (Flutter, iOS, Android). **BREAKING** para el uso en apaisado, que hasta
  ahora se permitía sin estar diseñado.
- El tope de alejar pasa de "el mundo entero cabe en pantalla" a "el mundo
  cubre el área visible". Deja de haber una escala a la que se vea fondo.
  Como consecuencia, el encuadre inicial y el tope de alejar pasan a ser el
  mismo valor.
- El tope de acercar sube por encima del 14× actual, hasta donde el detalle
  del asset 50m lo justifique.
- El encuadre automático de dos coordenadas garantiza un acercamiento
  perceptible en el revelado, tanto con los pines juntos como con los pines
  en extremos opuestos del mundo. La animación en sí no cambia: cambia el
  encuadre al que lleva.
- Los encuadres calculados —los que impone la pantalla con el mapa cerrado a
  gestos— conservan el suelo viejo, más bajo, para poder enseñar los dos
  pines aunque la respuesta sea casi antipodal. El jugador no puede alcanzar
  ese suelo con el dedo.

## Capabilities

### New Capabilities

- `app-orientation`: la app se presenta siempre en vertical, en cualquier
  pantalla y en las dos plataformas.

### Modified Capabilities

- `app-world-map`: el requisito "Encuadre inicial y límites de zoom" cambia
  el tope de alejar (cubrir el área visible, no ver el mundo entero) y el de
  acercar. El requisito "El desplazamiento no deja salir del mundo" pierde el
  caso de mundo más pequeño que el área visible, que deja de ser alcanzable.
  El requisito "Encuadre automático de varias coordenadas con márgenes"
  añade la garantía de acercamiento perceptible.
- `app-game-screen`: el requisito "El revelado muestra el resultado del
  desafío respondido" concreta que el encuadre de los dos pines siempre
  acerca de forma visible.

## Impact

- `app/lib/mapa/mapa_mundi_controller.dart`: `escalaMinima`, `escalaInicial`,
  `factorZoomMaximo` y `camaraPara`. Es el grueso del cambio.
- `app/lib/main.dart`, `app/ios/Runner/Info.plist`,
  `app/android/app/src/main/AndroidManifest.xml`: bloqueo de orientación.
- `app/test/mapa_mundi_controller_test.dart` y `app/test/mapa_mundi_test.dart`:
  los tests que hoy afirman los límites viejos cambian de expectativa.
- Sin impacto en backend ni en panel. Ningún dato persistido cambia.
- No arregla del todo el "mapa cortado": la Antártida aplastada contra el
  borde inferior por el recorte de la proyección es otra causa, y se trata en
  INT-103 junto al render en dispositivo. Este cambio elimina las franjas.
