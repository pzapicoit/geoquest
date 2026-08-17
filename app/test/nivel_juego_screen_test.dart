import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geoquest/screens/nivel_juego_screen.dart';
import 'package:geoquest/services/nivel_juego_gateway.dart';

import 'fakes/fake_nivel_juego_gateway.dart';

const _desafioImagen = DesafioJuego(
  id: 'd1',
  tipo: TipoDesafio.imagen,
  activo: true,
  imagenUrl: 'https://example.com/foto.jpg',
);

const _desafioVideo = DesafioJuego(
  id: 'd2',
  tipo: TipoDesafio.video,
  activo: true,
  videoUrl: 'https://example.com/clip.mp4',
);

const _desafioTexto = DesafioJuego(
  id: 'd3',
  tipo: TipoDesafio.preguntaTexto,
  activo: true,
  textoPregunta: '¿Dónde está esto?',
);

Widget _pantalla(NivelJuegoGateway gateway) => MaterialApp(
  home: NivelJuegoScreen(nivelId: 'nivel-1', gateway: gateway),
);

void main() {
  testWidgets('muestra un loading mientras arranca el intento', (tester) async {
    final gateway = FakeNivelJuegoGateway(
      const IntentoNivel(intentoId: 'i1', desafios: [_desafioTexto]),
    );

    await tester.pumpWidget(_pantalla(gateway));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('un desafío de tipo pregunta_texto muestra el texto en grande', (
    tester,
  ) async {
    final gateway = FakeNivelJuegoGateway(
      const IntentoNivel(intentoId: 'i1', desafios: [_desafioTexto]),
    );

    await tester.pumpWidget(_pantalla(gateway));
    await tester.pumpAndSettle();

    expect(find.text('¿Dónde está esto?'), findsOneWidget);
    expect(gateway.ultimoNivelId, 'nivel-1');
  });

  testWidgets('un desafío de tipo imagen muestra Image.network', (
    tester,
  ) async {
    final gateway = FakeNivelJuegoGateway(
      const IntentoNivel(intentoId: 'i1', desafios: [_desafioImagen]),
    );

    await tester.pumpWidget(_pantalla(gateway));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('nivel-juego-imagen')), findsOneWidget);
  });

  testWidgets('un desafío de tipo video muestra el widget de video', (
    tester,
  ) async {
    final gateway = FakeNivelJuegoGateway(
      const IntentoNivel(intentoId: 'i1', desafios: [_desafioVideo]),
    );

    await tester.pumpWidget(_pantalla(gateway));
    await tester.pump();

    expect(find.byKey(const Key('nivel-juego-video')), findsOneWidget);
  });

  testWidgets(
    'si el video no puede inicializarse, muestra un aviso en vez de quedarse en negro',
    (tester) async {
      // En el entorno de test no hay plugin de plataforma para
      // video_player, así que `initialize()` falla siempre — ejercita el
      // mismo camino que una URL de vídeo rota en producción.
      final gateway = FakeNivelJuegoGateway(
        const IntentoNivel(intentoId: 'i1', desafios: [_desafioVideo]),
      );

      await tester.pumpWidget(_pantalla(gateway));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('nivel-juego-video-error')), findsOneWidget);
    },
  );

  testWidgets(
    'un intento sin desafíos muestra el estado de error, sin crashear',
    (tester) async {
      final gateway = FakeNivelJuegoGateway(
        const IntentoNivel(intentoId: 'i1', desafios: []),
      );

      await tester.pumpWidget(_pantalla(gateway));
      await tester.pumpAndSettle();

      expect(
        find.text('Este nivel todavía no tiene desafíos disponibles'),
        findsOneWidget,
      );
      expect(find.text('Reintentar'), findsOneWidget);
    },
  );

  testWidgets('el progreso muestra "Desafío 1 de N" para el primer desafío', (
    tester,
  ) async {
    final gateway = FakeNivelJuegoGateway(
      const IntentoNivel(
        intentoId: 'i1',
        desafios: [_desafioTexto, _desafioImagen, _desafioVideo],
      ),
    );

    await tester.pumpWidget(_pantalla(gateway));
    await tester.pumpAndSettle();

    expect(find.text('Desafío 1 de 3'), findsOneWidget);
  });

  testWidgets('el puntaje del intento recién arrancado se muestra en 0', (
    tester,
  ) async {
    final gateway = FakeNivelJuegoGateway(
      const IntentoNivel(intentoId: 'i1', desafios: [_desafioTexto]),
    );

    await tester.pumpWidget(_pantalla(gateway));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('nivel-juego-puntaje')), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
  });

  testWidgets('si arrancar el intento falla, muestra el estado de error', (
    tester,
  ) async {
    final gateway = FakeNivelJuegoGateway(
      const IntentoNivel(intentoId: 'i1', desafios: [_desafioTexto]),
    )..throwOnNextCall = Exception('sin red');

    await tester.pumpWidget(_pantalla(gateway));
    await tester.pumpAndSettle();

    expect(find.text('No se pudo arrancar la partida'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });

  testWidgets('reintentar tras un error vuelve a llamar a iniciarIntento', (
    tester,
  ) async {
    final gateway = FakeNivelJuegoGateway(
      const IntentoNivel(intentoId: 'i1', desafios: [_desafioTexto]),
    )..throwOnNextCall = Exception('sin red');

    await tester.pumpWidget(_pantalla(gateway));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(gateway.iniciarIntentoCalls, 2);
    expect(find.text('¿Dónde está esto?'), findsOneWidget);
  });

  testWidgets(
    'cerrar el toast ("Listo, voy a adivinar") lo oculta y revela el stub de mapa',
    (tester) async {
      final gateway = FakeNivelJuegoGateway(
        const IntentoNivel(intentoId: 'i1', desafios: [_desafioTexto]),
      );

      await tester.pumpWidget(_pantalla(gateway));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('nivel-juego-mapa-stub')), findsOneWidget);
      expect(find.text('¿Dónde está esto?'), findsOneWidget);

      await tester.tap(find.byKey(const Key('nivel-juego-boton-listo')));
      await tester.pumpAndSettle();

      expect(find.text('¿Dónde está esto?'), findsNothing);
      expect(find.byKey(const Key('nivel-juego-mapa-stub')), findsOneWidget);
    },
  );
}
