import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geoquest/screens/nivel_juego_screen.dart';
import 'package:geoquest/screens/resumen_nivel_screen.dart';
import 'package:geoquest/services/nivel_juego_gateway.dart';

import 'fakes/fake_nivel_juego_gateway.dart';
import 'fakes/mundo_de_prueba.dart';

Widget _app(ResumenNivelScreen pantalla) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () =>
                Navigator.of(context)
                    .push(MaterialPageRoute<void>(builder: (_) => pantalla)),
            child: const Text('Ver resumen'),
          ),
        ),
      ),
    ),
  );
}

const _movil = Size(390, 844);

Future<void> _abrir(WidgetTester tester, ResumenNivelScreen pantalla) async {
  tester.view.physicalSize = _movil;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(_app(pantalla));
  await tester.tap(find.text('Ver resumen'));
  await tester.pump();
  await tester.pump();
}

/// `true` si la estrella de ese índice está encendida (color opaco), `false`
/// si está apagada (blanco muy tenue).
bool _estrellaEncendida(WidgetTester tester, int indice) {
  final texto = tester.widget<Text>(
    find.descendant(
      of: find.byKey(Key('resumen-nivel-estrella-$indice')),
      matching: find.text('★'),
    ),
  );
  return (texto.style?.color?.a ?? 0) > 0.5;
}

ResumenNivelScreen _pantallaSuperada({
  int puntajeTotal = 2140,
  int estrellas = 3,
  int? mejorPuntajeAnterior = 1820,
  NivelJuegoGateway? gateway,
}) {
  return ResumenNivelScreen(
    resultado: ResultadoIntento(
      puntajeTotal: puntajeTotal,
      superado: true,
      estrellas: estrellas,
      puntajeMinimoSuperar: 1500,
      mejorPuntajeAnterior: mejorPuntajeAnterior,
    ),
    nivelId: 'nivel-1',
    nivelNombre: 'Capitales del Mediterráneo',
    nivelOrden: 3,
    tematicaNombre: 'Praderas de Europa',
    totalDesafios: 6,
    gateway:
        gateway ??
        FakeNivelJuegoGateway(
          const IntentoNivel(intentoId: 'i2', desafios: []),
        ),
    cargadorDeMundo: cargarMundoDePrueba,
  );
}

ResumenNivelScreen _pantallaNoSuperada({
  int puntajeTotal = 1350,
  int puntajeMinimoSuperar = 1500,
  NivelJuegoGateway? gateway,
}) {
  return ResumenNivelScreen(
    resultado: ResultadoIntento(
      puntajeTotal: puntajeTotal,
      superado: false,
      estrellas: 0,
      puntajeMinimoSuperar: puntajeMinimoSuperar,
      mejorPuntajeAnterior: null,
    ),
    nivelId: 'nivel-1',
    nivelNombre: 'Capitales del Mediterráneo',
    nivelOrden: 3,
    tematicaNombre: 'Praderas de Europa',
    totalDesafios: 6,
    gateway:
        gateway ??
        FakeNivelJuegoGateway(
          const IntentoNivel(intentoId: 'i2', desafios: []),
        ),
    cargadorDeMundo: cargarMundoDePrueba,
  );
}

void main() {
  group('estado superado', () {
    testWidgets('muestra el mensaje de celebración, el puntaje y "Continuar"', (
      tester,
    ) async {
      await _abrir(tester, _pantallaSuperada());

      expect(find.text('¡Nivel superado!'), findsOneWidget);
      expect(find.text('2.140'), findsOneWidget);
      expect(find.byKey(const Key('resumen-nivel-continuar')), findsOneWidget);
      expect(find.byKey(const Key('resumen-nivel-reintentar')), findsNothing);
    });

    testWidgets('las estrellas se rellenan una a una, sin confeti con 2', (
      tester,
    ) async {
      await _abrir(tester, _pantallaSuperada(estrellas: 2));

      expect(_estrellaEncendida(tester, 0), isFalse);
      expect(_estrellaEncendida(tester, 1), isFalse);
      expect(_estrellaEncendida(tester, 2), isFalse);

      await tester.pump(const Duration(milliseconds: 420));
      expect(_estrellaEncendida(tester, 0), isTrue);
      expect(_estrellaEncendida(tester, 1), isFalse);

      await tester.pump(const Duration(milliseconds: 480));
      expect(_estrellaEncendida(tester, 1), isTrue);

      // Solo 2 estrellas: nunca se enciende la tercera ni hay confeti.
      await tester.pump(const Duration(milliseconds: 1000));
      expect(_estrellaEncendida(tester, 2), isFalse);
      expect(find.byKey(const Key('confeti-1')), findsNothing);
    });

    testWidgets('con 3 estrellas se dispara el confeti al completarse', (
      tester,
    ) async {
      await _abrir(tester, _pantallaSuperada(estrellas: 3));

      // 420 + 480 + 480 = 1380 ms para la tercera estrella.
      await tester.pump(const Duration(milliseconds: 1380));
      expect(_estrellaEncendida(tester, 2), isTrue);

      // 240 ms más para el confeti (D8 de `design.md`).
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 140));
      await tester.pump();

      // El confeti se pinta como piezas Container sin key propia; basta con
      // comprobar que la capa de confeti (identificada por su key) existe.
      // `_ronda` empieza en 0 y la primera coreografía (lanzada desde
      // `initState`) ya la incrementa a 1.
      expect(find.byKey(const Key('confeti-1')), findsOneWidget);
    });

    testWidgets('"Continuar" hace pop y vuelve a la pantalla anterior', (
      tester,
    ) async {
      await _abrir(tester, _pantallaSuperada());

      await tester.tap(find.byKey(const Key('resumen-nivel-continuar')));
      await tester.pumpAndSettle();

      expect(find.text('Ver resumen'), findsOneWidget);
    });

    testWidgets('"Repetir animación" reinicia las estrellas desde cero', (
      tester,
    ) async {
      await _abrir(tester, _pantallaSuperada(estrellas: 1));

      await tester.pump(const Duration(milliseconds: 420));
      expect(_estrellaEncendida(tester, 0), isTrue);

      await tester.tap(find.byKey(const Key('resumen-nivel-repetir')));
      await tester.pump();
      expect(_estrellaEncendida(tester, 0), isFalse);

      await tester.pump(const Duration(milliseconds: 420));
      expect(_estrellaEncendida(tester, 0), isTrue);
    });
  });

  group('récord personal', () {
    testWidgets('se muestra cuando el puntaje mejora un resultado anterior', (
      tester,
    ) async {
      await _abrir(
        tester,
        _pantallaSuperada(puntajeTotal: 2140, mejorPuntajeAnterior: 1820),
      );

      await tester.pump(const Duration(milliseconds: 1600));
      expect(find.byKey(const Key('resumen-nivel-record')), findsOneWidget);
    });

    testWidgets('no se muestra en el primer intento superado del nivel', (
      tester,
    ) async {
      await _abrir(
        tester,
        _pantallaSuperada(puntajeTotal: 2140, mejorPuntajeAnterior: null),
      );

      await tester.pump(const Duration(milliseconds: 1600));
      expect(find.byKey(const Key('resumen-nivel-record')), findsNothing);
    });

    testWidgets('no se muestra si el puntaje no mejora el anterior', (
      tester,
    ) async {
      await _abrir(
        tester,
        _pantallaSuperada(puntajeTotal: 1600, mejorPuntajeAnterior: 1820),
      );

      await tester.pump(const Duration(milliseconds: 1600));
      expect(find.byKey(const Key('resumen-nivel-record')), findsNothing);
    });
  });

  group('estado no superado', () {
    testWidgets('muestra el ánimo, cuánto faltó y las estrellas apagadas', (
      tester,
    ) async {
      await _abrir(
        tester,
        _pantallaNoSuperada(puntajeTotal: 1350, puntajeMinimoSuperar: 1500),
      );

      expect(find.text('¡Casi lo tienes!'), findsOneWidget);
      expect(find.text('1.350'), findsOneWidget);
      expect(find.text('Te faltaron 150 puntos'), findsOneWidget);
      expect(_estrellaEncendida(tester, 0), isFalse);
      expect(_estrellaEncendida(tester, 1), isFalse);
      expect(_estrellaEncendida(tester, 2), isFalse);

      // Sin animación: pasar el tiempo no cambia nada.
      await tester.pump(const Duration(seconds: 2));
      expect(_estrellaEncendida(tester, 0), isFalse);
    });

    testWidgets('"Reintentar" arranca un intento nuevo del mismo nivel', (
      tester,
    ) async {
      final gateway = FakeNivelJuegoGateway(
        const IntentoNivel(
          intentoId: 'i-nuevo',
          desafios: [
            DesafioJuego(
              id: 'd1',
              tipo: TipoDesafio.preguntaTexto,
              activo: true,
              textoPregunta: '¿Dónde está esto?',
            ),
          ],
        ),
      );

      await _abrir(tester, _pantallaNoSuperada(gateway: gateway));

      await tester.tap(find.byKey(const Key('resumen-nivel-reintentar')));
      await tester.pump();
      await tester.pump();
      // La transición de `pushReplacement` mantiene la ruta saliente en el
      // árbol unos milisegundos; sin este pump, la búsqueda de más abajo
      // todavía encontraría el botón "Reintentar" de la ruta que se va.
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(NivelJuegoScreen), findsOneWidget);
      expect(gateway.iniciarIntentoCalls, 1);
      expect(gateway.ultimoNivelId, 'nivel-1');
      expect(find.byKey(const Key('resumen-nivel-reintentar')), findsNothing);
    });

    testWidgets('"Volver al camino" hace pop sin arrancar ningún intento', (
      tester,
    ) async {
      final gateway = FakeNivelJuegoGateway(
        const IntentoNivel(intentoId: 'i-nuevo', desafios: []),
      );

      await _abrir(tester, _pantallaNoSuperada(gateway: gateway));

      await tester.tap(find.byKey(const Key('resumen-nivel-volver')));
      await tester.pumpAndSettle();

      expect(find.text('Ver resumen'), findsOneWidget);
      expect(gateway.iniciarIntentoCalls, 0);
    });
  });
}
