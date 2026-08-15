import 'package:flutter_test/flutter_test.dart';
import 'package:geoquest/services/account_linking_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fakes/fake_auth_gateway.dart';

void main() {
  group('AccountLinkingService', () {
    test('lanza el flujo de vinculación con el proveedor pedido', () async {
      final auth = FakeAuthGateway();
      final service = AccountLinkingService(auth);

      final result = await service.link(OAuthProvider.google);

      expect(result, isA<AccountLinkStarted>());
      expect(auth.linkIdentityCalls, 1);
      expect(auth.lastLinkedProvider, OAuthProvider.google);
    });

    test('devuelve fallo explícito cuando la identidad ya está vinculada a otra cuenta', () async {
      final auth = FakeAuthGateway()
        ..throwOnNextCall = const AuthException(
          'Identity is already linked to another user',
        );
      final service = AccountLinkingService(auth);

      final result = await service.link(OAuthProvider.apple);

      expect(result, isA<AccountLinkFailure>());
      expect((result as AccountLinkFailure).reason, contains('already linked'));
    });
  });
}
