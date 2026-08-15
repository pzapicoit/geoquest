import 'package:geoquest/services/auth_gateway.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Falso de [AuthGateway] para probar los servicios de sesión sin salir a la
/// red ni depender de un proyecto Supabase real (INT-75).
class FakeAuthGateway implements AuthGateway {
  FakeAuthGateway({this.initialSession});

  Session? initialSession;

  /// Excepción a lanzar en la próxima llamada, si se define.
  Object? throwOnNextCall;

  int signInAnonymouslyCalls = 0;
  int linkIdentityCalls = 0;
  Map<String, dynamic>? lastSignInData;
  OAuthProvider? lastLinkedProvider;

  @override
  Session? get currentSession => initialSession;

  @override
  Future<void> signInAnonymously({Map<String, dynamic>? data}) async {
    signInAnonymouslyCalls++;
    lastSignInData = data;

    final error = throwOnNextCall;
    if (error != null) {
      throwOnNextCall = null;
      throw error;
    }

    initialSession = _fakeSession();
  }

  @override
  Future<void> linkIdentity(OAuthProvider provider) async {
    linkIdentityCalls++;
    lastLinkedProvider = provider;

    final error = throwOnNextCall;
    if (error != null) {
      throwOnNextCall = null;
      throw error;
    }
  }

  Session _fakeSession() => Session(
    accessToken: 'fake-access-token',
    tokenType: 'bearer',
    user: const User(
      id: 'fake-user-id',
      appMetadata: {},
      userMetadata: {},
      aud: 'authenticated',
      createdAt: '2026-08-15T00:00:00Z',
      isAnonymous: true,
    ),
  );
}
