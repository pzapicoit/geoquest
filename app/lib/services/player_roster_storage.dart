import 'package:shared_preferences/shared_preferences.dart';

/// Apodos que ya han entrado en este dispositivo, para ofrecerlos como atajo
/// en la pantalla de acceso (INT-128).
///
/// Guarda **apodos y nada más**: ni contraseñas, ni sesiones, ni nada que por
/// sí solo permita entrar. Elegir uno rellena el campo del apodo; la
/// contraseña se sigue escribiendo, que es lo que evita que compartir un móvil
/// sea compartir las cuentas.
class PlayerRosterStorage {
  static const _prefsKey = 'player_roster';

  /// Tope de apodos recordados. Con más, la lista deja de ser un atajo y pasa
  /// a ser un historial de quién ha usado este móvil.
  static const maxApodos = 5;

  Future<List<String>> read() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_prefsKey) ?? const [];
  }

  /// Deja [apodo] el primero de la lista, sin duplicarlo, y descarta el más
  /// antiguo si se supera el tope.
  Future<void> registrar(String apodo) async {
    final prefs = await SharedPreferences.getInstance();
    final actuales = prefs.getStringList(_prefsKey) ?? const <String>[];

    // La comparación ignora mayúsculas por la misma razón que la identidad de
    // acceso (D2): "Pablo" y "pablo" son el mismo jugador, y verlos dos veces
    // en la lista solo confunde a quien la usa.
    final sinDuplicado = actuales
        .where((a) => a.toLowerCase() != apodo.toLowerCase())
        .toList();

    await prefs.setStringList(
      _prefsKey,
      [apodo, ...sinDuplicado].take(maxApodos).toList(),
    );
  }

  /// Retira un apodo de este dispositivo. No toca el perfil remoto: se sigue
  /// pudiendo entrar escribiendo el apodo y su contraseña.
  Future<void> olvidar(String apodo) async {
    final prefs = await SharedPreferences.getInstance();
    final actuales = prefs.getStringList(_prefsKey) ?? const <String>[];

    await prefs.setStringList(
      _prefsKey,
      actuales.where((a) => a.toLowerCase() != apodo.toLowerCase()).toList(),
    );
  }
}
