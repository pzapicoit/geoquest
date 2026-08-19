## Why

Tres roces de la pantalla de partida detectados jugando de verdad (INT-114). Con la
vista puesta en el mapa el jugador no ve que se le acaba el tiempo, porque el único
aviso es que una barra de 6 px del HUD cambia de color. La barra además avanza a
saltos de un segundo, que en una pantalla a 60 fps se lee como un tirón, y su reloj
—un `Timer.periodic` que decrementa un entero— deriva y pierde ticks al volver de
segundo plano. Y para mirar de cerca una costa hay que ir a los botones de zoom,
cuando el gesto que todo el mundo prueba primero es el doble toque.

Ninguno de los tres cambia reglas de juego: el bonus por rapidez lo sigue calculando
el servidor desde `mostrado_en` (`challenge-timer`), y el reloj del cliente sigue
siendo presentación.

## What Changes

- **Marco rojo de tiempo crítico.** Un borde rojo fino en todo el canto de la
  pantalla mientras el desafío está en zona crítica: entra con un fundido corto,
  respira muy despacio para que se note en visión periférica y se apaga al
  confirmar, al agotarse el tiempo y durante el revelado. No tapa mapa ni controles
  y no intercepta toques.
- **Zona crítica con suelo de segundos.** El umbral sigue siendo la misma fracción
  `< 0.2` que ya usa el color de la barra, pero se le añade un suelo de 5 s para las
  dificultades cortas, donde una quinta parte son 1-2 s y el aviso no llegaría a
  tiempo de servir. Barra y marco comparten la misma condición, así que siguen
  encendiéndose juntos.
- **Cuenta atrás continua contra un instante de fin.** La fuente de tiempo pasa a ser
  un deadline de reloj de pared más un `Ticker` que recalcula lo que queda en cada
  fotograma: la barra avanza fluida, la etiqueta sigue en segundos enteros, y el
  tiempo restante deja de depender de cuántos ticks se hayan entregado. Volver de
  segundo plano deja el tiempo cuadrado con el reloj real.
- **Doble toque en el mapa para acercar sobre ese punto.** Dos toques seguidos y
  cercanos acercan el mapa 2× animado en ~200 ms manteniendo quieto el punto tocado,
  reutilizando la aritmética de foco que ya tiene el controlador. El primer toque
  sigue colocando el pin al instante: el doble toque se detecta en el propio
  `onTapUp`, sin registrar un reconocedor de doble toque que retrasaría la acción
  principal de la pantalla.
- Sin cambios de backend, de esquema, de RPC ni de puntuación. Sin dependencias
  nuevas.

## Capabilities

### New Capabilities

Ninguna. Los tres cambios afinan comportamiento ya especificado.

### Modified Capabilities
- `app-game-screen`: la cuenta atrás pasa a avanzar de forma continua contra un
  instante de fin (y no a saltos de un segundo acumulados), se define la zona
  crítica de tiempo con su suelo de segundos, y se añade el marco rojo de aviso
  periférico con sus condiciones de apagado.
- `app-world-map`: se añade el doble toque como gesto de acercar sobre el punto
  tocado, y se fija que el toque simple sigue colocando el pin sin esperar a
  descartar un segundo toque.

## Impact

- `app/lib/screens/nivel_juego_screen.dart`: desaparece el `Timer.periodic` de la
  cuenta atrás y el entero `_segundosRestantes`; el HUD recibe la cuenta atrás como
  `Listenable` para que solo repinte la barra por fotograma, y el `Stack` del `build`
  gana el marco crítico.
- `app/lib/screens/cuenta_atras_de_desafio.dart` (nuevo): la cuenta atrás como pieza
  propia —deadline, ticker, fracción, zona crítica, aviso de agotado— para poder
  probar el modelo de tiempo sin montar la pantalla entera.
- `app/lib/mapa/mapa_mundi.dart`: detección del doble toque y animación de cámara del
  acercamiento.
- `app/lib/mapa/mapa_mundi_controller.dart`: el cálculo del encuadre con foco se
  saca a un método que devuelve la cámara destino, para poder animar hacia ella sin
  duplicar la aritmética ni los topes de zoom.
- Tests: `app/test/nivel_juego_screen_test.dart` (los que avanzan el reloj de segundo
  en segundo), `app/test/mapa_mundi_test.dart`,
  `app/test/mapa_mundi_controller_test.dart`, y uno nuevo para la cuenta atrás.
- El reloj de pared se inyecta en la pantalla (como ya se inyectan `gateway` y
  `cargadorDeMundo`) porque `flutter_test` no falsea el reloj global de
  `package:clock`: sin inyección, un deadline no se puede probar con `tester.pump`.
