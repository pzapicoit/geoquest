import 'package:geoquest/services/nivel_juego_gateway.dart';

/// Falso de [NivelJuegoGateway] para probar la pantalla de juego sin salir
/// a la red (INT-91).
class FakeNivelJuegoGateway implements NivelJuegoGateway {
  FakeNivelJuegoGateway(this.intento);

  IntentoNivel intento;

  /// Excepción a lanzar en la próxima llamada, si se define.
  Object? throwOnNextCall;

  int iniciarIntentoCalls = 0;
  String? ultimoNivelId;

  @override
  Future<IntentoNivel> iniciarIntento(String nivelId) async {
    iniciarIntentoCalls++;
    ultimoNivelId = nivelId;

    final error = throwOnNextCall;
    if (error != null) {
      throwOnNextCall = null;
      throw error;
    }

    return intento;
  }
}
