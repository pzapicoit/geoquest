import 'package:flutter_test/flutter_test.dart';
import 'package:geoquest/services/username_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('UsernameStorage', () {
    test('no hay nombre de usuario cuando no se ha guardado ninguno', () async {
      final result = await UsernameStorage().read();

      expect(result, isNull);
    });

    test('guarda y luego lee el mismo nombre de usuario', () async {
      final storage = UsernameStorage();

      await storage.save('Ana');
      final result = await storage.read();

      expect(result, 'Ana');
    });

    test('el nombre de usuario persiste entre instancias distintas', () async {
      await UsernameStorage().save('Ana');
      final result = await UsernameStorage().read();

      expect(result, 'Ana');
    });
  });
}
