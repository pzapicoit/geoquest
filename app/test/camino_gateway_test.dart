import 'package:flutter_test/flutter_test.dart';
import 'package:geoquest/services/camino_gateway.dart';

ParadaCamino _parada({
  String tematicaId = 't1',
  String tematicaNombre = 'Monumentos',
  bool desbloqueado = true,
  int estrellasRequeridas = 0,
  int estrellasAcumuladasUsuario = 0,
  bool esActual = false,
  bool superado = false,
  int estrellasObtenidas = 0,
}) {
  return ParadaCamino(
    caminoId: 'c-$tematicaId-$estrellasRequeridas',
    orden: estrellasRequeridas,
    nivelId: 'n1',
    tematicaId: tematicaId,
    tematicaNombre: tematicaNombre,
    superado: superado,
    estrellasObtenidas: estrellasObtenidas,
    estrellasRequeridas: estrellasRequeridas,
    estrellasAcumuladasUsuario: estrellasAcumuladasUsuario,
    desbloqueado: desbloqueado,
    esActual: esActual,
  );
}

void main() {
  group('intercalarFronteras', () {
    test('no inserta frontera entre paradas de la misma temática', () {
      final paradas = [_parada(tematicaId: 't1'), _parada(tematicaId: 't1')];

      final entradas = intercalarFronteras(paradas);

      expect(entradas, hasLength(2));
      expect(entradas, everyElement(isA<ParadaCamino>()));
    });

    test('inserta una frontera bloqueada con las estrellas que faltan', () {
      final paradas = [
        _parada(tematicaId: 't1', tematicaNombre: 'Monumentos'),
        _parada(
          tematicaId: 't2',
          tematicaNombre: 'Banderas',
          desbloqueado: false,
          estrellasRequeridas: 500,
          estrellasAcumuladasUsuario: 480,
        ),
      ];

      final entradas = intercalarFronteras(paradas);

      expect(entradas, hasLength(3));
      final frontera = entradas[1] as ParadaFrontera;
      expect(frontera.tematicaAnteriorNombre, 'Monumentos');
      expect(frontera.tematicaSiguienteNombre, 'Banderas');
      expect(frontera.desbloqueada, isFalse);
      expect(frontera.estrellasFaltantes, 20);
    });

    test('inserta una frontera desbloqueada sin estrellas faltantes', () {
      final paradas = [
        _parada(tematicaId: 't1'),
        _parada(
          tematicaId: 't2',
          desbloqueado: true,
          estrellasRequeridas: 500,
          estrellasAcumuladasUsuario: 500,
        ),
      ];

      final frontera = intercalarFronteras(paradas)[1] as ParadaFrontera;

      expect(frontera.desbloqueada, isTrue);
      expect(frontera.estrellasFaltantes, 0);
    });

    test('el mínimo de estrellas faltantes es 1 aunque el umbral ya casi se alcance', () {
      final paradas = [
        _parada(tematicaId: 't1'),
        _parada(
          tematicaId: 't2',
          desbloqueado: false,
          estrellasRequeridas: 500,
          estrellasAcumuladasUsuario: 500,
        ),
      ];

      final frontera = intercalarFronteras(paradas)[1] as ParadaFrontera;

      expect(frontera.estrellasFaltantes, 1);
    });

    test(
      'varias temáticas seguidas insertan una frontera entre cada cambio',
      () {
        final paradas = [
          _parada(tematicaId: 't1'),
          _parada(tematicaId: 't2'),
          _parada(tematicaId: 't3'),
        ];

        final entradas = intercalarFronteras(paradas);

        expect(entradas.whereType<ParadaFrontera>(), hasLength(2));
        expect(entradas, hasLength(5));
      },
    );

    test('camino vacío no produce ninguna entrada', () {
      expect(intercalarFronteras([]), isEmpty);
    });
  });

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
