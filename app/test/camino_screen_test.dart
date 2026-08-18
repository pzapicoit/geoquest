import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geoquest/route_observer.dart';
import 'package:geoquest/screens/camino_screen.dart';
import 'package:geoquest/screens/nivel_juego_screen.dart';
import 'package:geoquest/services/camino_gateway.dart';
import 'package:geoquest/services/nivel_juego_gateway.dart';
import 'package:geoquest/services/username_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes/fake_camino_gateway.dart';
import 'fakes/fake_nivel_juego_gateway.dart';

final _nivelJuegoGatewayDePrueba = FakeNivelJuegoGateway(
  const IntentoNivel(
    intentoId: 'intento-1',
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

const _monumentos = ParadaCamino(
  caminoId: 'c1',
  orden: 1,
  nivelId: 'nivel-superado',
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
  caminoId: 'c2',
  orden: 2,
  nivelId: 'nivel-actual',
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
  caminoId: 'c3',
  orden: 3,
  nivelId: 'nivel-bloqueado',
  tematicaId: 'banderas',
  tematicaNombre: 'Banderas',
  superado: false,
  estrellasObtenidas: 0,
  estrellasRequeridas: 500,
  estrellasAcumuladasUsuario: 480,
  desbloqueado: false,
  esActual: false,
);

final _frontera = ParadaFrontera(
  tematicaAnteriorNombre: _monumentos2.tematicaNombre,
  tematicaSiguienteNombre: _banderas.tematicaNombre,
  desbloqueada: _banderas.desbloqueado,
  estrellasFaltantes:
      _banderas.estrellasRequeridas - _banderas.estrellasAcumuladasUsuario,
);

final _caminoDePrueba = CaminoJugador(
  entradas: [_monumentos, _monumentos2, _frontera, _banderas],
  puntosTotales: 240,
);

Widget _pantalla(CaminoGateway gateway) => MaterialApp(
  navigatorObservers: [routeObserver],
  home: CaminoScreen(
    caminoGateway: gateway,
    usernameStorage: UsernameStorage(),
    nivelJuegoGateway: _nivelJuegoGatewayDePrueba,
  ),
);

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

  testWidgets('la frontera bloqueada muestra cuántas estrellas faltan', (
    tester,
  ) async {
    await _pump(tester, FakeCaminoGateway(_caminoDePrueba));

    expect(
      find.text('Necesitas 20 ★ más para cruzar a Banderas'),
      findsOneWidget,
    );
  });

  testWidgets('los puntos totales del jugador aparecen en la barra superior', (
    tester,
  ) async {
    await _pump(tester, FakeCaminoGateway(_caminoDePrueba));

    expect(find.text('240'), findsOneWidget);
  });

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

      await tester.tap(find.byKey(const Key('parada-nivel-actual')));
      await tester.pumpAndSettle();

      expect(find.byType(NivelJuegoScreen), findsOneWidget);
      expect(_nivelJuegoGatewayDePrueba.ultimoNivelId, 'nivel-actual');
    },
  );

  testWidgets(
    'tocar una parada ya superada navega a la pantalla de juego, permitiendo rejugar',
    (tester) async {
      await _pump(tester, FakeCaminoGateway(_caminoDePrueba));

      await tester.tap(find.byKey(const Key('parada-nivel-superado')));
      await tester.pumpAndSettle();

      expect(find.byType(NivelJuegoScreen), findsOneWidget);
    },
  );

  testWidgets('volver de la pantalla de juego recarga el camino (INT-94)', (
    tester,
  ) async {
    final caminoGateway = FakeCaminoGateway(_caminoDePrueba);
    await _pump(tester, caminoGateway);

    expect(caminoGateway.fetchCaminoCalls, 1);

    await tester.tap(find.byKey(const Key('parada-nivel-actual')));
    await tester.pumpAndSettle();
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
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(caminoGateway.fetchCaminoCalls, 1);

      await tester.tap(find.byKey(const Key('parada-nivel-actual')));
      await tester.pumpAndSettle();
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
          caminoId: 'c$orden',
          orden: orden,
          nivelId: 'nivel-$orden',
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
        caminoId: 'c1',
        orden: 1,
        nivelId: 'nivel-1',
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

      await tester.tap(find.byKey(const Key('camino-boton-jugar')));
      await tester.pumpAndSettle();

      expect(find.byType(NivelJuegoScreen), findsOneWidget);
    },
  );

  testWidgets(
    'sin ninguna parada actual (camino completo), el botón "Jugar nivel" no aparece',
    (tester) async {
      const completa = ParadaCamino(
        caminoId: 'c1',
        orden: 1,
        nivelId: 'nivel-1',
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
        caminoId: 'c1',
        orden: 1,
        nivelId: 'nivel-unico',
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
}
