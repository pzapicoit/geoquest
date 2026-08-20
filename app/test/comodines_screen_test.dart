import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geoquest/screens/comodines_screen.dart';
import 'package:geoquest/services/comodines_gateway.dart';

import 'fakes/fake_comodines_gateway.dart';

Widget _pantalla(ComodinesGateway gateway, {int puntosTotales = 1240}) {
  return MaterialApp(
    home: ComodinesScreen(gateway: gateway, puntosTotales: puntosTotales),
  );
}

void main() {
  testWidgets('enseña las 4 tarjetas con su cantidad', (tester) async {
    final gateway = FakeComodinesGateway(
      inventario: inventarioDePrueba(tiempo: 2, pais: 0, km1000: 1, km500: 3),
    );

    await tester.pumpWidget(_pantalla(gateway));
    await tester.pumpAndSettle();

    for (final tipo in ComodinTipo.values) {
      expect(
        find.byKey(Key('comodines-tarjeta-${tipo.aTexto}')),
        findsOneWidget,
      );
    }
    expect(
      tester
          .widget<Text>(find.byKey(const Key('comodines-cantidad-tiempo')))
          .data,
      'x2',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const Key('comodines-cantidad-pais')))
          .data,
      'x0',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const Key('comodines-cantidad-km500')))
          .data,
      'x3',
    );
  });

  testWidgets('el subtítulo suma el total de los 4 tipos', (tester) async {
    final gateway = FakeComodinesGateway(
      inventario: inventarioDePrueba(tiempo: 2, pais: 0, km1000: 1, km500: 3),
    );

    await tester.pumpWidget(_pantalla(gateway));
    await tester.pumpAndSettle();

    expect(
      tester.widget<Text>(find.byKey(const Key('comodines-subtitulo'))).data,
      '6 comodines en tu mochila',
    );
  });

  testWidgets('la cabecera muestra el badge de puntos recibido', (
    tester,
  ) async {
    await tester.pumpWidget(
      _pantalla(FakeComodinesGateway(), puntosTotales: 4321),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<Text>(find.byKey(const Key('comodines-puntos-totales')))
          .data,
      '4 321',
    );
  });

  testWidgets('el botón "?" enseña una descripción del comodín', (
    tester,
  ) async {
    await tester.pumpWidget(_pantalla(FakeComodinesGateway()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('comodines-info-tiempo')));
    await tester.pump();

    expect(find.textContaining('sin límite de tiempo'), findsOneWidget);
  });

  testWidgets('un error de carga muestra el estado de error con reintentar', (
    tester,
  ) async {
    final gateway = FakeComodinesGateway()
      ..throwOnNextMisComodines = Exception('sin red');

    await tester.pumpWidget(_pantalla(gateway));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('comodines-error')), findsOneWidget);

    await tester.tap(find.byKey(const Key('comodines-reintentar')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('comodines-error')), findsNothing);
    expect(find.byKey(const Key('comodines-lista')), findsOneWidget);
  });

  group('hoja "Obtener más"', () {
    testWidgets('muestra las 3 opciones, el anuncio deshabilitado', (
      tester,
    ) async {
      await tester.pumpWidget(_pantalla(FakeComodinesGateway()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('comodines-obtener-mas')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('comodines-opcion-anuncio')), findsOneWidget);
      expect(find.byKey(const Key('comodines-opcion-puntos')), findsOneWidget);
      expect(find.byKey(const Key('comodines-opcion-pack')), findsOneWidget);
    });

    testWidgets(
      'tocar "Ver un anuncio" avisa que está próximamente y no llama al RPC',
      (tester) async {
        final gateway = FakeComodinesGateway();
        await tester.pumpWidget(_pantalla(gateway));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('comodines-obtener-mas')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('comodines-opcion-anuncio')));
        await tester.pump();

        expect(find.textContaining('próximamente'), findsOneWidget);
        expect(gateway.concederComodinPorAnuncioCalls, 0);
      },
    );

    testWidgets('tocar "Canjear puntos" avisa que está próximamente', (
      tester,
    ) async {
      await tester.pumpWidget(_pantalla(FakeComodinesGateway()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('comodines-obtener-mas')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('comodines-opcion-puntos')));
      await tester.pump();

      expect(find.textContaining('próximamente'), findsOneWidget);
    });

    testWidgets('tocar "Pack explorador" avisa que está próximamente', (
      tester,
    ) async {
      await tester.pumpWidget(_pantalla(FakeComodinesGateway()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('comodines-obtener-mas')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('comodines-opcion-pack')));
      await tester.pump();

      expect(find.textContaining('próximamente'), findsOneWidget);
    });
  });

  testWidgets('el botón atrás cierra la pantalla', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ComodinesScreen(
                    gateway: FakeComodinesGateway(),
                    puntosTotales: 0,
                  ),
                ),
              ),
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    expect(find.text('Comodines'), findsOneWidget);

    await tester.tap(find.byKey(const Key('comodines-boton-volver')));
    await tester.pumpAndSettle();

    expect(find.text('Comodines'), findsNothing);
    expect(find.text('Abrir'), findsOneWidget);
  });
}
