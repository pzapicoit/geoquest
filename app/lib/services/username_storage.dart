import 'package:shared_preferences/shared_preferences.dart';

/// Persiste localmente el nombre de usuario elegido por el jugador, para que
/// la pantalla de entrada (INT-108, antes splash INT-88) sepa si debe
/// pedirlo de nuevo o mostrar la bienvenida de regreso.
class UsernameStorage {
  static const _prefsKey = 'username';

  Future<String?> read() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefsKey);
  }

  Future<void> save(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, username);
  }

  /// Borra el apodo guardado — usado por "Cambiar de jugador" (INT-108)
  /// para volver a mostrar la captura de apodo con un dispositivo que ya
  /// tenía uno guardado.
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }
}
