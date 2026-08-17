import 'dart:math' as math;

import 'mapa_mundi_controller.dart';

/// Ruta más corta sobre la esfera —el arco de gran círculo— entre dos
/// coordenadas, troceada en puntos.
///
/// D6 de `design.md` (INT-93): es el `d3.geoInterpolate` del diseño escrito a
/// mano, interpolando sobre vectores unitarios. La línea del revelado tiene
/// que curvarse como se curva un vuelo, no seguir la recta que dibuja
/// Mercator: entre Madrid y Tokio la diferencia es media Siberia.
///
/// [avance] recorta el arco —1 llega hasta [destino], 0,4 se queda en el 40 %
/// del camino—, que es cómo se traza la línea poco a poco. [puntos] es en
/// cuántos tramos se trocea lo que se devuelve.
List<Coordenada> interpolarGranCirculo(
  Coordenada origen,
  Coordenada destino, {
  int puntos = 60,
  double avance = 1,
}) {
  assert(puntos >= 1, 'Un arco necesita al menos un tramo');

  final recorrido = avance.clamp(0.0, 1.0);
  if (recorrido == 0) return [origen];

  final desde = _PuntoDeLaEsfera.de(origen);
  final hasta = _PuntoDeLaEsfera.de(destino);
  final angulo = desde.anguloHasta(hasta);
  final seno = math.sin(angulo);

  // Mismo punto o antípodas: no hay un único gran círculo que los una, así
  // que se cae a interpolar la coordenada en línea recta. Para llegar aquí
  // hacen falta nueve decimales de coincidencia, así que en la práctica solo
  // pasa cuando el jugador clava el pin exactamente en el sitio.
  if (seno.abs() < 1e-9) {
    return [
      origen,
      Coordenada(
        latitud:
            origen.latitud + (destino.latitud - origen.latitud) * recorrido,
        longitud:
            origen.longitud + (destino.longitud - origen.longitud) * recorrido,
      ),
    ];
  }

  return [
    for (var i = 0; i <= puntos; i++)
      _enElArco(desde, hasta, angulo, seno, (i / puntos) * recorrido),
  ];
}

/// Parte un arco allí donde cruza el antimeridiano.
///
/// El mundo del mapa no se repite (INT-92), así que una línea que salta de
/// 179° E a 179° O cruzaría la pantalla entera de lado a lado dibujando
/// justo la ruta que no es. Partida en dos, cada trozo se va por su borde,
/// que es como se dibuja siempre una ruta de vuelo sobre un plano.
List<List<Coordenada>> partirEnElAntimeridiano(List<Coordenada> arco) {
  if (arco.length < 2) return [arco];

  final trozos = <List<Coordenada>>[];
  var trozo = <Coordenada>[arco.first];
  for (var i = 1; i < arco.length; i++) {
    if ((arco[i].longitud - arco[i - 1].longitud).abs() > 180) {
      trozos.add(trozo);
      trozo = <Coordenada>[];
    }
    trozo.add(arco[i]);
  }
  trozos.add(trozo);

  return trozos;
}

Coordenada _enElArco(
  _PuntoDeLaEsfera desde,
  _PuntoDeLaEsfera hasta,
  double angulo,
  double seno,
  double t,
) {
  final pesoDesde = math.sin((1 - t) * angulo) / seno;
  final pesoHasta = math.sin(t * angulo) / seno;

  return _PuntoDeLaEsfera(
    x: desde.x * pesoDesde + hasta.x * pesoHasta,
    y: desde.y * pesoDesde + hasta.y * pesoHasta,
    z: desde.z * pesoDesde + hasta.z * pesoHasta,
  ).aCoordenada();
}

/// Una coordenada como vector en el espacio, que es donde interpolar sobre la
/// esfera es una suma ponderada y no una fórmula con casos especiales.
class _PuntoDeLaEsfera {
  const _PuntoDeLaEsfera({required this.x, required this.y, required this.z});

  factory _PuntoDeLaEsfera.de(Coordenada coordenada) {
    final latitud = coordenada.latitud * math.pi / 180;
    final longitud = coordenada.longitud * math.pi / 180;
    final cosenoDeLatitud = math.cos(latitud);

    return _PuntoDeLaEsfera(
      x: cosenoDeLatitud * math.cos(longitud),
      y: cosenoDeLatitud * math.sin(longitud),
      z: math.sin(latitud),
    );
  }

  final double x;
  final double y;
  final double z;

  double anguloHasta(_PuntoDeLaEsfera otro) {
    final producto = x * otro.x + y * otro.y + z * otro.z;
    return math.acos(producto.clamp(-1.0, 1.0));
  }

  Coordenada aCoordenada() {
    final norma = math.max(math.sqrt(x * x + y * y + z * z), 1e-12);

    return Coordenada(
      latitud: math.asin((z / norma).clamp(-1.0, 1.0)) * 180 / math.pi,
      longitud: math.atan2(y, x) * 180 / math.pi,
    );
  }
}
