import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geoquest/screens/ranking_screen.dart';
import 'package:geoquest/services/camino_gateway.dart';
import 'package:geoquest/services/ranking_gateway.dart';

import 'fakes/fake_ranking_gateway.dart';

const _paradas = [
  ParadaCamino(
    orden: 1,
    caminoId: 'c1',
    tematicaId: 't-monumentos',
    tematicaNombre: 'Monumentos',
    superado: true,
    estrellasObtenidas: 3,
    estrellasRequeridas: 0,
    estrellasAcumuladasUsuario: 100,
    desbloqueado: true,
    esActual: false,
  ),
  ParadaCamino(
    orden: 2,
    caminoId: 'c2',
    tematicaId: 't-banderas',
    tematicaNombre: 'Banderas',
    superado: false,
    estrellasObtenidas: 0,
    estrellasRequeridas: 100,
    estrellasAcumuladasUsuario: 100,
    desbloqueado: true,
    esActual: true,
  ),
];

const _globalDePrueba = [
  EntradaRanking(
    usuarioId: 'u1',
    nombre: 'Marta',
    puntuacion: 500,
    nivelesSuperados: 5,
    posicion: 1,
    esUsuarioActual: false,
  ),
  EntradaRanking(
    usuarioId: 'u2',
    nombre: 'Kilian',
    puntuacion: 400,
    nivelesSuperados: 4,
    posicion: 2,
    esUsuarioActual: false,
  ),
  EntradaRanking(
    usuarioId: 'u3',
    nombre: 'Nina',
    puntuacion: 300,
    nivelesSuperados: 3,
    posicion: 3,
    esUsuarioActual: false,
  ),
  EntradaRanking(
    usuarioId: 'u4',
    nombre: 'Dani',
    puntuacion: 200,
    nivelesSuperados: 2,
    posicion: 4,
    esUsuarioActual: false,
  ),
  EntradaRanking(
    usuarioId: 'yo',
    nombre: 'Ana',
    puntuacion: 50,
    nivelesSuperados: 1,
    posicion: 20,
    esUsuarioActual: true,
  ),
];

Widget _pantalla(
  FakeRankingGateway gateway, {
  List<ParadaCamino>? paradas,
  int puntosTotales = 1234,
}) => MaterialApp(
  home: RankingScreen(
    rankingGateway: gateway,
    paradas: paradas ?? _paradas,
    puntosTotales: puntosTotales,
  ),
);

void main() {
  testWidgets(
    'la pestaña Global carga por defecto y muestra el podio y la lista',
    (tester) async {
      final gateway = FakeRankingGateway(global: _globalDePrueba);
      await tester.pumpWidget(_pantalla(gateway));
      await tester.pumpAndSettle();

      expect(gateway.fetchGlobalCalls, 1);
      expect(find.text('Marta'), findsOneWidget);
      expect(find.text('Dani'), findsOneWidget);
    },
  );

  testWidgets(
    'la cabecera muestra los puntos totales pasados por CaminoScreen',
    (tester) async {
      final gateway = FakeRankingGateway(global: _globalDePrueba);
      await tester.pumpWidget(_pantalla(gateway, puntosTotales: 1234));
      await tester.pumpAndSettle();

      final texto = tester.widget<Text>(
        find.byKey(const Key('ranking-puntos-totales')),
      );
      expect(texto.data, '1 234');
    },
  );

  testWidgets('el selector de chips solo aparece en Camino y Temática', (
    tester,
  ) async {
    final gateway = FakeRankingGateway(global: _globalDePrueba);
    await tester.pumpWidget(_pantalla(gateway));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ranking-chip-camino-c1')), findsNothing);

    await tester.tap(find.byKey(const Key('ranking-tab-camino')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ranking-chip-camino-c1')), findsOneWidget);
    expect(
      find.byKey(const Key('ranking-chip-tematica-t-monumentos')),
      findsNothing,
    );

    await tester.tap(find.byKey(const Key('ranking-tab-tematica')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('ranking-chip-tematica-t-monumentos')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('ranking-chip-camino-c1')), findsNothing);
  });

  testWidgets(
    'el texto de un chip de filtro no se recorta contra su propio borde',
    (tester) async {
      final gateway = FakeRankingGateway(global: _globalDePrueba);
      await tester.pumpWidget(_pantalla(gateway));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('ranking-tab-camino')));
      await tester.pumpAndSettle();

      final chip = find.byKey(const Key('ranking-chip-camino-c1'));
      final texto = find.descendant(of: chip, matching: find.text('Camino 1'));

      final altoChip = tester.getSize(chip).height;
      final altoTexto = tester.getSize(texto).height;
      // Presupuesto real del widget: el chip reserva `vertical: 9` de padding
      // a cada lado (`_SelectorChips`, `Container` del chip) — el texto debe
      // caber en lo que queda sin recortarse contra el borde.
      const paddingVerticalChip = 9 * 2;

      expect(altoTexto, lessThan(altoChip - paddingVerticalChip));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'cambiar a la pestaña Camino recarga la clasificación de la primera parada',
    (tester) async {
      final gateway = FakeRankingGateway(
        global: _globalDePrueba,
        porCamino: {
          'c1': const [
            EntradaRanking(
              usuarioId: 'u9',
              nombre: 'JugadorCamino',
              puntuacion: 90,
              superado: true,
              posicion: 1,
              esUsuarioActual: false,
            ),
          ],
        },
      );
      await tester.pumpWidget(_pantalla(gateway));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('ranking-tab-camino')));
      await tester.pumpAndSettle();

      expect(gateway.fetchPorCaminoCalls, 1);
      expect(gateway.caminoIdsConsultados, ['c1']);
      expect(find.text('JugadorCamino'), findsOneWidget);
    },
  );

  testWidgets('seleccionar otro chip de camino recarga con ese caminoId', (
    tester,
  ) async {
    final gateway = FakeRankingGateway(
      global: _globalDePrueba,
      porCamino: {
        'c1': const [
          EntradaRanking(
            usuarioId: 'u9',
            nombre: 'UnoC1',
            puntuacion: 10,
            superado: true,
            posicion: 1,
            esUsuarioActual: false,
          ),
        ],
        'c2': const [
          EntradaRanking(
            usuarioId: 'u9',
            nombre: 'UnoC2',
            puntuacion: 20,
            superado: false,
            posicion: 1,
            esUsuarioActual: false,
          ),
        ],
      },
    );
    await tester.pumpWidget(_pantalla(gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ranking-tab-camino')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('ranking-chip-camino-c2')));
    await tester.pumpAndSettle();

    expect(gateway.caminoIdsConsultados, ['c1', 'c2']);
    expect(find.text('UnoC2'), findsOneWidget);
  });

  testWidgets(
    'cambiar a la pestaña Temática recarga la clasificación de la primera '
    'temática',
    (tester) async {
      final gateway = FakeRankingGateway(
        global: _globalDePrueba,
        porTematica: {
          't-monumentos': const [
            EntradaRanking(
              usuarioId: 'u9',
              nombre: 'JugadorTematica',
              puntuacion: 70,
              nivelesSuperados: 2,
              posicion: 1,
              esUsuarioActual: false,
            ),
          ],
        },
      );
      await tester.pumpWidget(_pantalla(gateway));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('ranking-tab-tematica')));
      await tester.pumpAndSettle();

      expect(gateway.fetchPorTematicaCalls, 1);
      expect(gateway.tematicaIdsConsultadas, ['t-monumentos']);
      expect(find.text('JugadorTematica'), findsOneWidget);
    },
  );

  testWidgets('seleccionar otra temática recarga con ese tematicaId', (
    tester,
  ) async {
    final gateway = FakeRankingGateway(
      global: _globalDePrueba,
      porTematica: {
        't-monumentos': const [
          EntradaRanking(
            usuarioId: 'u9',
            nombre: 'UnoMonumentos',
            puntuacion: 10,
            nivelesSuperados: 1,
            posicion: 1,
            esUsuarioActual: false,
          ),
        ],
        't-banderas': const [
          EntradaRanking(
            usuarioId: 'u9',
            nombre: 'UnoBanderas',
            puntuacion: 20,
            nivelesSuperados: 2,
            posicion: 1,
            esUsuarioActual: false,
          ),
        ],
      },
    );
    await tester.pumpWidget(_pantalla(gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ranking-tab-tematica')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('ranking-chip-tematica-t-banderas')));
    await tester.pumpAndSettle();

    expect(gateway.tematicaIdsConsultadas, ['t-monumentos', 't-banderas']);
    expect(find.text('UnoBanderas'), findsOneWidget);
  });

  testWidgets(
    'la fila fija muestra la posición propia aunque quede fuera del top cargado',
    (tester) async {
      final gateway = FakeRankingGateway(global: _globalDePrueba);
      await tester.pumpWidget(_pantalla(gateway));
      await tester.pumpAndSettle();

      final filaPropia = find.byKey(const Key('ranking-fila-propia'));
      expect(filaPropia, findsOneWidget);
      expect(
        find.descendant(of: filaPropia, matching: find.textContaining('Ana')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: filaPropia, matching: find.text('20')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'sin puntuación agregable, la fila propia muestra "sin posición todavía" '
    'y se ve el estado vacío',
    (tester) async {
      final gateway = FakeRankingGateway(
        global: const [
          EntradaRanking(
            usuarioId: 'yo',
            nombre: 'Ana',
            puntuacion: 0,
            nivelesSuperados: 0,
            posicion: null,
            esUsuarioActual: true,
          ),
        ],
      );
      await tester.pumpWidget(_pantalla(gateway));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('ranking-estado-vacio')), findsOneWidget);
      expect(find.text('Sin posición todavía'), findsOneWidget);
    },
  );

  testWidgets('muestra un spinner mientras carga', (tester) async {
    final gateway = FakeRankingGateway(global: _globalDePrueba);
    await tester.pumpWidget(_pantalla(gateway));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('un error de red muestra el estado de error con reintentar', (
    tester,
  ) async {
    final gateway = FakeRankingGateway(global: _globalDePrueba)
      ..throwOnNextCall = Exception('sin red');
    await tester.pumpWidget(_pantalla(gateway));
    await tester.pumpAndSettle();

    expect(find.text('No se pudo cargar la clasificación'), findsOneWidget);

    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(find.text('Marta'), findsOneWidget);
  });
}
