import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geoquest/screens/camino_screen.dart';
import 'package:geoquest/screens/login_screen.dart';
import 'package:geoquest/screens/username_screen.dart';
import 'package:geoquest/services/camino_gateway.dart';
import 'package:geoquest/services/player_roster_storage.dart';
import 'package:geoquest/services/player_session_service.dart';
import 'package:geoquest/services/username_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fakes/fake_auth_gateway.dart';
import 'fakes/fake_camino_gateway.dart';
import 'fakes/fake_estado_apodo_gateway.dart';
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
  mejorPuntaje: 1240,
  puntosAcumulados: 1240,
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
  mejorPuntaje: 0,
  puntosAcumulados: 1240,
);

final _caminoDePrueba = CaminoJugador(
  entradas: [_monumentos, _museos],
  puntosTotales: 1240,
);

/// Servicio de sesión con falsos. Sin él, la pantalla construiría el suyo
/// contra `Supabase.instance`, que en un test no está inicializado.
PlayerSessionService _sessionService({
  required UsernameStorage usernameStorage,
  required FakeAuthGateway auth,
}) => PlayerSessionService(
  auth: auth,
  profile: FakeProfileGateway(),
  estadoApodo: FakeEstadoApodoGateway(),
  usernameStorage: usernameStorage,
  roster: PlayerRosterStorage(),
);

Widget _pantalla({
  required UsernameStorage usernameStorage,
  required CaminoGateway caminoGateway,
  required FakeAuthGateway auth,
}) => MaterialApp(
  home: LoginScreen(
    usernameStorage: usernameStorage,
    profileGateway: FakeProfileGateway(),
    caminoGateway: caminoGateway,
    sessionService: _sessionService(
      usernameStorage: usernameStorage,
      auth: auth,
    ),
  ),
);

Future<void> _pump(
  WidgetTester tester, {
  required UsernameStorage usernameStorage,
  required CaminoGateway caminoGateway,
  FakeAuthGateway? auth,
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
    _pantalla(
      usernameStorage: usernameStorage,
      caminoGateway: caminoGateway,
      auth: auth ?? _conContrasena(),
    ),
  );
  await tester.pumpAndSettle();
}

/// Jugador con contraseña: tiene identidad, así que puede irse y volver.
FakeAuthGateway _conContrasena() {
  final auth = FakeAuthGateway();
  auth.signInWithPassword(email: 'quien-sea@geoquest.invalid', password: 'x');
  return auth;
}

/// Invitado: sesión anónima sin identidad, alcanzable solo desde este móvil.
FakeAuthGateway _sinContrasena() {
  final auth = FakeAuthGateway();
  auth.signInAnonymously();
  return auth;
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

  testWidgets('un jugador sin contraseña no puede irse sin ponerse una', (
    tester,
  ) async {
    // Su perfil solo existe en este móvil: soltar la sesión lo perdería.
    SharedPreferences.setMockInitialValues({'username': 'GeoLince'});
    final usernameStorage = UsernameStorage();
    final auth = _sinContrasena();

    await _pump(
      tester,
      usernameStorage: usernameStorage,
      caminoGateway: FakeCaminoGateway(_caminoDePrueba),
      auth: auth,
    );

    await tester.tap(find.byKey(const Key('switch-player-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('protect-password-field')), findsOneWidget);
    expect(auth.signOutCalls, 0);
    expect(await usernameStorage.read(), 'GeoLince');
  });

  testWidgets('descartar a conciencia sí suelta al jugador sin contraseña', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'username': 'GeoLince'});
    final usernameStorage = UsernameStorage();
    final auth = _sinContrasena();

    await _pump(
      tester,
      usernameStorage: usernameStorage,
      caminoGateway: FakeCaminoGateway(_caminoDePrueba),
      auth: auth,
    );

    await tester.tap(find.byKey(const Key('switch-player-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('discard-player')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-discard')));
    await tester.pumpAndSettle();

    expect(find.byType(UsernameScreen), findsOneWidget);
    expect(auth.signOutCalls, 1);
    expect(await usernameStorage.read(), isNull);
  });

  testWidgets(
    'a un jugador sin contraseña se le ofrece ponérsela, no vincular cuenta',
    (tester) async {
      SharedPreferences.setMockInitialValues({'username': 'GeoLince'});

      await _pump(
        tester,
        usernameStorage: UsernameStorage(),
        caminoGateway: FakeCaminoGateway(_caminoDePrueba),
        auth: _sinContrasena(),
      );

      expect(find.byKey(const Key('protect-progress')), findsOneWidget);
      expect(find.byKey(const Key('link-account')), findsNothing);
    },
  );

  testWidgets('poner contraseña desde el aviso deja cambiar de jugador', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'username': 'GeoLince'});
    final usernameStorage = UsernameStorage();
    final auth = _sinContrasena();

    await _pump(
      tester,
      usernameStorage: usernameStorage,
      caminoGateway: FakeCaminoGateway(_caminoDePrueba),
      auth: auth,
    );

    await tester.tap(find.byKey(const Key('switch-player-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('protect-password-field')),
      'secreta123',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('save-password')));
    await tester.pumpAndSettle();

    // El mismo usuario conserva su perfil y ahora sí puede irse.
    expect(auth.updateUserCalls, 1);
    expect(auth.signOutCalls, 1);
    expect(find.byType(UsernameScreen), findsOneWidget);
    expect(await usernameStorage.read(), isNull);
  });

  testWidgets(
    'si no se puede guardar la contraseña, avisa y no suelta la sesión',
    (tester) async {
      SharedPreferences.setMockInitialValues({'username': 'GeoLince'});
      final usernameStorage = UsernameStorage();
      final auth = _sinContrasena()
        ..throwOnUpdateUser = const AuthException('sin conexión');

      await _pump(
        tester,
        usernameStorage: usernameStorage,
        caminoGateway: FakeCaminoGateway(_caminoDePrueba),
        auth: auth,
      );

      await tester.tap(find.byKey(const Key('switch-player-button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('protect-password-field')),
        'secreta123',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('save-password')));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('No se pudo guardar la contraseña'),
        findsOneWidget,
      );
      expect(auth.signOutCalls, 0);
      expect(await usernameStorage.read(), 'GeoLince');
    },
  );

  testWidgets('una contraseña corta no habilita el guardado en el aviso', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'username': 'GeoLince'});

    await _pump(
      tester,
      usernameStorage: UsernameStorage(),
      caminoGateway: FakeCaminoGateway(_caminoDePrueba),
      auth: _sinContrasena(),
    );

    await tester.tap(find.byKey(const Key('switch-player-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('protect-password-field')),
      'corta',
    );
    await tester.pump();

    final boton = tester.widget<TextButton>(
      find.byKey(const Key('save-password')),
    );
    expect(boton.onPressed, isNull);
  });

  testWidgets('si no se puede cerrar la sesión, se avisa y no se cambia', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'username': 'Ana'});
    final usernameStorage = UsernameStorage();
    final auth = _conContrasena()
      ..throwOnSignOut = const AuthException('sin conexión');

    await _pump(
      tester,
      usernameStorage: usernameStorage,
      caminoGateway: FakeCaminoGateway(_caminoDePrueba),
      auth: auth,
    );

    await tester.tap(find.byKey(const Key('switch-player-button')));
    await tester.pumpAndSettle();

    expect(find.textContaining('No se pudo cerrar la sesión'), findsOneWidget);
    expect(find.textContaining('¡Hola, Ana!'), findsOneWidget);
    expect(await usernameStorage.read(), 'Ana');
  });

  testWidgets('el enlace de ponerse contraseña abre el aviso', (tester) async {
    SharedPreferences.setMockInitialValues({'username': 'GeoLince'});

    await _pump(
      tester,
      usernameStorage: UsernameStorage(),
      caminoGateway: FakeCaminoGateway(_caminoDePrueba),
      auth: _sinContrasena(),
    );

    await tester.tap(find.byKey(const Key('protect-progress')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('protect-password-field')), findsOneWidget);
  });

  testWidgets('cancelar el descarte deja al jugador donde estaba', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'username': 'GeoLince'});
    final usernameStorage = UsernameStorage();
    final auth = _sinContrasena();

    await _pump(
      tester,
      usernameStorage: usernameStorage,
      caminoGateway: FakeCaminoGateway(_caminoDePrueba),
      auth: auth,
    );

    await tester.tap(find.byKey(const Key('switch-player-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('discard-player')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(auth.signOutCalls, 0);
    expect(await usernameStorage.read(), 'GeoLince');
  });
}
