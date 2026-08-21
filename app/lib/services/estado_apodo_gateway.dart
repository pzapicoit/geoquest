import 'package:supabase_flutter/supabase_flutter.dart';

/// En qué situación está un apodo antes de intentar crear un perfil o entrar
/// en uno (INT-128, D5).
enum EstadoApodo {
  /// Nadie lo usa: se puede crear un perfil con él.
  libre,

  /// Es de un jugador que tiene contraseña: se entra pidiéndosela.
  conContrasena,

  /// Es de un jugador sin contraseña (un invitado). No hay credencial que
  /// comprobar para entrar, y darlo de alta se lo arrebataría a su dueño, así
  /// que se rechaza y se pide otro apodo.
  sinContrasena,
}

/// Consulta el estado de un apodo.
///
/// Existe porque `signInWithPassword` responde lo mismo —`Invalid login
/// credentials`— tanto si el usuario no existe como si la contraseña es
/// incorrecta. Sin esta consulta, la pantalla no podría distinguir "ese apodo
/// no es tuyo" de "te has equivocado de contraseña".
abstract class EstadoApodoGateway {
  Future<EstadoApodo> consultar(String apodo);
}

class SupabaseEstadoApodoGateway implements EstadoApodoGateway {
  SupabaseEstadoApodoGateway(this._client);

  final SupabaseClient _client;

  @override
  Future<EstadoApodo> consultar(String apodo) async {
    final resultado = await _client.rpc<dynamic>(
      'estado_apodo',
      params: {'p_alias': apodo},
    );

    return switch (resultado) {
      'libre' => EstadoApodo.libre,
      'con_contrasena' => EstadoApodo.conContrasena,
      'sin_contrasena' => EstadoApodo.sinContrasena,
      // Un valor que no reconocemos no se interpreta como "libre": eso
      // llevaría a intentar dar de alta un apodo que puede ser de alguien.
      // Ante la duda, se falla y la pantalla ofrece reintentar.
      _ => throw StateError('Estado de apodo desconocido: $resultado'),
    };
  }
}
