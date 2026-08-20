import 'dart:math' as math;

import 'mapa_mundi_controller.dart';
import 'mercator.dart';

/// Radio medio de la Tierra en km: la misma esfera que usa
/// `calcular_distancia_km` en Postgres (Haversine). El radio del círculo
/// (`radioKm`) lo decide siempre el servidor (`usar_comodin`), nunca un
/// literal aquí — así un ajuste de balance (INT-119 delta-1: 500/150 km en
/// vez de 1000/500) no toca código de la app.
const double _radioTierraKm = 6371;

/// Puntos del borde de un círculo de [radioKm] centrado en [centro], sobre
/// la esfera.
///
/// D7 de `design.md` (INT-119): análogo a `interpolarGranCirculo` de
/// `gran_circulo.dart`, pero para el borde completo de un círculo en vez de
/// un arco entre dos puntos — la fórmula del "destino esférico" (rumbo +
/// distancia angular) en vez de la interpolación por vectores unitarios,
/// porque aquí no hay dos puntos que unir sino un centro y una distancia
/// fija en todas direcciones.
///
/// Se muestrea en [puntos] rumbos repartidos entre 0 y 360°, cerrando el
/// círculo: el último punto coincide con el primero, igual que necesita
/// `partirEnElAntimeridiano` para trocear un contorno cerrado igual que
/// trocea un arco abierto.
List<Coordenada> puntosDelCirculo(
  Coordenada centro,
  double radioKm, {
  int puntos = 72,
}) {
  assert(puntos >= 3, 'Un círculo necesita al menos tres puntos');
  assert(radioKm > 0, 'El radio tiene que ser positivo');

  final anguloAngular = radioKm / _radioTierraKm;
  final latCentro = centro.latitud * math.pi / 180;
  final lngCentro = centro.longitud * math.pi / 180;
  final senoLat = math.sin(latCentro);
  final cosenoLat = math.cos(latCentro);
  final senoAngular = math.sin(anguloAngular);
  final cosenoAngular = math.cos(anguloAngular);

  return [
    for (var i = 0; i <= puntos; i++)
      _destino(
        senoLat,
        cosenoLat,
        lngCentro,
        senoAngular,
        cosenoAngular,
        (i / puntos) * 2 * math.pi,
      ),
  ];
}

/// Punto a una distancia angular fija de un centro, en el rumbo [rumbo]
/// (radianes, 0 = norte, creciendo en sentido horario) — la fórmula estándar
/// de "destino esférico" a partir de punto+rumbo+distancia.
Coordenada _destino(
  double senoLatCentro,
  double cosenoLatCentro,
  double lngCentro,
  double senoAngular,
  double cosenoAngular,
  double rumbo,
) {
  final latDestino = math.asin(
    (senoLatCentro * cosenoAngular +
            cosenoLatCentro * senoAngular * math.cos(rumbo))
        .clamp(-1.0, 1.0),
  );
  final lngDestino =
      lngCentro +
      math.atan2(
        math.sin(rumbo) * senoAngular * cosenoLatCentro,
        cosenoAngular - senoLatCentro * math.sin(latDestino),
      );

  return Coordenada(
    latitud: latDestino * 180 / math.pi,
    longitud: Mercator.normalizarLongitud(lngDestino * 180 / math.pi),
  );
}
