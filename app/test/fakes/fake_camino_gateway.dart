import 'package:geoquest/services/camino_gateway.dart';

/// Falso de [CaminoGateway] para probar la Home del jugador sin salir a la
/// red (INT-90).
class FakeCaminoGateway implements CaminoGateway {
  FakeCaminoGateway(this.camino);

  CaminoJugador camino;

  /// Excepción a lanzar en la próxima llamada, si se define.
  Object? throwOnNextCall;

  int fetchCaminoCalls = 0;

  @override
  Future<CaminoJugador> fetchCamino() async {
    fetchCaminoCalls++;

    final error = throwOnNextCall;
    if (error != null) {
      throwOnNextCall = null;
      throw error;
    }

    return camino;
  }
}
