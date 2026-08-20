## 1. Backend

- [x] 1.1 Migración: `create or replace function usar_comodin(...)` — caso `tiempo` devuelve `{"tipo":"tiempo"}` (sin `extra_segundos`); casos `km1000`/`km500` devuelven `radio_km` 500/150 en vez de 1000/500. De paso se corrige un aviso de lint pre-existente en esta misma función (case sin rama final para el análisis estático) con un `raise` inalcanzable en la práctica.
- [x] 1.2 Verificado contra el remoto con intentos reales: `km1000` → `radio_km=500`; `km500` → `radio_km=150` (coords reales confirmadas, p. ej. Taj Mahal/Coliseo); `tiempo` → payload `{"tipo":"tiempo"}` sin `extra_segundos`. `supabase db lint --linked` sin avisos en `usar_comodin` (queda un aviso pre-existente y no relacionado en `conceder_comodin_por_anuncio`, fuera de alcance de este delta).

## 2. App — comodín tiempo

- [x] 2.1 `_NivelJuegoScreenState._aplicarEfectoComodin`: caso `ResultadoTiempo` llama a `_cuentaAtras.parar()` en vez de `.extender(...)`.
- [x] 2.2 `ResultadoTiempo` en `comodines_gateway.dart` pierde el campo `extraSegundos` (ya no lo manda el backend); actualizado `mapearResultadoUsoComodin` y sus tests (`comodines_gateway_test.dart`, `fake_comodines_gateway.dart`).
- [x] 2.3 Retirado `CuentaAtrasDeDesafio.extender()` de `cuenta_atras_de_desafio.dart` (sin llamadores tras 2.1) y sus 4 tests dedicados en `cuenta_atras_de_desafio_test.dart`. `parar()` documenta ahora también este uso.
- [x] 2.4 Reescrito el test en `nivel_juego_screen_test.dart`: tras usar `tiempo`, se avanza 90s (más que los 60s del desafío) y se comprueba que no hay auto-envío (`respuestasEnviadas` vacío, sin `nivel-juego-revelado`) y que la etiqueta de la cuenta atrás queda congelada. Textos de descripción/etiqueta (`comodines_screen.dart`, `bandeja_comodines.dart`) actualizados de "15 segundos extra" a "sin límite de tiempo".

## 3. App — radios de los comodines de distancia

- [x] 3.1 Confirmado: ni `BandejaComodines` ni el mapa tienen ningún literal de radio propio — `radioKm` viaja siempre desde el payload de `usar_comodin`. Solo se actualizó un comentario en `circulo_radio.dart` que citaba "1000/500" como ejemplo.
- [x] 3.2 Test de widget en `nivel_juego_screen_test.dart` ("usar un comodín de radio dibuja el círculo en el mapa") actualizado a `radioKm: 500` para `km1000`; tests de mapeo en `comodines_gateway_test.dart` actualizados a 500/150. Los tests genéricos de `mapa_mundi_controller_test.dart` (`mostrarRadio`/`limpiarRadio`) no dependen de estos valores de negocio, se dejan igual.

## 4. App — visual

- [x] 4.1 `BandejaComodines._IconoComodin`: icono de 56px a 72px; hueco entre iconos reducido de 8 a 4px para que los 4 + el botón de cerrar sigan cabiendo sin desbordar en pantallas estrechas (≈360px de ancho necesario, seguro incluso en un iPhone SE de 375px).
- [x] 4.2 `ComodinesScreen._TarjetaComodin` reescrita: sin `Border.all`/caja, sin el arte ancho como fondo — ahora es una `Row` simple (icono 64px + nombre/cantidad + botón "?") apoyada directamente sobre el fondo de la pantalla. Espacio entre tarjetas de 14 a 28px.
- [x] 4.3 Los 10 tests de `comodines_screen_test.dart` siguen en verde sin cambios — usaban las claves (`comodines-tarjeta-*`, `comodines-cantidad-*`) y textos, no la estructura interna del widget.

## 5. Cierre

- [x] 5.1 `flutter analyze` limpio, `dart format --set-exit-if-changed` sin cambios.
- [x] 5.2 `flutter test` — 367/367 en verde (371 originales − 4 tests de `extender` retirados + 0 netos nuevos, ya contados en los grupos anteriores).
- [x] 5.3 `supabase db lint --linked` sin avisos en las funciones tocadas por este delta (queda un aviso pre-existente y no relacionado en `conceder_comodin_por_anuncio`, fuera de alcance).
- [x] 5.4 `.devplugin/architecture.md` actualizado (filas `backend/` y `app/`) con el cambio de efecto y los radios nuevos.
- [x] 5.5 Specs sincronizadas: `comodines` (efecto tiempo, radios) y `challenge-timer` (requisito de extensión sustituido por el de detención completa).
