import 'package:flutter_test/flutter_test.dart';
import 'package:geoquest/services/anuncios_gateway.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Cliente sin credenciales reales: `mostrarAnuncioRewarded` no lo toca en
/// absoluto (solo habla con el SDK de AdMob), así que basta con que exista
/// para poder construir el gateway.
final _clienteDePrueba = SupabaseClient(
  'https://example.invalid',
  'clave-de-prueba',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TipoAnuncioPendiente', () {
    test('fromString/values son inversas para los 3 valores', () {
      for (final tipo in TipoAnuncioPendiente.values) {
        expect(TipoAnuncioPendiente.fromString(tipo.name), tipo);
      }
    });

    test('un texto desconocido lanza ArgumentError', () {
      expect(
        () => TipoAnuncioPendiente.fromString('sorpresa'),
        throwsArgumentError,
      );
    });
  });

  group('AdMobAnunciosGateway.mostrarAnuncioRewarded (D6, fail-open)', () {
    // No hay plugin de plataforma para google_mobile_ads en el entorno de
    // test (mismo motivo que video_player en nivel_juego_screen_test.dart):
    // RewardedInterstitialAd.load() falla siempre con
    // MissingPluginException. Eso ejercita exactamente el camino de fallo
    // de carga que D6 pide resolver como fail-open — no hay forma de
    // simular aquí un anuncio que sí carga y se muestra, igual que
    // video_player tampoco prueba un vídeo que sí arranca.
    test(
      'un fallo de carga (SDK no disponible) se resuelve sin lanzar',
      () async {
        final gateway = AdMobAnunciosGateway(
          _clienteDePrueba,
          timeoutCarga: const Duration(milliseconds: 200),
        );

        await expectLater(gateway.mostrarAnuncioRewarded(), completes);
      },
    );

    test('un timeout extremadamente corto también se resuelve sin lanzar ni '
        'colgarse', () async {
      final gateway = AdMobAnunciosGateway(
        _clienteDePrueba,
        timeoutCarga: Duration.zero,
      );

      await expectLater(gateway.mostrarAnuncioRewarded(), completes);
    });

    test(
      'se resuelve dentro de un margen razonable sobre el timeout',
      () async {
        final gateway = AdMobAnunciosGateway(
          _clienteDePrueba,
          timeoutCarga: const Duration(milliseconds: 200),
        );

        final cronometro = Stopwatch()..start();
        await gateway.mostrarAnuncioRewarded();
        cronometro.stop();

        // Generoso a propósito: solo protege contra una regresión que deje de
        // aplicar el timeout y dependa de un valor real de red.
        expect(cronometro.elapsed, lessThan(const Duration(seconds: 2)));
      },
    );
  });

  group('AdMobAnunciosGateway.mostrarParaRecompensa (INT-117 delta-1)', () {
    // Mismo motivo que el grupo anterior: sin plugin de plataforma,
    // RewardedAd.load() también falla con MissingPluginException. A
    // diferencia de mostrarAnuncioRewarded, aquí el resultado observable es
    // `false` (sin recompensa), no un fail-open silencioso.
    test('un fallo de carga real devuelve false, sin lanzar', () async {
      final gateway = AdMobAnunciosGateway(
        _clienteDePrueba,
        timeoutCarga: const Duration(milliseconds: 200),
      );

      final resultado = await gateway.mostrarParaRecompensa();
      expect(resultado, isFalse);
    });

    test('un timeout extremadamente corto también devuelve false', () async {
      final gateway = AdMobAnunciosGateway(
        _clienteDePrueba,
        timeoutCarga: Duration.zero,
      );

      final resultado = await gateway.mostrarParaRecompensa();
      expect(resultado, isFalse);
    });
  });
}
