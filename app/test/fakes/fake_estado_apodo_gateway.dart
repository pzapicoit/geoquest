import 'package:geoquest/services/estado_apodo_gateway.dart';

/// Falso de [EstadoApodoGateway] para probar las decisiones de sesión sin
/// salir a la red (INT-128).
class FakeEstadoApodoGateway implements EstadoApodoGateway {
  FakeEstadoApodoGateway({this.estado = EstadoApodo.libre});

  EstadoApodo estado;
  Object? throwOnNextCall;

  int consultarCalls = 0;
  String? lastApodo;

  @override
  Future<EstadoApodo> consultar(String apodo) async {
    consultarCalls++;
    lastApodo = apodo;

    final error = throwOnNextCall;
    if (error != null) {
      throwOnNextCall = null;
      throw error;
    }

    return estado;
  }
}
