import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geoquest/screens/camino_screen.dart';
import 'package:geoquest/screens/username_screen.dart';
import 'package:geoquest/services/estado_apodo_gateway.dart';
import 'package:geoquest/services/player_roster_storage.dart';
import 'package:geoquest/services/player_session_service.dart';
import 'package:geoquest/services/username_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fakes/fake_auth_gateway.dart';
import 'fakes/fake_estado_apodo_gateway.dart';
import 'fakes/fake_profile_gateway.dart';

late FakeAuthGateway auth;
late FakeEstadoApodoGateway estadoApodo;

Widget _pantalla({
  required FakeProfileGateway profileGateway,
  UsernameStorage? usernameStorage,
  PlayerRosterStorage? rosterStorage,
}) {
  final storage = usernameStorage ?? UsernameStorage();
  final roster = rosterStorage ?? PlayerRosterStorage();

  return MaterialApp(
    home: UsernameScreen(
      usernameStorage: storage,
      profileGateway: profileGateway,
      rosterStorage: roster,
      sessionService: PlayerSessionService(
        auth: auth,
        profile: profileGateway,
        estadoApodo: estadoApodo,
        usernameStorage: storage,
        roster: roster,
      ),
    ),
  );
}

Finder get _startButton => find.widgetWithText(FilledButton, 'Empezar a jugar');
Finder get _nicknameField => find.byKey(const Key('nickname-field'));
Finder get _passwordField => find.byKey(const Key('password-field'));

/// El diseño usa una cabecera de marca alta (`_heroHeight`); en el tamaño
/// de superficie por defecto de los tests (800x600) el resto del contenido
/// queda fuera del área táctil. Se agranda la superficie al tamaño de un
/// teléfono real para que los `tap()` lleguen a los widgets.
Future<void> _pump(
  WidgetTester tester, {
  required FakeProfileGateway profileGateway,
  UsernameStorage? usernameStorage,
  PlayerRosterStorage? rosterStorage,
}) async {
  tester.view.physicalSize = const Size(390, 2200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  // El hero anima el logo/wordmark y hace flotar las insignias en bucle
  // infinito; sin esto, pumpAndSettle() nunca terminaría de asentar.
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(
    () => tester.platformDispatcher.clearAccessibilityFeaturesTestValue(),
  );

  await tester.pumpWidget(
    _pantalla(
      profileGateway: profileGateway,
      usernameStorage: usernameStorage,
      rosterStorage: rosterStorage,
    ),
  );
  await tester.pumpAndSettle();
}

/// Rellena los dos campos que ahora exige la pantalla.
Future<void> _rellenar(
  WidgetTester tester, {
  required String apodo,
  String contrasena = 'secreta123',
}) async {
  await tester.enterText(_nicknameField, apodo);
  await tester.enterText(_passwordField, contrasena);
  await tester.pump();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    auth = FakeAuthGateway();
    estadoApodo = FakeEstadoApodoGateway();
  });

  testWidgets('con el campo vacío, el CTA está deshabilitado', (tester) async {
    await _pump(tester, profileGateway: FakeProfileGateway());

    final button = tester.widget<FilledButton>(_startButton);
    expect(button.onPressed, isNull);
  });

  testWidgets('por debajo del mínimo, el CTA sigue deshabilitado y avisa', (
    tester,
  ) async {
    await _pump(tester, profileGateway: FakeProfileGateway());

    await _rellenar(tester, apodo: 'Ab');

    expect(
      find.text('Mínimo ${UsernameScreen.minLength} caracteres'),
      findsOneWidget,
    );
    expect(tester.widget<FilledButton>(_startButton).onPressed, isNull);
  });

  testWidgets('sin contraseña suficiente, el CTA sigue deshabilitado y avisa', (
    tester,
  ) async {
    await _pump(tester, profileGateway: FakeProfileGateway());

    await _rellenar(tester, apodo: 'Ana', contrasena: 'corta');

    expect(
      find.textContaining('Mínimo ${UsernameScreen.minPasswordLength}'),
      findsOneWidget,
    );
    expect(tester.widget<FilledButton>(_startButton).onPressed, isNull);
  });

  testWidgets('con apodo y contraseña válidos, el CTA se habilita', (
    tester,
  ) async {
    await _pump(tester, profileGateway: FakeProfileGateway());

    await _rellenar(tester, apodo: 'Ana');

    expect(tester.widget<FilledButton>(_startButton).onPressed, isNotNull);
  });

  testWidgets('no admite más caracteres que el máximo permitido', (
    tester,
  ) async {
    await _pump(tester, profileGateway: FakeProfileGateway());

    await tester.enterText(
      _nicknameField,
      'A' * (UsernameScreen.maxLength + 5),
    );
    await tester.pump();

    final field = tester.widget<TextField>(
      find.descendant(of: _nicknameField, matching: find.byType(TextField)),
    );
    expect(field.controller!.text.length, UsernameScreen.maxLength);
  });

  testWidgets('con un apodo libre crea el perfil, lo guarda y navega', (
    tester,
  ) async {
    estadoApodo.estado = EstadoApodo.libre;
    final profileGateway = FakeProfileGateway();
    final usernameStorage = UsernameStorage();

    await _pump(
      tester,
      profileGateway: profileGateway,
      usernameStorage: usernameStorage,
    );

    await _rellenar(tester, apodo: 'Ana');
    await tester.tap(_startButton);
    await tester.pumpAndSettle();

    expect(profileGateway.lastNickname, 'Ana');
    expect(auth.updateUserCalls, 1);
    expect(await usernameStorage.read(), 'Ana');
    expect(find.byType(CaminoScreen), findsOneWidget);
  });

  testWidgets('con un apodo que ya tiene contraseña, entra sin renombrar', (
    tester,
  ) async {
    estadoApodo.estado = EstadoApodo.conContrasena;
    final profileGateway = FakeProfileGateway();

    await _pump(tester, profileGateway: profileGateway);

    await _rellenar(tester, apodo: 'Ana');
    await tester.tap(_startButton);
    await tester.pumpAndSettle();

    expect(find.byType(CaminoScreen), findsOneWidget);
    // La garantía de que no se pisa el perfil de otro jugador.
    expect(profileGateway.updateNicknameCalls, 0);
  });

  testWidgets('la contraseña incorrecta se distingue del error de conexión', (
    tester,
  ) async {
    estadoApodo.estado = EstadoApodo.conContrasena;
    auth.throwOnSignInWithPassword = const AuthException(
      'Invalid login credentials',
      statusCode: '400',
      code: 'invalid_credentials',
    );

    await _pump(tester, profileGateway: FakeProfileGateway());

    await _rellenar(tester, apodo: 'Ana', contrasena: 'la-que-no-es');
    await tester.tap(_startButton);
    await tester.pumpAndSettle();

    expect(find.textContaining('no es la contraseña'), findsOneWidget);
    expect(find.textContaining('Comprueba tu conexión'), findsNothing);
    expect(find.byType(UsernameScreen), findsOneWidget);
    expect(find.text('Ana'), findsOneWidget);
  });

  testWidgets('un apodo ocupado por un jugador sin contraseña se rechaza', (
    tester,
  ) async {
    estadoApodo.estado = EstadoApodo.sinContrasena;
    // El perfil activo es otro, así que ese apodo es de un tercero.
    final profileGateway = FakeProfileGateway(nicknameActual: 'Otro');

    await _pump(tester, profileGateway: profileGateway);

    await _rellenar(tester, apodo: 'Zapi');
    await tester.tap(_startButton);
    await tester.pumpAndSettle();

    expect(find.textContaining('no tiene contraseña'), findsOneWidget);
    expect(find.textContaining('Elige otro apodo'), findsOneWidget);
    expect(find.byType(UsernameScreen), findsOneWidget);
    expect(profileGateway.updateNicknameCalls, 0);
  });

  testWidgets('si falla la conexión, avisa, no navega y conserva lo escrito', (
    tester,
  ) async {
    estadoApodo.throwOnNextCall = Exception('sin conexión');

    await _pump(tester, profileGateway: FakeProfileGateway());

    await _rellenar(tester, apodo: 'Ana');
    await tester.tap(_startButton);
    await tester.pumpAndSettle();

    expect(find.textContaining('Comprueba tu conexión'), findsOneWidget);
    expect(find.byType(UsernameScreen), findsOneWidget);
    expect(find.text('Ana'), findsOneWidget);
  });

  testWidgets('el botón de dado rellena el campo con un apodo no vacío', (
    tester,
  ) async {
    await _pump(tester, profileGateway: FakeProfileGateway());

    await tester.tap(find.byKey(const Key('dice-button')));
    await tester.pump();

    final field = tester.widget<TextField>(
      find.descendant(of: _nicknameField, matching: find.byType(TextField)),
    );
    expect(field.controller!.text, isNotEmpty);
  });

  testWidgets(
    'entrar como invitado sin escribir nada asigna apodo, guarda y navega',
    (tester) async {
      final profileGateway = FakeProfileGateway();
      final usernameStorage = UsernameStorage();

      await _pump(
        tester,
        profileGateway: profileGateway,
        usernameStorage: usernameStorage,
      );

      await tester.tap(find.byKey(const Key('guest-link')));
      await tester.pumpAndSettle();

      expect(profileGateway.lastNickname, isNotEmpty);
      expect(await usernameStorage.read(), isNotEmpty);
      expect(
        auth.updateUserCalls,
        0,
        reason: 'un invitado no tiene contraseña',
      );
      expect(find.byType(CaminoScreen), findsOneWidget);
    },
  );

  group('apodos recordados en este dispositivo', () {
    testWidgets('sin ninguno, no se dibuja la sección', (tester) async {
      await _pump(tester, profileGateway: FakeProfileGateway());

      expect(find.byKey(const Key('roster')), findsNothing);
    });

    testWidgets('elegir uno rellena el apodo pero no entra', (tester) async {
      final roster = PlayerRosterStorage();
      await roster.registrar('Ana');

      await _pump(
        tester,
        profileGateway: FakeProfileGateway(),
        rosterStorage: roster,
      );

      await tester.tap(find.byKey(const Key('roster-Ana')));
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(
        find.descendant(of: _nicknameField, matching: find.byType(TextField)),
      );
      expect(field.controller!.text, 'Ana');
      // Sigue haciendo falta la contraseña: compartir móvil no es compartir
      // las cuentas.
      expect(find.byType(CaminoScreen), findsNothing);
      expect(auth.signInWithPasswordCalls, 0);
    });

    testWidgets('olvidar uno lo retira de la lista', (tester) async {
      final roster = PlayerRosterStorage();
      await roster.registrar('Ana');

      await _pump(
        tester,
        profileGateway: FakeProfileGateway(),
        rosterStorage: roster,
      );

      await tester.tap(find.byTooltip('Olvidar Ana en este dispositivo'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('roster-Ana')), findsNothing);
      expect(await roster.read(), isEmpty);
    });
  });

  testWidgets('explica para qué sirve la contraseña y que no se recupera', (
    tester,
  ) async {
    await _pump(tester, profileGateway: FakeProfileGateway());

    expect(find.textContaining('recuperas tu progreso'), findsOneWidget);
    expect(find.textContaining('no podemos recuperarla'), findsOneWidget);
    // El mensaje viejo prometía justo lo contrario de lo que hace la pantalla.
    expect(find.textContaining('Sin contraseñas'), findsNothing);
  });

  testWidgets('una contraseña rechazada por débil se avisa como tal', (
    tester,
  ) async {
    estadoApodo.estado = EstadoApodo.libre;
    auth.throwOnUpdateUser = const AuthException(
      'Password should be at least 6 characters',
      statusCode: '422',
      code: 'weak_password',
    );

    await _pump(tester, profileGateway: FakeProfileGateway());

    await _rellenar(tester, apodo: 'Ana', contrasena: 'seiscar');
    await tester.tap(_startButton);
    await tester.pumpAndSettle();

    expect(find.textContaining('demasiado débil'), findsOneWidget);
    expect(find.byType(CaminoScreen), findsNothing);
  });

  testWidgets('el ojo alterna entre mostrar y ocultar la contraseña', (
    tester,
  ) async {
    await _pump(tester, profileGateway: FakeProfileGateway());

    TextField campo() => tester.widget<TextField>(
      find.descendant(of: _passwordField, matching: find.byType(TextField)),
    );

    expect(campo().obscureText, isTrue);

    await tester.tap(find.byKey(const Key('password-visibility')));
    await tester.pump();

    expect(campo().obscureText, isFalse);
  });
}
