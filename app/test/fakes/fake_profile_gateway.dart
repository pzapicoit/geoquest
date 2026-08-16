import 'package:geoquest/services/profile_gateway.dart';

/// Falso de [ProfileGateway] para probar la pantalla de nombre de usuario
/// sin salir a la red (INT-89).
class FakeProfileGateway implements ProfileGateway {
  int updateNicknameCalls = 0;
  String? lastNickname;

  /// Excepción a lanzar en la próxima llamada, si se define.
  Object? throwOnNextCall;

  @override
  Future<void> updateNickname(String nombre) async {
    updateNicknameCalls++;
    lastNickname = nombre;

    final error = throwOnNextCall;
    if (error != null) {
      throwOnNextCall = null;
      throw error;
    }
  }
}
