import 'dart:async';

import 'package:geoquest/services/nivel_juego_gateway.dart';

/// Lo que se mandó en una llamada a `responderDesafio`, para poder
/// comprobarlo desde los tests (INT-92).
class RespuestaEnviada {
  const RespuestaEnviada({
    required this.intentoId,
    required this.desafioId,
    required this.latitud,
    required this.longitud,
  });

  final String intentoId;
  final String desafioId;
  final double latitud;
  final double longitud;
}

/// Respuesta de ejemplo del servidor, para no repetir el revelado entero en
/// cada test que solo mira la distancia o los puntos (INT-93).
RespuestaDesafio respuestaDePrueba({
  double distanciaKm = 118.4,
  int puntos = 4700,
  double latitudReal = 41.8902,
  double longitudReal = 12.4922,
  String nombreLugar = 'Coliseo de Roma',
  int puntosMaximos = 5000,
}) {
  return RespuestaDesafio(
    distanciaKm: distanciaKm,
    puntos: puntos,
    latitudReal: latitudReal,
    longitudReal: longitudReal,
    nombreLugar: nombreLugar,
    puntosMaximos: puntosMaximos,
  );
}

/// Falso de [NivelJuegoGateway] para probar la pantalla de juego sin salir
/// a la red (INT-91).
class FakeNivelJuegoGateway implements NivelJuegoGateway {
  FakeNivelJuegoGateway(this.intento);

  IntentoNivel intento;

  /// Excepción a lanzar en la próxima llamada, si se define.
  Object? throwOnNextCall;

  int iniciarIntentoCalls = 0;
  String? ultimoNivelId;

  /// Deja `iniciarIntento` colgado hasta que el test lo complete, para poder
  /// mirar el estado de carga sin depender de cuántos fotogramas caben antes
  /// de que se resuelva un `Future` inmediato.
  Completer<void>? pausaAlIniciar;

  /// Lo que devuelve `responderDesafio`; los tests que comprueban el puntaje
  /// o el revelado la cambian antes de confirmar (INT-92, INT-93).
  RespuestaDesafio respuesta = respuestaDePrueba();

  /// Excepción a lanzar en la próxima llamada a `responderDesafio`.
  Object? throwOnNextResponder;

  final List<RespuestaEnviada> respuestasEnviadas = [];

  @override
  Future<IntentoNivel> iniciarIntento(String nivelId) async {
    iniciarIntentoCalls++;
    ultimoNivelId = nivelId;

    await pausaAlIniciar?.future;

    final error = throwOnNextCall;
    if (error != null) {
      throwOnNextCall = null;
      throw error;
    }

    return intento;
  }

  @override
  Future<RespuestaDesafio> responderDesafio({
    required String intentoId,
    required String desafioId,
    required double latitud,
    required double longitud,
  }) async {
    respuestasEnviadas.add(
      RespuestaEnviada(
        intentoId: intentoId,
        desafioId: desafioId,
        latitud: latitud,
        longitud: longitud,
      ),
    );

    final error = throwOnNextResponder;
    if (error != null) {
      throwOnNextResponder = null;
      throw error;
    }

    return respuesta;
  }
}
