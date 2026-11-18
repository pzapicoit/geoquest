## Context

`PlayerSessionService` llama a `AuthGateway.signOut()` en tres sitios:

- `_sesionRecienCreada`, que usan `entrarComoInvitado` y `_crearJugador`;
- `cambiarDeJugador`;
- `descartarJugador`.

La implementación real delega en `GoTrueClient.signOut()` (`gotrue` 2.27.2, la versión del `pubspec.lock`,
`gotrue_client.dart:1078-1110`). Ese método:

1. borra la sesión local y avisa a los suscriptores con `signedOut`;
2. llama a `POST /logout`;
3. ignora 401/403/404 y **relanza cualquier otro error**, sea un 5xx o un fallo
   de red.

Así que cuando la app ve la excepción, el dispositivo ya no tiene sesión. Tratar
eso como «no se pudo cerrar» es un falso negativo: rompe la entrada como
invitado y deja «cambiar de jugador» a medias.

En la pantalla de carga, `AnonymousSessionService` construye
`AnonymousSessionFailure('No se pudo iniciar sesión: $error')`, y el splash pinta
ese texto tal cual.

## Goals / Non-Goals

**Goals:**
- Que un error del servidor en `/logout` no bloquee ningún flujo cuando la
  sesión local ya se ha soltado.
- Que el splash muestre un motivo legible y clasificado.

**Non-Goals:**
- Reintentar `/logout` en el servidor. Una sesión remota huérfana caduca sola
  con su token y no da acceso a nada desde este dispositivo.
- Cambiar los mensajes de error de la pantalla de apodo (`EntradaFallida`). Tras
  este cambio, ese mensaje deja de aparecer en el caso que motivó la issue.
- Distinguir en web «sin red» de «servidor caído sin respuesta». El navegador
  devuelve el mismo `Failed to fetch` en ambos casos (un 521 de Cloudflare
  llega sin cabeceras CORS), así que el mensaje cubre los dos con honestidad.

## Decisions

**D1. La tolerancia vive en `PlayerSessionService`, no en el gateway.**
Un helper privado `_cerrarSesionLocal()` hace `await _auth.signOut()`. Solo
captura `AuthException`, porque `gotrue` envuelve en ese tipo tanto la respuesta
de `/logout` como el fallo de red. Cualquier otra excepción se propaga sin más.
Con un `AuthException`, mira `_auth.currentSession`: si es `null`, registra el
error con `dart:developer` y sigue; si no, lo relanza. Los tres puntos de uso
pasan a usarlo.
- *Alternativa:* hacerlo en `SupabaseAuthGateway.signOut`. Se descarta porque el
  gateway envuelve un `GoTrueClient` real y no se puede probar sin red, mientras
  que el servicio ya se prueba con `FakeAuthGateway`. Además, la regla («la
  verdad es el estado local») es una decisión de producto del flujo de sesión,
  no un detalle del SDK.
- *Alternativa:* `signOut(scope: SignOutScope.local)` sin llamada remota. No
  existe en `gotrue`: el scope local también llama a `/logout`.

**D2. El falso modela el comportamiento real del SDK.**
`FakeAuthGateway.signOut` gana un modo que primero limpia la sesión y después
lanza, como hace `gotrue`, además del modo actual (lanza sin tocar la sesión).
Sin esto, los tests no reproducirían el bug.

**D3. `AnonymousSessionFailure` lleva una causa clasificada.**
Un enum `CausaFalloSesion { sinRespuesta, servidor, otra }` más el `detalle`
técnico. El texto visible lo elige el splash a partir de la causa, así que la
redacción vive en la UI y el servicio no compone frases.

Desde el alta anónima, `gotrue` envuelve **todo** fallo del cliente HTTP en
`AuthRetryableFetchException` (`fetch.dart:188-190`): sin código si no hubo
respuesta, y con código si el servidor contestó 5xx (`fetch.dart:47-53`).
Clasificación:
- `AuthException` con `statusCode` ≥ 500 → `servidor`;
- `AuthRetryableFetchException` sin código → `sinRespuesta`;
- `ClientException` y `TimeoutException` sin envolver → `sinRespuesta`. Es
  defensivo: con `gotrue` 2.27 no llegan así;
- cualquier otro error → `otra`.

## Risks / Trade-offs

- [Tragar un error real] → Solo se toleran `AuthException`, y solo si la sesión
  local ya es `null`, que es justo el estado que buscaba la operación. Con
  `gotrue` 2.27 la sesión local siempre es `null` cuando `signOut` lanza (la
  suelta antes de cualquier punto que pueda fallar), así que la rama «sesión
  viva → relanzar» es **defensiva**: no se alcanza con el SDK actual y protege
  ante uno que cambie el orden. Los tests la ejercitan con el falso.
- [Sesión persistida en disco] → `supabase_flutter` 2.17 borra la sesión
  guardada en un listener asíncrono de `onAuthStateChange`, y si ese borrado
  falla solo lo registra. En ese caso, tras reiniciar la app podría restaurarse
  la sesión del jugador anterior con el apodo ya olvidado. Es preexistente y
  ajeno al error de `/logout`; este cambio no lo empeora en el camino normal.
- [Sesión remota huérfana] → Si `/logout` falla, el refresh token sigue vivo en
  el servidor hasta caducar. No da acceso desde este dispositivo, que ya no lo
  tiene.
- [Clasificar por tipo de excepción del SDK] → Si `gotrue` cambia sus tipos, la
  causa cae en `otra`, que tiene un mensaje genérico correcto. No hay regresión
  peor que la de hoy.
- [Cambio de API de `AnonymousSessionFailure`] → Solo lo consumen el splash y sus
  tests; se actualizan en el mismo cambio.
