import 'package:flutter_test/flutter_test.dart';
import 'package:geoquest/services/camino_gateway.dart';

void main() {
  group('sumarPuntos', () {
    test('suma los puntos de todas las respuestas', () {
      final total = sumarPuntos([
        {'puntos': 120},
        {'puntos': 80},
        {'puntos': 0},
      ]);

      expect(total, 200);
    });

    test('sin respuestas, el total es 0', () {
      expect(sumarPuntos([]), 0);
    });
  });
}
