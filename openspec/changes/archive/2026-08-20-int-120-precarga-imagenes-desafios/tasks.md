## 1. Precarga en la pantalla de juego

- [x] 1.1 Añadir a `NivelJuegoScreen` el parámetro opcional
      `precargarImagen` (`Future<void> Function(BuildContext, String)?`), con
      el comentario de por qué es inyectable, siguiendo el estilo de
      `gateway`/`ahora` (D6 de `design.md`).
- [x] 1.2 En `_NivelJuegoScreenState`, resolver el mecanismo real por defecto:
      `precacheImage(NetworkImage(url), context, onError: (_, _) {})`, con el
      comentario de que `onError` es obligatorio porque sin él el fallo va a
      `FlutterError.reportError` (D4) y de que el provider tiene que ser
      `NetworkImage(url)` a pelo para compartir clave de caché con
      `Image.network` (D5).
- [x] 1.3 Implementar `_precargarImagenesDelIntento(IntentoNivel)`: recorre
      `intento.desafios` en orden, se queda con los de
      `tipo == TipoDesafio.imagen` y `imagenUrl` no nula ni vacía (D8), y
      precarga de una en una con `await` (D2), comprobando `mounted` antes de
      cada iteración (D7) y con `try/catch` por llamada que no aborta el bucle
      (D4).
- [x] 1.4 Llamar a `_precargarImagenesDelIntento` desde `_alCargarElIntento`,
      después de `_arrancarCuentaAtras`, sin `await` (fire-and-forget) para no
      retrasar nada de la partida (D1).
- [x] 1.5 Dejar `_PistaImagen` y `_MiniaturaDeLaPista` intactos, con un
      comentario en `_PistaImagen` avisando de que su provider tiene que
      seguir siendo `Image.network(url)` sin `cacheWidth` para que la precarga
      acierte en caché (D5).

## 2. Tests

- [x] 2.1 Añadir al harness de `nivel_juego_screen_test.dart` la inyección de
      `precargarImagen` en `_appConCamino`, con un recolector de URLs.
- [x] 2.2 Test: un intento con varios desafíos de imagen precarga todas sus
      URLs, en orden de juego, incluida la del primero.
- [x] 2.3 Test: los desafíos de vídeo y de pregunta de texto no generan
      ninguna precarga.
- [x] 2.4 Test: con la precarga colgada sin resolver, la pista del primer
      desafío ya está visible y la partida es jugable (no bloquea).
- [x] 2.5 Test: si la precarga de una URL falla (la función inyectada lanza),
      no se rompe la partida, no aparece mensaje de error y se siguen
      precargando las URLs de los demás desafíos.
- [x] 2.6 Test: salir del nivel con precargas pendientes no provoca error ni
      `setState` tras `dispose` (la precarga que resuelve después es inocua).
- [x] 2.7 Guardar la coincidencia de clave de caché con una aserción sobre el
      provider real del widget —`imagen.image == NetworkImage(url)` en la
      pista y en la miniatura del revelado— en vez de un grep del fuente: un
      `cacheWidth`/`cacheHeight` envolvería el provider en un `ResizeImage` y
      la aserción lo caza (verificación de D5).
- [x] 2.8 Test extra: sin inyectar nada corre la precarga real, y su `onError`
      vacío evita que el fallo inevitable de red en `flutter_test` llegue a
      `FlutterError.reportError` (cubre D4 y la implementación por defecto).

## 3. Verificación y cierre

- [x] 3.1 `flutter analyze` y `dart format` limpios en `app/`.
- [x] 3.2 `flutter test` completo en verde (toda la suite, no solo el fichero
      tocado).
- [x] 3.3 Cobertura de las líneas nuevas de `nivel_juego_screen.dart`.
- [ ] 3.4 Prueba en dispositivo con red lenta (throttling): los desafíos de
      imagen posteriores al primero aparecen sin salto de carga.
