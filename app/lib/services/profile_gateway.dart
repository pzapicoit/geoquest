import 'package:supabase_flutter/supabase_flutter.dart';

/// Superficie mínima de Supabase para actualizar el perfil del jugador,
/// para poder probarla con un falso sin salir a la red (INT-89).
abstract class ProfileGateway {
  Future<void> updateNickname(String nombre);
}

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

    await _client.from('profiles').update({'nombre': nombre}).eq('id', userId);
  }
}
