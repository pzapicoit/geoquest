import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geoquest/mapa/mapa_mundi.dart';
import 'package:geoquest/mapa/mapa_mundi_controller.dart';

import 'fakes/mundo_de_prueba.dart';

/// Monta el mapa en una pantalla vertical de móvil y espera a que cargue la
/// geometría y a que el controlador reciba su tamaño.
Future<MapaMundiController> _montar(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final controlador = MapaMundiController();
  addTearDown(controlador.dispose);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: MapaMundi(controller: controlador, cargador: cargarMundoDePrueba),
      ),
    ),
  );
  // Un fotograma para resolver la carga y otro para el ajuste de tamaño, que
  // se hace justo después del primer layout.
  await tester.pump();
  await tester.pump();

  return controlador;
}

void main() {
  testWidgets('mientras carga la geometría enseña un indicador', (
    tester,
  ) async {
    final controlador = MapaMundiController();
    addTearDown(controlador.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: MapaMundi(
          controller: controlador,
          cargador: () async => cargarMundoDePrueba(),
        ),
      ),
    );

    expect(find.byKey(const Key('mapa-cargando')), findsOneWidget);
  });

  testWidgets('si la geometría no se puede leer, lo dice', (tester) async {
    final controlador = MapaMundiController();
    addTearDown(controlador.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: MapaMundi(
          controller: controlador,
          cargador: () async => throw Exception('asset roto'),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('mapa-error')), findsOneWidget);
  });

  testWidgets('un toque coloca el pin donde se ha tocado', (tester) async {
    final controlador = await _montar(tester);
    expect(controlador.listo, isTrue);

    const punto = Offset(195, 422);
    final esperada = controlador.pantallaACoordenadas(punto)!;

    await tester.tapAt(punto);
    await tester.pump();

    expect(controlador.pin, esperada);
  });

  testWidgets('arrastrar desplaza el mapa y no coloca pin', (tester) async {
    final controlador = await _montar(tester);
    final antes = controlador.desplazamiento;

    final gesto = await tester.startGesture(const Offset(195, 422));
    for (var i = 0; i < 3; i++) {
      await gesto.moveBy(const Offset(30, 0));
      await tester.pump();
    }
    await gesto.up();
    await tester.pump();

    expect(controlador.pin, isNull);
    expect(controlador.desplazamiento.dx, greaterThan(antes.dx));
  });

  testWidgets('los botones de zoom acercan y alejan sin colocar pin', (
    tester,
  ) async {
    final controlador = await _montar(tester);
    final inicial = controlador.escala;

    await tester.tap(find.byKey(const Key('mapa-acercar')));
    await tester.pump();
    expect(controlador.escala, greaterThan(inicial));
    expect(controlador.pin, isNull);

    await tester.tap(find.byKey(const Key('mapa-alejar')));
    await tester.pump();
    expect(controlador.escala, closeTo(inicial, 1e-9));
    expect(controlador.pin, isNull);
  });

  testWidgets('el pin aparece en pantalla al colocarlo', (tester) async {
    final controlador = await _montar(tester);

    controlador.colocarPin(
      const Coordenada(latitud: 40.4168, longitud: -3.7038),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // El pin se dibuja fuera del pintor del mundo (D7 de `design.md`), así
    // que aparece como un `CustomPaint` propio dentro del árbol del mapa.
    expect(
      find.descendant(
        of: find.byType(MapaMundi),
        matching: find.byType(CustomPaint),
      ),
      findsWidgets,
    );
    expect(controlador.pin, isNotNull);
  });
}
