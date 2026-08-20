## Context

`comodines_screen.dart` ya tiene todo el cableado del lado servidor listo desde INT-119: `ComodinesGateway.concederComodinPorAnuncio()`, manejo de `ComodinRechazadoException`/`MotivoRechazoComodin.topeDiarioAlcanzado`, refresco del inventario al volver de la hoja. Lo único que falta es el propio SDK — que ya existe en el repo desde INT-117, pero solo se usó para `RewardedInterstitialAd` (gating automático antes de un intento). `AnunciosGateway`/`AdMobAnunciosGateway` (`app/lib/services/anuncios_gateway.dart`) es el sitio natural para añadir la carga/muestra de anuncios bajo demanda, siguiendo la misma separación ya establecida: `AnunciosGateway` sabe de AdMob, `ComodinesGateway` solo sabe del RPC.

## Goals / Non-Goals

**Goals:**
- Activar de verdad el botón "Ver un anuncio" con un `RewardedAd` real, sin tocar el resto de la hoja "Obtener más" (canjear puntos/pack explorador siguen sin acción).
- Solo conceder el comodín si el jugador de verdad ganó la recompensa (`onUserEarnedReward`), nunca por una carga fallida ni por cerrar el anuncio antes de tiempo.
- Tope diario de 4/día, sin cambiar la lógica ya existente de `conceder_comodin_por_anuncio` (tabla `comodines_concesiones_anuncio`, tipo aleatorio uniforme).

**Non-Goals:**
- Verificación server-side (SSV) del visionado — sigue fuera de alcance, igual que decidió INT-119 (D6 de su design.md): se confía en que la app solo llama al RPC tras el callback de recompensa.
- Cambiar el criterio de "1 comodín por intento" ni ningún otro requirement de `comodines` no relacionado con la obtención por anuncio.

## Decisions

**D1 — `RewardedAd`, no `RewardedInterstitialAd`, para este flujo.** La distinción de formato de AdMob no es solo naming: `RewardedInterstitialAd` está pensado para que la app decida cuándo interrumpir (un punto de transición, como entrar a una parada — INT-117 original), mientras que `RewardedAd` es el formato para cuando el jugador elige explícitamente "quiero ver un anuncio a cambio de algo" tocando un botón. Usar el formato equivocado aquí no rompería nada a nivel de código (la API es casi idéntica), pero sí sería un mal uso deliberado del SDK — se corrige desde el diseño, no como una nota de estilo.

**D2 — Nuevo método en `AdMobAnunciosGateway`, no en `ComodinesGateway`.** `Future<bool> mostrarParaRecompensa()`: carga un `RewardedAd` con timeout (reutiliza el mismo patrón de `_cargarConTimeout` de INT-117, adaptado al tipo `RewardedAd`/`RewardedAdLoadCallback`), lo muestra si carga, y devuelve `true` solo si `onUserEarnedReward` llegó a dispararse antes de que el anuncio se cerrara. `ComodinesScreen` orquesta: si `mostrarParaRecompensa()` devuelve `true`, llama a `ComodinesGateway.concederComodinPorAnuncio()`; si devuelve `false` (no cargó, falló, se cerró sin recompensa), muestra un aviso y no toca el servidor. Mantiene la separación ya existente: ningún gateway mezcla RPC con SDK de anuncios.

**D3 — Sin fail-open aquí: un fallo de carga es un error visible, no una razón para seguir sin hacer nada.** A diferencia del gating de INT-117 (donde "no bloquear al jugador" es la prioridad), aquí no hay nada que "dejar pasar": si el anuncio no carga, simplemente no hay recompensa que conceder. `_verAnuncio` muestra el mismo tipo de aviso que ya usa para otros rechazos (`_error`), invitando a reintentar, en vez de fingir éxito.

**D4 — El `AnunciosGateway` de `CaminoScreen` se reenvía a `ComodinesScreen`, no se crea uno nuevo.** Mismo patrón que `comodinesGateway`/`nivelJuegoGateway`: `CaminoScreen._onTapComodines` ya tiene `_anunciosGateway` construido (o inyectado en tests); se le pasa a `ComodinesScreen` en vez de que esta construya su propio `AdMobAnunciosGateway`.

**D5 — Tope diario 4/día como default de la función, no como literal en el cliente.** `conceder_comodin_por_anuncio(p_tope_diario integer default 4)`: el cliente sigue llamando sin argumentos (`ComodinesGateway.concederComodinPorAnuncio()` no cambia su firma), el número vive en un solo sitio, igual que el resto de configuración de umbrales de este esquema (`dificultad_defaults`, etc.).

## Risks / Trade-offs

- **[Riesgo] Sin SSV, un cliente modificado podría reportar `onUserEarnedReward` sin haberlo visto realmente.** → Ya aceptado en INT-119 (D6): el tope diario bajo (4) limita el daño; no es una pared, es una v1 deliberadamente simple, igual que el resto de esta capability.
- **[Trade-off] Dos formatos de anuncio distintos en la misma app (`RewardedInterstitialAd` para gating, `RewardedAd` para bajo demanda) añaden algo de superficie al gateway.** Se acepta porque es la forma correcta de usar el SDK para cada caso, no una complejidad accidental.

## Migration Plan

1. Migración de esquema: `create or replace function conceder_comodin_por_anuncio(p_tope_diario integer default 4) ...` (mismo cuerpo, solo cambia el default).
2. App: `AdMobAnunciosGateway.mostrarParaRecompensa()` (carga/muestra `RewardedAd` con timeout, devuelve si se ganó la recompensa).
3. App: `ComodinesScreen`/`_HojaObtenerMas` reciben `AnunciosGateway`, se retira `anuncioDisponible` fijo, `_verAnuncio` llama a `mostrarParaRecompensa()` antes de `concederComodinPorAnuncio()`.
4. `CaminoScreen._onTapComodines` reenvía su `_anunciosGateway` a `ComodinesScreen`.
5. Sin cambios destructivos: todo aditivo o un default distinto. Rollback = volver el default a 5 y/o revertir el flag de la app.

## Open Questions

Ninguna pendiente: el tope (4) y el formato (`RewardedAd`) ya están decididos para este delta.
