## Context

`iniciar_intento_parada(p_camino_id uuid)` (`challenge-play`) es la única puerta de entrada a una partida: crea el `intento_nivel`, sortea y persiste la selección de desafíos (`intento_desafios`) y responde en una sola llamada. No existe hoy ningún punto de la app entre "el jugador toca una parada" y esa llamada — `camino_screen.dart` navega directo a la pantalla de juego, que dispara `iniciar_intento_parada` en su `initState`.

`profiles` es la única tabla con una fila por jugador que ya sobrevive a reinstalar la app / cambiar de dispositivo (es la misma fila de `auth.users`, ver `game-data-model`); comodines (INT-119) usó una tabla aparte porque necesitaba 4 filas por catálogo, no 1 contador simple.

No existe ninguna cuenta de AdMob todavía (alta pendiente, fuera de alcance de código de esta historia). Google publica IDs de test fijos y estables para `RewardedInterstitialAd` en iOS que sirven para desarrollar y probar sin cuenta real.

## Goals / Non-Goals

**Goals:**
- Determinar server-side, sin estado nuevo por parte del cliente, si toca anuncio de desbloqueo, de cadencia, o ninguno, antes de que la app arranque un intento.
- Aplicar la regla de no-solape (prioridad desbloqueo, ciclo de cadencia no gastado) de forma atómica junto con la creación del intento, no como dos pasos que puedan desincronizarse.
- Integrar `google_mobile_ads` con fail-open real: cualquier fallo de carga dentro de un timeout deja jugar sin bloquear.
- Dejar el código listo para producción sin depender de que la cuenta AdMob ya exista (IDs de test por defecto, mismos que `dart_define.example.json` ya usa para otras claves).

**Non-Goals:**
- Verificación server-side (SSV) de que el anuncio se mostró de verdad — no se necesita: el servidor no concede ninguna recompensa por ver este anuncio (a diferencia del comodín-por-vídeo de INT-119), solo dosifica cuándo se ofrece; un cliente modificado que se lo salte no gana nada que no tuviera ya.
- Activar la vía de comodín-por-vídeo-bajo-demanda (INT-119, hoy deshabilitada) — se deja para una historia futura que reutilice el SDK aquí integrado.
- Alta de cuenta AdMob, App ID real, unidades de anuncio de producción y perfil de pagos — gestión de cuenta externa, no código.
- Anuncios en Android — el proyecto sigue "iOS primero" (architecture.md); se deja la dependencia multiplataforma pero sin configurar `AndroidManifest.xml` todavía.

## Decisions

**D1 — Contador de cadencia como columna en `profiles`, no tabla aparte.** `profiles` gana `intentos_desde_ultimo_anuncio_cadencia integer not null default 0`. A diferencia de comodines (4 tipos, tabla `(usuario_id, tipo)`), aquí hay un único contador por jugador: una columna es la representación mínima y ya vive en la tabla que sobrevive a reinstalar/cambiar de dispositivo.

**D2 — Un enum de catálogo cerrado para el tipo de anuncio pendiente.** `create type tipo_anuncio_pendiente as enum ('ninguno', 'desbloqueo', 'cadencia')`, igual que `tipo_comodin` en INT-119. Alternativa descartada: devolver texto libre o un booleano — el enum documenta el catálogo cerrado en el esquema mismo y da un tipo Dart claro tras el codegen.

**D3 — RPC de solo lectura `anuncio_debido(p_camino_id uuid)` separada de `iniciar_intento_parada`.** El anuncio debe mostrarse *antes* de arrancar el intento, así que la app necesita preguntar sin efectos secundarios, mostrar el vídeo (o fallar rápido), y solo entonces llamar a `iniciar_intento_parada`. `anuncio_debido` es `SECURITY INVOKER` (las policies ya vigentes de `intentos_nivel`/`profiles`/`camino` bastan, igual que el resto de RPCs de lectura de `challenge-play`) y calcula:
  - `es_desbloqueo`: `camino.orden > 1` para `p_camino_id` **y** no existe ninguna fila en `intentos_nivel` para `(auth.uid(), p_camino_id)` — sin flag nuevo, tal como pedía la historia.
  - `es_cadencia`: `profiles.intentos_desde_ultimo_anuncio_cadencia + 1 >= 3` para el usuario actual.
  - Devuelve `'desbloqueo'` si `es_desbloqueo` (prioridad, D5), si no `'cadencia'` si `es_cadencia`, si no `'ninguno'`.

**D4 — `iniciar_intento_parada` recalcula la misma lógica dentro de su propia transacción para mutar el contador, en vez de confiar en lo que la app reporte.** No se añade un parámetro "ya mostré el anuncio": `iniciar_intento_parada` repite el cálculo de D3 (en el mismo `plpgsql`, antes de insertar `intentos_nivel`) y aplica la mutación:
  - Si `es_desbloqueo` (con o sin solape de cadencia): el contador de cadencia **no se toca**.
  - Si no hay desbloqueo y `es_cadencia`: el contador se resetea a `0`.
  - Si no hay desbloqueo ni cadencia: el contador se incrementa en 1.

  Esto implementa la regla de no-solape (punto 3 de la historia) sin ningún flag de "ciclo gastado": cuando desbloqueo y cadencia coinciden, el contador queda exactamente igual que estaba, así que la próxima vez que ese jugador juegue cualquier parada, `es_cadencia` vuelve a ser cierto de inmediato — el ciclo pendiente no se pierde, solo se pospone una partida. Al recalcularse en la misma llamada que crea el intento (una única función `plpgsql`, una sola transacción), no hay ventana de carrera entre "consultar" y "consumir" distinta de la que ya asume el resto de RPCs de este esquema.

**D5 — Prioridad fija: desbloqueo gana sobre cadencia, nunca los dos vídeos.** Se decide explícitamente no encolar un segundo anuncio tras el primero — la historia pide "un único vídeo" en el solape, y mostrar dos anuncios seguidos antes de una parada nueva es la clase de fricción que esta historia busca evitar en "las primeras paradas… la parte más sensible para retener a un jugador nuevo".

**D6 — Fail-open con timeout, sin reintento.** La app pide la carga del `RewardedInterstitialAd` con un timeout corto (propuesta: 5 s) desde que se decide que toca anuncio. Si carga a tiempo, se muestra (con su salida/skip nativo de Google) y, al cerrarse (`onAdDismissedFullScreenContent`, se haya "ganado" el reward o no — aquí no se concede ninguno, D-Non-Goals), se llama a `iniciar_intento_parada`. Si no carga a tiempo o `onAdFailedToLoad` dispara antes, se llama a `iniciar_intento_parada` igual, sin mostrar nada ni reintentar. En ambos casos el contador se actualiza igual (D4), porque el servidor no distingue "se mostró" de "falló la carga" — el jugador ya tuvo su turno de anuncio para este ciclo, cargara o no.

**D7 — IDs de AdMob vía `dart_define`, con los test IDs de Google como plantilla.** Mismo patrón que el resto de configuración sensible (architecture.md, `app/`): `dart_define.json` (gitignorado) lleva `ADMOB_APP_ID_IOS` y `ADMOB_AD_UNIT_REWARDED_INTERSTITIAL_IOS`; `dart_define.example.json` los rellena con los IDs de test oficiales de Google para iOS (`ca-app-pub-3940256099942544~1712485313` de app, `ca-app-pub-3940256099942544/6978759866` de unidad Rewarded Interstitial), de forma que build y tests corren sin cuenta AdMob real. `Info.plist` lleva `GADApplicationIdentifier` inyectado desde ese mismo define en build time.

## Risks / Trade-offs

- **[Riesgo] Doble tap o doble navegación podría llamar dos veces a `iniciar_intento_parada` antes de que la primera responda, ambas viendo el contador "antes" de la mutación.** → Mitigación: mismo riesgo que ya existe hoy sin este cambio (crearía dos `intentos_nivel`); se acepta con el mismo nivel de protección actual (debounce en el cliente al navegar), no se añade lock adicional en el servidor para esta historia.
- **[Riesgo] Sin SSV, un cliente modificado podría llamar `iniciar_intento_parada` sin haber mostrado el anuncio nunca.** → Aceptado explícitamente (Non-Goals): no hay recompensa que proteger, solo cadencia de monetización; el `eCPM`/ingreso ya asume un fill rate y comportamiento real variable.
- **[Trade-off] El contador de cadencia es acumulado de por vida (decisión ya tomada con el usuario), no por sesión ni por día.** Un jugador muy activo en una sola sesión larga verá anuncios de cadencia varias veces esa sesión; se acepta porque simplifica la lógica y coincide con "igual que el resto del progreso".
- **[Riesgo] Cuenta AdMob no existe todavía.** → Mitigación: D7 deja el código funcionando end-to-end con IDs de test; pasar a producción es solo sustituir el `dart_define.json` real una vez exista la cuenta, sin tocar código.

## Migration Plan

1. Migración de esquema: `create type tipo_anuncio_pendiente as enum ('ninguno', 'desbloqueo', 'cadencia')`; `alter table profiles add column intentos_desde_ultimo_anuncio_cadencia integer not null default 0`.
2. RPC nueva `anuncio_debido(p_camino_id uuid) returns tipo_anuncio_pendiente` (`security invoker`).
3. `CREATE OR REPLACE FUNCTION iniciar_intento_parada` con la mutación de contador de D4, sin cambiar su firma ni su respuesta actual.
4. App: dependencia `google_mobile_ads`, `dart_define.json`/`dart_define.example.json` con IDs de test, `Info.plist` con `GADApplicationIdentifier`, inicialización del SDK en el arranque de la app.
5. App: servicio/gateway que envuelve `anuncio_debido` + carga/muestra de `RewardedInterstitialAd` con timeout fail-open, enganchado antes de navegar a la pantalla de juego (mismo sitio donde hoy se dispara `iniciar_intento_parada`).
6. Sin cambios destructivos: todo aditivo (columna con default, enum nuevo, función reemplazada sin cambiar contrato externo). Rollback = drop de la columna/enum/RPC nueva y revertir `iniciar_intento_parada` a su versión anterior.

## Open Questions

- Timeout de carga del anuncio antes de fail-open: ¿5 s (propuesta de este diseño) u otro valor? No cambia el esquema, ajustable solo en la app.
- ¿Se quiere telemetría (aunque sea un log simple) de cuántos fail-open ocurren por falta de fill, para dimensionar el problema antes de tener datos reales de la consola AdMob? Fuera de alcance salvo que se pida explícitamente.
