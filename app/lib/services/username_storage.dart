import 'package:shared_preferences/shared_preferences.dart';

/// Persiste localmente el nombre de usuario elegido por el jugador, para que
/// el splash (INT-88) sepa si debe pedirlo de nuevo o saltar directo al mapa.
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
}
