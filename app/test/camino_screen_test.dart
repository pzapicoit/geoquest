import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geoquest/route_observer.dart';
import 'package:geoquest/screens/camino_screen.dart';
import 'package:geoquest/screens/comodines_screen.dart';
import 'package:geoquest/screens/nivel_juego_screen.dart';
import 'package:geoquest/services/camino_gateway.dart';
import 'package:geoquest/services/nivel_juego_gateway.dart';
import 'package:geoquest/services/username_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes/fake_camino_gateway.dart';
import 'fakes/fake_comodines_gateway.dart';
import 'fakes/fake_nivel_juego_gateway.dart';
import 'fakes/fake_ranking_gateway.dart';

final _nivelJuegoGatewayDePrueba = FakeNivelJuegoGateway(
  const IntentoNivel(
    intentoId: 'intento-1',
    desafios: [
      DesafioJuego(
        id: 'd1',
        nombre: 'Lugar de prueba',
        tipo: TipoDesafio.preguntaTexto,
        activo: true,
        textoPregunta: '¿Dónde está esto?',
      ),
    ],
  ),
);

const _monumentos = ParadaCamino(
  orden: 1,
  caminoId: 'nivel-superado',
  tematicaId: 'monumentos',
  tematicaNombre: 'Monumentos',
  superado: true,
  estrellasObtenidas: 2,
  estrellasRequeridas: 0,
  estrellasAcumuladasUsuario: 480,
  desbloqueado: true,
  esActual: false,
);

const _monumentos2 = ParadaCamino(
  orden: 2,
  caminoId: 'nivel-actual',
  tematicaId: 'monumentos',
  tematicaNombre: 'Monumentos',
  superado: false,
  estrellasObtenidas: 0,
  estrellasRequeridas: 200,
  estrellasAcumuladasUsuario: 480,
  desbloqueado: true,
  esActual: true,
);

const _banderas = ParadaCamino(
  orden: 3,
  caminoId: 'nivel-bloqueado',
  tematicaId: 'banderas',
  tematicaNombre: 'Banderas',
  superado: false,
  estrellasObtenidas: 0,
  estrellasRequeridas: 500,
  estrellasAcumuladasUsuario: 480,
  desbloqueado: false,
  esActual: false,
);

final _caminoDePrueba = CaminoJugador(
  entradas: [_monumentos, _monumentos2, _banderas],
  puntosTotales: 240,
);

Widget _pantalla(CaminoGateway gateway) => MaterialApp(
  navigatorObservers: [routeObserver],
  home: CaminoScreen(
    caminoGateway: gateway,
    usernameStorage: UsernameStorage(),
    nivelJuegoGateway: _nivelJuegoGatewayDePrueba,
    comodinesGateway: FakeComodinesGateway(),
  ),
);

/// Entra en la pantalla de juego tocando algo que navega a ella.
///
/// Sin `pumpAndSettle` a propósito: desde INT-114 la cuenta atrás del desafío
/// repinta la barra en cada fotograma, así que la pantalla de juego no deja de
/// programar fotogramas mientras corre el tiempo. Los pumps sueltos dan de
/// sobra para la transición de ruta y para que el intento cargue.
Future<void> _entrarEnElNivel(WidgetTester tester, Finder gatillo) async {
  await tester.tap(gatillo);
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

Future<void> _pump(WidgetTester tester, CaminoGateway gateway) async {
  tester.view.physicalSize = const Size(390, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(_pantalla(gateway));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'username': 'Ana'});
  });

  testWidgets('la parada superada muestra sus estrellas y "mejor intento"', (
    tester,
  ) async {
    await _pump(tester, FakeCaminoGateway(_caminoDePrueba));

    expect(find.text('2/3 ★ · mejor intento'), findsOneWidget);
  });

  testWidgets('la parada actual se marca como "¡Es tu turno!"', (tester) async {
    await _pump(tester, FakeCaminoGateway(_caminoDePrueba));

    expect(find.text('¡Es tu turno! · mín. 200 ★'), findsOneWidget);
  });

  testWidgets('la parada bloqueada muestra el umbral y no las estrellas', (
    tester,
  ) async {
    await _pump(tester, FakeCaminoGateway(_caminoDePrueba));

    expect(find.text('Bloqueado · mín. 500 ★'), findsOneWidget);
  });

  testWidgets('los puntos totales del jugador aparecen en la barra superior', (
    tester,
  ) async {
    await _pump(tester, FakeCaminoGateway(_caminoDePrueba));

    final pildora = tester.widget<Text>(find.byKey(const Key('camino-puntos')));
    expect(pildora.data, '240');
  });

  testWidgets(
    'el indicador izquierdo de cada parada muestra los puntos totales del '
    'jugador, formateados con separador de miles',
    (tester) async {
      final camino = CaminoJugador(
        entradas: [_monumentos, _monumentos2, _banderas],
        puntosTotales: 1234,
      );
      await _pump(tester, FakeCaminoGateway(camino));

      for (final caminoId in [
        'nivel-superado',
        'nivel-actual',
        'nivel-bloqueado',
      ]) {
        final indicador = tester.widget<Text>(
          find.byKey(Key('parada-puntos-$caminoId')),
        );
        expect(indicador.data, '1 234');
      }
    },
  );

  testWidgets(
    'el indicador izquierdo muestra 0 cuando el jugador no tiene puntos',
    (tester) async {
      final camino = CaminoJugador(entradas: [_monumentos], puntosTotales: 0);
      await _pump(tester, FakeCaminoGateway(camino));

      final indicador = tester.widget<Text>(
        find.byKey(const Key('parada-puntos-nivel-superado')),
      );
      expect(indicador.data, '0');
    },
  );

  testWidgets(
    'la parada bloqueada muestra un icono de candado y las demás no',
    (tester) async {
      await _pump(tester, FakeCaminoGateway(_caminoDePrueba));

      expect(
        find.descendant(
          of: find.byKey(const Key('parada-borde-nivel-bloqueado')),
          matching: find.byIcon(Icons.lock_rounded),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('parada-borde-nivel-actual')),
          matching: find.byIcon(Icons.lock_rounded),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('parada-borde-nivel-superado')),
          matching: find.byIcon(Icons.lock_rounded),
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'la parada bloqueada aplica un filtro de escala de grises a su portada',
    (tester) async {
      await _pump(tester, FakeCaminoGateway(_caminoDePrueba));

      const grayscale = ColorFilter.matrix(<double>[
        0.2126, 0.7152, 0.0722, 0, 0, //
        0.2126, 0.7152, 0.0722, 0, 0, //
        0.2126, 0.7152, 0.0722, 0, 0, //
        0, 0, 0, 1, 0, //
      ]);

      final bloqueada = tester.widget<ColorFiltered>(
        find.descendant(
          of: find.byKey(const Key('parada-borde-nivel-bloqueado')),
          matching: find.byType(ColorFiltered),
        ),
      );
      expect(bloqueada.colorFilter, grayscale);

      final actual = tester.widget<ColorFiltered>(
        find.descendant(
          of: find.byKey(const Key('parada-borde-nivel-actual')),
          matching: find.byType(ColorFiltered),
        ),
      );
      expect(actual.colorFilter, isNot(grayscale));
    },
  );

  testWidgets(
    'tocar una parada bloqueada no navega ni produce ninguna respuesta',
    (tester) async {
      await _pump(tester, FakeCaminoGateway(_caminoDePrueba));

      await tester.tap(find.byKey(const Key('parada-nivel-bloqueado')));
      await tester.pumpAndSettle();

      expect(find.byType(NivelJuegoScreen), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      // La única aparición del texto es la etiqueta de la propia tarjeta,
      // no una respuesta al toque.
      expect(find.text('Bloqueado · mín. 500 ★'), findsOneWidget);
    },
  );

  testWidgets(
    'tocar la parada actual navega a la pantalla de juego de ese nivel',
    (tester) async {
      await _pump(tester, FakeCaminoGateway(_caminoDePrueba));

      await _entrarEnElNivel(
        tester,
        find.byKey(const Key('parada-nivel-actual')),
      );

      expect(find.byType(NivelJuegoScreen), findsOneWidget);
      expect(_nivelJuegoGatewayDePrueba.ultimoCaminoId, 'nivel-actual');
    },
  );

  testWidgets(
    'tocar una parada ya superada navega a la pantalla de juego, permitiendo rejugar',
    (tester) async {
      await _pump(tester, FakeCaminoGateway(_caminoDePrueba));

      await _entrarEnElNivel(
        tester,
        find.byKey(const Key('parada-nivel-superado')),
      );

      expect(find.byType(NivelJuegoScreen), findsOneWidget);
    },
  );

  testWidgets('volver de la pantalla de juego recarga el camino (INT-94)', (
    tester,
  ) async {
    final caminoGateway = FakeCaminoGateway(_caminoDePrueba);
    await _pump(tester, caminoGateway);

    expect(caminoGateway.fetchCaminoCalls, 1);

    await _entrarEnElNivel(
      tester,
      find.byKey(const Key('parada-nivel-actual')),
    );
    expect(find.byType(NivelJuegoScreen), findsOneWidget);

    Navigator.of(tester.element(find.byType(NivelJuegoScreen))).pop();
    await tester.pumpAndSettle();

    expect(find.byType(NivelJuegoScreen), findsNothing);
    expect(caminoGateway.fetchCaminoCalls, 2);
  });

  testWidgets(
    'reintentar tras no superar el nivel, y superarlo la segunda vez, '
    'también recarga el camino al volver (regresión de /opsx-verify: un '
    '.then() sobre el push original no sobrevive a un pushReplacement '
    'intermedio)',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final caminoGateway = FakeCaminoGateway(_caminoDePrueba);
      final nivelGateway =
          FakeNivelJuegoGateway(
              const IntentoNivel(
                intentoId: 'intento-1',
                desafios: [
                  DesafioJuego(
                    id: 'd1',
                    nombre: 'Lugar de prueba',
                    tipo: TipoDesafio.preguntaTexto,
                    activo: true,
                    textoPregunta: '¿Dónde está esto?',
                  ),
                ],
              ),
            )
            ..resultado = resultadoDePrueba(
              superado: false,
              estrellas: 0,
              puntajeTotal: 900,
            );

      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [routeObserver],
          home: CaminoScreen(
            caminoGateway: caminoGateway,
            usernameStorage: UsernameStorage(),
            nivelJuegoGateway: nivelGateway,
            comodinesGateway: FakeComodinesGateway(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(caminoGateway.fetchCaminoCalls, 1);

      await _entrarEnElNivel(
        tester,
        find.byKey(const Key('parada-nivel-actual')),
      );
      expect(find.byType(NivelJuegoScreen), findsOneWidget);

      // Juega el único desafío del intento hasta llegar al resumen: cierra
      // la pista, coloca un pin, confirma y deja correr el revelado entero
      // (sin `pumpAndSettle`, como en `nivel_juego_screen_test.dart`: la
      // indicación "toca el mapa" late en bucle mientras no hay pin).
      Future<void> jugarHastaElResumen() async {
        await tester.tap(find.byKey(const Key('nivel-juego-boton-listo')));
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));

        await tester.tapAt(const Offset(195, 422));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        await tester.tap(find.byKey(const Key('nivel-juego-confirmar')));
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pump(const Duration(milliseconds: 5600));

        await tester.tap(find.byKey(const Key('nivel-juego-siguiente')));
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
      }

      await jugarHastaElResumen();
      expect(find.byKey(const Key('resumen-nivel-reintentar')), findsOneWidget);
      // Todavía no ha vuelto al camino: sigue oculto bajo el resumen del
      // intento fallido, así que no hay recarga que comprobar aquí.

      await tester.tap(find.byKey(const Key('resumen-nivel-reintentar')));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(NivelJuegoScreen), findsOneWidget);

      // Esta vez el intento sí supera el nivel.
      nivelGateway.resultado = resultadoDePrueba(
        superado: true,
        estrellas: 3,
        puntajeTotal: 2200,
      );
      await jugarHastaElResumen();
      expect(find.byKey(const Key('resumen-nivel-continuar')), findsOneWidget);

      await tester.tap(find.byKey(const Key('resumen-nivel-continuar')));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.byType(CaminoScreen), findsOneWidget);
      expect(find.byType(NivelJuegoScreen), findsNothing);
      // Antes del fix, este contador se quedaba en 1: el `.then()` del
      // `push` original se resolvía en el primer `pushReplacement` (al
      // fallar), y "Continuar" tras el segundo intento (superado) no
      // disparaba ninguna recarga.
      expect(caminoGateway.fetchCaminoCalls, 2);
    },
  );

  testWidgets(
    'el auto-scroll deja la parada actual visible y centrada en la pantalla',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      ParadaCamino nivel(
        int orden, {
        bool esActual = false,
        bool superado = false,
      }) {
        return ParadaCamino(
          orden: orden,
          caminoId: 'nivel-$orden',
          tematicaId: 'monumentos',
          tematicaNombre: 'Monumentos',
          superado: superado,
          estrellasObtenidas: superado ? 3 : 0,
          estrellasRequeridas: 0,
          estrellasAcumuladasUsuario: 999,
          desbloqueado: true,
          esActual: esActual,
        );
      }

      final caminoLargo = CaminoJugador(
        entradas: [
          nivel(1, superado: true),
          nivel(2, superado: true),
          nivel(3, superado: true),
          nivel(4, superado: true),
          nivel(5, esActual: true),
          nivel(6),
          nivel(7),
        ],
        puntosTotales: 0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CaminoScreen(
            caminoGateway: FakeCaminoGateway(caminoLargo),
            usernameStorage: UsernameStorage(),
            comodinesGateway: FakeComodinesGateway(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final rect = tester.getRect(find.byKey(const Key('parada-nivel-5')));

      // No queda pegada a ningún borde: el auto-scroll la trajo hacia el
      // centro de la pantalla, no solo "dentro" de ella.
      expect(rect.center.dy, greaterThan(844 * 0.25));
      expect(rect.center.dy, lessThan(844 * 0.75));
    },
  );

  testWidgets(
    'el botón "Jugar nivel" aparece con la parada actual y navega a ella',
    (tester) async {
      const unica = ParadaCamino(
        orden: 1,
        caminoId: 'nivel-1',
        tematicaId: 'monumentos',
        tematicaNombre: 'Monumentos',
        superado: false,
        estrellasObtenidas: 0,
        estrellasRequeridas: 0,
        estrellasAcumuladasUsuario: 0,
        desbloqueado: true,
        esActual: true,
      );

      await _pump(
        tester,
        FakeCaminoGateway(
          const CaminoJugador(entradas: [unica], puntosTotales: 0),
        ),
      );

      expect(find.text('Jugar nivel 1 · Monumentos'), findsOneWidget);

      await _entrarEnElNivel(
        tester,
        find.byKey(const Key('camino-boton-jugar')),
      );

      expect(find.byType(NivelJuegoScreen), findsOneWidget);
    },
  );

  testWidgets(
    'sin ninguna parada actual (camino completo), el botón "Jugar nivel" no aparece',
    (tester) async {
      const completa = ParadaCamino(
        orden: 1,
        caminoId: 'nivel-1',
        tematicaId: 'monumentos',
        tematicaNombre: 'Monumentos',
        superado: true,
        estrellasObtenidas: 3,
        estrellasRequeridas: 0,
        estrellasAcumuladasUsuario: 3,
        desbloqueado: true,
        esActual: false,
      );

      await _pump(
        tester,
        FakeCaminoGateway(
          const CaminoJugador(entradas: [completa], puntosTotales: 0),
        ),
      );

      expect(find.byKey(const Key('camino-boton-jugar')), findsNothing);
    },
  );

  testWidgets(
    'con un camino corto, la parada queda apoyada sobre el botón de jugar, '
    'no pegada al borde ni centrada en medio de la pantalla',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      const unica = ParadaCamino(
        orden: 1,
        caminoId: 'nivel-unico',
        tematicaId: 'monumentos',
        tematicaNombre: 'Monumentos',
        superado: false,
        estrellasObtenidas: 0,
        estrellasRequeridas: 0,
        estrellasAcumuladasUsuario: 0,
        desbloqueado: true,
        esActual: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CaminoScreen(
            caminoGateway: FakeCaminoGateway(
              const CaminoJugador(entradas: [unica], puntosTotales: 0),
            ),
            usernameStorage: UsernameStorage(),
            comodinesGateway: FakeComodinesGateway(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final rect = tester.getRect(find.byKey(const Key('parada-nivel-unico')));

      // No pegada al borde absoluto (deja el margen de `_ctaAltura`)...
      expect(rect.bottom, lessThan(844 - 40));
      // ...pero tampoco centrada a media pantalla: se apoya en la mitad
      // inferior, justo encima del botón.
      expect(rect.bottom, greaterThan(844 * 0.75));
      expect(rect.center.dy, greaterThan(844 * 0.5));
    },
  );

  testWidgets(
    'sin frontera, el nivel 1 sigue abajo del todo y el de mayor orden arriba '
    '(INT-105)',
    (tester) async {
      await _pump(tester, FakeCaminoGateway(_caminoDePrueba));

      final rectNivel1 = tester.getRect(
        find.byKey(const Key('parada-nivel-superado')),
      );
      final rectNivel2 = tester.getRect(
        find.byKey(const Key('parada-nivel-actual')),
      );
      final rectNivel3 = tester.getRect(
        find.byKey(const Key('parada-nivel-bloqueado')),
      );

      expect(rectNivel1.center.dy, greaterThan(rectNivel2.center.dy));
      expect(rectNivel2.center.dy, greaterThan(rectNivel3.center.dy));
    },
  );

  testWidgets(
    'una parada bloqueada muestra su número y título atenuados, no a color '
    'pleno (INT-105)',
    (tester) async {
      await _pump(tester, FakeCaminoGateway(_caminoDePrueba));

      final numeroTexto = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const Key('parada-nivel-bloqueado')),
          matching: find.text('3'),
        ),
      );
      final tituloTexto = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const Key('parada-nivel-bloqueado')),
          matching: find.text('Banderas'),
        ),
      );

      final borde = tester.widget<Container>(
        find.byKey(const Key('parada-borde-nivel-bloqueado')),
      );
      final decoracion = borde.decoration as BoxDecoration;

      expect(numeroTexto.style?.color, Colors.white.withValues(alpha: 0.4));
      expect(tituloTexto.style?.color, Colors.white.withValues(alpha: 0.62));
      expect(decoracion.border?.top.color, Colors.white12);
    },
  );

  testWidgets(
    'el camino aplica un ShaderMask para desvanecer el contenido bajo la '
    'cabecera y el botón de jugar (INT-105)',
    (tester) async {
      await _pump(tester, FakeCaminoGateway(_caminoDePrueba));

      final mask = tester.widget<ShaderMask>(find.byType(ShaderMask));

      expect(mask.blendMode, BlendMode.dstIn);
    },
  );

  testWidgets(
    'al hacer scroll, una parada que se acerca a la cabecera se desvanece '
    'más que una que sigue en la zona central (INT-105)',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      ParadaCamino nivel(int orden, {bool esActual = false}) {
        return ParadaCamino(
          orden: orden,
          caminoId: 'nivel-$orden',
          tematicaId: 'monumentos',
          tematicaNombre: 'Monumentos',
          superado: false,
          estrellasObtenidas: 0,
          estrellasRequeridas: 0,
          estrellasAcumuladasUsuario: 0,
          desbloqueado: true,
          esActual: esActual,
        );
      }

      final caminoLargo = CaminoJugador(
        entradas: [for (var i = 1; i <= 10; i++) nivel(i, esActual: i == 1)],
        puntosTotales: 0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CaminoScreen(
            caminoGateway: FakeCaminoGateway(caminoLargo),
            usernameStorage: UsernameStorage(),
            comodinesGateway: FakeComodinesGateway(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // El auto-scroll centra el nivel 1 (el `esActual`, abajo del todo,
      // offset al máximo). Arrastramos hacia abajo (offset decreciente)
      // para acercarnos al principio del camino: el nivel 9 queda cerca de
      // la cabecera mientras el nivel 7 sigue en la zona central segura.
      await tester.drag(find.byType(Scrollable), const Offset(0, 1200));
      await tester.pump();

      final opacidadCentro = tester
          .widget<Opacity>(
            find.descendant(
              of: find.byKey(const ValueKey('nivel-7')),
              matching: find.byType(Opacity),
            ),
          )
          .opacity;
      final opacidadBorde = tester
          .widget<Opacity>(
            find.descendant(
              of: find.byKey(const ValueKey('nivel-9')),
              matching: find.byType(Opacity),
            ),
          )
          .opacity;

      expect(opacidadBorde, lessThan(opacidadCentro));
    },
  );

  testWidgets(
    'el riel de progreso cubre desde la parada actual hasta el final del '
    'camino (INT-105)',
    (tester) async {
      await _pump(tester, FakeCaminoGateway(_caminoDePrueba));

      final pista = tester.getRect(find.byKey(const Key('camino-riel-pista')));
      final relleno = tester.getRect(
        find.byKey(const Key('camino-riel-relleno')),
      );

      // Progreso parcial (hay una parada `esActual`): el relleno no cubre
      // desde el principio del riel, pero sí hasta el mismo final.
      expect(relleno.top, greaterThan(pista.top));
      expect(relleno.bottom, closeTo(pista.bottom, 0.5));
    },
  );

  testWidgets(
    'con el camino completo (sin parada actual), el riel de progreso se '
    'rellena entero (INT-105)',
    (tester) async {
      const completa = ParadaCamino(
        orden: 1,
        caminoId: 'nivel-1',
        tematicaId: 'monumentos',
        tematicaNombre: 'Monumentos',
        superado: true,
        estrellasObtenidas: 3,
        estrellasRequeridas: 0,
        estrellasAcumuladasUsuario: 3,
        desbloqueado: true,
        esActual: false,
      );

      await _pump(
        tester,
        FakeCaminoGateway(
          const CaminoJugador(entradas: [completa], puntosTotales: 0),
        ),
      );

      final pista = tester.getRect(find.byKey(const Key('camino-riel-pista')));
      final relleno = tester.getRect(
        find.byKey(const Key('camino-riel-relleno')),
      );

      expect(relleno.top, closeTo(pista.top, 0.5));
      expect(relleno.bottom, closeTo(pista.bottom, 0.5));
    },
  );

  testWidgets(
    'el botón de Ranking en la barra superior navega a la pantalla de '
    'Clasificación',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [routeObserver],
          home: CaminoScreen(
            caminoGateway: FakeCaminoGateway(_caminoDePrueba),
            usernameStorage: UsernameStorage(),
            nivelJuegoGateway: _nivelJuegoGatewayDePrueba,
            rankingGateway: FakeRankingGateway(),
            comodinesGateway: FakeComodinesGateway(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('camino-ranking-boton')));
      await tester.pumpAndSettle();

      expect(find.text('Clasificación'), findsOneWidget);
    },
  );

  group('pill de comodines (INT-119)', () {
    testWidgets('la cabecera muestra la suma de los 4 tipos', (tester) async {
      final comodines = FakeComodinesGateway(
        inventario: inventarioDePrueba(tiempo: 2, pais: 1, km1000: 3, km500: 0),
      );

      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [routeObserver],
          home: CaminoScreen(
            caminoGateway: FakeCaminoGateway(_caminoDePrueba),
            usernameStorage: UsernameStorage(),
            nivelJuegoGateway: _nivelJuegoGatewayDePrueba,
            comodinesGateway: comodines,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<Text>(find.byKey(const Key('camino-comodines-total')))
            .data,
        '6',
      );
    });

    testWidgets('tocar el pill navega a la pantalla Comodines', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [routeObserver],
          home: CaminoScreen(
            caminoGateway: FakeCaminoGateway(_caminoDePrueba),
            usernameStorage: UsernameStorage(),
            nivelJuegoGateway: _nivelJuegoGatewayDePrueba,
            comodinesGateway: FakeComodinesGateway(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('camino-comodines-boton')));
      await tester.pumpAndSettle();

      expect(find.byType(ComodinesScreen), findsOneWidget);
      expect(find.text('Comodines'), findsOneWidget);
    });
  });
}
