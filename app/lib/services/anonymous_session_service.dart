import 'dart:async';

import 'package:http/http.dart' show ClientException;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_gateway.dart';
import 'device_id_service.dart';

/// Resultado de garantizar que exista una sesión antes de mostrar cualquier
/// pantalla de juego.
sealed class AnonymousSessionResult {
  const AnonymousSessionResult();
}

class AnonymousSessionReady extends AnonymousSessionResult {
  const AnonymousSessionReady();
}

/// Por qué no se pudo preparar la sesión, en términos que la pantalla puede
/// traducir a un mensaje para el jugador (INT-145).
enum CausaFalloSesion {
  /// La petición no obtuvo respuesta: sin red, tiempo agotado o servidor caído
  /// sin contestar. En web los tres llegan igual (`Failed to fetch`).
  sinRespuesta,

  /// El servidor contestó, con un error 5xx.
  servidor,

  /// Cualquier otro error.
  otra,
}

class AnonymousSessionFailure extends AnonymousSessionResult {
  const AnonymousSessionFailure(this.causa, this.detalle);

  final CausaFalloSesion causa;

  /// Texto técnico del error, para depuración. No se enseña al jugador.
  final String detalle;
}

/// Clasifica el error de crear la sesión (INT-145). Es pública para poder
/// probar la tabla sin montar el servicio.
CausaFalloSesion clasificarFalloSesion(Object error) {
  if (error is AuthException) {
    final codigo = int.tryParse(error.statusCode ?? '');
    if (codigo != null && codigo >= 500) return CausaFalloSesion.servidor;
    // `gotrue` envuelve en `AuthRetryableFetchException` sin código los fallos
    // en los que no hubo respuesta (red, CORS); con código ≥ 500 ya se ha
    // tratado arriba.
    if (error is AuthRetryableFetchException) {
      return CausaFalloSesion.sinRespuesta;
    }
    return CausaFalloSesion.otra;
  }
  if (error is ClientException || error is TimeoutException) {
    return CausaFalloSesion.sinRespuesta;
  }
  // `SocketException` vive en `dart:io`, que no existe en web; se reconoce por
  // el nombre del tipo para no partir el código por plataforma.
  if (error.runtimeType.toString() == 'SocketException') {
    return CausaFalloSesion.sinRespuesta;
  }
  return CausaFalloSesion.otra;
}

/// Crea una sesión anónima en el primer arranque y reutiliza la sesión ya
/// persistida (por el propio SDK) en los siguientes, sin volver a dar de
/// alta al usuario (INT-75).
class AnonymousSessionService {
  AnonymousSessionService(this._auth, this._deviceId);

  final AuthGateway _auth;
  final DeviceIdService _deviceId;

  Future<AnonymousSessionResult> ensureSession() async {
    if (_auth.currentSession != null) {
      return const AnonymousSessionReady();
    }

    try {
      final deviceId = await _deviceId.getOrCreate();
      await _auth.signInAnonymously(data: {'device_id': deviceId});
      return const AnonymousSessionReady();
    } catch (error) {
      return AnonymousSessionFailure(clasificarFalloSesion(error), '$error');
    }
  }
}
