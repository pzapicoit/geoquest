import 'package:flutter_test/flutter_test.dart';
import 'package:geoquest/services/camino_gateway.dart';

/// Una fila de `camino_jugador` como la devuelve postgrest, con lo mínimo que
/// mira [construirCaminoJugador] más el `mejor_puntaje` que se está probando.
Map<String, dynamic> _fila({
  required int orden,
  required int mejorPuntaje,
  String tematicaId = 'monumentos',
}) => {
  'camino_id': 'nivel-$orden',
  'orden': orden,
  'nombre': 'Parada $orden',
  'tematica_id': tematicaId,
  'tematica_nombre': 'Monumentos',
  'superado': mejorPuntaje > 0,
  'estrellas_obtenidas': 0,
  'estrellas_requeridas': 0,
  'estrellas_acumuladas_usuario': 0,
  'desbloqueado': true,
  'es_actual': false,
  'mejor_puntaje': mejorPuntaje,
};

void main() {
  group('construirCaminoJugador', () {
    test(
      'el acumulado de cada parada suma los mejores intentos hasta ella',
      () {
        final camino = construirCaminoJugador([
          _fila(orden: 1, mejorPuntaje: 300),
          _fila(orden: 2, mejorPuntaje: 500),
          _fila(orden: 3, mejorPuntaje: 200),
        ], const {});

        expect(camino.entradas.map((p) => p.puntosAcumulados).toList(), [
          300,
          800,
          1000,
        ]);
      },
    );

    test('cada parada conserva su propio mejor intento sin acumular', () {
      final camino = construirCaminoJugador([
        _fila(orden: 1, mejorPuntaje: 300),
        _fila(orden: 2, mejorPuntaje: 500),
      ], const {});

      expect(camino.entradas.map((p) => p.mejorPuntaje).toList(), [300, 500]);
    });

    test('una parada sin jugar intercalada repite el acumulado anterior', () {
      final camino = construirCaminoJugador([
        _fila(orden: 1, mejorPuntaje: 300),
        _fila(orden: 2, mejorPuntaje: 0),
        _fila(orden: 3, mejorPuntaje: 200),
      ], const {});

      expect(camino.entradas.map((p) => p.puntosAcumulados).toList(), [
        300,
        300,
        500,
      ]);
    });

    test('el total es el acumulado de la última parada', () {
      final camino = construirCaminoJugador([
        _fila(orden: 1, mejorPuntaje: 300),
        _fila(orden: 2, mejorPuntaje: 500),
        _fila(orden: 3, mejorPuntaje: 0),
      ], const {});

      expect(camino.puntosTotales, camino.entradas.last.puntosAcumulados);
      expect(camino.puntosTotales, 800);
    });

    test('el acumulado nunca decrece a lo largo del camino', () {
      final camino = construirCaminoJugador([
        for (var orden = 1; orden <= 6; orden++)
          _fila(orden: orden, mejorPuntaje: orden.isEven ? 0 : 100 * orden),
      ], const {});

      final acumulados = camino.entradas
          .map((p) => p.puntosAcumulados)
          .toList();
      for (var i = 1; i < acumulados.length; i++) {
        expect(acumulados[i], greaterThanOrEqualTo(acumulados[i - 1]));
      }
    });

    test('un camino vacío da un total de 0 y ninguna parada', () {
      final camino = construirCaminoJugador(const [], const {});

      expect(camino.entradas, isEmpty);
      expect(camino.puntosTotales, 0);
    });

    test('un jugador sin puntos deja todos los acumulados en 0', () {
      final camino = construirCaminoJugador([
        _fila(orden: 1, mejorPuntaje: 0),
        _fila(orden: 2, mejorPuntaje: 0),
      ], const {});

      expect(camino.entradas.every((p) => p.puntosAcumulados == 0), isTrue);
      expect(camino.puntosTotales, 0);
    });

    test(
      'una fila sin la columna mejor_puntaje cuenta como 0, no revienta',
      () {
        // Un cliente contra una base donde la migración de INT-123 no está
        // aplicada todavía: la columna no viaja en la respuesta.
        final fila = _fila(orden: 1, mejorPuntaje: 0)..remove('mejor_puntaje');

        final camino = construirCaminoJugador([fila], const {});

        expect(camino.entradas.single.mejorPuntaje, 0);
        expect(camino.puntosTotales, 0);
      },
    );

    test('la portada de la temática se adjunta a cada parada', () {
      final camino = construirCaminoJugador(
        [
          _fila(orden: 1, mejorPuntaje: 0, tematicaId: 'monumentos'),
          _fila(orden: 2, mejorPuntaje: 0, tematicaId: 'banderas'),
        ],
        const {'monumentos': 'https://cdn/monumentos.png'},
      );

      expect(
        camino.entradas.first.imagenPortadaUrl,
        'https://cdn/monumentos.png',
      );
      expect(camino.entradas.last.imagenPortadaUrl, isNull);
    });
  });
}
