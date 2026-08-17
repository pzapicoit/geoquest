import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:geoquest/mapa/mundo_geometria.dart';

/// Comprueba el asset real que viaja en la app (INT-92). Se lee del disco en
/// vez de por `rootBundle` para que el test valide exactamente el fichero
/// commiteado, sin depender del empaquetado.
ByteData _assetDelMundo() {
  final fichero = File(rutaAssetMundo);
  expect(
    fichero.existsSync(),
    isTrue,
    reason:
        'Falta $rutaAssetMundo. Se regenera con '
        '`dart run tool/build_world_asset.dart`.',
  );
  return ByteData.sublistView(fichero.readAsBytesSync());
}

void main() {
  test('el asset del mundo trae la geometría esperada', () {
    final paises = leerAnillos(_assetDelMundo());

    expect(paises.length, greaterThan(200));

    final anillos = paises.expand((pais) => pais).toList();
    expect(anillos.length, greaterThan(1000));

    final puntos = anillos.fold<int>(0, (n, a) => n + a.length ~/ 2);
    expect(puntos, greaterThan(50000));
  });

  test('todas las coordenadas del asset son coordenadas de verdad', () {
    final paises = leerAnillos(_assetDelMundo());

    for (final pais in paises) {
      for (final anillo in pais) {
        // Un anillo con menos de tres puntos no encierra nada: sería señal
        // de que el cosido de arcos se ha comido geometría.
        expect(anillo.length ~/ 2, greaterThanOrEqualTo(3));

        for (var i = 0; i < anillo.length; i += 2) {
          expect(anillo[i], inInclusiveRange(-180, 180));
          expect(anillo[i + 1], inInclusiveRange(-90, 90));
        }
      }
    }
  });

  test('un binario sin la firma se rechaza en vez de leerse a ciegas', () {
    final basura = ByteData(64)..setUint32(0, 0xDEADBEEF);

    expect(() => leerAnillos(basura), throwsFormatException);
  });

  test('la geometría construida cuenta lo que ha dibujado', () {
    final paises = leerAnillos(_assetDelMundo());
    final geometria = construirGeometria(paises);

    expect(geometria.numeroDePaises, paises.length);
    expect(geometria.numeroDeAnillos, greaterThan(1000));
    expect(geometria.numeroDePuntos, greaterThan(50000));

    // El mundo proyectado ocupa exactamente el cuadrado [0,1]: es lo que da
    // por hecho la cámara al colocar y recortar.
    final limites = geometria.tierra.getBounds();
    expect(limites.left, greaterThanOrEqualTo(-1e-6));
    expect(limites.top, greaterThanOrEqualTo(-1e-6));
    expect(limites.right, lessThanOrEqualTo(1 + 1e-6));
    expect(limites.bottom, lessThanOrEqualTo(1 + 1e-6));
  });
}
