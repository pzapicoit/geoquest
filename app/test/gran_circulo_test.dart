import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:geoquest/mapa/gran_circulo.dart';
import 'package:geoquest/mapa/mapa_mundi_controller.dart';

const _madrid = Coordenada(latitud: 40.4168, longitud: -3.7038);
const _roma = Coordenada(latitud: 41.8902, longitud: 12.4922);
const _tokio = Coordenada(latitud: 35.6762, longitud: 139.6503);
const _sanFrancisco = Coordenada(latitud: 37.7749, longitud: -122.4194);

/// Distancia en km entre dos coordenadas, la misma Haversine que
/// `calcular_distancia_km` en Postgres. Sirve para comprobar que el arco
/// avanza a paso constante.
double _distanciaKm(Coordenada a, Coordenada b) {
  double radianes(double grados) => grados * math.pi / 180;

  final dLat = radianes(b.latitud - a.latitud);
  final dLng = radianes(b.longitud - a.longitud);
  final h =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(radianes(a.latitud)) *
          math.cos(radianes(b.latitud)) *
          math.pow(math.sin(dLng / 2), 2);

  return 2 * 6371 * math.asin(math.min(1, math.sqrt(h.toDouble())));
}

void main() {
  group('interpolarGranCirculo', () {
    test('el arco empieza y acaba en las coordenadas que se le dan', () {
      final arco = interpolarGranCirculo(_madrid, _roma, puntos: 12);

      expect(arco, hasLength(13));
      expect(arco.first.latitud, closeTo(_madrid.latitud, 1e-9));
      expect(arco.first.longitud, closeTo(_madrid.longitud, 1e-9));
      expect(arco.last.latitud, closeTo(_roma.latitud, 1e-9));
      expect(arco.last.longitud, closeTo(_roma.longitud, 1e-9));
    });

    test('avanza a paso constante sobre la esfera', () {
      final arco = interpolarGranCirculo(_madrid, _tokio, puntos: 10);
      final total = _distanciaKm(_madrid, _tokio);

      for (var i = 1; i < arco.length; i++) {
        expect(_distanciaKm(arco[i - 1], arco[i]), closeTo(total / 10, 1));
      }
    });

    test('el punto medio del arco no es la media de las coordenadas', () {
      // Entre Tokio y San Francisco el gran círculo sube hacia las Aleutianas;
      // la recta de Mercator se quedaría cerca del paralelo de partida.
      final arco = interpolarGranCirculo(_tokio, _sanFrancisco, puntos: 2);
      final medioDelArco = arco[1];
      final medioPlano =
          (_tokio.latitud + _sanFrancisco.latitud) / 2; // ≈ 36,7°

      expect(medioDelArco.latitud, greaterThan(medioPlano + 3));
      expect(
        _distanciaKm(_tokio, medioDelArco),
        closeTo(_distanciaKm(_tokio, _sanFrancisco) / 2, 1),
      );
    });

    test('el avance recorta el arco donde toca', () {
      final entero = interpolarGranCirculo(_madrid, _tokio, puntos: 60);
      final mitad = interpolarGranCirculo(
        _madrid,
        _tokio,
        puntos: 60,
        avance: 0.5,
      );

      expect(mitad.first, entero.first);
      expect(
        _distanciaKm(_madrid, mitad.last),
        closeTo(_distanciaKm(_madrid, _tokio) / 2, 1),
      );
    });

    test('sin avance no hay línea que dibujar', () {
      final arco = interpolarGranCirculo(_madrid, _tokio, avance: 0);

      expect(arco, [_madrid]);
    });

    test('un acierto exacto no revienta la interpolación', () {
      final arco = interpolarGranCirculo(_roma, _roma, puntos: 8);

      expect(arco.first, _roma);
      for (final punto in arco) {
        expect(punto.latitud, closeTo(_roma.latitud, 1e-6));
        expect(punto.longitud, closeTo(_roma.longitud, 1e-6));
      }
    });
  });

  group('partirEnElAntimeridiano', () {
    test('un arco que no cruza se queda de una pieza', () {
      final arco = interpolarGranCirculo(_madrid, _roma, puntos: 20);

      final trozos = partirEnElAntimeridiano(arco);

      expect(trozos, hasLength(1));
      expect(trozos.single, hasLength(arco.length));
    });

    test('un arco que cruza el antimeridiano se parte en dos', () {
      // Tokio → San Francisco cruza el Pacífico: sin partirlo, la línea
      // atravesaría el mapa entero por Eurasia (D15 de `design.md`).
      final arco = interpolarGranCirculo(_tokio, _sanFrancisco, puntos: 40);

      final trozos = partirEnElAntimeridiano(arco);

      expect(trozos, hasLength(2));
      expect(trozos.first.first, arco.first);
      expect(trozos.last.last, arco.last);
      // Ningún trozo salta de un borde al otro por dentro.
      for (final trozo in trozos) {
        for (var i = 1; i < trozo.length; i++) {
          expect(
            (trozo[i].longitud - trozo[i - 1].longitud).abs(),
            lessThanOrEqualTo(180),
          );
        }
      }
      expect(
        trozos.fold<int>(0, (suma, trozo) => suma + trozo.length),
        arco.length,
      );
    });

    test('un arco de un solo punto no se parte', () {
      final trozos = partirEnElAntimeridiano(const [_madrid]);

      expect(trozos, hasLength(1));
    });
  });
}
