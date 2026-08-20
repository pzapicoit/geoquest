## 1. Esquema y RPCs (backend/supabase)

- [x] 1.1 Migración: `create type tipo_anuncio_pendiente as enum ('ninguno', 'desbloqueo', 'cadencia')`
- [x] 1.2 Migración: `alter table profiles add column intentos_desde_ultimo_anuncio_cadencia integer not null default 0`
- [x] 1.3 RPC `anuncio_debido(p_camino_id uuid) returns tipo_anuncio_pendiente`, `security invoker`, calcula desbloqueo (sin intento previo del usuario en esa parada y `camino.orden > 1`) y cadencia (contador + 1 >= 3), con prioridad desbloqueo
- [x] 1.4 Modificar `iniciar_intento_parada`: recalcular las mismas condiciones dentro de la transacción y actualizar `profiles.intentos_desde_ultimo_anuncio_cadencia` (intacto si desbloqueo, reset a 0 si cadencia sin solape, +1 en cualquier otro caso), sin cambiar su firma ni su respuesta actual
- [x] 1.5 `supabase db lint --linked` sobre las migraciones nuevas (limpio salvo un warning preexistente de INT-119 ajeno a este cambio; el propio de `anuncio_debido` se corrigió en `20260820200100_corrige_lint_anuncio_debido.sql`)

## 2. Integración del SDK de AdMob (app/)

- [x] 2.1 Añadir dependencia `google_mobile_ads` a `pubspec.yaml` (`^9.1.0`, la más reciente que resuelve limpio)
- [x] 2.2 `dart_define.example.json`/`dart_define.json`: añadido `ADMOB_AD_UNIT_REWARDED_INTERSTITIAL_IOS` con el ad unit de test oficial de Google. **Desviación del texto original:** `ADMOB_APP_ID_IOS` NO viaja por dart-define — Info.plist lo necesita antes de que exista motor Dart (dart-define solo llega a `String.fromEnvironment`), así que se resolvió como build setting nativo (`GEOQUEST_ADMOB_APP_ID_IOS` en Debug/Release.xcconfig, ver 2.3), mismo mecanismo que `GEOQUEST_BUNDLE_ID` ya existente.
- [x] 2.3 `ios/Runner/Info.plist`: `GADApplicationIdentifier` = `$(GEOQUEST_ADMOB_APP_ID_IOS)`, definido en `Debug.xcconfig`/`Release.xcconfig` con el App ID de test oficial de Google
- [x] 2.4 `MobileAds.instance.initialize()` en `main.dart`, sin bloquear el arranque (`unawaited`)
- [x] 2.5 `AnunciosGateway`/`AdMobAnunciosGateway` en `app/lib/services/anuncios_gateway.dart`: envuelve `anuncio_debido` y la carga/muestra de `RewardedInterstitialAd` con timeout fail-open de 5s (sin reintento); todo el cuerpo de `mostrarSiToca` va protegido con try/catch para que un fallo del RPC (no solo del anuncio) tampoco bloquee

## 3. Punto de enganche antes de arrancar un intento (app/)

- [x] 3.1 En `camino_screen.dart` (`_onTapParada`, ahora async): antes de navegar a `NivelJuegoScreen`, llama a `_anunciosGateway.mostrarSiToca(parada.caminoId)` (internamente consulta `anuncio_debido`)
- [x] 3.2 `mostrarSiToca` muestra el `RewardedInterstitialAd` si toca (o continúa directo si no carga a tiempo/falla/no toca) y solo entonces `_onTapParada` navega con normalidad — `iniciar_intento_parada` sigue disparándose donde ya lo hace hoy, dentro de `NivelJuegoScreen`
- [x] 3.3 Flag `_resolviendoAnuncio` bloquea doble tap (tarjeta de parada y botón fijo "Jugar") mientras se resuelve; sin spinner nuevo, para no introducir loading intrusivo cuando la respuesta es rápida

## 4. Tests

- [x] 4.1 Verificado funcionalmente contra el proyecto remoto (sin Docker, no aplica pgTAP — mismo enfoque que INT-119 para RPCs dependientes de `auth.uid()`/RLS): sesión anónima real, 8 llamadas encadenadas a `anuncio_debido`/`iniciar_intento_parada` cubriendo ninguno, cadencia (con reset), desbloqueo (contador intacto) y el caso crítico de solape (intento 7: desbloqueo con prioridad, ciclo de cadencia no consumido, contador se recupera en el intento 8)
- [x] 4.2 Cubierto por la misma verificación funcional de 4.1 (los 3 casos de mutación del contador — intacto / reset / incremento — están entre los 8 escenarios ejercitados)
- [x] 4.3 `test/anuncios_gateway_test.dart`: `TipoAnuncioPendiente.fromString` (pura) + `mostrarAnuncioRewarded()` fail-open real (sin plugin de plataforma para `google_mobile_ads` en el entorno de test, `RewardedInterstitialAd.load()` falla con `MissingPluginException` — mismo patrón que `video_player` en `nivel_juego_screen_test.dart`: se explota el fallo natural del entorno de test en vez de mockear el canal de plataforma) y timeout con `Duration.zero`. El camino feliz (anuncio que carga y se muestra) no es simulable en este entorno, igual que un vídeo que sí arranca en `video_player`
- [x] 4.4 3 tests nuevos en `camino_screen_test.dart`: sin anuncio pendiente navega directo; con anuncio pendiente navega igual tras resolverse; un segundo toque mientras se resuelve no dispara una segunda navegación (guard de `_resolviendoAnuncio`)
- [x] 4.5 `flutter test --coverage` (375/375 verdes), `flutter analyze` (limpio), `dart format --set-exit-if-changed lib test` (limpio). Cobertura de `anuncios_gateway.dart`: 18/41 líneas (44%) — en línea con el resto de gateways del proyecto (`camino_gateway.dart` 11%, `profile_gateway.dart` 17%, `comodines_gateway.dart` 64%), ninguno con umbral numérico fijado (architecture.md: "umbral por definir"); `camino_screen.dart` sube a 443/457 (97%)

## 5. Documentación

- [x] 5.1 Actualizado `.devplugin/architecture.md`: fila de `backend/` y `app/` con el resumen de este cambio (contador de cadencia, RPC `anuncio_debido`, integración `google_mobile_ads`, fail-open)

## 6. Revisión adversarial

Veredicto: **APROBADO**. Sin hallazgos críticos ni de riesgo real (fail-open ya cubría el único edge case señalado). Un hallazgo menor corregido antes de archivar:

- [x] 6.1 `anuncio_debido` no comprobaba `camino.activo`: podía sugerir un anuncio para una parada inactiva que `iniciar_intento_parada` iba a rechazar de todos modos (sin riesgo real, cubierto por fail-open, pero más limpio devolver `ninguno` directamente). Corregido en `20260820200200_anuncio_debido_valida_parada_activa.sql`, aplicado al remoto y verificado sin regresión (una parada activa real sigue devolviendo `desbloqueo`/`cadencia` igual que antes).
- Segundo hallazgo (timing del test de doble-tap en `camino_screen_test.dart`, potencialmente sensible en sistemas muy cargados) — sin cambio: el propio revisor lo calificó de robusto para CI y cambiar el timing artificial arriesga más que soluciona.
