import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geoquest/config/app_config.dart';
import 'package:geoquest/screens/login_screen.dart';
import 'package:geoquest/screens/splash_screen.dart';
import 'package:geoquest/screens/username_screen.dart';
import 'package:geoquest/services/anonymous_session_service.dart';
import 'package:geoquest/services/camino_gateway.dart';
import 'package:geoquest/services/device_id_service.dart';
import 'package:geoquest/services/username_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fakes/fake_auth_gateway.dart';
import 'fakes/fake_camino_gateway.dart';

const _config = AppConfig.forTesting(
  supabaseUrl: 'https://proyecto.supabase.co',
  supabasePublishableKey: 'sb_publishable_test',
);

const _caminoVacio = CaminoJugador(entradas: [], puntosTotales: 0);

Widget _pantalla({
  required AnonymousSessionService service,
  Duration minDuration = Duration.zero,
  CaminoGateway? caminoGateway,
}) => MaterialApp(
  home: SplashScreen(
    config: _config,
    sessionService: service,
    usernameStorage: UsernameStorage(),
    caminoGateway: caminoGateway ?? FakeCaminoGateway(_caminoVacio),
    minDuration: minDuration,
  ),
);

Session _fakeSession() => Session(
  accessToken: 'fake-access-token',
  tokenType: 'bearer',
  user: const User(
    id: 'fake-user-id',
    appMetadata: {},
    userMetadata: {},
    aud: 'authenticated',
    createdAt: '2026-08-15T00:00:00Z',
    isAnonymous: true,
  ),
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // Varios tests navegan a UsernameScreen, cuya cabecera anima el
    // logo/wordmark y hace flotar insignias en bucle infinito; sin esto,
    // pumpAndSettle() nunca terminaría de asentar.
    TestWidgetsFlutterBinding
        .instance
        .platformDispatcher
        .accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
      disableAnimations: true,
    );
  });

  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher
        .clearAccessibilityFeaturesTestValue();
  });

  testWidgets('muestra el logo y la marca de GeoQuest mientras carga', (
    tester,
  ) async {
    final service = AnonymousSessionService(
      FakeAuthGateway(),
      DeviceIdService(),
    );

    await tester.pumpWidget(_pantalla(service: service));
    await tester.pump();

    expect(find.byType(Image), findsOneWidget);
    expect(find.byKey(const Key('splash-wordmark')), findsOneWidget);

    await tester.pumpAndSettle();
  });

  testWidgets('sin sesión guardada, crea una sesión anónima', (tester) async {
    final auth = FakeAuthGateway();
    final service = AnonymousSessionService(auth, DeviceIdService());

    await tester.pumpWidget(_pantalla(service: service));
    await tester.pumpAndSettle();

    expect(auth.signInAnonymouslyCalls, 1);
  });

  testWidgets('con sesión ya guardada, no crea una sesión nueva', (
    tester,
  ) async {
    final auth = FakeAuthGateway(initialSession: _fakeSession());
    final service = AnonymousSessionService(auth, DeviceIdService());

    await tester.pumpWidget(_pantalla(service: service));
    await tester.pumpAndSettle();

    expect(auth.signInAnonymouslyCalls, 0);
  });

  testWidgets(
    'sin nombre de usuario guardado, navega a la pantalla de nombre de usuario',
    (tester) async {
      final service = AnonymousSessionService(
        FakeAuthGateway(),
        DeviceIdService(),
      );

      await tester.pumpWidget(_pantalla(service: service));
      await tester.pumpAndSettle();

      expect(find.byType(UsernameScreen), findsOneWidget);
    },
  );

  testWidgets(
    'con nombre de usuario guardado, navega a la bienvenida de regreso',
    (tester) async {
      SharedPreferences.setMockInitialValues({'username': 'Ana'});
      final service = AnonymousSessionService(
        FakeAuthGateway(),
        DeviceIdService(),
      );

      await tester.pumpWidget(_pantalla(service: service));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(UsernameScreen), findsNothing);
      expect(find.textContaining('¡Hola, Ana!'), findsOneWidget);
    },
  );

  testWidgets(
    'muestra el fallo con opción de reintentar cuando falla la sesión',
    (tester) async {
      final auth = FakeAuthGateway()
        ..throwOnNextCall = const AuthException(
          'Proveedor anónimo deshabilitado',
        );
      final service = AnonymousSessionService(auth, DeviceIdService());

      await tester.pumpWidget(_pantalla(service: service));
      await tester.pumpAndSettle();

      expect(find.text('No se pudo iniciar sesión'), findsOneWidget);
      expect(find.text('Proveedor anónimo deshabilitado'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
    },
  );

  testWidgets('reintentar tras un fallo vuelve a intentar y puede navegar', (
    tester,
  ) async {
    final auth = FakeAuthGateway()
      ..throwOnNextCall = const AuthException(
        'Proveedor anónimo deshabilitado',
      );
    final service = AnonymousSessionService(auth, DeviceIdService());

    await tester.pumpWidget(_pantalla(service: service));
    await tester.pumpAndSettle();
    expect(auth.signInAnonymouslyCalls, 1);

    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(auth.signInAnonymouslyCalls, 2);
    expect(find.byType(UsernameScreen), findsOneWidget);
  });

  testWidgets(
    'permanece el tiempo mínimo aunque la sesión resuelva al instante',
    (tester) async {
      final service = AnonymousSessionService(
        FakeAuthGateway(),
        DeviceIdService(),
      );

      await tester.pumpWidget(
        _pantalla(
          service: service,
          minDuration: const Duration(milliseconds: 500),
        ),
      );

      // La sesión resuelve casi al instante, pero el mínimo aún no se cumple.
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.byType(UsernameScreen), findsNothing);

      // Con las animaciones desactivadas (ver setUp) nada mantiene
      // pumpAndSettle() bombeando frames por sí solo, así que se avanza
      // explícitamente el tiempo mínimo restante antes de asentar.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.byType(UsernameScreen), findsOneWidget);
    },
  );

  testWidgets('muestra la tarjeta de consejo mientras carga', (tester) async {
    final service = AnonymousSessionService(
      FakeAuthGateway(),
      DeviceIdService(),
    );

    await tester.pumpWidget(
      _pantalla(
        service: service,
        minDuration: const Duration(milliseconds: 500),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('desbloquear su pregunta'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
  });

  testWidgets(
    'con animaciones en bucle activas (halo, brillo), pumpAndSettle no se '
    'cuelga',
    (tester) async {
      final service = AnonymousSessionService(
        FakeAuthGateway(),
        DeviceIdService(),
      );

      await tester.pumpWidget(
        _pantalla(
          service: service,
          minDuration: const Duration(milliseconds: 500),
        ),
      );

      // Si algún HaloPulse o el brillo de la barra ignorase
      // disableAnimations y quedara en bucle infinito, alguno de estos
      // pumpAndSettle lanzaría un timeout en vez de terminar.
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.byType(UsernameScreen), findsOneWidget);
    },
  );
}
