import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geoquest/screens/camino_screen.dart';
import 'package:geoquest/screens/username_screen.dart';
import 'package:geoquest/services/profile_gateway.dart';
import 'package:geoquest/services/username_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes/fake_profile_gateway.dart';

Widget _pantalla({
  required FakeProfileGateway profileGateway,
  UsernameStorage? usernameStorage,
}) => MaterialApp(
  home: UsernameScreen(
    usernameStorage: usernameStorage ?? UsernameStorage(),
    profileGateway: profileGateway,
  ),
);

Finder get _startButton => find.widgetWithText(FilledButton, 'Empezar a jugar');

/// El diseño usa una cabecera de marca alta (`_heroHeight`); en el tamaño
/// de superficie por defecto de los tests (800x600) el resto del contenido
/// queda fuera del área táctil. Se agranda la superficie al tamaño de un
/// teléfono real para que los `tap()` lleguen a los widgets.
Future<void> _pump(
  WidgetTester tester, {
  required FakeProfileGateway profileGateway,
  UsernameStorage? usernameStorage,
}) async {
  tester.view.physicalSize = const Size(390, 1600);
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
    _pantalla(profileGateway: profileGateway, usernameStorage: usernameStorage),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
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

    await tester.enterText(find.byKey(const Key('nickname-field')), 'Al');
    await tester.pump();

    final button = tester.widget<FilledButton>(_startButton);
    expect(button.onPressed, isNull);
    expect(find.text('Mínimo 3 caracteres'), findsOneWidget);
  });

  testWidgets('dentro del rango permitido, el CTA se habilita', (tester) async {
    await _pump(tester, profileGateway: FakeProfileGateway());

    await tester.enterText(find.byKey(const Key('nickname-field')), 'Ana');
    await tester.pump();

    final button = tester.widget<FilledButton>(_startButton);
    expect(button.onPressed, isNotNull);
    expect(find.text('Mínimo 3 caracteres'), findsNothing);
  });

  testWidgets('no admite más caracteres que el máximo permitido', (
    tester,
  ) async {
    await _pump(tester, profileGateway: FakeProfileGateway());

    await tester.enterText(
      find.byKey(const Key('nickname-field')),
      'UnApodoDemasiadoLargo',
    );
    await tester.pump();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text.length, UsernameScreen.maxLength);
    expect(find.byKey(const Key('nickname-counter')), findsOneWidget);
    expect(find.text('16/16'), findsOneWidget);
  });

  testWidgets('guarda el apodo local y remoto, y navega al camino', (
    tester,
  ) async {
    final profileGateway = FakeProfileGateway();
    final usernameStorage = UsernameStorage();

    await _pump(
      tester,
      profileGateway: profileGateway,
      usernameStorage: usernameStorage,
    );

    await tester.enterText(find.byKey(const Key('nickname-field')), 'Ana');
    await tester.pump();
    await tester.tap(_startButton);
    await tester.pumpAndSettle();

    expect(profileGateway.updateNicknameCalls, 1);
    expect(profileGateway.lastNickname, 'Ana');
    expect(await usernameStorage.read(), 'Ana');
    expect(find.byType(CaminoScreen), findsOneWidget);
  });

  testWidgets(
    'si falla el guardado remoto, muestra el error, no navega y conserva el apodo',
    (tester) async {
      final profileGateway = FakeProfileGateway()
        ..throwOnNextCall = Exception('sin conexión');

      await _pump(tester, profileGateway: profileGateway);

      await tester.enterText(find.byKey(const Key('nickname-field')), 'Ana');
      await tester.pump();
      await tester.tap(_startButton);
      await tester.pumpAndSettle();

      expect(
        find.textContaining('No se pudo guardar tu apodo'),
        findsOneWidget,
      );
      expect(find.byType(UsernameScreen), findsOneWidget);
      expect(find.text('Ana'), findsOneWidget);
    },
  );

  testWidgets(
    'si el apodo ya está en uso, muestra un mensaje específico en vez del genérico',
    (tester) async {
      final profileGateway = FakeProfileGateway()
        ..throwOnNextCall = const AliasEnUsoException();

      await _pump(tester, profileGateway: profileGateway);

      await tester.enterText(find.byKey(const Key('nickname-field')), 'Zapi');
      await tester.pump();
      await tester.tap(_startButton);
      await tester.pumpAndSettle();

      expect(
        find.text('Ese apodo ya está en uso. Prueba con otro.'),
        findsOneWidget,
      );
      expect(find.textContaining('Comprueba tu conexión'), findsNothing);
      expect(find.byType(UsernameScreen), findsOneWidget);
      expect(find.text('Zapi'), findsOneWidget);
    },
  );

  testWidgets('el botón de dado rellena el campo con un apodo no vacío', (
    tester,
  ) async {
    await _pump(tester, profileGateway: FakeProfileGateway());

    await tester.tap(find.byKey(const Key('dice-button')));
    await tester.pump();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, isNotEmpty);
  });

  testWidgets(
    'entrar como invitado sin escribir apodo lo asigna, guarda y navega',
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

      expect(profileGateway.updateNicknameCalls, 1);
      expect(profileGateway.lastNickname, isNotEmpty);
      expect(await usernameStorage.read(), isNotEmpty);
      expect(find.byType(CaminoScreen), findsOneWidget);
    },
  );

  testWidgets('muestra el texto de tranquilidad sobre la sesión anónima', (
    tester,
  ) async {
    await _pump(tester, profileGateway: FakeProfileGateway());

    expect(find.textContaining('Sin contraseñas'), findsOneWidget);
  });
}
