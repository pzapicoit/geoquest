import 'package:flutter_test/flutter_test.dart';
import 'package:geoquest/config/app_config.dart';
import 'package:geoquest/services/connectivity_check.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Config de prueba. No usa AppConfig.fromEnvironment porque eso lee variables
/// de compilación, que en el entorno de test no están definidas.
AppConfig _config() => AppConfig.forTesting(
      supabaseUrl: 'https://proyecto.supabase.co',
      supabasePublishableKey: 'sb_publishable_test',
    );

void main() {
  group('ConnectivityCheck', () {
    test('devuelve ok cuando Auth responde 200', () async {
      final client = MockClient((_) async => http.Response('{}', 200));

      final result = await ConnectivityCheck(_config(), client: client).run();

      expect(result, isA<ConnectivityOk>());
    });

    test('consulta el health de Auth y manda la clave publicable', () async {
      late Uri llamada;
      late Map<String, String> cabeceras;
      final client = MockClient((request) async {
        llamada = request.url;
        cabeceras = request.headers;
        return http.Response('{}', 200);
      });

      await ConnectivityCheck(_config(), client: client).run();

      expect(llamada.path, '/auth/v1/health');
      expect(cabeceras['apikey'], 'sb_publishable_test');
    });

    test('no usa la raiz de PostgREST, que exigiria clave secreta', () async {
      late Uri llamada;
      final client = MockClient((request) async {
        llamada = request.url;
        return http.Response('{}', 200);
      });

      await ConnectivityCheck(_config(), client: client).run();

      expect(llamada.path, isNot('/rest/v1/'));
    });

    test('devuelve fallo con el motivo cuando la clave es invalida', () async {
      final client = MockClient(
        (_) async => http.Response('{"message":"Invalid API key"}', 401),
      );

      final result = await ConnectivityCheck(_config(), client: client).run();

      expect(result, isA<ConnectivityFailure>());
      expect((result as ConnectivityFailure).reason, contains('401'));
      expect(result.reason, contains('Invalid API key'));
    });

    test('devuelve fallo sin propagar la excepcion cuando la red falla', () async {
      final client = MockClient((_) async => throw const SocketExceptionStub());

      final result = await ConnectivityCheck(_config(), client: client).run();

      expect(result, isA<ConnectivityFailure>());
    });

    test('devuelve fallo cuando el proyecto no responde a tiempo', () async {
      final client = MockClient((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        return http.Response('{}', 200);
      });

      final result = await ConnectivityCheck(
        _config(),
        client: client,
        timeout: const Duration(milliseconds: 20),
      ).run();

      expect(result, isA<ConnectivityFailure>());
      expect((result as ConnectivityFailure).reason, contains('Sin respuesta'));
    });
  });
}

class SocketExceptionStub implements Exception {
  const SocketExceptionStub();
  @override
  String toString() => 'SocketException: red caida';
}
