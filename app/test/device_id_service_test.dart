import 'package:flutter_test/flutter_test.dart';
import 'package:geoquest/services/device_id_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('DeviceIdService', () {
    test('genera un UUID nuevo cuando no hay ninguno persistido', () async {
      final id = await DeviceIdService().getOrCreate();

      expect(id, isNotEmpty);
      expect(
        RegExp(r'^[0-9a-f-]{36}$').hasMatch(id),
        isTrue,
        reason: 'debe tener forma de UUID',
      );
    });

    test('reutiliza el UUID ya persistido en llamadas siguientes', () async {
      final service = DeviceIdService();

      final first = await service.getOrCreate();
      final second = await service.getOrCreate();

      expect(second, first);
    });

    test('el UUID persiste entre instancias distintas del servicio', () async {
      final first = await DeviceIdService().getOrCreate();
      final second = await DeviceIdService().getOrCreate();

      expect(second, first);
    });
  });
}
