## 1. Marco que cabe en la pantalla del móvil

- [x] 1.1 En `_MarcoDeTiempoCritico` (`app/lib/screens/nivel_juego_screen.dart`):
  meter el marco 6 px hacia dentro y darle radio 56 a los dos trazos —el mismo,
  porque comparten rectángulo—, con constantes nombradas y el motivo del margen
  documentado (DD1, DD2).
- [x] 1.2 Subir el trazo del borde de 3 a 4 px y el del halo de 7 a 8 px (DD2).

## 2. El doble toque solo acerca

- [x] 2.1 En `_MapaMundiState` (`app/lib/mapa/mapa_mundi.dart`): recordar el pin
  que había antes del primer toque de una pareja, junto al recuerdo de la
  posición del toque (DD3).
- [x] 2.2 Al confirmarse el doble toque, restaurar ese pin —`colocarPin` si había
  uno, `limpiarPin` si no— antes de lanzar el acercamiento, y no colocar pin en
  el segundo toque.
- [x] 2.3 Limpiar el pin recordado en `_olvidarElToque`, para que no pueda
  resucitar tras un `limpiarPin` de la pantalla al avanzar de desafío (DD4).

## 3. Tests

- [x] 3.1 En `app/test/mapa_mundi_test.dart`: un doble toque sobre un mapa sin pin
  acerca y deja el mapa sin pin.
- [x] 3.2 Un doble toque con un pin ya colocado en otro punto acerca y deja el pin
  donde estaba.
- [x] 3.3 Comprobar que no se rompe lo que ya valía: el toque simple sigue
  colocando pin sin esperar plazo, dos toques lejanos colocan pin en el segundo, y
  dos toques separados en el tiempo también.
- [x] 3.4 Actualizar el test que hoy afirma que el segundo toque deja el pin donde
  se acerca (`el segundo toque deja el pin donde se acerca`), que pasa a afirmar lo
  contrario.
- [x] 3.5 En `app/test/nivel_juego_screen_test.dart`: los dos trazos del marco
  tienen esquinas redondeadas con radio de sobra, el halo no tiene menos radio que
  el borde, el marco no llega al borde del área visible y su trazo es el nuevo.
  Verificado que el test falla con el radio anterior del halo.

## 4. Cierre

- [x] 4.1 `flutter analyze` y `dart format` limpios en `app/`.
- [x] 4.2 `flutter test` en verde y cobertura revisada de los ficheros tocados.
- [x] 4.3 Actualizar en `.devplugin/architecture.md` la nota del doble toque, que
  hoy dice que el pin se coloca en los dos toques.
- [x] 4.4 Al archivar, sincronizar `openspec/specs/app-game-screen/spec.md` y
  `openspec/specs/app-world-map/spec.md` con los requisitos `MODIFIED` de este
  delta.
