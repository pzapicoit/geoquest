import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/services.dart' show rootBundle;

import 'mercator.dart';

const String rutaAssetMundo = 'assets/world/world_50m.bin';

const int _firma = 0x47515731; // 'GQW1'

/// Geometría del mundo ya proyectada y lista para dibujar: dos `Path` en
/// coordenadas normalizadas `[0,1] × [0,1]` que el pintor coloca en pantalla
/// con una única transformación del canvas.
///
/// D3 de `design.md` (INT-92): el asset es un binario propio en vez de
/// TopoJSON, porque leerlo es recorrer un `ByteData` y no hace falta ninguna
/// dependencia para decodificar la topología en tiempo de ejecución.
class MundoGeometria {
  const MundoGeometria({
    required this.tierra,
    required this.reticula,
    required this.numeroDePaises,
    required this.numeroDeAnillos,
    required this.numeroDePuntos,
  });

  /// Todos los anillos de todos los países en un solo `Path` con relleno
  /// par-impar. Los países no se solapan y los enclaves llegan como agujero
  /// del país que los rodea, así que par-impar los resuelve solos — y un
  /// único `Path` deja el dibujo del mundo en dos llamadas por fotograma
  /// (relleno y contorno) en vez de casi quinientas.
  final Path tierra;

  /// Meridianos y paralelos cada 10°, como el `geoGraticule10` del mockup.
  final Path reticula;

  final int numeroDePaises;
  final int numeroDeAnillos;
  final int numeroDePuntos;
}

/// Lee el binario y devuelve, por país, sus anillos como listas planas
/// `[lng, lat, lng, lat, ...]`. Dart puro y sin `dart:ui`, para poder
/// comprobar el asset en un test sin levantar un widget.
List<List<Float32List>> leerAnillos(ByteData datos) {
  if (datos.lengthInBytes < 8 || datos.getUint32(0) != _firma) {
    throw const FormatException('El asset del mundo no tiene la firma GQW1');
  }

  final paises = <List<Float32List>>[];
  final numeroDePaises = datos.getUint32(4, Endian.little);
  var offset = 8;

  for (var p = 0; p < numeroDePaises; p++) {
    final numeroDeAnillos = datos.getUint32(offset, Endian.little);
    offset += 4;

    final anillos = <Float32List>[];
    for (var a = 0; a < numeroDeAnillos; a++) {
      final numeroDePuntos = datos.getUint32(offset, Endian.little);
      offset += 4;

      final anillo = Float32List(numeroDePuntos * 2);
      for (var i = 0; i < anillo.length; i++) {
        anillo[i] = datos.getFloat32(offset, Endian.little);
        offset += 4;
      }
      anillos.add(anillo);
    }
    paises.add(anillos);
  }

  return paises;
}

/// Proyecta los anillos a `[0,1] × [0,1]` y arma los `Path` que se dibujan.
MundoGeometria construirGeometria(List<List<Float32List>> paises) {
  final tierra = Path()..fillType = PathFillType.evenOdd;
  var anillos = 0;
  var puntos = 0;

  for (final pais in paises) {
    for (final anillo in pais) {
      final total = anillo.length ~/ 2;
      if (total < 3) continue;

      for (var i = 0; i < total; i++) {
        final x = Mercator.xDeLongitud(anillo[i * 2]);
        final y = Mercator.yDeLatitud(anillo[i * 2 + 1]);
        if (i == 0) {
          tierra.moveTo(x, y);
        } else {
          tierra.lineTo(x, y);
        }
      }
      tierra.close();
      anillos++;
      puntos += total;
    }
  }

  return MundoGeometria(
    tierra: tierra,
    reticula: _construirReticula(),
    numeroDePaises: paises.length,
    numeroDeAnillos: anillos,
    numeroDePuntos: puntos,
  );
}

/// En Mercator los meridianos son rectas verticales y los paralelos rectas
/// horizontales, así que la retícula se genera en código en vez de viajar en
/// el asset.
Path _construirReticula() {
  final reticula = Path();

  for (var longitud = -180; longitud <= 180; longitud += 10) {
    final x = Mercator.xDeLongitud(longitud.toDouble());
    reticula
      ..moveTo(x, 0)
      ..lineTo(x, 1);
  }

  for (var latitud = -80; latitud <= 80; latitud += 10) {
    final y = Mercator.yDeLatitud(latitud.toDouble());
    reticula
      ..moveTo(0, y)
      ..lineTo(1, y);
  }

  return reticula;
}

/// Carga el asset empaquetado. Se llama una vez por pantalla de juego; el
/// coste es leer 785 KB y recorrerlos, no hay red de por medio.
Future<MundoGeometria> cargarMundo() async {
  final datos = await rootBundle.load(rutaAssetMundo);
  return construirGeometria(leerAnillos(datos));
}
