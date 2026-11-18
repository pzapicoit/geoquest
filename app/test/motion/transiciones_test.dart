import 'package:animations/animations.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geoquest/motion/movimiento.dart';
import 'package:geoquest/motion/rutas.dart';

/// INT-151 (`app-motion`): base de movimiento y transiciones entre pantallas.
void main() {
  /// App mínima con el mismo `pageTransitionsTheme` que la real y un botón
  /// que navega con [navegar].
  Widget appDePrueba({
    required void Function(NavigatorState) navegar,
    bool reducirMovimiento = false,
  }) {
    return MaterialApp(
      theme: ThemeData(pageTransitionsTheme: temaDeTransiciones(web: false)),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(disableAnimations: reducirMovimiento),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => navegar(Navigator.of(context)),
            child: const Text('ir'),
          ),
        ),
      ),
    );
  }

  Widget destino(BuildContext _) =>
      const Scaffold(body: Text('destino', key: Key('destino')));

  group('movimientoReducido', () {
    Future<bool> leer(WidgetTester tester, {bool? desactivadas}) async {
      late bool valor;
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(disableAnimations: desactivadas ?? false),
          child: Builder(
            builder: (context) {
              valor = movimientoReducido(context);
              return const SizedBox();
            },
          ),
        ),
      );
      return valor;
    }

    testWidgets('es false con las animaciones activas', (tester) async {
      expect(await leer(tester, desactivadas: false), isFalse);
    });

    testWidgets('es true con «reducir movimiento»', (tester) async {
      expect(await leer(tester, desactivadas: true), isTrue);
    });

    testWidgets('es false si no hay MediaQuery', (tester) async {
      late bool valor;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            valor = movimientoReducido(context);
            return const SizedBox();
          },
        ),
      );
      expect(valor, isFalse);
    });
  });

  group('tema de transiciones', () {
    test('en la app nativa usa la del juego salvo en iOS', () {
      final tema = temaDeTransiciones(web: false);
      for (final plataforma in TargetPlatform.values) {
        final builder = tema.builders[plataforma];
        if (plataforma == TargetPlatform.iOS) {
          expect(builder, isA<TransicionNativaDeIOS>());
        } else {
          expect(
            builder,
            isA<TransicionDeProfundidad>(),
            reason: '$plataforma',
          );
        }
      }
    });

    test('en web usa la del juego en todas las plataformas, iOS incluido', () {
      final tema = temaDeTransiciones(web: true);
      for (final plataforma in TargetPlatform.values) {
        expect(
          tema.builders[plataforma],
          isA<TransicionDeProfundidad>(),
          reason: '$plataforma',
        );
      }
    });

    test('la nativa de iOS conserva el ritmo de Cupertino', () {
      const nativa = TransicionNativaDeIOS();
      const cupertino = CupertinoPageTransitionsBuilder();
      expect(nativa.transitionDuration, cupertino.transitionDuration);
      expect(nativa.delegatedTransition, isNotNull);
    });

    test('la transición dura lo que marca la base común', () {
      const transicion = TransicionDeProfundidad();
      expect(transicion.transitionDuration, Movimiento.pantalla);
      expect(transicion.reverseTransitionDuration, Movimiento.pantalla);
    });
  });

  group('rutas apiladas', () {
    testWidgets('entran con la transición de profundidad y terminan', (
      tester,
    ) async {
      await tester.pumpWidget(
        appDePrueba(
          navegar: (nav) => nav.push(MaterialPageRoute<void>(builder: destino)),
        ),
      );
      await tester.tap(find.text('ir'));
      await tester.pump();
      await tester.pump(Movimiento.pantalla ~/ 2);

      expect(find.byType(SharedAxisTransition), findsWidgets);

      await tester.pumpAndSettle();
      expect(find.byKey(const Key('destino')), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('con «reducir movimiento» solo hay fundido', (tester) async {
      await tester.pumpWidget(
        appDePrueba(
          reducirMovimiento: true,
          navegar: (nav) => nav.push(MaterialPageRoute<void>(builder: destino)),
        ),
      );
      await tester.tap(find.text('ir'));
      await tester.pump();
      await tester.pump(Movimiento.pantalla ~/ 2);

      expect(find.byType(SharedAxisTransition), findsNothing);
      expect(
        find.ancestor(
          of: find.byKey(const Key('destino')),
          matching: find.byType(FadeTransition),
        ),
        findsWidgets,
      );

      await tester.pumpAndSettle();
      expect(find.byKey(const Key('destino')), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('en iOS conservan la transición nativa', (tester) async {
      await tester.pumpWidget(
        appDePrueba(
          navegar: (nav) => nav.push(MaterialPageRoute<void>(builder: destino)),
        ),
      );
      await tester.tap(find.text('ir'));
      await tester.pump();
      await tester.pump(Movimiento.pantalla ~/ 2);

      expect(find.byType(SharedAxisTransition), findsNothing);
      expect(find.byType(CupertinoPageTransition), findsWidgets);

      await tester.pumpAndSettle();
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });

  testWidgets(
    'en iOS con «reducir movimiento» solo hay fundido, sin desplazamiento',
    (tester) async {
      await tester.pumpWidget(
        appDePrueba(
          reducirMovimiento: true,
          navegar: (nav) => nav.push(MaterialPageRoute<void>(builder: destino)),
        ),
      );
      await tester.tap(find.text('ir'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(CupertinoPageTransition), findsNothing);
      expect(
        find.ancestor(
          of: find.byKey(const Key('destino')),
          matching: find.byType(SlideTransition),
        ),
        findsNothing,
      );
      expect(
        find.ancestor(
          of: find.byKey(const Key('destino')),
          matching: find.byType(FadeTransition),
        ),
        findsWidgets,
      );

      await tester.pumpAndSettle();
      expect(find.byKey(const Key('destino')), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  /// La pantalla de debajo llega por un relevo, como el camino en la app real:
  /// así la nativa de iOS le aplica su `delegatedTransition`.
  Widget appConCaminoPorRelevo({required bool reducirMovimiento}) {
    return appDePrueba(
      reducirMovimiento: reducirMovimiento,
      navegar: (nav) => nav.pushReplacement(
        rutaDeRelevo<void>(
          (context) => Scaffold(
            body: TextButton(
              onPressed: () =>
                  Navigator.of(context)
                      .push(MaterialPageRoute<void>(builder: destino)),
              child: const Text('camino'),
            ),
          ),
        ),
      ),
    );
  }

  Finder desplazamientosDe(String texto) => find.ancestor(
    of: find.text(texto),
    matching: find.byWidgetPredicate(
      (w) => w is SlideTransition && w.position.value != Offset.zero,
    ),
  );

  testWidgets(
    'en iOS con «reducir movimiento» la pantalla de debajo tampoco se desplaza',
    (tester) async {
      await tester.pumpWidget(appConCaminoPorRelevo(reducirMovimiento: true));
      await tester.tap(find.text('ir'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('camino'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(desplazamientosDe('camino'), findsNothing);

      await tester.pumpAndSettle();
      expect(find.byKey(const Key('destino')), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'en iOS sin «reducir movimiento» la pantalla de debajo se aparta como en iOS',
    (tester) async {
      await tester.pumpWidget(appConCaminoPorRelevo(reducirMovimiento: false));
      await tester.tap(find.text('ir'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('camino'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(desplazamientosDe('camino'), findsWidgets);

      await tester.pumpAndSettle();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  group('rutaDeRelevo', () {
    testWidgets('sustituye con fundido cruzado y termina', (tester) async {
      await tester.pumpWidget(
        appDePrueba(
          navegar: (nav) => nav.pushReplacement(rutaDeRelevo(destino)),
        ),
      );
      await tester.tap(find.text('ir'));
      await tester.pump();
      await tester.pump(Movimiento.pantalla ~/ 2);

      expect(find.byType(FadeThroughTransition), findsWidgets);

      await tester.pumpAndSettle();
      expect(find.byKey(const Key('destino')), findsOneWidget);
      expect(find.text('ir'), findsNothing);
    });

    testWidgets('con «reducir movimiento» solo hay fundido', (tester) async {
      await tester.pumpWidget(
        appDePrueba(
          reducirMovimiento: true,
          navegar: (nav) => nav.pushReplacement(rutaDeRelevo(destino)),
        ),
      );
      await tester.tap(find.text('ir'));
      await tester.pump();
      await tester.pump(Movimiento.pantalla ~/ 2);

      expect(find.byType(FadeThroughTransition), findsNothing);
      // Solo los ancestros del destino: el `Scaffold` tiene sus propios
      // `ScaleTransition` (el animador del botón flotante) que no son de la
      // transición.
      expect(
        find.ancestor(
          of: find.byKey(const Key('destino')),
          matching: find.byType(ScaleTransition),
        ),
        findsNothing,
      );
      expect(
        find.ancestor(
          of: find.byKey(const Key('destino')),
          matching: find.byType(FadeTransition),
        ),
        findsWidgets,
      );

      await tester.pumpAndSettle();
      expect(find.byKey(const Key('destino')), findsOneWidget);
    });

    testWidgets('la ruta dura lo que marca la base común', (tester) async {
      final ruta = rutaDeRelevo<void>(destino) as PageRouteBuilder<void>;
      expect(ruta.transitionDuration, Movimiento.pantalla);
      expect(ruta.reverseTransitionDuration, Movimiento.pantalla);
    });
  });
}
