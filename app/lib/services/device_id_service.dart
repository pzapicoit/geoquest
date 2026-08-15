import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Genera y persiste el UUID de dispositivo que acompaña a cada alta anónima
/// (INT-75, D6: identificador provisional mientras no haya cuenta vinculada).
///
/// No sobrevive a una reinstalación de la app: es un identificador local, no
/// un mecanismo de recuperación de cuenta (eso lo cubre `linkIdentity`).
class DeviceIdService {
  DeviceIdService({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  static const _prefsKey = 'device_id';

  final Uuid _uuid;

  Future<String> getOrCreate() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_prefsKey);
    if (existing != null) return existing;

    final generated = _uuid.v4();
    await prefs.setString(_prefsKey, generated);
    return generated;
  }
}
