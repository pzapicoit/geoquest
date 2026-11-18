## 1. Cierre de sesión tolerante

- [x] 1.1 Añadir a `FakeAuthGateway` un modo de `signOut` que limpie la sesión antes de lanzar (como `gotrue`), sin romper el modo actual
- [x] 1.2 Tests en rojo en `player_session_service_test.dart`: entrar como invitado, crear jugador, cambiar de jugador y descartar jugador completan aunque `signOut` lance tras soltar la sesión local
- [x] 1.3 Test: si `signOut` lanza y la sesión local sigue viva, se mantiene el fallo y no se crea sesión ni se olvida el apodo
- [x] 1.4 Implementar `_cerrarSesionLocal()` en `PlayerSessionService` y usarlo en `_sesionRecienCreada`, `cambiarDeJugador` y `descartarJugador`

## 2. Motivo legible en el splash

- [x] 2.1 Añadir `CausaFalloSesion` y el campo `detalle` a `AnonymousSessionFailure`, y clasificar el error en `AnonymousSessionService.ensureSession`
- [x] 2.2 Tests de clasificación en `anonymous_session_service_test.dart`: `AuthException` 5xx → servidor; `ClientException` / `AuthRetryableFetchException` / timeout → sinRespuesta; resto → otra
- [x] 2.3 Splash: elegir el texto según la causa, sin excepción ni URL en pantalla, y `debugPrint` del detalle
- [x] 2.4 Test de widget en `splash_screen_test.dart`: con un fallo de red se ve el texto legible y no el de la excepción; «Reintentar» sigue funcionando

## 3. Cierre

- [x] 3.1 `flutter analyze`, `dart format` y `flutter test` en verde
- [x] 3.2 Prueba manual en web: con la sesión de invitado activa, simular el fallo de `/logout` y comprobar que la entrada como invitado sigue
  - Hecha el 2026-11-18 con `flutter run -d web-server` y Chrome DevTools, en un contexto de navegador limpio. Un script de inicio sustituye `window.fetch` para que `POST /auth/v1/logout` devuelva `500 {"code":"unexpected_failure"}`. Con la sesión anónima creada por el splash, «Entrar sin cuenta como invitado» llamó una vez a `/logout` (500 simulado) y siguió: `POST /auth/v1/signup` 200, `PATCH profiles` 204 y llegada al camino con el invitado «CazaAtlas». Sin el cambio, el mismo 500 real del 2026-11-18 terminó en «No se pudo completar la entrada».
