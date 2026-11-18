## Why

«Entrar sin cuenta como invitado» falla cuando el servidor devuelve un error al
cerrar la sesión anterior. Pasó el 2026-11-18, al reactivar Supabase:
`POST /auth/v1/logout?scope=local` respondió 500 y el jugador vio «Comprueba tu
conexión», con la conexión funcionando.

El SDK (`gotrue` 2.27) borra la sesión local **antes** de llamar al servidor y
después relanza cualquier error que no sea 401/403/404. La app interpreta esa
excepción como «no se pudo cerrar la sesión» y aborta, aunque en el dispositivo
la sesión ya esté cerrada.

En «cambiar de jugador» el efecto es peor: la operación devuelve fallo, pero la
sesión ya no existe y el apodo guardado sigue ahí. La app queda incoherente.

Además, la pantalla de carga enseña al jugador la excepción cruda
(`ClientException: Failed to fetch, uri=https://…/auth/v1/signup?`).

## What Changes

- Cerrar la sesión local deja de depender de que el servidor responda bien. Si
  el SDK lanza un error pero la sesión local ya no existe, la operación se da
  por buena y el flujo continúa. Afecta a:
  - entrar como invitado;
  - crear jugador con apodo y contraseña;
  - cambiar de jugador;
  - descartar un jugador sin contraseña.
- Si tras el error la sesión local **sigue** existiendo, se mantiene el fallo
  actual.
- El fallo al crear la sesión en la pantalla de carga muestra un texto para
  personas, según la causa:
  - la petición no llegó al servidor (sin red, o servidor caído sin respuesta);
  - el servidor respondió con un error 5xx;
  - cualquier otro error.

  El detalle técnico se conserva para el registro de depuración, pero no se
  enseña.

## Capabilities

### New Capabilities

Ninguna.

### Modified Capabilities

- `player-anonymous-auth`: nuevo requisito. Cerrar la sesión local no falla por
  un error del servidor si la sesión ya se ha soltado en el dispositivo.
- `app-splash`: el requisito «Reintento cuando falla la resolución de la sesión»
  pasa a exigir un motivo legible y clasificado, nunca la excepción cruda.

## Impact

- `app/lib/services/player_session_service.dart`: cierre de sesión tolerante,
  usado por `_sesionRecienCreada`, `cambiarDeJugador` y `descartarJugador`.
- `app/lib/services/anonymous_session_service.dart`: `AnonymousSessionFailure`
  pasa a llevar una causa clasificada y el detalle técnico por separado.
- `app/lib/screens/splash_screen.dart`: la tarjeta de error muestra el texto de
  la causa.
- Tests: `test/player_session_service_test.dart`,
  `test/anonymous_session_service_test.dart`, `test/splash_screen_test.dart` y
  el falso `test/fakes/fake_auth_gateway.dart`.
- No cambian el backend, las migraciones ni las dependencias.
