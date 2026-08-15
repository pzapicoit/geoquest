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

class AnonymousSessionFailure extends AnonymousSessionResult {
  const AnonymousSessionFailure(this.reason);
  final String reason;
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
    } on AuthException catch (error) {
      return AnonymousSessionFailure(error.message);
    } catch (error) {
      return AnonymousSessionFailure('No se pudo iniciar sesión: $error');
    }
  }
}
