---
type: scope
parent: int-117-publicidad-video-admob
reason: al probar en local, Pablo pide activar ya la obtención de comodines por vídeo bajo demanda (ComodinesScreen, deshabilitada desde INT-119 esperando esta integración) con tope diario de 4, en vez de dejarla para una historia futura como decía el proposal original de INT-117.
---

## Why

INT-119 dejó el botón "Ver un anuncio" de `ComodinesScreen` deshabilitado a propósito (`anuncioDisponible = false`), documentando explícitamente que se activaría cuando INT-117 integrase el SDK de AdMob. Con el SDK ya integrado y probado en local, tiene sentido cerrar ese cabo suelto en el mismo ciclo en vez de abrir una historia nueva para un cambio de una línea (el flag) más el flujo real de carga/recompensa.

## What Changes

- Se activa `anuncioDisponible` (pasa a depender de si hay un `RewardedAd` cargado, no de una constante fija): el botón "Ver un anuncio" de la hoja "Obtener más comodines" deja de mostrar "próximamente" y dispara un anuncio real.
- Nuevo método en `AnunciosGateway`/`AdMobAnunciosGateway` para este flujo bajo demanda, usando **`RewardedAd`** — no `RewardedInterstitialAd` (el formato de los anuncios de gating de INT-117): un `RewardedAd` es el formato correcto de AdMob cuando es el propio jugador quien elige ver un anuncio a cambio de algo, en vez de un punto de transición automático de la app.
- `ComodinesGateway.concederComodinPorAnuncio()` solo se llama si el anuncio realmente carga, se muestra y el jugador gana la recompensa (`onUserEarnedReward`) — si no carga o no se completa, se avisa y no se toca el servidor, igual que la salvaguarda que ya documentaba INT-119 para "no conceder un comodín por un anuncio que nunca se vio".
- Tope diario de concesiones por anuncio: **4/día** (bajaba de un default de 5 sin usar todavía, porque nada llamaba a esta vía hasta ahora).

## Capabilities

### Modified Capabilities
- `comodines`: la vía de obtención por vídeo pasa de "no disponible" a real, con tope diario fijado en 4.
- `video-ads`: nuevo requisito sobre el formato correcto (`RewardedAd`) para flujos bajo demanda, distinto del `RewardedInterstitialAd` de los anuncios de gating.

## Impact

- **Backend:** migración que cambia el default de `conceder_comodin_por_anuncio` de 5 a 4 (sin cambiar su firma ni su lógica).
- **App:** `AnunciosGateway` gana un método para cargar/mostrar `RewardedAd` y devolver si se ganó la recompensa; `ComodinesScreen`/`_HojaObtenerMas` reciben ese gateway (reenviado desde `CaminoScreen`, mismo patrón que `comodinesGateway`) y lo usan en `_verAnuncio`; se retira el flag fijo `anuncioDisponible = false`.
