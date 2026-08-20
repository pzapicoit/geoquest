## Why

GeoQuest no tiene ninguna vía de monetización hoy. Se introduce publicidad en vídeo (AdMob Rewarded Interstitial) en dos puntos de enganche — desbloqueo de una parada nueva y cadencia cada 3 intentos — sin bloquear nunca al jugador si el anuncio no carga, y sin tocar la experiencia de las primeras paradas ni el marco de tiempo crítico ya cuidado (INT-114).

## What Changes

- Nueva capability `video-ads`: lógica de servidor que decide, antes de arrancar un intento, si toca anuncio de desbloqueo (primera vez en una parada de `orden > 1`), anuncio de cadencia (cada 3 intentos jugados, contador persistente de por vida) o ninguno, aplicando la regla de no-solape (si coinciden, se muestra un único vídeo con prioridad para el de desbloqueo y el ciclo de cadencia no se consume).
- Integración de `google_mobile_ads` en la app: carga y muestra un `RewardedInterstitialAd` antes de iniciar un intento cuando toque, con **fail-open** — si el anuncio no carga (sin fill o sin conexión), se deja jugar sin bloquear ni reintentar.
- Configuración de IDs de AdMob (App ID y unidad de anuncio) inyectada igual que el resto de configuración sensible (`dart_define.json`, gitignorado), con los IDs de prueba oficiales de Google como valor de la plantilla `dart_define.example.json` hasta que exista cuenta de AdMob real.
- **Modified Capability** `challenge-play`: la RPC `iniciar_intento_parada` gana el efecto colateral de actualizar, dentro de la misma transacción que crea el intento, el contador de cadencia del jugador (incrementa o resetea a 0, salvo en el caso de no-solape con el desbloqueo, donde queda intacto).
- **Modified Capability** `game-data-model`: nueva columna de contador persistente en `profiles` y nuevo catálogo cerrado (enum) para el tipo de anuncio pendiente.

Fuera de alcance de esta historia (ya delimitado en la descripción de INT-117): comodines obtenidos por vídeo recompensado bajo demanda del jugador — esa vía ya existe como stub deshabilitado desde INT-119 (`comodines`) y se activará en una historia futura reutilizando el SDK que aquí se integra.

## Capabilities

### New Capabilities
- `video-ads`: decisión de cuándo mostrar un anuncio antes de un intento (desbloqueo / cadencia / ninguno), integración del SDK de AdMob en la app y manejo fail-open de fallo de carga.

### Modified Capabilities
- `challenge-play`: `iniciar_intento_parada` pasa a actualizar el contador de cadencia del jugador como parte de su transacción.
- `game-data-model`: `profiles` gana un contador persistente de intentos desde el último anuncio de cadencia; nuevo enum de catálogo cerrado para el tipo de anuncio pendiente.

## Impact

- **Backend:** migración de esquema (columna en `profiles`, enum nuevo), RPC nueva de solo lectura `anuncio_debido(p_camino_id)`, modificación de `iniciar_intento_parada`.
- **App:** dependencia `google_mobile_ads`, `GADApplicationIdentifier`/entradas SKAdNetwork en `Info.plist` (iOS primero), nuevo punto de enganche antes de navegar a la pantalla de juego, `dart_define.json`/`dart_define.example.json` con IDs de AdMob (test IDs de Google por defecto).
- **Fuera de alcance de código:** alta de cuenta AdMob, registro de la app (App ID iOS real) y perfil de pagos en la consola — administrativo, no bloquea esta implementación porque se desarrolla y prueba con los ad unit IDs de prueba de Google.
