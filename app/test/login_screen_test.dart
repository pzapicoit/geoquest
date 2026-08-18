import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geoquest/screens/camino_screen.dart';
import 'package:geoquest/screens/login_screen.dart';
import 'package:geoquest/screens/username_screen.dart';
import 'package:geoquest/services/camino_gateway.dart';
import 'package:geoquest/services/username_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes/fake_camino_gateway.dart';
import 'fakes/fake_profile_gateway.dart';

const _monumentos = ParadaCamino(
  orden: 1,
  caminoId: 'nivel-1',
  nivelNombre: 'Coliseo',
  tematicaId: 'monumentos',
  tematicaNombre: 'Monumentos',
  superado: true,
  estrellasObtenidas: 3,
  estrellasRequeridas: 0,
  estrellasAcumuladasUsuario: 480,
  desbloqueado: true,
  esActual: false,
);

const _museos = ParadaCamino(
  orden: 2,
  caminoId: 'nivel-2',
  nivelNombre: 'Museos',
  tematicaId: 'museos',
  tematicaNombre: 'Museos',
  superado: false,
  estrellasObtenidas: 0,
  estrellasRequeridas: 800,
  estrellasAcumuladasUsuario: 480,
  desbloqueado: false,
  esActual: false,
);

final _caminoDePrueba = CaminoJugador(
  entradas: [_monumentos, _museos],
  puntosTotales: 1240,
);

Widget _pantalla({
  required UsernameStorage usernameStorage,
  required CaminoGateway caminoGateway,
}) => MaterialApp(
  home: LoginScreen(
    usernameStorage: usernameStorage,
    profileGateway: FakeProfileGateway(),
    caminoGateway: caminoGateway,
  ),
);

Future<void> _pump(
  WidgetTester tester, {
  required UsernameStorage usernameStorage,
  required CaminoGateway caminoGateway,
}) async {
  tester.view.physicalSize = const Size(390, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(
    () => tester.platformDispatcher.clearAccessibilityFeaturesTestValue(),
  );

  await tester.pumpWidget(
    _pantalla(usernameStorage: usernameStorage, caminoGateway: caminoGateway),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('sin apodo guardado, muestra la captura de apodo', (
    tester,
  ) async {
    await _pump(
      tester,
      usernameStorage: UsernameStorage(),
      caminoGateway: FakeCaminoGateway(_caminoDePrueba),
    );

    expect(find.byType(UsernameScreen), findsOneWidget);
  });

  testWidgets(
    'con apodo guardado, saluda al jugador y muestra su progreso real',
    (tester) async {
      SharedPreferences.setMockInitialValues({'username': 'Ana'});

      await _pump(
        tester,
        usernameStorage: UsernameStorage(),
        caminoGateway: FakeCaminoGateway(_caminoDePrueba),
      );

      expect(find.textContaining('¡Hola, Ana!'), findsOneWidget);
      expect(find.text('1240'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.textContaining('Siguiente: Museos'), findsOneWidget);
      expect(find.text('Récord'), findsNothing);
      expect(find.text('Racha'), findsNothing);
      expect(find.textContaining('Última partida'), findsNothing);
    },
  );

  testWidgets('seguir jugando navega al mapa de temáticas', (tester) async {
    SharedPreferences.setMockInitialValues({'username': 'Ana'});

    await _pump(
      tester,
      usernameStorage: UsernameStorage(),
      caminoGateway: FakeCaminoGateway(_caminoDePrueba),
    );

    await tester.tap(find.byKey(const Key('continue-button')));
    await tester.pumpAndSettle();

    expect(find.byType(CaminoScreen), findsOneWidget);
  });

  testWidgets(
    'cambiar de jugador borra el apodo local y vuelve a la captura de apodo',
    (tester) async {
      SharedPreferences.setMockInitialValues({'username': 'Ana'});
      final usernameStorage = UsernameStorage();

      await _pump(
        tester,
        usernameStorage: usernameStorage,
        caminoGateway: FakeCaminoGateway(_caminoDePrueba),
      );

      await tester.tap(find.byKey(const Key('switch-player-button')));
      await tester.pumpAndSettle();

      expect(find.byType(UsernameScreen), findsOneWidget);
      expect(await usernameStorage.read(), isNull);
    },
  );

  testWidgets('el enlace de vincular cuenta no produce ningún efecto', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'username': 'Ana'});

    await _pump(
      tester,
      usernameStorage: UsernameStorage(),
      caminoGateway: FakeCaminoGateway(_caminoDePrueba),
    );

    expect(
      find.textContaining('Vincular una cuenta para no perder el progreso'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('link-account')));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.textContaining('¡Hola, Ana!'), findsOneWidget);
  });

  testWidgets(
    'si falla la carga del progreso, avisa y reintentar lo recupera',
    (tester) async {
      SharedPreferences.setMockInitialValues({'username': 'Ana'});
      final caminoGateway = FakeCaminoGateway(_caminoDePrueba)
        ..throwOnNextCall = Exception('sin conexión');

      await _pump(
        tester,
        usernameStorage: UsernameStorage(),
        caminoGateway: caminoGateway,
      );

      expect(find.text('No se pudo cargar tu progreso'), findsOneWidget);

      await tester.tap(find.byKey(const Key('retry-progress')));
      await tester.pumpAndSettle();

      expect(find.text('No se pudo cargar tu progreso'), findsNothing);
      expect(find.textContaining('Siguiente: Museos'), findsOneWidget);
    },
  );
}
