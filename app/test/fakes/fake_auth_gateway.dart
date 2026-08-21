import 'package:geoquest/services/auth_gateway.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Falso de [AuthGateway] para probar los servicios de sesión sin salir a la
/// red ni depender de un proyecto Supabase real (INT-75, ampliado en INT-128).
class FakeAuthGateway implements AuthGateway {
  FakeAuthGateway({this.initialSession});

  Session? initialSession;

  /// Excepción a lanzar en la próxima llamada, si se define.
  Object? throwOnNextCall;

  /// Excepciones por operación, para poder fallar solo una de la cadena
  /// (p. ej. que el alta anónima funcione y falle el poner contraseña).
  Object? throwOnSignInWithPassword;
  Object? throwOnUpdateUser;
  Object? throwOnSignOut;

  int signInAnonymouslyCalls = 0;
  int signInWithPasswordCalls = 0;
  int updateUserCalls = 0;
  int signOutCalls = 0;
  int linkIdentityCalls = 0;

  Map<String, dynamic>? lastSignInData;
  String? lastEmail;
  String? lastPassword;
  OAuthProvider? lastLinkedProvider;

  /// Orden en que se llamó a cada operación, para poder afirmar sobre la
  /// secuencia (el alta tiene que renombrar **antes** de tener credenciales).
  final List<String> calls = [];

  @override
  Session? get currentSession => initialSession;

  @override
  User? get currentUser => initialSession?.user;

  @override
  Future<void> signInAnonymously({Map<String, dynamic>? data}) async {
    signInAnonymouslyCalls++;
    calls.add('signInAnonymously');
    lastSignInData = data;

    _throwIfNeeded(null);
    initialSession = _fakeSession();
  }

  @override
  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async {
    signInWithPasswordCalls++;
    calls.add('signInWithPassword');
    lastEmail = email;
    lastPassword = password;

    if (_lanzar(() => throwOnSignInWithPassword, () {
      throwOnSignInWithPassword = null;
    })) {
      return;
    }
    initialSession = _fakeSession(email: email);
  }

  @override
  Future<void> updateUser({
    required String email,
    required String password,
  }) async {
    updateUserCalls++;
    calls.add('updateUser');
    lastEmail = email;
    lastPassword = password;

    if (_lanzar(() => throwOnUpdateUser, () {
      throwOnUpdateUser = null;
    })) {
      return;
    }
    initialSession = _fakeSession(email: email);
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    calls.add('signOut');

    if (_lanzar(() => throwOnSignOut, () {
      throwOnSignOut = null;
    })) {
      return;
    }
    initialSession = null;
  }

  @override
  Future<void> linkIdentity(OAuthProvider provider) async {
    linkIdentityCalls++;
    calls.add('linkIdentity');
    lastLinkedProvider = provider;

    _throwIfNeeded(null);
  }

  void _throwIfNeeded(Object? especifico) {
    final error = especifico ?? throwOnNextCall;
    if (error == null) return;
    if (especifico == null) throwOnNextCall = null;
    throw error;
  }

  /// Lanza el error configurado para esta operación **limpiándolo antes**, de
  /// modo que el siguiente intento pueda ir bien. Sin limpiarlo, un test que
  /// comprueba un reintento se quedaría fallando para siempre.
  bool _lanzar(Object? Function() leer, void Function() limpiar) {
    final error = leer() ?? throwOnNextCall;
    if (error == null) return false;

    limpiar();
    throwOnNextCall = null;
    throw error;
  }

  Session _fakeSession({String? email}) => Session(
    accessToken: 'fake-access-token',
    tokenType: 'bearer',
    user: User(
      id: 'fake-user-id',
      email: email,
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: '2026-08-15T00:00:00Z',
      isAnonymous: email == null,
    ),
  );
}
