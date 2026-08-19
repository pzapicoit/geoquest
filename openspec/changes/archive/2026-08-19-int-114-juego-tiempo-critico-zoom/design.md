## Context

La pantalla de juego (`app/lib/screens/nivel_juego_screen.dart`, 2420 líneas) ya
tiene todas las piezas que hacen falta; lo que hay que cambiar es de dónde sale el
tiempo y qué se dibuja con él.

Estado actual relevante:

- `_arrancarCuentaAtras` monta un `Timer.periodic(1 s)` y `_tick` decrementa el
  entero `_segundosRestantes` con un `setState` de toda la pantalla. La barra
  (`_CuentaAtras`) recibe ese entero y calcula `value = restantes / total`, así que
  solo cambia una vez por segundo.
- `_colorDeLaCuentaAtras` decide teal / ámbar / rojo por fracción (`> 0.5`, `>= 0.2`,
  resto). Ese `< 0.2` es hoy el único aviso de "queda poco".
- El estado usa `SingleTickerProviderStateMixin` para `_coreografia`, el
  `AnimationController` de los cinco tramos del revelado.
- El mapa (`app/lib/mapa/mapa_mundi.dart`) traduce gestos y delega las reglas al
  `MapaMundiController` (D5 de INT-92): `zoomEn(factor, foco)` ya mantiene quieto el
  punto focal, acota a `escalaMaxima` y recorta el desplazamiento. `CamaraMapa` y su
  `interpolar` + `aplicarCamara` son justo lo que INT-93 usa para animar la cámara
  del revelado desde fuera del controlador, que no tiene `vsync`.

Restricciones:

- El cliente no puntúa: `segundos_transcurridos` y el bonus por rapidez los calcula
  el servidor desde `intento_desafios.mostrado_en` (`challenge-timer`). El reloj de
  la pantalla es cosmético y no debe volverse otra fuente de verdad.
- `flutter_test` **no** instala un `withClock` de `package:clock`: su binding expone
  `binding.clock` (reloj de `FakeAsync`, que avanza con `tester.pump`) pero el
  `clock` global de `package:clock` sigue devolviendo la hora real. Verificado en
  `flutter_test/lib/src/binding.dart`. Cualquier deadline basado en el reloj global
  sería intesteable.
- Sin dependencias nuevas.

## Goals / Non-Goals

**Goals:**

- Que el jugador con la vista en el mapa se entere de que se le acaba el tiempo.
- Que la barra de cuenta atrás se mueva como un reloj y no a tirones, y que el tiempo
  restante sea el real aunque se pierdan fotogramas.
- Que el gesto de doble toque acerque sobre el punto tocado sin sacrificar la
  inmediatez de colocar el pin.
- Dejar el modelo de tiempo en una pieza probable por sí sola.

**Non-Goals:**

- Tocar puntuación, RPCs, esquema o bonus por rapidez.
- Doble toque con dos dedos para alejar, y doble toque durante el revelado (el mapa
  ya va con `interactivo: false`).
- Auto-confirmar mientras la app está en segundo plano (ver riesgos).
- Rediseñar el HUD ni la coreografía del revelado.

## Decisions

### D1 — La fuente de tiempo es un instante de fin, no una cuenta de ticks

Al volverse actual un desafío se calcula `_fin = ahora() + segundosPorDesafio` una
sola vez. Lo que queda se deriva siempre como `_fin - ahora()`, acotado a cero. Un
`Ticker` no lleva el tiempo: solo dice "hay fotograma nuevo, recalcula".

Esto arregla los dos síntomas de golpe. La fracción es continua porque se recalcula
por fotograma, y la deriva desaparece porque no se acumula nada: 300 fotogramas
perdidos no cambian el resultado. Alternativa descartada: bajar el `Timer.periodic` a
16 ms —seguiría acumulando error y gastaría timers para nada.

### D2 — El reloj de pared se inyecta

`NivelJuegoScreen` gana un parámetro `ahora` de tipo `DateTime Function()` con
`DateTime.now` por defecto, en la misma línea que los `gateway` y `cargadorDeMundo`
que ya se inyectan para probar. Los tests pasan `() => tester.binding.clock.now()`,
que avanza con `tester.pump`.

Alternativas descartadas:

- `package:clock` global (`clock.now()`): elegante, pero `flutter_test` no lo falsea
  (ver Context), así que los tests medirían tiempo real y el agotamiento no se podría
  provocar.
- Usar el `elapsed` del propio `Ticker` como fuente: es lo que se congela en segundo
  plano, o sea exactamente el bug que hay que arreglar.

### D3 — La cuenta atrás sale a su propia pieza

Nace `app/lib/screens/cuenta_atras_de_desafio.dart` con
`CuentaAtrasDeDesafio extends ChangeNotifier`: guarda total y deadline, se mueve con
un `Ticker` que recibe del `TickerProvider` de la pantalla, y expone `restante`,
`fraccion`, `enZonaCritica` y `arrancar(total)` / `parar()`, más un aviso de agotado.
La pantalla decide qué hacer al agotarse (confirmar con pin o sin pin); la pieza solo
cuenta.

Va en `screens/` junto a la pantalla, como ya están `entry_motion.dart` y
`entry_widgets.dart`, y no en `services/`, que es para lo que sale a la red. Con esto
el modelo de tiempo se prueba llamando a métodos, sin montar la pantalla —el mismo
reparto que `MapaMundiController` frente a `MapaMundi`.

### D4 — Repintar por fotograma, pero solo la barra y el marco

La cuenta atrás ya no vive en un campo del `State` con `setState`: la pantalla pasa
la propia `CuentaAtrasDeDesafio` (un `Listenable`) al HUD, y son la barra y el marco
los que se envuelven en su `AnimatedBuilder`. Un `setState` por fotograma
reconstruiría el `Stack` completo del `build`, incluido el `MapaMundi`, que es lo
caro de esta pantalla.

### D5 — La etiqueta redondea hacia arriba

`formatearCuentaAtras` sigue recibiendo segundos enteros; la pantalla le pasa
`restante.ceil()`. Con `ceil`, un desafío de 60 s enseña "1:00" durante el primer
segundo completo y "0:01" durante el último, que es como cuenta un cronómetro. Con
`floor` el primer segundo ya diría "0:59" y el último "0:00" durante un segundo
entero, con el marco rojo encendido y el jugador convencido de que se colgó.

### D6 — Zona crítica: fracción `< 0.2` **o** menos de 5 s, en una sola función

`bool enZonaCritica` vive en `CuentaAtrasDeDesafio` y de ahí lo consumen tanto el
color de la barra como el marco, para que no puedan desincronizarse. El suelo de 5 s
existe porque con 10 s por desafío una quinta parte son 2 s: el aviso llegaría cuando
ya no hay nada que hacer con él.

La comparación es estricta (`restante < 5 s`), no `<=`. Así el borde no se cruza en
el instante exacto en que un desafío de 25 s toca su quinta parte, y los tests no
quedan colgando de una igualdad de coma flotante. Aun así, el test existente
"pasa a ámbar cuando queda la mitad del tiempo" usa 10 s y comprueba a los 5 s justos
—en el filo del suelo—: se reescribe con 60 s, donde ámbar y suelo no se tocan, y el
suelo pasa a tener su propio test.

### D7 — El marco es un `IgnorePointer` con borde, no un overlay con relleno

`Positioned.fill(IgnorePointer(child: ...))` dentro del `Stack` del `build`, colocado
después del mapa y antes del HUD, con `DecoratedBox` y `Border.all(color: _rojo,
width: 3)` más una sombra interior muy suave para que el canto no se lea como una
línea dura. `IgnorePointer` es lo que garantiza el criterio de que no intercepte
toques.

El fundido de entrada son 240 ms con `AnimatedOpacity`. El latido se calcula del
propio tiempo restante (`0.62 + 0.38 · (0.5 + 0.5·sin(2π·t/1.4 s))`), sin un segundo
`AnimationController`: la cuenta atrás ya repinta cada fotograma, así que el latido
sale gratis y es determinista en tests. Amplitud baja y ciclo lento a propósito —el
juego se ve a pantalla completa y hay gente sensible al flash—, y con
`MediaQuery.of(context).disableAnimations` el marco se queda fijo.

### D8 — La pantalla pasa a `TickerProviderStateMixin`

Hacen falta dos tickers: el de `_coreografia` y el de la cuenta atrás. Es el cambio
mínimo; reutilizar `_coreografia` para contar el tiempo mezclaría dos relojes que se
paran en momentos distintos.

### D9 — El doble toque se detecta en `onTapUp`, sin `DoubleTapGestureRecognizer`

En cuanto se registra `onDoubleTap`, el `TapGestureRecognizer` del mismo
`GestureDetector` deja de poder declararse ganador al levantar el dedo: tiene que
esperar a que el reconocedor de doble toque se rinda, o sea `kDoubleTapTimeout`
(300 ms) de retardo en colocar el pin. Colocar el pin es *la* acción de esta
pantalla y el criterio de aceptación pide que siga sintiéndose inmediata, así que no
entramos en esa arena.

En su lugar, `_alTocar` recuerda el último toque (posición y un `Timer` de
`kDoubleTapTimeout` que lo olvida). Si llega otro toque con el recuerdo vivo y a
menos de 40 px, es doble toque: se coloca el pin como siempre *y además* se lanza el
acercamiento. El pin nunca se retrasa, y el gesto queda como el jugador lo espera —el
pin acaba justo en el punto que quería ver de cerca (D13).

Los 40 px son más ajustados que el `kDoubleTapSlop` (100) del framework a propósito:
el segundo toque mueve el pin, y con 100 px de holgura el pin daría un salto visible
antes de acercar. El plazo, en cambio, sí es la constante del framework, para no
divergir de lo que el sistema considera un doble toque.

Alternativas descartadas: mover el pin a `onTap` y aceptar los 300 ms (rompe el
criterio de inmediatez); un `RawGestureDetector` con un `TapGestureRecognizer` que
gane ansioso (hay que reimplementar la resolución de la arena para ganar lo mismo).

### D10 — El doble toque acerca 2×, no 1.7×

`factorBotonZoom` es 1.7 porque un botón se pulsa varias veces seguidas sin
esfuerzo. Un doble toque es un gesto deliberado de "acércame", y con 1.7 hacen falta
nueve para recorrer el rango hasta 40×. Se añade
`MapaMundiController.factorDobleToque = 2` como constante propia, para poder
retocarla en testing local sin tocar los botones.

### D11 — La cámara destino la calcula el controlador; el widget solo interpola

`zoomEn` se parte en dos: `camaraDeZoomEn(factor, foco)` devuelve la `CamaraMapa`
destino ya acotada (escala a `escalaMaxima`, desplazamiento recortado), y `zoomEn`
pasa a ser esa función más `aplicarCamara`. El widget anima con
`CamaraMapa.interpolar(desde, destino, t)` sobre un `AnimationController` propio.

Así los topes de zoom y el recorte no se duplican en el widget, se respeta que las
reglas viven en el controlador (D5 de INT-92) y el destino queda testeable sin
animación. Nota: `aplicarCamara` acota por abajo con `escalaMinimaDeEncuadre` en vez
de `escalaMinima`, pero al acercar desde un encuadre válido eso nunca actúa.

### D12 — La animación del doble toque se puede interrumpir

200 ms con `Curves.easeOutCubic`. Se detiene en `onScaleStart` (un pellizco manda
sobre una animación en curso) y en `didUpdateWidget` cuando `interactivo` pasa a
`false`: si el jugador confirma con la animación viva, la coreografía del revelado y
la animación del zoom se pelearían por `aplicarCamara`. El controlador se libera en
`dispose`. `_MapaMundiState` pasa a `SingleTickerProviderStateMixin`.

### D13 — El segundo toque del doble toque también coloca pin

No se suprime. Suprimirlo obligaría a retrasar el pin del segundo toque para saber si
había un tercero, y dejaría el pin en el primer punto mientras la cámara se centra en
el segundo. Coincidiendo los dos puntos en 40 px, el resultado visible es "el pin se
queda donde toqué y el mapa se acerca ahí".

## Risks / Trade-offs

- **Sin fotogramas no hay auto-confirmación**: si el tiempo se agota con la app en
  segundo plano, la respuesta vacía no se manda hasta el primer fotograma al volver.
  → Se acepta a propósito. El puntaje no depende de ello: el servidor acota
  `segundos_transcurridos` al límite de la parada, y sin `mostrado_en` lo trata como
  agotado (`challenge-timer`). Meter timers de fondo para adelantar una llamada que
  el servidor va a acotar igual sería complejidad sin premio.
- **Repintado por fotograma en la pantalla más cara del juego** → acotado por D4 a la
  barra y al marco; el mapa ya está detrás de un `RepaintBoundary` y su
  `CustomPaint` no se toca. Los `Text` del HUD que rebotan lo hacen con el mismo
  string, sin relayout de nada más.
- **El latido puede molestar a alguien** → amplitud 0.62–1.0 y ciclo de 1.4 s (nada
  cerca del rango de riesgo de flash), y se apaga con `disableAnimations`. Si en
  testing local sigue resultando inquieto, quitar el latido es borrar un término del
  cálculo de opacidad.
- **Detectar el doble toque a mano puede desviarse del sistema** → el plazo es
  `kDoubleTapTimeout` del framework; solo el slop es propio, y por una razón
  documentada (D9).
- **Tests que avanzan el reloj de segundo en segundo** → dejan de medir el modelo
  viejo pero siguen siendo válidos como escenarios; se adaptan uno a uno, con el de
  ámbar reescrito para salir del filo del suelo de 5 s (D6).
- **El marco tapa 3 px de mapa en el canto** → es donde menos se adivina y el mapa
  se puede arrastrar; a cambio es la única zona que el ojo ve sin dejar de mirar el
  centro.

## Open Questions

- El factor 2× del doble toque y el latido del marco son las dos cosas que hay que
  sentir jugando; las dos están detrás de una constante y un término, por si en
  testing local piden otra cosa.
