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
    mejorPuntaje: 0,
    puntosAcumulados: 0,
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
    mejorPuntaje: 0,
    puntosAcumulados: 0,
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

/// Para probar la navegación real ‹ (rejilla → sale de la pantalla) se
/// necesita una ruta anterior de la que hacer `pop`, igual que
/// `camino_screen_test.dart` hace con `CaminoScreen`.
Widget _pantallaConHistorial(FakeRankingGateway gateway) => MaterialApp(
  home: Builder(
    builder: (context) => Scaffold(
      body: Center(
        child: TextButton(
          key: const Key('abrir-ranking'),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => RankingScreen(
                rankingGateway: gateway,
                paradas: _paradas,
                puntosTotales: 1234,
              ),
            ),
          ),
          child: const Text('Abrir'),
        ),
      ),
    ),
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

  testWidgets(
    'la rejilla de tarjetas solo aparece en Camino y Temática; Global va '
    'directa a la clasificación',
    (tester) async {
      final gateway = FakeRankingGateway(global: _globalDePrueba);
      await tester.pumpWidget(_pantalla(gateway));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('ranking-rejilla-camino')), findsNothing);
      expect(find.byKey(const Key('ranking-lista')), findsOneWidget);

      await tester.tap(find.byKey(const Key('ranking-tab-camino')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ranking-rejilla-camino')), findsOneWidget);
      expect(
        find.byKey(const Key('ranking-tarjeta-camino-c1')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('ranking-lista')), findsNothing);

      await tester.tap(find.byKey(const Key('ranking-tab-tematica')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ranking-rejilla-tematica')), findsOneWidget);
      expect(
        find.byKey(const Key('ranking-tarjeta-tematica-t-monumentos')),
        findsOneWidget,
      );
    },
  );

  testWidgets('entrar en Camino muestra la rejilla; tocar una tarjeta abre su '
      'clasificación', (tester) async {
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
    expect(find.text('JugadorCamino'), findsNothing);

    await tester.tap(find.byKey(const Key('ranking-tarjeta-camino-c1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ranking-rejilla-camino')), findsNothing);
    expect(find.text('JugadorCamino'), findsOneWidget);
  });

  testWidgets('volver a la rejilla de Camino y tocar otra tarjeta carga esa '
      'clasificación', (tester) async {
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

    await tester.tap(find.byKey(const Key('ranking-tarjeta-camino-c1')));
    await tester.pumpAndSettle();
    expect(find.text('UnoC1'), findsOneWidget);

    await tester.tap(find.byKey(const Key('ranking-boton-volver')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ranking-rejilla-camino')), findsOneWidget);

    await tester.tap(find.byKey(const Key('ranking-tarjeta-camino-c2')));
    await tester.pumpAndSettle();
    expect(find.text('UnoC2'), findsOneWidget);
  });

  testWidgets(
    'entrar en Temática muestra la rejilla; tocar una tarjeta abre su '
    'clasificación',
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
      expect(find.text('JugadorTematica'), findsNothing);

      await tester.tap(
        find.byKey(const Key('ranking-tarjeta-tematica-t-monumentos')),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('ranking-rejilla-tematica')), findsNothing);
      expect(find.text('JugadorTematica'), findsOneWidget);
    },
  );

  testWidgets('volver a la rejilla de Temática y tocar otra tarjeta carga esa '
      'clasificación', (tester) async {
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

    await tester.tap(
      find.byKey(const Key('ranking-tarjeta-tematica-t-monumentos')),
    );
    await tester.pumpAndSettle();
    expect(find.text('UnoMonumentos'), findsOneWidget);

    await tester.tap(find.byKey(const Key('ranking-boton-volver')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ranking-rejilla-tematica')), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('ranking-tarjeta-tematica-t-banderas')),
    );
    await tester.pumpAndSettle();
    expect(find.text('UnoBanderas'), findsOneWidget);
  });

  testWidgets(
    'cambiar de pestaña con una tarjeta abierta resetea a la rejilla al '
    'volver a esa pestaña',
    (tester) async {
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
        },
      );
      await tester.pumpWidget(_pantalla(gateway));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ranking-tab-camino')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ranking-tarjeta-camino-c1')));
      await tester.pumpAndSettle();
      expect(find.text('UnoC1'), findsOneWidget);

      await tester.tap(find.byKey(const Key('ranking-tab-global')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ranking-tab-camino')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('ranking-rejilla-camino')), findsOneWidget);
      expect(find.text('UnoC1'), findsNothing);
    },
  );

  testWidgets(
    'cada tarjeta adelanta la posición propia: "Tú #N" o "Sin jugar"',
    (tester) async {
      final gateway = FakeRankingGateway(
        global: _globalDePrueba,
        porCamino: {
          'c1': const [
            EntradaRanking(
              usuarioId: 'yo',
              nombre: 'Ana',
              puntuacion: 90,
              superado: true,
              posicion: 7,
              esUsuarioActual: true,
            ),
          ],
          // 'c2' sin datos: el falso devuelve lista vacía -> sin fila
          // propia -> la tarjeta debe caer al "Sin jugar" por defecto.
        },
      );
      await tester.pumpWidget(_pantalla(gateway));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('ranking-tab-camino')));
      await tester.pumpAndSettle();

      final propiaC1 = tester.widget<Text>(
        find.byKey(const Key('ranking-tarjeta-camino-c1-propia')),
      );
      expect(propiaC1.data, 'Tú #7');

      final propiaC2 = tester.widget<Text>(
        find.byKey(const Key('ranking-tarjeta-camino-c2-propia')),
      );
      expect(propiaC2.data, 'Sin jugar');
    },
  );

  testWidgets(
    'volver desde una tarjeta abierta cierra la tarjeta sin salir de la '
    'pantalla; volver desde la rejilla sí sale de la pantalla',
    (tester) async {
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
        },
      );
      await tester.pumpWidget(_pantallaConHistorial(gateway));
      await tester.tap(find.byKey(const Key('abrir-ranking')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('ranking-tab-camino')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ranking-tarjeta-camino-c1')));
      await tester.pumpAndSettle();
      expect(find.text('UnoC1'), findsOneWidget);

      await tester.tap(find.byKey(const Key('ranking-boton-volver')));
      await tester.pumpAndSettle();
      expect(find.text('Clasificación'), findsOneWidget);
      expect(find.byKey(const Key('ranking-rejilla-camino')), findsOneWidget);

      await tester.tap(find.byKey(const Key('ranking-boton-volver')));
      await tester.pumpAndSettle();
      expect(find.text('Clasificación'), findsNothing);
      expect(find.byKey(const Key('abrir-ranking')), findsOneWidget);
    },
  );

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
