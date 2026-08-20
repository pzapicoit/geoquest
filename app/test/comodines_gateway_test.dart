import 'package:flutter_test/flutter_test.dart';
import 'package:geoquest/services/comodines_gateway.dart';

void main() {
  group('ComodinTipo', () {
    test('aTexto/fromString son inversas para los 4 tipos', () {
      for (final tipo in ComodinTipo.values) {
        expect(ComodinTipo.fromString(tipo.aTexto), tipo);
      }
    });

    test('un texto desconocido lanza ArgumentError', () {
      expect(() => ComodinTipo.fromString('oro'), throwsArgumentError);
    });
  });

  group('mapearInventario', () {
    test('mapea las 4 filas a sus cantidades', () {
      final inventario = mapearInventario([
        {'tipo': 'tiempo', 'cantidad': 1},
        {'tipo': 'pais', 'cantidad': 0},
        {'tipo': 'km1000', 'cantidad': 2},
        {'tipo': 'km500', 'cantidad': 0},
      ]);

      expect(inventario.cantidadDe(ComodinTipo.tiempo), 1);
      expect(inventario.cantidadDe(ComodinTipo.pais), 0);
      expect(inventario.cantidadDe(ComodinTipo.km1000), 2);
      expect(inventario.cantidadDe(ComodinTipo.km500), 0);
      expect(inventario.total, 3);
    });

    test('acepta la cantidad como texto (numeric serializado)', () {
      final inventario = mapearInventario([
        {'tipo': 'tiempo', 'cantidad': '4'},
      ]);

      expect(inventario.cantidadDe(ComodinTipo.tiempo), 4);
    });

    test('un tipo ausente en las filas se rellena a 0', () {
      final inventario = mapearInventario([
        {'tipo': 'tiempo', 'cantidad': 1},
      ]);

      expect(inventario.cantidadDe(ComodinTipo.pais), 0);
      expect(inventario.cantidadDe(ComodinTipo.km1000), 0);
      expect(inventario.cantidadDe(ComodinTipo.km500), 0);
    });

    test('sin filas, el total es 0', () {
      expect(mapearInventario([]).total, 0);
    });
  });

  group('mapearResultadoUsoComodin', () {
    test('tiempo se mapea sin datos propios', () {
      final resultado = mapearResultadoUsoComodin({'tipo': 'tiempo'});

      expect(resultado, isA<ResultadoTiempo>());
    });

    test('pais trae el nombre del pais', () {
      final resultado = mapearResultadoUsoComodin({
        'tipo': 'pais',
        'pais': 'Perú',
      });

      expect(resultado, isA<ResultadoPais>());
      expect((resultado as ResultadoPais).pais, 'Perú');
    });

    test('km1000 trae lat/lng/radio_km', () {
      final resultado = mapearResultadoUsoComodin({
        'tipo': 'km1000',
        'lat': 41.8902,
        'lng': 12.4922,
        'radio_km': 500,
      });

      expect(resultado, isA<ResultadoRadio>());
      final radio = resultado as ResultadoRadio;
      expect(radio.tipo, ComodinTipo.km1000);
      expect(radio.lat, 41.8902);
      expect(radio.lng, 12.4922);
      expect(radio.radioKm, 500);
    });

    test('km500 trae lat/lng/radio_km, con numeric serializado como texto', () {
      final resultado = mapearResultadoUsoComodin({
        'tipo': 'km500',
        'lat': '41.8902',
        'lng': '12.4922',
        'radio_km': '150',
      });

      final radio = resultado as ResultadoRadio;
      expect(radio.tipo, ComodinTipo.km500);
      expect(radio.lat, 41.8902);
      expect(radio.radioKm, 150);
    });
  });

  group('MotivoRechazoComodin.desde', () {
    test('traduce cada mensaje conocido de Postgrest', () {
      expect(
        MotivoRechazoComodin.desde('intento_o_desafio_invalido'),
        MotivoRechazoComodin.intentoODesafioInvalido,
      );
      expect(
        MotivoRechazoComodin.desde('pais_no_disponible'),
        MotivoRechazoComodin.paisNoDisponible,
      );
      expect(
        MotivoRechazoComodin.desde('sin_comodines_disponibles'),
        MotivoRechazoComodin.sinComodinesDisponibles,
      );
      expect(
        MotivoRechazoComodin.desde('comodin_ya_usado_en_este_intento'),
        MotivoRechazoComodin.comodinYaUsadoEnEsteIntento,
      );
      expect(
        MotivoRechazoComodin.desde('tope_diario_alcanzado'),
        MotivoRechazoComodin.topeDiarioAlcanzado,
      );
    });

    test('un mensaje desconocido o nulo cae en desconocido, sin romper', () {
      expect(
        MotivoRechazoComodin.desde('algo_que_no_existe_todavia'),
        MotivoRechazoComodin.desconocido,
      );
      expect(
        MotivoRechazoComodin.desde(null),
        MotivoRechazoComodin.desconocido,
      );
    });
  });
}
