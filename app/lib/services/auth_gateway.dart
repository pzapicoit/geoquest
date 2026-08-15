import 'package:supabase_flutter/supabase_flutter.dart';

/// Superficie mínima de Supabase Auth que necesitan los servicios de sesión,
/// para poder probarlos con un falso sin salir a la red (INT-75).
abstract class AuthGateway {
  Session? get currentSession;

  Future<void> signInAnonymously({Map<String, dynamic>? data});

  Future<void> linkIdentity(OAuthProvider provider);
}

class SupabaseAuthGateway implements AuthGateway {
  SupabaseAuthGateway(this._client);

  final GoTrueClient _client;

  @override
  Session? get currentSession => _client.currentSession;

  @override
  Future<void> signInAnonymously({Map<String, dynamic>? data}) =>
      _client.signInAnonymously(data: data);

  @override
  Future<void> linkIdentity(OAuthProvider provider) =>
      _client.linkIdentity(provider);
}
