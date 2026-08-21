import 'package:supabase_flutter/supabase_flutter.dart';

/// Superficie mínima de Supabase Auth que necesitan los servicios de sesión,
/// para poder probarlos con un falso sin salir a la red (INT-75).
///
/// No aparece `signUp`: dar de alta a un jugador con contraseña se hace sobre
/// una sesión anónima (INT-128, D6), porque en el momento de ponerle el apodo
/// aún no puede tener credenciales — si las tuviera, el trigger que hace
/// inmutable el apodo (D4) rechazaría el renombrado.
abstract class AuthGateway {
  Session? get currentSession;

  User? get currentUser;

  Future<void> signInAnonymously({Map<String, dynamic>? data});

  Future<void> signInWithPassword({
    required String email,
    required String password,
  });

  /// Establece identidad y contraseña sobre la sesión activa. Sobre un usuario
  /// anónimo es el camino documentado para convertirlo en permanente: conserva
  /// el mismo `user id` y, con él, todo el progreso (INT-128, D8).
  Future<void> updateUser({required String email, required String password});

  Future<void> signOut();

  Future<void> linkIdentity(OAuthProvider provider);
}

class SupabaseAuthGateway implements AuthGateway {
  SupabaseAuthGateway(this._client);

  final GoTrueClient _client;

  @override
  Session? get currentSession => _client.currentSession;

  @override
  User? get currentUser => _client.currentUser;

  @override
  Future<void> signInAnonymously({Map<String, dynamic>? data}) =>
      _client.signInAnonymously(data: data);

  @override
  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) => _client.signInWithPassword(email: email, password: password);

  @override
  Future<void> updateUser({required String email, required String password}) =>
      _client.updateUser(UserAttributes(email: email, password: password));

  @override
  Future<void> signOut() => _client.signOut();

  @override
  Future<void> linkIdentity(OAuthProvider provider) =>
      _client.linkIdentity(provider);
}
