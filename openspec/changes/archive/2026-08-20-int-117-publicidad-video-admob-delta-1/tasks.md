## 1. Backend

- [x] 1.1 Migración: `create or replace function conceder_comodin_por_anuncio(p_tope_diario integer default 4) ...` (mismo cuerpo que hoy, solo cambia el default de 5 a 4), aplicada y verificada contra el remoto (`supabase db push --linked` + `supabase db lint --linked`; verificación funcional con sesión anónima real: 4 concesiones aceptadas, la 5ª rechazada con `tope_diario_alcanzado`)

## 2. App — AnunciosGateway gana el flujo bajo demanda

- [x] 2.1 `AnunciosGateway`/`AdMobAnunciosGateway` (`app/lib/services/anuncios_gateway.dart`): nuevo método `Future<bool> mostrarParaRecompensa()` que carga y muestra un `RewardedAd` (con timeout de carga) y devuelve `true` solo si `onUserEarnedReward` disparó antes de cerrarse; `false` en cualquier otro caso (no cargó, falló, cerrado sin recompensa) — sin fail-open, es un resultado visible
- [x] 2.2 `FakeAnunciosGateway` (`app/test/fakes/fake_anuncios_gateway.dart`): soporte para configurar el resultado de `mostrarParaRecompensa()` en los tests (`recompensaGanada`, `mostrarParaRecompensaCalls`)

## 3. App — ComodinesScreen usa el flujo real

- [x] 3.1 `ComodinesScreen`/`_HojaObtenerMas` reciben un `AnunciosGateway` (mismo patrón que `comodinesGateway`); se retira la constante fija `anuncioDisponible = false`
- [x] 3.2 `_verAnuncio` llama a `anunciosGateway.mostrarParaRecompensa()`; si devuelve `true`, sigue igual que hoy (`concederComodinPorAnuncio()` + manejo de `ComodinRechazadoException`/tope diario); si devuelve `false`, muestra un aviso de error sin llamar al servidor
- [x] 3.3 `CaminoScreen._onTapComodines` reenvía su `_anunciosGateway` a `ComodinesScreen` (mismo patrón que `comodinesGateway`)

## 4. Tests

- [x] 4.1 Actualizado el test existente: ahora "muestra las 3 opciones, el anuncio habilitado" (ya no deshabilitado)
- [x] 4.2 2 tests nuevos en `comodines_screen_test.dart`: con `mostrarParaRecompensa()` devolviendo `true`, llama a `concederComodinPorAnuncio()` y muestra el SnackBar de éxito; devolviendo `false`, avisa (`comodines-anuncio-error`) sin llamar al RPC
- [x] 4.3 2 tests nuevos de `mostrarParaRecompensa()` en `anuncios_gateway_test.dart`: fallo de carga real en entorno de test y timeout extremadamente corto, ambos devuelven `false` sin lanzar
- [x] 4.4 `flutter test --coverage` (378/378 verdes), `flutter analyze` (limpio), `dart format --set-exit-if-changed lib test` (limpio). Se ajustaron 2 tests preexistentes en `camino_screen_test.dart`/`comodines_screen_test.dart` para inyectar `FakeAnunciosGateway` en construcciones directas de `CaminoScreen`/`ComodinesScreen` que antes no lo necesitaban

## 5. Documentación

- [x] 5.1 Actualizado `.devplugin/architecture.md` (fila `backend/` y `app/`)
