import 'package:flutter/gestures.dart' show kDoubleTapTimeout;
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

/// Dos toques seguidos en el mismo punto, con la animación del acercamiento ya
/// terminada al volver.
Future<void> _dobleToque(WidgetTester tester, Offset punto) async {
  await tester.tapAt(punto);
  await tester.pump(const Duration(milliseconds: 60));
  await tester.tapAt(punto);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
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

  testWidgets('desmontar el mapa sin ningún gesto no revienta', (tester) async {
    // La animación del doble toque es `late final`, así que si el mapa se va
    // sin que nadie la haya tocado se construye dentro del propio `dispose`.
    final controlador = MapaMundiController();
    addTearDown(controlador.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MapaMundi(
            controller: controlador,
            cargador: cargarMundoDePrueba,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pump();

    expect(tester.takeException(), isNull);
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

    testWidgets('en modo no interactivo el doble toque no hace nada', (
      tester,
    ) async {
      final controlador = await _montar(tester, interactivo: false);
      final encuadre = controlador.camara;

      await _dobleToque(tester, const Offset(195, 500));

      expect(controlador.camara, encuadre);
      expect(controlador.pin, isNull);
    });
  });

  group('doble toque para acercar', () {
    const punto = Offset(195, 500);

    testWidgets('acerca sobre el punto tocado y lo deja quieto', (
      tester,
    ) async {
      final controlador = await _montar(tester);
      final escalaInicial = controlador.escala;
      final coordenada = controlador.pantallaACoordenadas(punto)!;

      await _dobleToque(tester, punto);

      expect(
        controlador.escala,
        closeTo(escalaInicial * MapaMundiController.factorDobleToque, 1e-9),
      );
      final despues = controlador.pantallaACoordenadas(punto)!;
      expect(despues.latitud, closeTo(coordenada.latitud, 1e-6));
      expect(despues.longitud, closeTo(coordenada.longitud, 1e-6));
    });

    testWidgets('el acercamiento va animado, no de un salto', (tester) async {
      final controlador = await _montar(tester);
      final escalaInicial = controlador.escala;

      await tester.tapAt(punto);
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tapAt(punto);
      await tester.pump();

      expect(controlador.escala, escalaInicial);

      await tester.pump(const Duration(milliseconds: 100));
      final aMedias = controlador.escala;

      await tester.pump(const Duration(milliseconds: 200));

      expect(aMedias, greaterThan(escalaInicial));
      expect(aMedias, lessThan(escalaInicial * 2));
      expect(controlador.escala, closeTo(escalaInicial * 2, 1e-9));
    });

    testWidgets('un doble toque no deja pin', (tester) async {
      final controlador = await _montar(tester);
      final escalaInicial = controlador.escala;

      await _dobleToque(tester, punto);

      // El primer toque de la pareja sí colocó pin —no puede esperar a saber si
      // viene un segundo—, pero al confirmarse el doble toque se deshace: el
      // gesto era "acércame aquí", no "mi respuesta es aquí" (DD3 del delta 1).
      expect(controlador.pin, isNull);
      expect(controlador.escala, greaterThan(escalaInicial));
    });

    testWidgets('un doble toque no se lleva el pin que ya había', (
      tester,
    ) async {
      final controlador = await _montar(tester);
      final escalaInicial = controlador.escala;

      // La respuesta del jugador, ya colocada y lejos de donde va a mirar.
      await tester.tapAt(const Offset(120, 300));
      await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 20));
      final respuesta = controlador.pin!;

      await _dobleToque(tester, punto);

      expect(controlador.pin, respuesta);
      expect(controlador.escala, greaterThan(escalaInicial));
    });

    testWidgets('dos toques lejanos son dos toques, no un doble toque', (
      tester,
    ) async {
      final controlador = await _montar(tester);
      final escalaInicial = controlador.escala;
      const segundo = Offset(300, 700);
      final esperada = controlador.pantallaACoordenadas(segundo)!;

      await tester.tapAt(const Offset(100, 300));
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tapAt(segundo);
      await tester.pump(const Duration(milliseconds: 400));

      expect(controlador.escala, escalaInicial);
      expect(controlador.pin, esperada);
    });

    testWidgets('dos toques separados en el tiempo no acercan', (tester) async {
      final controlador = await _montar(tester);
      final escalaInicial = controlador.escala;

      final esperada = controlador.pantallaACoordenadas(punto)!;

      await tester.tapAt(punto);
      await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 20));
      await tester.tapAt(punto);
      await tester.pump(const Duration(milliseconds: 400));

      expect(controlador.escala, escalaInicial);
      // Son dos toques simples, así que el segundo deja su pin y nadie lo
      // deshace.
      expect(controlador.pin, esperada);
    });

    testWidgets('en el tope de acercar el doble toque no mueve nada', (
      tester,
    ) async {
      final controlador = await _montar(tester);
      for (var i = 0; i < 12; i++) {
        controlador.acercar();
      }
      await tester.pump();
      expect(controlador.escala, controlador.escalaMaxima);
      final encuadre = controlador.camara;

      await _dobleToque(tester, punto);

      expect(controlador.camara, encuadre);
    });

    testWidgets('el mundo sigue cubriendo la pantalla al acercar en un canto', (
      tester,
    ) async {
      final controlador = await _montar(tester);

      await _dobleToque(tester, const Offset(2, 2));

      expect(controlador.desplazamiento.dx, lessThanOrEqualTo(0));
      expect(controlador.desplazamiento.dy, lessThanOrEqualTo(0));
      expect(
        controlador.desplazamiento.dy,
        greaterThanOrEqualTo(844 - controlador.escala),
      );
    });

    testWidgets('un tercer toque seguido es un toque normal, no otro zoom', (
      tester,
    ) async {
      final controlador = await _montar(tester);

      await _dobleToque(tester, punto);
      final trasElDobleToque = controlador.escala;
      expect(controlador.pin, isNull);

      await tester.tapAt(punto);
      await tester.pump(const Duration(milliseconds: 400));

      // El doble toque no encadena: el tercer toque abre pareja nueva, así que
      // coloca pin y no vuelve a acercar.
      expect(controlador.escala, trasElDobleToque);
      expect(controlador.pin, isNotNull);
    });

    testWidgets('el pin del toque simple no espera el plazo del doble toque', (
      tester,
    ) async {
      final controlador = await _montar(tester);
      final esperada = controlador.pantallaACoordenadas(punto)!;

      await tester.tapAt(punto);
      // Un fotograma sin avanzar el reloj: si el pin dependiera de descartar un
      // segundo toque, aquí todavía no habría pin.
      await tester.pump();

      expect(controlador.pin, esperada);
    });

    testWidgets('dejar de ser interactivo corta la animación', (tester) async {
      final controlador = await _montar(tester);

      await tester.tapAt(punto);
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tapAt(punto);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final aMedias = controlador.escala;

      // La jugada se cierra a media animación: de aquí en adelante el encuadre
      // lo lleva la coreografía del revelado (D12).
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MapaMundi(
              controller: controlador,
              cargador: cargarMundoDePrueba,
              interactivo: false,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      expect(controlador.escala, aMedias);
    });

    testWidgets('un arrastre corta la animación del doble toque', (
      tester,
    ) async {
      final controlador = await _montar(tester);

      await tester.tapAt(punto);
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tapAt(punto);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final aMedias = controlador.escala;

      final gesto = await tester.startGesture(const Offset(195, 400));
      for (var i = 0; i < 3; i++) {
        await gesto.moveBy(const Offset(0, -20));
        await tester.pump();
      }
      await gesto.up();
      await tester.pump(const Duration(milliseconds: 400));

      // El zoom se queda donde lo dejó el dedo: la animación no ha seguido
      // sola hasta su destino.
      expect(controlador.escala, aMedias);
    });
  });
}
