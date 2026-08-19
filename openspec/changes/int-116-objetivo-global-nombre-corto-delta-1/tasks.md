## 1. App — mover el nombre del toast al revelado

- [x] 1.1 `_TarjetaDePista` (`nivel_juego_screen.dart`): quitar el bloque que muestra `desafio.nombre`, dejando solo `objetivoGlobal` entre la cabecera y el contenido.
- [x] 1.2 `_LugarRevelado` (`nivel_juego_screen.dart`): añadir `revelado.desafio.nombre` a la tarjeta de revelado, junto al rótulo de ubicación real (`nombre_lugar`) y sus coordenadas.

## 2. Tests

- [x] 2.1 `nivel_juego_screen_test.dart`: sustituir el test "muestra el objetivo global de la temática junto al nombre del desafío..." por uno que confirme que el toast muestra `objetivo_global` pero NO el `nombre` del desafío, para los tres tipos de contenido.
- [x] 2.2 `nivel_juego_screen_test.dart`: añadir/ampliar un test del revelado que confirme que la hoja de resultado muestra `nombre` junto a `nombre_lugar`.

## 3. Verificación

- [x] 3.1 `flutter test`, `flutter analyze`, `dart format --set-exit-if-changed` en verde.
- [ ] 3.2 Comprobación manual pendiente del usuario: jugar un desafío de "Personas de la Historia" o "Películas" y confirmar que la pista no menciona el nombre, y que el revelado sí lo muestra.
