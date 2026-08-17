import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:geoquest/mapa/mercator.dart';
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

/// Área con signo del anillo, por la fórmula del cordón de zapato sobre la
/// lista plana `[lng, lat, ...]`. La misma que usa el generador.
double _area(Float32List anillo) {
  final total = anillo.length ~/ 2;
  var doble = 0.0;
  for (var i = 0; i < total; i++) {
    final j = (i + 1) % total;
    doble +=
        anillo[i * 2] * anillo[j * 2 + 1] - anillo[j * 2] * anillo[i * 2 + 1];
  }
  return doble / 2;
}

/// Qué fracción del ancho del mundo es tierra a la altura `y` del cuadrado de
/// la proyección, con la misma regla par-impar con la que el pintor rellena.
///
/// Es Dart puro: proyecta los anillos, recoge los cortes de la horizontal y
/// suma los tramos rellenos. No hace falta `dart:ui` ni montar un widget para
/// saber si el mundo llega al borde.
double _fraccionDeTierraEn(List<List<Float32List>> paises, double y) {
  final cortes = <double>[];
  for (final pais in paises) {
    for (final anillo in pais) {
      final total = anillo.length ~/ 2;
      for (var k = 0; k < total; k++) {
        final j = (k + 1) % total;
        final y0 = Mercator.yDeLatitud(anillo[k * 2 + 1]);
        final y1 = Mercator.yDeLatitud(anillo[j * 2 + 1]);
        if ((y0 > y) == (y1 > y)) continue;

        final x0 = Mercator.xDeLongitud(anillo[k * 2]);
        final x1 = Mercator.xDeLongitud(anillo[j * 2]);
        cortes.add(x0 + (y - y0) / (y1 - y0) * (x1 - x0));
      }
    }
  }
  cortes.sort();

  // Con par-impar, los tramos rellenos son los que van del corte par al
  // impar siguiente.
  var relleno = 0.0;
  for (var i = 0; i + 1 < cortes.length; i += 2) {
    final desde = cortes[i].clamp(0.0, 1.0);
    final hasta = cortes[i + 1].clamp(0.0, 1.0);
    if (hasta > desde) relleno += hasta - desde;
  }
  return relleno;
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

  // INT-103. Las cuatro comprobaciones que siguen son invariantes del asset,
  // no valores esperados: el binario se recommitea y un número exacto habría
  // que actualizarlo a mano en cuanto se cambie de dataset. Lo que se fija es
  // lo que no puede dejar de ser cierto.

  test('ningún anillo del asset está colapsado en una línea', () {
    final paises = leerAnillos(_assetDelMundo());

    for (var p = 0; p < paises.length; p++) {
      for (var a = 0; a < paises[p].length; a++) {
        expect(
          _area(paises[p][a]).abs(),
          greaterThan(1e-9),
          reason:
              'El anillo $a del país $p encierra área cero. Un anillo así no '
              'rellena nada pero sí se traza en la pasada de contorno, y '
              'dibuja una raya que no es ninguna frontera.',
        );
      }
    }
  });

  test('ningún segmento del asset cruza el mapa de lado a lado', () {
    final paises = leerAnillos(_assetDelMundo());

    for (var p = 0; p < paises.length; p++) {
      for (var a = 0; a < paises[p].length; a++) {
        final anillo = paises[p][a];
        final total = anillo.length ~/ 2;
        for (var k = 0; k < total; k++) {
          final salto = (anillo[((k + 1) % total) * 2] - anillo[k * 2]).abs();
          expect(
            salto,
            lessThanOrEqualTo(180),
            reason:
                'El anillo $a del país $p salta $salto° de longitud entre dos '
                'vértices. En la proyección eso va de un borde del cuadrado '
                'al otro: hay que partir el anillo en el antimeridiano.',
          );
        }
      }
    }
  });

  test('el mundo llega relleno hasta el canto inferior', () {
    final paises = leerAnillos(_assetDelMundo());

    // Justo por encima del borde del mundo. Con la Antártida sin cerrar aquí
    // había un 0,2 % de tierra: el relleno se cortaba a media pantalla y
    // dejaba una banda de océano que se lee como un mapa recortado.
    expect(_fraccionDeTierraEn(paises, 0.9999), greaterThan(0.95));

    // Y no es que solo toque el canto: la banda entera por debajo de la costa
    // antártica es tierra. Aquí había un 2,3 %.
    expect(_fraccionDeTierraEn(paises, 0.985), greaterThan(0.95));
  });

  test('ningún anillo repite un punto dentro del recorrido', () {
    final paises = leerAnillos(_assetDelMundo());

    for (var p = 0; p < paises.length; p++) {
      for (var a = 0; a < paises[p].length; a++) {
        final anillo = paises[p][a];
        for (var k = 0; k + 3 < anillo.length; k += 2) {
          final repetido =
              anillo[k] == anillo[k + 2] && anillo[k + 1] == anillo[k + 3];
          expect(
            repetido,
            isFalse,
            reason:
                'El anillo $a del país $p repite el punto ${anillo[k]}, '
                '${anillo[k + 1]} en la posición ${k ~/ 2}. Un punto repetido '
                'deja un segmento de longitud cero: sale de cortar el anillo '
                'por un vértice que el dato ya traía duplicado.',
          );
        }
      }
    }
  });

  test('el umbral con el que se descartan los degenerados tiene margen', () {
    final paises = leerAnillos(_assetDelMundo());

    // El generador tira los anillos de área menor que 1e-9. Que ninguna isla
    // legítima ande cerca de ese umbral es lo que hace seguro el filtro; si un
    // dataset futuro trajera uno, este test avisa antes de que desaparezca del
    // mapa sin que nadie se entere.
    final areas = [
      for (final pais in paises)
        for (final anillo in pais) _area(anillo).abs(),
    ]..sort();

    expect(areas.first, greaterThan(1e-6));
  });

  test('el territorio a los dos lados del antimeridiano sigue dibujado', () {
    final paises = leerAnillos(_assetDelMundo());

    var pegadosAlEste = 0;
    var pegadosAlOeste = 0;
    for (final pais in paises) {
      for (final anillo in pais) {
        for (var i = 0; i < anillo.length; i += 2) {
          if (anillo[i] == 180) pegadosAlEste++;
          if (anillo[i] == -180) pegadosAlOeste++;
        }
      }
    }

    // Partir un anillo en el antimeridiano deja cada trozo cerrado contra su
    // borde del mundo. Si solo hubiera vértices de un lado, el partido
    // estaría tirando territorio en vez de repartirlo: Chukotka y la mitad
    // oriental de Fiyi se quedarían sin dibujar.
    expect(pegadosAlEste, greaterThan(0));
    expect(pegadosAlOeste, greaterThan(0));
  });

  test('ningún país se queda sin territorio al regenerar el asset', () {
    final paises = leerAnillos(_assetDelMundo());

    // El generador fusiona, acota y parte anillos. Ninguna de esas reglas
    // puede acabar dejando un país sin nada que dibujar: el juego consiste en
    // reconocer costas, y una isla que desaparece es un desafío sin respuesta.
    for (var p = 0; p < paises.length; p++) {
      expect(
        paises[p].any((anillo) => _area(anillo).abs() > 1e-9),
        isTrue,
        reason: 'El país $p se ha quedado sin ningún anillo con área.',
      );
    }
  });
}
