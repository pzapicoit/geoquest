import 'package:flutter_test/flutter_test.dart';
import 'package:geoquest/services/player_roster_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late PlayerRosterStorage storage;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    storage = PlayerRosterStorage();
  });

  test('sin nada guardado, la lista está vacía', () async {
    expect(await storage.read(), isEmpty);
  });

  test('el último en entrar aparece primero', () async {
    await storage.registrar('Pablo');
    await storage.registrar('María');

    expect(await storage.read(), ['María', 'Pablo']);
  });

  test(
    'no duplica un apodo que vuelve a entrar, y lo sube al principio',
    () async {
      await storage.registrar('Pablo');
      await storage.registrar('María');
      await storage.registrar('Pablo');

      expect(await storage.read(), ['Pablo', 'María']);
    },
  );

  test('trata como el mismo apodo el que solo cambia en mayúsculas', () async {
    await storage.registrar('Pablo');
    await storage.registrar('pablo');

    expect(await storage.read(), ['pablo']);
  });

  test(
    'al superar el tope descarta el que lleva más tiempo sin entrar',
    () async {
      for (var i = 1; i <= PlayerRosterStorage.maxApodos; i++) {
        await storage.registrar('Jugador$i');
      }
      await storage.registrar('Nuevo');

      final apodos = await storage.read();
      expect(apodos, hasLength(PlayerRosterStorage.maxApodos));
      expect(apodos.first, 'Nuevo');
      expect(apodos, isNot(contains('Jugador1')));
    },
  );

  test('olvidar retira solo ese apodo', () async {
    await storage.registrar('Pablo');
    await storage.registrar('María');

    await storage.olvidar('Pablo');

    expect(await storage.read(), ['María']);
  });
}
