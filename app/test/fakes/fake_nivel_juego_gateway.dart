import 'dart:async';

import 'package:geoquest/services/nivel_juego_gateway.dart';

/// Lo que se mandó en una llamada a `responderDesafio`, para poder
/// comprobarlo desde los tests (INT-92).
///
/// `latitud`/`longitud` llegan `null` en una respuesta sin pin (INT-99).
class RespuestaEnviada {
  const RespuestaEnviada({
    required this.intentoId,
    required this.desafioId,
    required this.latitud,
    required this.longitud,
  });

  final String intentoId;
  final String desafioId;
  final double? latitud;
  final double? longitud;
}

/// Respuesta de ejemplo del servidor, para no repetir el revelado entero en
/// cada test que solo mira la distancia o los puntos (INT-93).
///
/// Por defecto trae `puntosBonus = 0` y `puntosDistancia = puntos`: la
/// mayoría de los tests existentes no ejercitan el bonus por rapidez
/// (INT-99), así que asumen su forma más simple. `distanciaKm` es `null`
/// solo cuando el propio test lo pide, para representar una respuesta sin
/// pin.
RespuestaDesafio respuestaDePrueba({
  double? distanciaKm = 118.4,
  int puntos = 4700,
  double latitudReal = 41.8902,
  double longitudReal = 12.4922,
  String nombreLugar = 'Coliseo de Roma',
  int puntosMaximos = 5000,
  int? puntosDistancia,
  int puntosBonus = 0,
}) {
  return RespuestaDesafio(
    distanciaKm: distanciaKm,
    puntos: puntos,
    latitudReal: latitudReal,
    longitudReal: longitudReal,
    nombreLugar: nombreLugar,
    puntosMaximos: puntosMaximos,
    puntosDistancia: puntosDistancia ?? (puntos - puntosBonus),
    puntosBonus: puntosBonus,
  );
}

/// Resultado de ejemplo de cerrar un intento, para no repetir el jsonb
/// entero en cada test que solo mira una parte del resumen (INT-94).
ResultadoIntento resultadoDePrueba({
  int puntajeTotal = 2140,
  bool superado = true,
  int estrellas = 3,
  int puntajeMinimoSuperar = 1500,
  int? mejorPuntajeAnterior = 1820,
}) {
  return ResultadoIntento(
    puntajeTotal: puntajeTotal,
    superado: superado,
    estrellas: estrellas,
    puntajeMinimoSuperar: puntajeMinimoSuperar,
    mejorPuntajeAnterior: mejorPuntajeAnterior,
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

  /// Lo que devuelve `cerrarIntento`; los tests del resumen del nivel la
  /// cambian antes de cerrar (INT-94).
  ResultadoIntento resultado = resultadoDePrueba();

  /// Excepción a lanzar en la próxima llamada a `cerrarIntento`.
  Object? throwOnNextCerrar;

  /// Deja `cerrarIntento` colgado hasta que el test lo complete, mismo
  /// motivo que [pausaAlIniciar].
  Completer<void>? pausaAlCerrar;

  int cerrarIntentoCalls = 0;
  String? ultimoIntentoIdCerrado;

  /// Cada llamada a `marcarDesafioMostrado`, en orden, para comprobar desde
  /// los tests cuándo arranca el cronómetro de cada desafío (INT-99).
  final List<String> desafiosMarcadosMostrados = [];

  @override
  Future<void> marcarDesafioMostrado({
    required String intentoId,
    required String desafioId,
  }) async {
    desafiosMarcadosMostrados.add(desafioId);
  }

  @override
  Future<ResultadoIntento> cerrarIntento(String intentoId) async {
    cerrarIntentoCalls++;
    ultimoIntentoIdCerrado = intentoId;

    await pausaAlCerrar?.future;

    final error = throwOnNextCerrar;
    if (error != null) {
      throwOnNextCerrar = null;
      throw error;
    }

    return resultado;
  }

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
    required double? latitud,
    required double? longitud,
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
