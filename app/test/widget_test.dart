import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geoquest/config/app_config.dart';
import 'package:geoquest/main.dart';
import 'package:geoquest/services/connectivity_check.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _config = AppConfig.forTesting(
  supabaseUrl: 'https://proyecto.supabase.co',
  supabasePublishableKey: 'sb_publishable_test',
);

/// Pantalla con un cliente HTTP falso, para no salir a la red en los tests.
Widget _pantalla(http.Client client) => MaterialApp(
      home: ConnectivityScreen(
        config: _config,
        check: ConnectivityCheck(_config, client: client),
      ),
    );

void main() {
  testWidgets('muestra progreso mientras comprueba', (tester) async {
    final client = MockClient((_) async {
      await Future<void>.delayed(const Duration(seconds: 1));
      return http.Response('{}', 200);
    });

    await tester.pumpWidget(_pantalla(client));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Deja resolver la petición pendiente antes de terminar el test.
    await tester.pumpAndSettle(const Duration(seconds: 2));
  });

  testWidgets('muestra el exito cuando el proyecto responde', (tester) async {
    final client = MockClient((_) async => http.Response('{}', 200));

    await tester.pumpWidget(_pantalla(client));
    await tester.pumpAndSettle();

    expect(find.text('Conectado a Supabase'), findsOneWidget);
  });

  testWidgets('muestra el fallo y el motivo, sin cerrarse, con clave invalida',
      (tester) async {
    final client = MockClient(
      (_) async => http.Response('{"message":"Invalid API key"}', 401),
    );

    await tester.pumpWidget(_pantalla(client));
    await tester.pumpAndSettle();

    expect(find.text('Sin conexión con Supabase'), findsOneWidget);
    expect(find.textContaining('401'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });

  testWidgets('reintentar vuelve a lanzar la comprobacion', (tester) async {
    var llamadas = 0;
    final client = MockClient((_) async {
      llamadas++;
      return http.Response('{}', 200);
    });

    await tester.pumpWidget(_pantalla(client));
    await tester.pumpAndSettle();
    expect(llamadas, 1);

    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(llamadas, 2);
  });
}
