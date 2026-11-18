import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geoquest/motion/fondo_de_carga.dart';
import 'package:geoquest/motion/movimiento.dart';
import 'package:geoquest/motion/presencia.dart';
import 'package:geoquest/motion/pulsable.dart';

/// INT-152: piezas de movimiento reutilizables (`Presencia`, `Pulsable`,
/// `FondoDeCarga`).
void main() {
  Widget envolver(Widget hijo, {bool reducirMovimiento = false}) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reducirMovimiento),
      child: Scaffold(body: Center(child: hijo)),
    ),
  );

  double opacidadDe(WidgetTester tester, Finder finder) => tester
      .widget<FadeTransition>(
        find.ancestor(of: finder, matching: find.byType(FadeTransition)).first,
      )
      .opacity
      .value;

  Offset desplazamientoDe(WidgetTester tester, Finder finder) {
    final transform = tester.widget<Transform>(
      find.ancestor(of: finder, matching: find.byType(Transform)).first,
    );
    final t = transform.transform.getTranslation();
    return Offset(t.x, t.y);
  }

  group('Presencia', () {
    Widget presencia({
      required bool visible,
      int contador = 0,
      VoidCallback? onTap,
      EstiloDePresencia estilo = EstiloDePresencia.deslizar,
      Duration retraso = Duration.zero,
      bool reducirMovimiento = false,
    }) => envolver(
      Presencia(
        visible: visible,
        estilo: estilo,
        retraso: retraso,
        child: TextButton(onPressed: onTap, child: Text('hijo $contador')),
      ),
      reducirMovimiento: reducirMovimiento,
    );

    testWidgets('entra desde abajo con fundido y termina', (tester) async {
      await tester.pumpWidget(presencia(visible: true));
      await tester.pump(Movimiento.media ~/ 3);

      final hijo = find.text('hijo 0');
      expect(opacidadDe(tester, hijo), inExclusiveRange(0, 1));
      expect(desplazamientoDe(tester, hijo).dy, greaterThan(0));

      await tester.pumpAndSettle();
      expect(opacidadDe(tester, hijo), 1);
      expect(desplazamientoDe(tester, hijo), Offset.zero);
    });

    testWidgets('al ocultarse sigue pintando el último hijo hasta salir', (
      tester,
    ) async {
      await tester.pumpWidget(presencia(visible: true, contador: 1));
      await tester.pumpAndSettle();

      // Se oculta y a la vez cambia el hijo: debe salir el que se veía.
      await tester.pumpWidget(presencia(visible: false, contador: 2));
      await tester.pump(Movimiento.media ~/ 3);
      expect(find.text('hijo 1'), findsOneWidget);
      expect(find.text('hijo 2'), findsNothing);

      await tester.pumpAndSettle();
      expect(find.text('hijo 1'), findsNothing);
    });

    testWidgets('mientras sale no recibe toques', (tester) async {
      var toques = 0;
      await tester.pumpWidget(presencia(visible: true, onTap: () => toques++));
      await tester.pumpAndSettle();

      await tester.pumpWidget(presencia(visible: false, onTap: () => toques++));
      await tester.pump(Movimiento.media ~/ 4);
      await tester.tap(find.text('hijo 0'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(toques, 0);
    });

    testWidgets('con retraso no se ve ni se pulsa hasta que empieza', (
      tester,
    ) async {
      var toques = 0;
      await tester.pumpWidget(
        presencia(
          visible: true,
          retraso: Movimiento.media,
          onTap: () => toques++,
        ),
      );
      await tester.pump(Movimiento.media ~/ 2);
      expect(opacidadDe(tester, find.text('hijo 0')), 0);
      await tester.tap(find.text('hijo 0'), warnIfMissed: false);
      expect(toques, 0);

      // `pumpAndSettle` no espera a un `Timer` sin fotogramas pendientes.
      await tester.pump(Movimiento.media);
      await tester.pumpAndSettle();
      expect(opacidadDe(tester, find.text('hijo 0')), 1);
      await tester.tap(find.text('hijo 0'));
      expect(toques, 1);
    });

    testWidgets('con «reducir movimiento» solo hay fundido', (tester) async {
      await tester.pumpWidget(
        presencia(visible: true, reducirMovimiento: true),
      );
      await tester.pump(Movimiento.media ~/ 3);

      final hijo = find.text('hijo 0');
      expect(opacidadDe(tester, hijo), inExclusiveRange(0, 1));
      expect(desplazamientoDe(tester, hijo), Offset.zero);
      await tester.pumpAndSettle();
    });

    testWidgets('oculta desde el principio no pinta nada', (tester) async {
      await tester.pumpWidget(presencia(visible: false));
      expect(find.text('hijo 0'), findsNothing);
    });
  });

  group('Pulsable', () {
    double escalaDe(WidgetTester tester) =>
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;

    Widget pulsable({bool habilitado = true, bool reducir = false}) => envolver(
      Pulsable(
        habilitado: habilitado,
        child: const SizedBox(width: 120, height: 48, child: Text('botón')),
      ),
      reducirMovimiento: reducir,
    );

    testWidgets('se encoge mientras está pulsado y vuelve al soltar', (
      tester,
    ) async {
      await tester.pumpWidget(pulsable());
      final gesto = await tester.startGesture(
        tester.getCenter(find.text('botón')),
      );
      await tester.pump();
      expect(escalaDe(tester), Pulsable.escalaPulsado);

      await gesto.up();
      await tester.pump();
      expect(escalaDe(tester), 1);
    });

    testWidgets('deshabilitado no cambia de escala', (tester) async {
      await tester.pumpWidget(pulsable(habilitado: false));
      final gesto = await tester.startGesture(
        tester.getCenter(find.text('botón')),
      );
      await tester.pump();
      expect(escalaDe(tester), 1);
      await gesto.up();
    });

    testWidgets('con «reducir movimiento» no cambia de escala', (tester) async {
      await tester.pumpWidget(pulsable(reducir: true));
      final gesto = await tester.startGesture(
        tester.getCenter(find.text('botón')),
      );
      await tester.pump();
      expect(escalaDe(tester), 1);
      await gesto.up();
    });
  });

  group('FondoDeCarga', () {
    testWidgets('anima un brillo en bucle', (tester) async {
      await tester.pumpWidget(
        envolver(
          const SizedBox(width: 200, height: 150, child: FondoDeCarga()),
        ),
      );
      Gradient gradiente() =>
          (tester
                      .widget<DecoratedBox>(
                        find.descendant(
                          of: find.byType(FondoDeCarga),
                          matching: find.byType(DecoratedBox),
                        ),
                      )
                      .decoration
                  as BoxDecoration)
              .gradient!;

      final antes = (gradiente() as LinearGradient).begin;
      await tester.pump(FondoDeCarga.duracionDelBarrido ~/ 3);
      expect((gradiente() as LinearGradient).begin, isNot(antes));
    });

    testWidgets('con «reducir movimiento» queda quieto y deja asentar', (
      tester,
    ) async {
      await tester.pumpWidget(
        envolver(
          const SizedBox(width: 200, height: 150, child: FondoDeCarga()),
          reducirMovimiento: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(FondoDeCarga),
          matching: find.byType(ColoredBox),
        ),
        findsOneWidget,
      );
    });
  });
}
