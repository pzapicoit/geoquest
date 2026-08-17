import 'dart:math' as math;

/// Proyección Mercator sobre un cuadrado normalizado `[0,1] × [0,1]`
/// (convención web-mercator: `x = 0` es 180° O, `y = 0` es el borde norte).
///
/// D4 de `design.md` (INT-92): son diez líneas de matemáticas conocidas, así
/// que no se añade ninguna dependencia. Todo lo que la pantalla necesita
/// —dónde cae una coordenada y qué coordenada hay bajo un punto— sale de
/// aquí, y se prueba sin construir un solo widget.
class Mercator {
  const Mercator._();

  /// Latitud a la que Mercator cierra el mundo en un cuadrado perfecto. Más
  /// allá la proyección se dispara hacia el infinito, así que ni se dibuja ni
  /// se puede marcar (ver Risks de `design.md`: la Antártida queda fuera).
  static const double latitudMaxima = 85.05112877980659;

  static double xDeLongitud(double longitud) => (longitud + 180) / 360;

  static double yDeLatitud(double latitud) {
    final acotada = latitud.clamp(-latitudMaxima, latitudMaxima);
    final radianes = acotada * math.pi / 180;
    return 0.5 - math.log(math.tan(math.pi / 4 + radianes / 2)) / (2 * math.pi);
  }

  static double longitudDeX(double x) => x * 360 - 180;

  static double latitudDeY(double y) {
    final radianes =
        2 * math.atan(math.exp((0.5 - y) * 2 * math.pi)) - math.pi / 2;
    return radianes * 180 / math.pi;
  }

  /// Lleva cualquier longitud al rango `[-180, 180]`, que es lo que espera
  /// `desafios.lng_real` (constraint del esquema) y lo que la RPC
  /// `responder_desafio` va a recibir.
  static double normalizarLongitud(double longitud) {
    final desplazada = (longitud + 180) % 360;
    return (desplazada < 0 ? desplazada + 360 : desplazada) - 180;
  }
}
