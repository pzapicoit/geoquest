import 'package:flutter_test/flutter_test.dart';
import 'package:geoquest/mapa/guiones.dart';

double _largoTotal(List<Guion> guiones) =>
    guiones.fold(0, (suma, guion) => suma + (guion.$2 - guion.$1).distance);

void main() {
  group('trocearEnGuiones', () {
    test('el primer guión arranca donde arranca la línea', () {
      final guiones = trocearEnGuiones(const [Offset(10, 10), Offset(110, 10)]);

      expect(guiones.first.$1, const Offset(10, 10));
      expect(guiones.first.$2, const Offset(12.5, 10));
    });

    test('reparte guiones y huecos del largo pedido', () {
      // 100 px con patrón 2,5 + 9: un ciclo cada 11,5 px → 9 guiones.
      final guiones = trocearEnGuiones(const [Offset.zero, Offset(100, 0)]);

      expect(guiones, hasLength(9));
      for (final guion in guiones) {
        expect((guion.$2 - guion.$1).distance, closeTo(2.5, 1e-9));
      }
    });

    test('el patrón sigue de un tramo al siguiente, sin reiniciarse', () {
      // La misma línea recta, contada como un tramo o como diez, tiene que
      // dar el mismo dibujo: si no, cada vértice del arco pintaría un guión
      // de más.
      final deUnTramo = trocearEnGuiones(const [Offset.zero, Offset(100, 0)]);
      final deDiez = trocearEnGuiones([
        for (var i = 0; i <= 10; i++) Offset(i * 10, 0),
      ]);

      expect(_largoTotal(deDiez), closeTo(_largoTotal(deUnTramo), 1e-9));
      expect(deDiez.first.$1, deUnTramo.first.$1);
    });

    test('una línea más corta que el primer guión se pinta entera', () {
      final guiones = trocearEnGuiones(const [Offset.zero, Offset(1, 0)]);

      expect(guiones, hasLength(1));
      expect(guiones.single.$2, const Offset(1, 0));
    });

    test('una línea sin largo no pinta nada', () {
      expect(trocearEnGuiones(const [Offset(5, 5)]), isEmpty);
      expect(trocearEnGuiones(const [Offset(5, 5), Offset(5, 5)]), isEmpty);
      expect(trocearEnGuiones(const []), isEmpty);
    });

    test('el patrón se puede cambiar', () {
      final guiones = trocearEnGuiones(
        const [Offset.zero, Offset(30, 0)],
        guion: 5,
        hueco: 5,
      );

      expect(guiones, hasLength(3));
      expect(guiones[1].$1, const Offset(10, 0));
      expect(guiones[1].$2, const Offset(15, 0));
    });
  });
}
