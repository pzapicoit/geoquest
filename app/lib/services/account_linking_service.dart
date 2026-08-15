import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_gateway.dart';

/// Resultado de vincular una identidad externa sobre la sesión anónima.
sealed class AccountLinkResult {
  const AccountLinkResult();
}

/// El flujo de vinculación se lanzó correctamente. `linkIdentity` abre un
/// navegador externo y completa de forma asíncrona vía deep link; este
/// resultado no significa que la identidad ya quedó vinculada, solo que el
/// arranque del flujo no falló.
class AccountLinkStarted extends AccountLinkResult {
  const AccountLinkStarted();
}

class AccountLinkFailure extends AccountLinkResult {
  const AccountLinkFailure(this.reason);
  final String reason;
}

/// Vincula una identidad Google/Apple sobre la sesión anónima activa
/// (`linkIdentity`), conservando el mismo `user id` y por tanto el progreso
/// (INT-75, D4). Si la identidad ya pertenece a otra cuenta, la vinculación
/// falla explícitamente y la sesión anónima original no se ve afectada.
class AccountLinkingService {
  AccountLinkingService(this._auth);

  final AuthGateway _auth;

  Future<AccountLinkResult> link(OAuthProvider provider) async {
    try {
      await _auth.linkIdentity(provider);
      return const AccountLinkStarted();
    } on AuthException catch (error) {
      return AccountLinkFailure(error.message);
    } catch (error) {
      return AccountLinkFailure('No se pudo vincular la cuenta: $error');
    }
  }
}
