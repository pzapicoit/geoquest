import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:geoquest/mapa/circulo_radio.dart';
import 'package:geoquest/mapa/mapa_mundi_controller.dart';

const _madrid = Coordenada(latitud: 40.4168, longitud: -3.7038);
const _ecuador = Coordenada(latitud: 0, longitud: 0);
const _cercaDelPolo = Coordenada(latitud: 80, longitud: 45);
const _cercaDelAntimeridiano = Coordenada(latitud: 10, longitud: 179.5);

/// Distancia en km entre dos coordenadas (Haversine), la misma fórmula que
/// usa `gran_circulo_test.dart` para comprobar el arco de gran círculo:
/// sirve igual aquí para comprobar que cada punto del borde cae a la
/// distancia pedida del centro.
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
  group('puntosDelCirculo', () {
    test('cada punto del borde cae a radioKm del centro', () {
      final borde = puntosDelCirculo(_madrid, 1000, puntos: 36);

      for (final punto in borde) {
        expect(_distanciaKm(_madrid, punto), closeTo(1000, 1));
      }
    });

    test('se cierra: el último punto coincide con el primero', () {
      final borde = puntosDelCirculo(_madrid, 500, puntos: 24);

      expect(borde, hasLength(25));
      expect(borde.first.latitud, closeTo(borde.last.latitud, 1e-9));
      expect(borde.first.longitud, closeTo(borde.last.longitud, 1e-9));
    });

    test('funciona igual centrado en el ecuador', () {
      final borde = puntosDelCirculo(_ecuador, 500, puntos: 12);

      for (final punto in borde) {
        expect(_distanciaKm(_ecuador, punto), closeTo(500, 1));
      }
    });

    test('funciona cerca de un polo, sin latitudes fuera de rango', () {
      final borde = puntosDelCirculo(_cercaDelPolo, 1000, puntos: 40);

      for (final punto in borde) {
        expect(punto.latitud, inInclusiveRange(-90, 90));
        expect(_distanciaKm(_cercaDelPolo, punto), closeTo(1000, 2));
      }
    });

    test('funciona cerca del antimeridiano, con longitudes normalizadas', () {
      final borde = puntosDelCirculo(_cercaDelAntimeridiano, 500, puntos: 40);

      for (final punto in borde) {
        expect(punto.longitud, inInclusiveRange(-180, 180));
        expect(_distanciaKm(_cercaDelAntimeridiano, punto), closeTo(500, 1));
      }
    });

    test('un radio mayor deja los puntos más lejos del centro', () {
      final cerca = puntosDelCirculo(_madrid, 500, puntos: 8);
      final lejos = puntosDelCirculo(_madrid, 1000, puntos: 8);

      for (var i = 0; i < cerca.length; i++) {
        expect(
          _distanciaKm(_madrid, lejos[i]),
          greaterThan(_distanciaKm(_madrid, cerca[i])),
        );
      }
    });
  });
}
