import 'package:flutter_test/flutter_test.dart';
import 'package:geoquest/services/anuncios_gateway.dart';

void main() {
  group('AnunciosGatewayWeb', () {
    // No recibe SupabaseClient a propósito: si alguna de estas operaciones
    // tocara la red o el SDK, no habría forma de construirlo aquí.
    const gateway = AnunciosGatewayWeb();

    test('declara que no hay anuncios disponibles', () {
      expect(gateway.anunciosDisponibles, isFalse);
    });

    test('anuncioDebido nunca hace esperar un anuncio', () async {
      expect(
        await gateway.anuncioDebido('cualquier-camino'),
        TipoAnuncioPendiente.ninguno,
      );
    });

    test('mostrarSiToca no lanza y no bloquea (su fail-open)', () async {
      await expectLater(gateway.mostrarSiToca('cualquier-camino'), completes);
    });

    test(
      'mostrarParaRecompensa devuelve false: no hay nada que conceder',
      () async {
        // A diferencia del gating, este flujo NO es fail-open: quien llama no
        // debe conceder un comodín si no se gana la recompensa.
        expect(await gateway.mostrarParaRecompensa(), isFalse);
      },
    );
  });
}
