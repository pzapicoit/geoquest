## 1. La cuenta atrás como pieza propia

- [x] 1.1 Crear `app/lib/screens/cuenta_atras_de_desafio.dart` con
  `CuentaAtrasDeDesafio extends ChangeNotifier`: constructor con `vsync`,
  `ahora` (`DateTime Function()`, por defecto `DateTime.now`) y el aviso
  `alAgotarse`; estado interno de total y deadline (D1, D2, D3).
- [x] 1.2 Implementar `arrancar(Duration total)` —fija deadline y arranca el ticker,
  cancelando cualquier cuenta anterior—, `parar()` y `dispose()` que libera el ticker.
- [x] 1.3 Implementar los derivados: `restante` (acotado a cero), `fraccion` (0-1),
  `segundosParaLaEtiqueta` con `ceil` (D5) y `enZonaCritica` con fracción `< 0.2` o
  `restante < 5 s` como única fuente del umbral rojo (D6).
- [x] 1.4 En cada fotograma: recalcular contra `ahora()`, `notifyListeners()`, y al
  llegar a cero parar el ticker y llamar a `alAgotarse` una sola vez.
- [x] 1.5 Crear `app/test/cuenta_atras_de_desafio_test.dart`: fracción continua entre
  segundos, etiqueta en enteros, zona crítica por fracción y por suelo de 5 s, aviso
  de agotado único, reinicio al arrancar de nuevo, y coherencia con el reloj real
  cuando pasa tiempo sin fotogramas.

## 2. Cuenta atrás continua en la pantalla de juego

- [x] 2.1 Añadir el parámetro inyectable `ahora` a `NivelJuegoScreen` y pasar el
  estado a `TickerProviderStateMixin` (D8).
- [x] 2.2 Sustituir `int _segundosRestantes` + `Timer? _temporizadorDeCuentaAtras`
  por una `CuentaAtrasDeDesafio`; `_arrancarCuentaAtras` la arranca con los segundos
  efectivos y sigue llamando a `marcarDesafioMostrado` igual que ahora.
- [x] 2.3 Borrar `_tick` y enganchar `_alAgotarseElTiempo` al aviso de la pieza, sin
  cambiar su comportamiento (con pin → `_confirmar`, sin pin → `_confirmarSinPin`,
  nada si hay revelado).
- [x] 2.4 Parar la cuenta atrás donde hoy se cancela el timer (confirmar, confirmar
  sin pin, salir) y liberarla en `dispose`.
- [x] 2.5 Pasar la cuenta atrás al HUD como `Listenable` en vez de un entero, y
  envolver la barra en su propio `AnimatedBuilder` para que el fotograma no
  reconstruya el `Stack` de `build` (D4). Mantener que el HUD no la enseña durante el
  revelado.
- [x] 2.6 Reescribir `_CuentaAtras` para leer `fraccion`, `segundosParaLaEtiqueta` y
  `enZonaCritica`, con `_colorDeLaCuentaAtras` apoyado en `enZonaCritica` en vez de
  recalcular el umbral. Conservar las claves
  `nivel-juego-cuenta-atras` y `nivel-juego-cuenta-atras-etiqueta`.

## 3. Marco de tiempo crítico

- [x] 3.1 Añadir el widget del marco con clave `nivel-juego-marco-critico`:
  `Positioned.fill` + `IgnorePointer` + borde rojo de 3 px con sombra interior suave,
  fundido de entrada de 240 ms (D7).
- [x] 3.2 Calcular el latido de opacidad a partir del tiempo restante, sin
  `AnimationController` extra, y dejarlo fijo cuando
  `MediaQuery.of(context).disableAnimations` es `true`.
- [x] 3.3 Insertarlo en el `Stack` de `build` por encima del mapa y por debajo del
  HUD, condicionado a `!revelando && cuentaAtras.enZonaCritica`.

## 4. Doble toque en el mapa

- [x] 4.1 Partir `zoomEn` del controlador en `camaraDeZoomEn(factor, foco)` —que
  devuelve la cámara destino ya acotada— más `aplicarCamara`, sin cambiar el
  comportamiento de pellizco ni de los botones (D11).
- [x] 4.2 Añadir la constante `factorDobleToque = 2` al controlador (D10).
- [x] 4.3 En `_MapaMundiState`: pasar a `SingleTickerProviderStateMixin` y añadir el
  `AnimationController` de 200 ms que interpola de la cámara actual a la destino con
  `Curves.easeOutCubic`.
- [x] 4.4 Detectar el doble toque dentro de `_alTocar`: recordar posición y plazo
  (`kDoubleTapTimeout`) del último toque con un `Timer` que lo olvida, y tratar como
  doble toque el que llegue a menos de 40 px con el recuerdo vivo (D9). El pin se
  sigue colocando en los dos toques (D13).
- [x] 4.5 Interrumpir la animación en `onScaleStart` y cuando `interactivo` pasa a
  `false` en `didUpdateWidget`; liberar controlador y `Timer` en `dispose` (D12).

## 5. Tests

- [x] 5.1 En `app/test/mapa_mundi_controller_test.dart`: `camaraDeZoomEn` mantiene el
  foco quieto, respeta `escalaMaxima` y recorta el desplazamiento en el borde del
  mundo; `zoomEn` sigue pasando sus tests actuales.
- [x] 5.2 En `app/test/mapa_mundi_test.dart`: doble toque acerca sobre el punto y la
  escala recorre valores intermedios; dos toques lejanos o separados en el tiempo no
  acercan; el doble toque en escala máxima no mueve nada; el mapa no interactivo lo
  ignora; un pellizco corta la animación; un toque simple coloca el pin sin esperar
  plazo.
- [x] 5.3 En `app/test/nivel_juego_screen_test.dart`: inyectar
  `ahora: () => tester.binding.clock.now()` en el helper de montaje y adaptar los
  tests que avanzaban el reloj de segundo en segundo.
- [x] 5.4 Reescribir el test de ámbar con 60 s por desafío para sacarlo del filo del
  suelo de 5 s, y añadir uno del suelo (10 s por desafío, quedan 4 → rojo) (D6).
- [x] 5.5 Añadir cobertura de la fracción continua en pantalla (la `value` de la
  barra cambia a mitad de segundo mientras la etiqueta no) y de la coherencia con el
  reloj real tras un salto de tiempo sin fotogramas.
- [x] 5.6 Añadir cobertura del marco: aparece al entrar en zona crítica, no está
  antes, no intercepta el toque que coloca el pin, desaparece al confirmar, al
  agotarse el tiempo y durante el revelado, no vuelve al arrancar el desafío
  siguiente, y se queda fijo con `disableAnimations`.

## 6. Cierre

- [x] 6.1 `flutter analyze` y `dart format` limpios en `app/`.
- [x] 6.2 `flutter test` en verde y cobertura revisada de los ficheros tocados.
- [x] 6.3 Actualizar `.devplugin/architecture.md` con el nuevo modelo de tiempo de la
  cuenta atrás y el gesto de doble toque del mapa.
