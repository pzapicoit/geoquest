## 1. Backend

- [ ] 1.1 Migración: `create or replace function usar_comodin(...)` — caso `tiempo` devuelve `{"tipo":"tiempo"}` (sin `extra_segundos`); casos `km1000`/`km500` devuelven `radio_km` 500/150 en vez de 1000/500.
- [ ] 1.2 Verificar contra el remoto (mismo patrón que la historia original): un intento real, usar `km1000` y comprobar `radio_km = 500`; usar `km500` y comprobar `radio_km = 150`; usar `tiempo` y comprobar que el payload ya no trae `extra_segundos`.

## 2. App — comodín tiempo

- [ ] 2.1 `_NivelJuegoScreenState._aplicarEfectoComodin`: caso `ResultadoTiempo` llama a `_cuentaAtras.parar()` en vez de `.extender(...)`.
- [ ] 2.2 `ResultadoTiempo` en `comodines_gateway.dart` pierde el campo `extraSegundos` (ya no lo manda el backend); actualizar `mapearResultadoUsoComodin` y sus tests.
- [ ] 2.3 Retirar `CuentaAtrasDeDesafio.extender()` de `cuenta_atras_de_desafio.dart` (sin llamadores tras 2.1) y sus 4 tests dedicados en `cuenta_atras_de_desafio_test.dart`.
- [ ] 2.4 Actualizar el test "usar el comodín tiempo extiende la cuenta atrás" en `nivel_juego_screen_test.dart` para reflejar que ahora la detiene (`corriendo == false`, `restante` deja de disminuir), no que la extiende.

## 3. App — radios de los comodines de distancia

- [ ] 3.1 Confirmar que `BandejaComodines`/mapa no tienen ningún literal de radio propio (deberían venir siempre del payload del servidor) — si lo tienen, quitarlo para que 500/150 lleguen solo desde el backend.
- [ ] 3.2 Test de widget: usar `km1000` dibuja un círculo de 500km; usar `km500` dibuja uno de 150km (ajustar los tests existentes que asuman 1000/500).

## 4. App — visual

- [ ] 4.1 `BandejaComodines._IconoComodin`: aumentar el tamaño de icono (56px actual → más grande, p. ej. 72px), ajustando el layout de la fila si hace falta.
- [ ] 4.2 `ComodinesScreen._TarjetaComodin`: quitar la caja/borde (`Border.all`) y el arte ancho como fondo de tarjeta; usar el icono cuadrado (ya transparente) junto al nombre/cantidad; aumentar el espacio vertical entre tarjetas.
- [ ] 4.3 Tests de widget de `comodines_screen_test.dart` afectados por el rediseño de `_TarjetaComodin` (claves/estructura si cambian).

## 5. Cierre

- [ ] 5.1 `flutter analyze` + `dart format --set-exit-if-changed` limpios.
- [ ] 5.2 `flutter test` completo en verde.
- [ ] 5.3 `supabase db lint --linked` sin errores.
- [ ] 5.4 Actualizar `.devplugin/architecture.md` con el cambio de efecto (tiempo detiene, no extiende) y los radios nuevos (500/150).
- [ ] 5.5 Sincronizar specs (`comodines`, `challenge-timer`) a los ficheros principales al archivar el delta.
