import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geoquest/config/app_config.dart';
import 'package:geoquest/main.dart';
import 'package:geoquest/services/anonymous_session_service.dart';
import 'package:geoquest/services/device_id_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fakes/fake_auth_gateway.dart';

const _config = AppConfig.forTesting(
  supabaseUrl: 'https://proyecto.supabase.co',
  supabasePublishableKey: 'sb_publishable_test',
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget pantalla(AnonymousSessionService service) => MaterialApp(
    home: SessionGate(config: _config, sessionService: service),
  );

  testWidgets('muestra progreso mientras arranca la sesión', (tester) async {
    final auth = FakeAuthGateway();
    final service = AnonymousSessionService(auth, DeviceIdService());

    await tester.pumpWidget(pantalla(service));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();
  });

  testWidgets('con sesión lista, deja pasar a la pantalla de conectividad', (
    tester,
  ) async {
    final auth = FakeAuthGateway();
    final service = AnonymousSessionService(auth, DeviceIdService());

    await tester.pumpWidget(pantalla(service));
    await tester.pumpAndSettle();

    expect(find.text('GeoQuest — entorno'), findsOneWidget);
  });

  testWidgets(
    'muestra el fallo con opción de reintentar cuando el alta anónima falla',
    (tester) async {
      final auth = FakeAuthGateway()
        ..throwOnNextCall = const AuthException(
          'Proveedor anónimo deshabilitado',
        );
      final service = AnonymousSessionService(auth, DeviceIdService());

      await tester.pumpWidget(pantalla(service));
      await tester.pumpAndSettle();

      expect(find.text('No se pudo iniciar sesión'), findsOneWidget);
      expect(find.text('Proveedor anónimo deshabilitado'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
    },
  );

  testWidgets('reintentar tras un fallo vuelve a intentar el alta anónima', (
    tester,
  ) async {
    final auth = FakeAuthGateway()
      ..throwOnNextCall = const AuthException(
        'Proveedor anónimo deshabilitado',
      );
    final service = AnonymousSessionService(auth, DeviceIdService());

    await tester.pumpWidget(pantalla(service));
    await tester.pumpAndSettle();
    expect(auth.signInAnonymouslyCalls, 1);

    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(auth.signInAnonymouslyCalls, 2);
    expect(find.text('GeoQuest — entorno'), findsOneWidget);
  });
}
