import 'package:flutter_test/flutter_test.dart';
import 'package:geoquest/screens/ranking_screen.dart';
import 'package:geoquest/services/camino_gateway.dart';

const _c1 = ParadaCamino(
  orden: 1,
  caminoId: 'c1',
  tematicaId: 't-monumentos',
  tematicaNombre: 'Monumentos',
  superado: true,
  estrellasObtenidas: 3,
  estrellasRequeridas: 0,
  estrellasAcumuladasUsuario: 100,
  desbloqueado: true,
  esActual: false,
);

const _c2 = ParadaCamino(
  orden: 2,
  caminoId: 'c2',
  tematicaId: 't-banderas',
  tematicaNombre: 'Banderas',
  superado: false,
  estrellasObtenidas: 0,
  estrellasRequeridas: 100,
  estrellasAcumuladasUsuario: 100,
  desbloqueado: true,
  esActual: true,
);

const _c3 = ParadaCamino(
  orden: 3,
  caminoId: 'c3',
  tematicaId: 't-monumentos',
  tematicaNombre: 'Monumentos',
  superado: false,
  estrellasObtenidas: 0,
  estrellasRequeridas: 200,
  estrellasAcumuladasUsuario: 100,
  desbloqueado: false,
  esActual: false,
);

void main() {
  group('derivarChipsNivel', () {
    test(
      'una entrada por parada, en orden de `orden` aunque llegue desordenado',
      () {
        final chips = derivarChipsNivel([_c3, _c1, _c2]);

        expect(chips.map((c) => c.caminoId), ['c1', 'c2', 'c3']);
        expect(chips.map((c) => c.orden), [1, 2, 3]);
      },
    );

    test('lista vacía de paradas produce lista vacía de chips', () {
      expect(derivarChipsNivel(const []), isEmpty);
    });
  });

  group('derivarChipsTematica', () {
    test('temáticas distintas, dedupe conservando el primer nombre visto', () {
      final chips = derivarChipsTematica([_c1, _c2, _c3]);

      expect(chips.map((c) => c.tematicaId), ['t-monumentos', 't-banderas']);
      expect(chips.first.tematicaNombre, 'Monumentos');
    });

    test('lista vacía de paradas produce lista vacía de chips', () {
      expect(derivarChipsTematica(const []), isEmpty);
    });
  });
}
