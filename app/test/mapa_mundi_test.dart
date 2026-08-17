import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geoquest/mapa/mapa_mundi.dart';
import 'package:geoquest/mapa/mapa_mundi_controller.dart';

import 'fakes/mundo_de_prueba.dart';

/// Monta el mapa en una pantalla vertical de móvil y espera a que cargue la
/// geometría y a que el controlador reciba su tamaño.
Future<MapaMundiController> _montar(
  WidgetTester tester, {
  bool interactivo = true,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final controlador = MapaMundiController();
  addTearDown(controlador.dispose);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: MapaMundi(
          controller: controlador,
          cargador: cargarMundoDePrueba,
          interactivo: interactivo,
        ),
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

  group('revelado', () {
    testWidgets('con ubicación real se dibujan los dos pines rotulados', (
      tester,
    ) async {
      final controlador = await _montar(tester, interactivo: false);

      controlador.colocarPin(
        const Coordenada(latitud: 40.4168, longitud: -3.7038),
      );
      controlador.revelarUbicacion(
        const Coordenada(latitud: 41.8902, longitud: 12.4922),
        nombre: 'Roma',
      );
      controlador.progresoDeLaLinea = 1;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byKey(const Key('mapa-pin-real')), findsOneWidget);
      expect(find.text('TU PIN'), findsOneWidget);
      expect(find.text('ROMA'), findsOneWidget);
    });

    testWidgets('el pin real muestra el nombre del lugar recibido, no "Real"', (
      tester,
    ) async {
      final controlador = await _montar(tester, interactivo: false);

      controlador.colocarPin(
        const Coordenada(latitud: 40.4168, longitud: -3.7038),
      );
      controlador.revelarUbicacion(
        const Coordenada(latitud: 41.8902, longitud: 12.4922),
        nombre: 'Parque Nacional Torres del Paine',
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('REAL'), findsNothing);
      expect(find.text('PARQUE NACIONAL TORRES DEL PAINE'), findsOneWidget);
    });

    testWidgets('un nombre de lugar largo no rompe el layout del pin', (
      tester,
    ) async {
      final controlador = await _montar(tester, interactivo: false);

      controlador.colocarPin(
        const Coordenada(latitud: 40.4168, longitud: -3.7038),
      );
      controlador.revelarUbicacion(
        const Coordenada(latitud: 41.8902, longitud: 12.4922),
        nombre:
            'Un nombre de lugar excepcionalmente largo para probar el '
            'truncado del rótulo sobre el mapa',
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Ningún overflow: si el rótulo desbordara su caja, `flutter_test`
      // levanta un `FlutterError` durante el pump.
      expect(tester.takeException(), isNull);

      final texto = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const Key('mapa-pin-real')),
          matching: find.byType(Text),
        ),
      );
      expect(texto.maxLines, 1);
      expect(texto.overflow, TextOverflow.ellipsis);
    });

    testWidgets('con los dos pines muy próximos, sus rótulos no se solapan', (
      tester,
    ) async {
      final controlador = await _montar(tester, interactivo: false);

      // Coordenadas separadas por un puñado de metros: en el zoom inicial
      // caen prácticamente en el mismo punto de pantalla.
      controlador.colocarPin(
        const Coordenada(latitud: 40.4168, longitud: -3.7038),
      );
      controlador.revelarUbicacion(
        const Coordenada(latitud: 40.41681, longitud: -3.70381),
        nombre: 'Madrid',
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final centroTuPin = tester.getCenter(find.text('TU PIN'));
      final centroReal = tester.getCenter(find.text('MADRID'));

      // El rótulo del jugador va por debajo de su pin y el real por
      // encima del suyo: quedan en lados opuestos del eje vertical, sin
      // solaparse, sin importar cuánto se acerquen los pines.
      expect(centroTuPin.dy, greaterThan(centroReal.dy));
    });

    testWidgets('sin ubicación real el pin del jugador no lleva rótulo', (
      tester,
    ) async {
      final controlador = await _montar(tester);

      controlador.colocarPin(
        const Coordenada(latitud: 40.4168, longitud: -3.7038),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byKey(const Key('mapa-pin-real')), findsNothing);
      expect(find.text('TU PIN'), findsNothing);
    });

    testWidgets('en modo no interactivo un toque no coloca pin', (
      tester,
    ) async {
      final controlador = await _montar(tester, interactivo: false);
      final encuadre = controlador.camara;

      await tester.tapAt(const Offset(195, 422));
      await tester.pump();

      expect(controlador.pin, isNull);
      expect(controlador.camara, encuadre);
    });

    testWidgets('en modo no interactivo arrastrar no mueve el mapa', (
      tester,
    ) async {
      final controlador = await _montar(tester, interactivo: false);
      final encuadre = controlador.camara;

      final gesto = await tester.startGesture(const Offset(195, 422));
      for (var i = 0; i < 3; i++) {
        await gesto.moveBy(const Offset(30, 0));
        await tester.pump();
      }
      await gesto.up();
      await tester.pump();

      expect(controlador.camara, encuadre);
    });

    testWidgets('en modo no interactivo no hay botones de zoom', (
      tester,
    ) async {
      await _montar(tester, interactivo: false);

      expect(find.byKey(const Key('mapa-acercar')), findsNothing);
      expect(find.byKey(const Key('mapa-alejar')), findsNothing);
    });
  });
}
