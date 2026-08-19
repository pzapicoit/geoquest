import 'package:flutter_test/flutter_test.dart';
import 'package:geoquest/services/ranking_gateway.dart';

void main() {
  group('mapearEntradaRanking', () {
    test('mapea una fila de clasificacion_global', () {
      final entrada = mapearEntradaRanking({
        'usuario_id': 'u1',
        'nombre': 'Marta_G',
        'avatar_url': null,
        'puntuacion': 4820,
        'niveles_superados': 10,
        'superado': null,
        'posicion': 1,
        'es_usuario_actual': false,
      });

      expect(entrada.usuarioId, 'u1');
      expect(entrada.nombre, 'Marta_G');
      expect(entrada.puntuacion, 4820);
      expect(entrada.nivelesSuperados, 10);
      expect(entrada.superado, isNull);
      expect(entrada.posicion, 1);
      expect(entrada.esUsuarioActual, isFalse);
    });

    test('mapea una fila de clasificacion_por_camino', () {
      final entrada = mapearEntradaRanking({
        'usuario_id': 'u2',
        'nombre': 'Kilian77',
        'avatar_url': 'https://example.com/a.png',
        'puntuacion': 980,
        'niveles_superados': null,
        'superado': true,
        'posicion': 3,
        'es_usuario_actual': true,
      });

      expect(entrada.avatarUrl, 'https://example.com/a.png');
      expect(entrada.nivelesSuperados, isNull);
      expect(entrada.superado, isTrue);
      expect(entrada.esUsuarioActual, isTrue);
    });

    test('acepta puntuacion y posicion serializadas como texto (bigint)', () {
      final entrada = mapearEntradaRanking({
        'usuario_id': 'u3',
        'nombre': 'AtlasNina',
        'avatar_url': null,
        'puntuacion': '9007199254740993',
        'niveles_superados': 2,
        'superado': null,
        'posicion': '250',
        'es_usuario_actual': false,
      });

      expect(entrada.puntuacion, 9007199254740993);
      expect(entrada.posicion, 250);
    });

    test('jugador sin puntuacion agregable llega con posicion null', () {
      final entrada = mapearEntradaRanking({
        'usuario_id': 'u4',
        'nombre': 'NuevoJugador',
        'avatar_url': null,
        'puntuacion': 0,
        'niveles_superados': 0,
        'superado': null,
        'posicion': null,
        'es_usuario_actual': true,
      });

      expect(entrada.posicion, isNull);
      expect(entrada.puntuacion, 0);
      expect(entrada.esUsuarioActual, isTrue);
    });
  });
}
