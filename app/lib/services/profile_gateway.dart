import 'package:supabase_flutter/supabase_flutter.dart';

/// Superficie mínima de Supabase para actualizar el perfil del jugador,
/// para poder probarla con un falso sin salir a la red (INT-89).
abstract class ProfileGateway {
  Future<void> updateNickname(String nombre);

  /// Apodo del perfil de la sesión activa, o `null` si no hay sesión o el
  /// perfil no existe. Sirve para reconocer el caso en que el apodo que se
  /// intenta usar es **el del propio jugador** sin contraseña, que no es un
  /// apodo ocupado por otro sino una invitación a ponerle una (INT-128).
  Future<String?> currentNickname();
}

/// Se lanza cuando el apodo ya lo usa otro jugador (violación del índice
/// único de `profiles.nombre`, INT-111 delta 1), para que la pantalla lo
/// distinga de un fallo de red y muestre un mensaje específico.
class AliasEnUsoException implements Exception {
  const AliasEnUsoException();
}

/// Código Postgres de violación de unicidad — el índice único parcial de
/// `profiles.nombre` (INT-111 delta 1) lo dispara cuando el alias ya existe.
bool esViolacionDeAliasUnico(PostgrestException error) => error.code == '23505';

/// Actualiza `profiles.nombre` de la sesión activa. Se apoya en la policy
/// `profiles_update_own` (INT-77): cualquier usuario autenticado —también
/// anónimo— puede actualizar su propia fila.
class SupabaseProfileGateway implements ProfileGateway {
  SupabaseProfileGateway(this._client);

  final SupabaseClient _client;

  @override
  Future<void> updateNickname(String nombre) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('No hay sesión activa para actualizar el perfil.');
    }

    try {
      await _client
          .from('profiles')
          .update({'nombre': nombre})
          .eq('id', userId);
    } on PostgrestException catch (error) {
      if (esViolacionDeAliasUnico(error)) {
        throw const AliasEnUsoException();
      }
      rethrow;
    }
  }

  @override
  Future<String?> currentNickname() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    // Se apoya en la policy `profiles_select_own` (INT-76): un jugador puede
    // leer su propia fila y solo la suya.
    final fila = await _client
        .from('profiles')
        .select('nombre')
        .eq('id', userId)
        .maybeSingle();

    return fila?['nombre'] as String?;
  }
}
