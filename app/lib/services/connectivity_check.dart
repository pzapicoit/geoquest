import 'dart:async';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';

/// Resultado de comprobar que la app alcanza el proyecto de Supabase.
sealed class ConnectivityResult {
  const ConnectivityResult();
}

class ConnectivityOk extends ConnectivityResult {
  const ConnectivityOk(this.latency);
  final Duration latency;
}

class ConnectivityFailure extends ConnectivityResult {
  const ConnectivityFailure(this.reason);
  final String reason;
}

/// Comprueba conectividad contra el proyecto de Supabase.
///
/// Usa el endpoint de salud de Auth (`/auth/v1/health`), que responde con la
/// clave publicable y con la base vacía — importante, porque el esquema no
/// existe hasta INT-74.
///
/// Deliberadamente NO usa la raíz de PostgREST (`/rest/v1/`): con el formato
/// nuevo de claves ese endpoint exige clave secreta y devuelve 401 con la
/// publicable ("Only secret API keys can be used for this endpoint"), así que
/// daría un falso negativo.
class ConnectivityCheck {
  ConnectivityCheck(this.config, {http.Client? client, this.timeout = const Duration(seconds: 10)})
      : _client = client ?? http.Client();

  final AppConfig config;
  final Duration timeout;
  final http.Client _client;

  Future<ConnectivityResult> run() async {
    final stopwatch = Stopwatch()..start();
    try {
      final response = await _client.get(
        Uri.parse('${config.supabaseUrl}/auth/v1/health'),
        headers: {'apikey': config.supabasePublishableKey},
      ).timeout(timeout);
      stopwatch.stop();

      if (response.statusCode == 200) {
        return ConnectivityOk(stopwatch.elapsed);
      }
      return ConnectivityFailure(
        'El proyecto respondió HTTP ${response.statusCode}.\n${response.body}',
      );
    } on TimeoutException {
      return ConnectivityFailure('Sin respuesta en ${timeout.inSeconds}s.');
    } catch (error) {
      return ConnectivityFailure('No se pudo alcanzar el proyecto: $error');
    }
  }
}
