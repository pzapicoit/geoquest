import 'dart:typed_data';

import 'package:geoquest/mapa/mundo_geometria.dart';

/// Mundo mínimo para montar el mapa en tests sin leer los 785 KB del asset
/// real: un único "país" cuadrado sobre el ecuador (INT-92).
///
/// Lo que se prueba con él es la mecánica —qué coordenada sale de un toque,
/// qué hace cada gesto—, no el dibujo, así que la geometría concreta da
/// igual mientras sea válida.
Future<MundoGeometria> cargarMundoDePrueba() async {
  return construirGeometria([
    [
      Float32List.fromList([
        -20, 20, //
        20, 20,
        20, -20,
        -20, -20,
        -20, 20,
      ]),
    ],
  ]);
}
