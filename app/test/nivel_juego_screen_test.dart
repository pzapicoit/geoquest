import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geoquest/mapa/mapa_mundi.dart';
import 'package:geoquest/screens/nivel_juego_screen.dart';
import 'package:geoquest/services/nivel_juego_gateway.dart';

import 'fakes/fake_nivel_juego_gateway.dart';
import 'fakes/mundo_de_prueba.dart';

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

/// Punto de la pantalla que cae sobre el mapa: por encima de los controles de
/// abajo y por debajo del HUD.
const _sobreElMapa = Offset(195, 422);

const _movil = Size(390, 844);

/// La pantalla de juego se abre siempre desde el camino, así que los tests la
/// montan igual: con una pantalla previa a la que poder volver.
Widget _appConCamino(NivelJuegoGateway gateway, {String? nivelNombre}) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => NivelJuegoScreen(
                  caminoId: 'nivel-1',
                  nivelNombre: nivelNombre,
                  gateway: gateway,
                  cargadorDeMundo: cargarMundoDePrueba,
                ),
              ),
            ),
            child: const Text('Ir al nivel'),
          ),
        ),
      ),
    ),
  );
}

/// Deja pasar los fotogramas que necesitan las cargas y las animaciones de
/// entrada. No se usa `pumpAndSettle` a propósito: el halo del pin y el punto
/// de la indicación laten en bucle y nunca dejarían de programar fotogramas.
Future<void> _asentar(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

Future<void> _abrirNivel(
  WidgetTester tester,
  NivelJuegoGateway gateway, {
  String? nivelNombre,
}) async {
  tester.view.physicalSize = _movil;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(_appConCamino(gateway, nivelNombre: nivelNombre));
  await tester.tap(find.text('Ir al nivel'));
  await _asentar(tester);
}

Future<void> _cerrarPista(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('nivel-juego-boton-listo')));
  await _asentar(tester);
}

Future<void> _colocarPin(WidgetTester tester) async {
  await tester.tapAt(_sobreElMapa);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// Confirma el pin y deja que la coreografía del revelado llegue al final
/// (INT-93: 5,44 s de secuencia).
Future<void> _confirmarYRevelar(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('nivel-juego-confirmar')));
  await _asentar(tester);
  await tester.pump(const Duration(milliseconds: 5600));
}

Future<void> _avanzarDesdeElRevelado(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('nivel-juego-siguiente')));
  await _asentar(tester);
}

FakeNivelJuegoGateway _gatewayCon(
  List<DesafioJuego> desafios, {
  int segundosPorDesafio = 60,
}) => FakeNivelJuegoGateway(
  IntentoNivel(
    intentoId: 'i1',
    desafios: desafios,
    segundosPorDesafio: segundosPorDesafio,
  ),
);

const _respondido = Color(0xFF2BC0A8);
const _actual = Color(0xFFFFC53D);
final _pendiente = Colors.white.withValues(alpha: 0.16);

const _tealDeLaCuentaAtras = Color(0xFF2BC0A8);
const _goldDeLaCuentaAtras = Color(0xFFFFC53D);
const _rojoDeLaCuentaAtras = Color(0xFFFF5A5F);

/// Etiqueta actual de la cuenta atrás ("m:ss"), leída del HUD.
String _etiquetaDeLaCuentaAtras(WidgetTester tester) {
  return tester
      .widget<Text>(find.byKey(const Key('nivel-juego-cuenta-atras-etiqueta')))
      .data!;
}

/// Color con el que se pinta la etiqueta de la cuenta atrás en este momento.
Color _colorDeLaCuentaAtrasEnPantalla(WidgetTester tester) {
  return tester
      .widget<Text>(find.byKey(const Key('nivel-juego-cuenta-atras-etiqueta')))
      .style!
      .color!;
}

/// Color de cada segmento de la barra de progreso, en orden.
List<Color?> _coloresDeSegmentos(WidgetTester tester) {
  final fila = tester.widget<Row>(
    find.byKey(const Key('nivel-juego-segmentos')),
  );

  return [
    for (final hijo in fila.children)
      if (hijo is Expanded)
        ((hijo.child as Container).decoration! as BoxDecoration).color,
  ];
}

void main() {
  group('arranque del intento', () {
    testWidgets('muestra un loading mientras arranca', (tester) async {
      final gateway = _gatewayCon(const [_desafioTexto])
        ..pausaAlIniciar = Completer<void>();

      await tester.pumpWidget(_appConCamino(gateway));
      await tester.tap(find.text('Ir al nivel'));
      await _asentar(tester);

      expect(find.byType(CircularProgressIndicator), findsWidgets);
      expect(find.text('¿Dónde está esto?'), findsNothing);

      gateway.pausaAlIniciar!.complete();
      await _asentar(tester);

      expect(find.text('¿Dónde está esto?'), findsOneWidget);
    });

    testWidgets('si falla, muestra el estado de error', (tester) async {
      final gateway = _gatewayCon(const [_desafioTexto])
        ..throwOnNextCall = Exception('sin red');

      await _abrirNivel(tester, gateway);

      expect(find.text('No se pudo arrancar la partida'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
    });

    testWidgets('reintentar vuelve a llamar a iniciarIntento', (tester) async {
      final gateway = _gatewayCon(const [_desafioTexto])
        ..throwOnNextCall = Exception('sin red');

      await _abrirNivel(tester, gateway);
      await tester.tap(find.text('Reintentar'));
      await _asentar(tester);

      expect(gateway.iniciarIntentoCalls, 2);
      expect(find.text('¿Dónde está esto?'), findsOneWidget);
    });

    testWidgets('un intento sin desafíos no crashea', (tester) async {
      await _abrirNivel(tester, _gatewayCon(const []));

      expect(
        find.text('Este nivel todavía no tiene desafíos disponibles'),
        findsOneWidget,
      );
      expect(find.text('Reintentar'), findsOneWidget);
    });
  });

  group('toast de pista', () {
    testWidgets('un desafío de texto muestra la pregunta', (tester) async {
      final gateway = _gatewayCon(const [_desafioTexto]);

      await _abrirNivel(tester, gateway);

      expect(find.text('¿Dónde está esto?'), findsOneWidget);
      expect(gateway.ultimoCaminoId, 'nivel-1');
    });

    testWidgets('un desafío de imagen muestra Image.network', (tester) async {
      await _abrirNivel(tester, _gatewayCon(const [_desafioImagen]));

      expect(find.byKey(const Key('nivel-juego-imagen')), findsOneWidget);
    });

    testWidgets('un desafío de vídeo monta el reproductor', (tester) async {
      await _abrirNivel(tester, _gatewayCon(const [_desafioVideo]));

      expect(find.byKey(const Key('nivel-juego-video')), findsOneWidget);
    });

    testWidgets('si el vídeo no arranca, avisa en vez de quedarse en negro', (
      tester,
    ) async {
      // En el entorno de test no hay plugin de plataforma para video_player,
      // así que `initialize()` falla siempre — el mismo camino que una URL
      // rota en producción.
      await _abrirNivel(tester, _gatewayCon(const [_desafioVideo]));

      expect(find.byKey(const Key('nivel-juego-video-error')), findsOneWidget);
    });

    testWidgets('la cabecera identifica tipo y número de pista', (
      tester,
    ) async {
      await _abrirNivel(
        tester,
        _gatewayCon(const [_desafioTexto, _desafioVideo]),
      );

      expect(find.text('PREGUNTA · PISTA 1'), findsOneWidget);
    });

    testWidgets('el pie explica qué se pide según el tipo', (tester) async {
      await _abrirNivel(tester, _gatewayCon(const [_desafioImagen]));

      expect(
        find.text(
          '¿Dónde se tomó esta imagen? Coloca tu pin lo más cerca que puedas.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('tocar el fondo oscurecido cierra la pista', (tester) async {
      await _abrirNivel(tester, _gatewayCon(const [_desafioTexto]));

      await tester.tapAt(const Offset(195, 700));
      await _asentar(tester);

      expect(find.text('¿Dónde está esto?'), findsNothing);
      expect(
        find.byKey(const Key('nivel-juego-indicacion-sin-pin')),
        findsOneWidget,
      );
    });

    testWidgets('la X de la cabecera cierra la pista', (tester) async {
      await _abrirNivel(tester, _gatewayCon(const [_desafioTexto]));

      await tester.tap(find.byKey(const Key('nivel-juego-cerrar-pista')));
      await _asentar(tester);

      expect(find.text('¿Dónde está esto?'), findsNothing);
    });
  });

  group('HUD de progreso y puntaje', () {
    testWidgets('muestra "Desafío 1 de N" con la pista abierta', (
      tester,
    ) async {
      await _abrirNivel(
        tester,
        _gatewayCon(const [_desafioTexto, _desafioImagen, _desafioVideo]),
      );

      expect(find.text('Desafío 1 de 3'), findsOneWidget);
      expect(find.byKey(const Key('nivel-juego-puntaje')), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
    });

    testWidgets('sigue visible tras cerrar la pista', (tester) async {
      await _abrirNivel(
        tester,
        _gatewayCon(const [_desafioTexto, _desafioImagen]),
      );
      await _cerrarPista(tester);

      expect(find.text('Desafío 1 de 2'), findsOneWidget);
      expect(find.byKey(const Key('nivel-juego-puntaje')), findsOneWidget);
    });

    testWidgets('hay un segmento por desafío del intento', (tester) async {
      await _abrirNivel(
        tester,
        _gatewayCon(const [
          _desafioTexto,
          _desafioImagen,
          _desafioVideo,
          _desafioImagen,
          _desafioVideo,
          _desafioTexto,
        ]),
      );

      expect(find.text('Desafío 1 de 6'), findsOneWidget);
      expect(_coloresDeSegmentos(tester), hasLength(6));
    });

    testWidgets('los segmentos distinguen respondido, actual y pendiente', (
      tester,
    ) async {
      final gateway = _gatewayCon(const [
        _desafioTexto,
        _desafioImagen,
        _desafioVideo,
      ]);

      await _abrirNivel(tester, gateway);
      expect(_coloresDeSegmentos(tester), [_actual, _pendiente, _pendiente]);

      await _cerrarPista(tester);
      await _colocarPin(tester);
      await _confirmarYRevelar(tester);

      // Con el revelado en pantalla el desafío ya cuenta como respondido.
      expect(_coloresDeSegmentos(tester), [
        _respondido,
        _pendiente,
        _pendiente,
      ]);

      await _avanzarDesdeElRevelado(tester);

      expect(_coloresDeSegmentos(tester), [_respondido, _actual, _pendiente]);
    });

    testWidgets('enseña el nombre del nivel que llega del camino', (
      tester,
    ) async {
      await _abrirNivel(
        tester,
        _gatewayCon(const [_desafioTexto]),
        nivelNombre: 'Praderas de Europa',
      );

      expect(find.text('PRADERAS DE EUROPA'), findsOneWidget);
    });

    testWidgets('sin nombre de nivel no deja hueco ni falla', (tester) async {
      await _abrirNivel(tester, _gatewayCon(const [_desafioTexto]));

      expect(find.byKey(const Key('nivel-juego-nombre-nivel')), findsNothing);
      expect(find.text('Desafío 1 de 1'), findsOneWidget);
    });
  });

  group('fase de adivinar', () {
    testWidgets('cerrar la pista revela el mapa y su indicación', (
      tester,
    ) async {
      await _abrirNivel(tester, _gatewayCon(const [_desafioTexto]));
      await _cerrarPista(tester);

      expect(find.text('¿Dónde está esto?'), findsNothing);
      expect(
        find.byKey(const Key('nivel-juego-indicacion-sin-pin')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('nivel-juego-confirmar')), findsOneWidget);
    });

    testWidgets('sin pin, Confirmar está deshabilitado', (tester) async {
      final gateway = _gatewayCon(const [_desafioTexto]);
      await _abrirNivel(tester, gateway);
      await _cerrarPista(tester);

      final boton = tester.widget<TextButton>(
        find.byKey(const Key('nivel-juego-confirmar')),
      );
      expect(boton.onPressed, isNull);

      await tester.tap(find.byKey(const Key('nivel-juego-confirmar')));
      await tester.pump();
      expect(gateway.respuestasEnviadas, isEmpty);
    });

    testWidgets('colocar el pin habilita Confirmar y muestra coordenadas', (
      tester,
    ) async {
      await _abrirNivel(tester, _gatewayCon(const [_desafioTexto]));
      await _cerrarPista(tester);
      await _colocarPin(tester);

      final boton = tester.widget<TextButton>(
        find.byKey(const Key('nivel-juego-confirmar')),
      );
      expect(boton.onPressed, isNotNull);
      expect(
        find.byKey(const Key('nivel-juego-indicacion-con-pin')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('nivel-juego-coordenadas')), findsOneWidget);
    });

    testWidgets('reabrir la pista no pierde el pin', (tester) async {
      await _abrirNivel(tester, _gatewayCon(const [_desafioTexto]));
      await _cerrarPista(tester);
      await _colocarPin(tester);

      await tester.tap(find.byKey(const Key('nivel-juego-ver-pista')));
      await _asentar(tester);
      expect(find.text('¿Dónde está esto?'), findsOneWidget);

      await _cerrarPista(tester);

      expect(
        find.byKey(const Key('nivel-juego-indicacion-con-pin')),
        findsOneWidget,
      );
      final boton = tester.widget<TextButton>(
        find.byKey(const Key('nivel-juego-confirmar')),
      );
      expect(boton.onPressed, isNotNull);
    });
  });

  group('confirmar la respuesta', () {
    testWidgets('manda intento, desafío y coordenadas del pin', (tester) async {
      final gateway = _gatewayCon(const [_desafioTexto, _desafioImagen]);
      await _abrirNivel(tester, gateway);
      await _cerrarPista(tester);
      await _colocarPin(tester);

      await tester.tap(find.byKey(const Key('nivel-juego-confirmar')));
      await _asentar(tester);

      expect(gateway.respuestasEnviadas, hasLength(1));
      final enviada = gateway.respuestasEnviadas.single;
      expect(enviada.intentoId, 'i1');
      expect(enviada.desafioId, 'd3');
      expect(enviada.latitud, inInclusiveRange(-85.06, 85.06));
      expect(enviada.longitud, inInclusiveRange(-180, 180));
    });

    testWidgets('confirmar revela el resultado sin avanzar de desafío', (
      tester,
    ) async {
      final gateway = _gatewayCon(const [_desafioTexto, _desafioImagen]);

      await _abrirNivel(tester, gateway);
      await _cerrarPista(tester);
      await _colocarPin(tester);
      await _confirmarYRevelar(tester);

      expect(find.byKey(const Key('nivel-juego-revelado')), findsOneWidget);
      expect(find.text('Desafío 1 de 2'), findsOneWidget);
      // Ni la pista del siguiente ni los controles de adivinar.
      expect(find.byKey(const Key('nivel-juego-imagen')), findsNothing);
      expect(find.byKey(const Key('nivel-juego-confirmar')), findsNothing);
    });

    testWidgets('si enviar falla, avisa y conserva el pin sin revelar', (
      tester,
    ) async {
      final gateway = _gatewayCon(const [_desafioTexto, _desafioImagen])
        ..throwOnNextResponder = Exception('sin red');

      await _abrirNivel(tester, gateway);
      await _cerrarPista(tester);
      await _colocarPin(tester);
      await tester.tap(find.byKey(const Key('nivel-juego-confirmar')));
      await _asentar(tester);

      expect(find.byKey(const Key('nivel-juego-aviso')), findsOneWidget);
      expect(find.byKey(const Key('nivel-juego-revelado')), findsNothing);
      expect(find.text('Desafío 1 de 2'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
      expect(
        find.byKey(const Key('nivel-juego-indicacion-con-pin')),
        findsOneWidget,
      );

      final boton = tester.widget<TextButton>(
        find.byKey(const Key('nivel-juego-confirmar')),
      );
      expect(boton.onPressed, isNotNull);
    });

    testWidgets('reintentar tras un fallo vuelve a enviar', (tester) async {
      final gateway = _gatewayCon(const [_desafioTexto, _desafioImagen])
        ..throwOnNextResponder = Exception('sin red');

      await _abrirNivel(tester, gateway);
      await _cerrarPista(tester);
      await _colocarPin(tester);
      await tester.tap(find.byKey(const Key('nivel-juego-confirmar')));
      await _asentar(tester);

      await _confirmarYRevelar(tester);

      expect(gateway.respuestasEnviadas, hasLength(2));
      expect(find.byKey(const Key('nivel-juego-revelado')), findsOneWidget);
    });
  });

  group('revelado de la respuesta', () {
    testWidgets(
      'la secuencia acaba con la distancia y los puntos del servidor',
      (tester) async {
        final gateway = _gatewayCon(const [_desafioTexto, _desafioImagen])
          ..respuesta = respuestaDePrueba(
            distanciaKm: 247.4,
            puntos: 520,
            puntosMaximos: 5000,
          );

        await _abrirNivel(tester, gateway);
        await _cerrarPista(tester);
        await _colocarPin(tester);
        await _confirmarYRevelar(tester);

        expect(find.text('247'), findsOneWidget);
        expect(find.text('+520'), findsOneWidget);
        expect(find.text('/ 5.000'), findsOneWidget);
        // Y el puntaje del intento en el HUD ya cuenta esos puntos.
        expect(find.text('520'), findsOneWidget);
      },
    );

    testWidgets('el lugar real y sus coordenadas se revelan', (tester) async {
      final gateway = _gatewayCon(const [_desafioTexto])
        ..respuesta = respuestaDePrueba(
          nombreLugar: 'Coliseo de Roma',
          latitudReal: 41.8902,
          longitudReal: 12.4922,
        );

      await _abrirNivel(tester, gateway);
      await _cerrarPista(tester);
      await _colocarPin(tester);
      await _confirmarYRevelar(tester);

      expect(find.text('Coliseo de Roma'), findsOneWidget);
      final coordenadas = tester.widget<Text>(
        find.byKey(const Key('nivel-juego-coordenadas-reales')),
      );
      expect(coordenadas.data, '41,9° N · 12,5° E');
    });

    testWidgets('la miniatura enseña la imagen de la pista', (tester) async {
      await _abrirNivel(tester, _gatewayCon(const [_desafioImagen]));
      await _cerrarPista(tester);
      await _colocarPin(tester);
      await _confirmarYRevelar(tester);

      expect(
        find.byKey(const Key('nivel-juego-miniatura-imagen')),
        findsOneWidget,
      );
    });

    testWidgets('una pista sin imagen enseña el distintivo de su tipo', (
      tester,
    ) async {
      await _abrirNivel(tester, _gatewayCon(const [_desafioVideo]));
      await _cerrarPista(tester);
      await _colocarPin(tester);
      await _confirmarYRevelar(tester);

      expect(
        find.byKey(const Key('nivel-juego-miniatura-tipo')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('nivel-juego-miniatura-imagen')),
        findsNothing,
      );
    });

    testWidgets('el mapa deja de aceptar gestos', (tester) async {
      await _abrirNivel(tester, _gatewayCon(const [_desafioTexto]));
      await _cerrarPista(tester);
      await _colocarPin(tester);
      await _confirmarYRevelar(tester);

      expect(
        tester.widget<MapaMundi>(find.byType(MapaMundi)).interactivo,
        isFalse,
      );
    });

    testWidgets('cambiar de tamaño a media animación no rompe el revelado', (
      tester,
    ) async {
      final gateway = _gatewayCon(const [_desafioTexto, _desafioImagen]);

      await _abrirNivel(tester, gateway);
      await _cerrarPista(tester);
      await _colocarPin(tester);
      await tester.tap(find.byKey(const Key('nivel-juego-confirmar')));
      await _asentar(tester);

      // En pleno tramo de cámara: el encuadre de destino se recalcula para el
      // tamaño nuevo en vez de seguir hacia el viejo. Desde INT-102 el cambio
      // ya no puede venir de una rotación, pero sí del teclado o de las barras
      // del sistema.
      await tester.pump(const Duration(milliseconds: 1400));
      tester.view.physicalSize = const Size(390, 600);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 4200));

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('nivel-juego-revelado')), findsOneWidget);
    });

    testWidgets('el revelado no avanza solo', (tester) async {
      final gateway = _gatewayCon(const [_desafioTexto, _desafioImagen]);

      await _abrirNivel(tester, gateway);
      await _cerrarPista(tester);
      await _colocarPin(tester);
      await _confirmarYRevelar(tester);
      await tester.pump(const Duration(seconds: 10));

      expect(find.byKey(const Key('nivel-juego-revelado')), findsOneWidget);
      expect(find.text('Desafío 1 de 2'), findsOneWidget);
    });

    testWidgets('avanzar abre la pista del siguiente con el mapa limpio', (
      tester,
    ) async {
      final gateway = _gatewayCon(const [_desafioTexto, _desafioImagen])
        ..respuesta = respuestaDePrueba(distanciaKm: 12, puntos: 1200);

      await _abrirNivel(tester, gateway);
      await _cerrarPista(tester);
      await _colocarPin(tester);
      await _confirmarYRevelar(tester);
      await _avanzarDesdeElRevelado(tester);

      expect(find.byKey(const Key('nivel-juego-revelado')), findsNothing);
      expect(find.text('Desafío 2 de 2'), findsOneWidget);
      expect(find.text('1.200'), findsOneWidget);
      expect(find.byKey(const Key('nivel-juego-imagen')), findsOneWidget);

      await _cerrarPista(tester);
      expect(
        find.byKey(const Key('nivel-juego-indicacion-sin-pin')),
        findsOneWidget,
      );
    });

    testWidgets(
      'en el último desafío "Ver resultados" cierra el intento y navega al '
      'resumen',
      (tester) async {
        final gateway = _gatewayCon(const [_desafioTexto]);

        await _abrirNivel(tester, gateway);
        await _cerrarPista(tester);
        await _colocarPin(tester);
        await _confirmarYRevelar(tester);

        expect(find.text('Ver resultados'), findsOneWidget);
        expect(find.text('Siguiente'), findsNothing);

        await tester.tap(find.byKey(const Key('nivel-juego-siguiente')));
        await _asentar(tester);

        expect(gateway.cerrarIntentoCalls, 1);
        expect(gateway.ultimoIntentoIdCerrado, 'i1');
        // Navega al resumen (INT-94), no vuelve a la pantalla anterior.
        expect(find.text('Ir al nivel'), findsNothing);
        expect(
          find.byKey(const Key('resumen-nivel-continuar')),
          findsOneWidget,
        );
      },
    );

    testWidgets('mientras se cierra el intento, "Ver resultados" queda '
        'deshabilitado', (tester) async {
      final gateway = _gatewayCon(const [_desafioTexto]);
      gateway.pausaAlCerrar = Completer<void>();

      await _abrirNivel(tester, gateway);
      await _cerrarPista(tester);
      await _colocarPin(tester);
      await _confirmarYRevelar(tester);

      await tester.tap(find.byKey(const Key('nivel-juego-siguiente')));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(find.byKey(const Key('nivel-juego-siguiente')))
            .onPressed,
        isNull,
      );

      gateway.pausaAlCerrar!.complete();
      await _asentar(tester);
    });

    testWidgets('si cerrar el intento falla, avisa y conserva el revelado', (
      tester,
    ) async {
      final gateway = _gatewayCon(const [_desafioTexto])
        ..throwOnNextCerrar = Exception('sin red');

      await _abrirNivel(tester, gateway);
      await _cerrarPista(tester);
      await _colocarPin(tester);
      await _confirmarYRevelar(tester);

      await tester.tap(find.byKey(const Key('nivel-juego-siguiente')));
      await _asentar(tester);

      expect(gateway.cerrarIntentoCalls, 1);
      expect(find.byKey(const Key('nivel-juego-aviso')), findsOneWidget);
      expect(find.text('Ver resultados'), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(find.byKey(const Key('nivel-juego-siguiente')))
            .onPressed,
        isNotNull,
      );
    });

    testWidgets('repetir la animación no vuelve a llamar al servidor', (
      tester,
    ) async {
      final gateway = _gatewayCon(const [_desafioTexto, _desafioImagen])
        ..respuesta = respuestaDePrueba(distanciaKm: 247.4, puntos: 1200);

      await _abrirNivel(tester, gateway);
      await _cerrarPista(tester);
      await _colocarPin(tester);
      await _confirmarYRevelar(tester);

      await tester.tap(find.byKey(const Key('nivel-juego-repetir')));
      await tester.pump();

      // Los contadores vuelven a empezar y el servidor no se toca.
      expect(gateway.respuestasEnviadas, hasLength(1));
      expect(find.text('+0'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 5600));

      // Y al acabar el puntaje del intento sigue siendo el de una jugada.
      expect(find.text('+1.200'), findsOneWidget);
      expect(find.text('1.200'), findsOneWidget);
    });
  });

  group('salir del nivel', () {
    testWidgets('la X pide confirmación antes de nada', (tester) async {
      await _abrirNivel(tester, _gatewayCon(const [_desafioTexto]));

      await tester.tap(find.byKey(const Key('nivel-juego-salir')));
      await _asentar(tester);

      expect(find.text('¿Salir del nivel?'), findsOneWidget);
      expect(find.text('Ir al nivel'), findsNothing);
    });

    testWidgets('seguir jugando cierra el aviso y no navega', (tester) async {
      await _abrirNivel(tester, _gatewayCon(const [_desafioTexto]));

      await tester.tap(find.byKey(const Key('nivel-juego-salir')));
      await _asentar(tester);
      await tester.tap(find.byKey(const Key('nivel-juego-seguir-jugando')));
      await _asentar(tester);

      expect(find.text('¿Salir del nivel?'), findsNothing);
      expect(find.text('Desafío 1 de 1'), findsOneWidget);
      expect(find.text('Ir al nivel'), findsNothing);
    });

    testWidgets('salir y perder el intento vuelve al camino', (tester) async {
      await _abrirNivel(tester, _gatewayCon(const [_desafioTexto]));

      await tester.tap(find.byKey(const Key('nivel-juego-salir')));
      await _asentar(tester);
      await tester.tap(find.byKey(const Key('nivel-juego-salir-confirmar')));
      await _asentar(tester);
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Ir al nivel'), findsOneWidget);
    });

    testWidgets('el aviso dice cuántos puntos se pierden', (tester) async {
      final gateway = _gatewayCon(const [_desafioTexto, _desafioImagen])
        ..respuesta = respuestaDePrueba(distanciaKm: 8, puntos: 1200);

      await _abrirNivel(tester, gateway);
      await _cerrarPista(tester);
      await _colocarPin(tester);
      await _confirmarYRevelar(tester);

      await tester.tap(find.byKey(const Key('nivel-juego-salir')));
      await _asentar(tester);

      final detalle = tester.widget<Text>(
        find.byKey(const Key('nivel-juego-salir-detalle')),
      );
      expect(detalle.data, contains('1.200 puntos'));
    });
  });

  group('formato', () {
    test('el puntaje se separa por millares', () {
      expect(formatearPuntaje(0), '0');
      expect(formatearPuntaje(950), '950');
      expect(formatearPuntaje(1200), '1.200');
      expect(formatearPuntaje(24500), '24.500');
      expect(formatearPuntaje(1234567), '1.234.567');
    });

    test('la distancia lleva un decimal por debajo de 10 km', () {
      // Un acierto casi exacto no puede leerse como "0 km" (D12).
      expect(formatearDistancia(0), '0,0');
      expect(formatearDistancia(0.42), '0,4');
      expect(formatearDistancia(9.94), '9,9');
      expect(formatearDistancia(10), '10');
      expect(formatearDistancia(247.4), '247');
      expect(formatearDistancia(1234.6), '1.235');
    });

    test('la cuenta atrás se muestra como m:ss', () {
      expect(formatearCuentaAtras(60), '1:00');
      expect(formatearCuentaAtras(9), '0:09');
      expect(formatearCuentaAtras(0), '0:00');
      expect(formatearCuentaAtras(125), '2:05');
    });
  });

  group('cuenta atrás', () {
    testWidgets(
      'arranca con los segundos completos del nivel, en teal, y marca el '
      'primer desafío como mostrado',
      (tester) async {
        final gateway = _gatewayCon(const [
          _desafioTexto,
        ], segundosPorDesafio: 60);

        await _abrirNivel(tester, gateway);

        expect(_etiquetaDeLaCuentaAtras(tester), '1:00');
        expect(_colorDeLaCuentaAtrasEnPantalla(tester), _tealDeLaCuentaAtras);
        expect(gateway.desafiosMarcadosMostrados, ['d3']);
      },
    );

    testWidgets('sigue corriendo con el toast de pista abierto', (
      tester,
    ) async {
      final gateway = _gatewayCon(const [
        _desafioTexto,
      ], segundosPorDesafio: 10);

      await _abrirNivel(tester, gateway);
      // La pista no se cierra: la cuenta atrás sigue visible por encima.
      expect(find.text('¿Dónde está esto?'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));

      expect(_etiquetaDeLaCuentaAtras(tester), '0:07');
    });

    testWidgets('pasa a ámbar cuando queda la mitad del tiempo o menos', (
      tester,
    ) async {
      final gateway = _gatewayCon(const [
        _desafioTexto,
      ], segundosPorDesafio: 10);

      await _abrirNivel(tester, gateway);
      await tester.pump(const Duration(seconds: 5));

      expect(_etiquetaDeLaCuentaAtras(tester), '0:05');
      expect(_colorDeLaCuentaAtrasEnPantalla(tester), _goldDeLaCuentaAtras);
    });

    testWidgets('pasa a rojo por debajo de una quinta parte del tiempo', (
      tester,
    ) async {
      final gateway = _gatewayCon(const [
        _desafioTexto,
      ], segundosPorDesafio: 10);

      await _abrirNivel(tester, gateway);
      await tester.pump(const Duration(seconds: 9));

      expect(_etiquetaDeLaCuentaAtras(tester), '0:01');
      expect(_colorDeLaCuentaAtrasEnPantalla(tester), _rojoDeLaCuentaAtras);
    });

    testWidgets('no se enseña mientras se ve el revelado', (tester) async {
      await _abrirNivel(tester, _gatewayCon(const [_desafioTexto]));
      await _cerrarPista(tester);
      await _colocarPin(tester);
      await _confirmarYRevelar(tester);

      expect(find.byKey(const Key('nivel-juego-cuenta-atras')), findsNothing);
    });

    testWidgets(
      'avanzar de desafío reinicia la cuenta atrás y vuelve a marcar el '
      'nuevo desafío como mostrado',
      (tester) async {
        final gateway = _gatewayCon(
          const [_desafioTexto, _desafioImagen],
          segundosPorDesafio: 30,
        )..respuesta = respuestaDePrueba(distanciaKm: 12, puntos: 1200);

        await _abrirNivel(tester, gateway);
        await _cerrarPista(tester);
        await tester.pump(const Duration(seconds: 10));
        await _colocarPin(tester);
        await _confirmarYRevelar(tester);
        await _avanzarDesdeElRevelado(tester);

        expect(_etiquetaDeLaCuentaAtras(tester), '0:30');
        expect(gateway.desafiosMarcadosMostrados, ['d3', 'd1']);
      },
    );

    testWidgets(
      'reintentar tras un fallo al arrancar también arranca la cuenta atrás',
      (tester) async {
        final gateway = _gatewayCon(const [
          _desafioTexto,
        ], segundosPorDesafio: 45)..throwOnNextCall = Exception('sin red');

        await _abrirNivel(tester, gateway);
        await tester.tap(find.text('Reintentar'));
        await _asentar(tester);

        expect(_etiquetaDeLaCuentaAtras(tester), '0:45');
        expect(gateway.desafiosMarcadosMostrados, ['d3']);
      },
    );
  });

  group('agotar el tiempo', () {
    testWidgets(
      'con un pin colocado, confirma automáticamente y revela el resultado',
      (tester) async {
        final gateway = _gatewayCon(
          const [_desafioTexto],
          segundosPorDesafio: 3,
        )..respuesta = respuestaDePrueba(distanciaKm: 12, puntos: 1200);

        await _abrirNivel(tester, gateway);
        await _cerrarPista(tester);
        await _colocarPin(tester);

        await tester.pump(const Duration(seconds: 5));
        await tester.pump(const Duration(milliseconds: 5600));

        expect(gateway.respuestasEnviadas, hasLength(1));
        final enviada = gateway.respuestasEnviadas.single;
        expect(enviada.latitud, isNotNull);
        expect(enviada.longitud, isNotNull);
        expect(find.byKey(const Key('nivel-juego-revelado')), findsOneWidget);
        expect(find.text('+1.200'), findsOneWidget);
      },
    );

    testWidgets(
      'sin ningún pin colocado, responde sin coordenadas y revela con 0 '
      'puntos, sin distancia ni desglose',
      (tester) async {
        final gateway =
            _gatewayCon(const [_desafioTexto], segundosPorDesafio: 3)
              ..respuesta = respuestaDePrueba(
                distanciaKm: null,
                puntos: 0,
                puntosDistancia: 0,
                puntosBonus: 0,
              );

        await _abrirNivel(tester, gateway);
        await _cerrarPista(tester);

        await tester.pump(const Duration(seconds: 5));
        await tester.pump(const Duration(milliseconds: 5600));

        expect(gateway.respuestasEnviadas, hasLength(1));
        final enviada = gateway.respuestasEnviadas.single;
        expect(enviada.latitud, isNull);
        expect(enviada.longitud, isNull);
        expect(find.byKey(const Key('nivel-juego-revelado')), findsOneWidget);
        expect(find.text('+0'), findsOneWidget);
        expect(find.byKey(const Key('nivel-juego-distancia')), findsNothing);
        expect(
          find.byKey(const Key('nivel-juego-puntos-precision')),
          findsNothing,
        );
        expect(find.byKey(const Key('nivel-juego-puntos-bonus')), findsNothing);
      },
    );

    testWidgets('agotar el tiempo en el último desafío sigue rotulando "Ver '
        'resultados"', (tester) async {
      final gateway = _gatewayCon(const [_desafioTexto], segundosPorDesafio: 3);

      await _abrirNivel(tester, gateway);
      await _cerrarPista(tester);

      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(milliseconds: 5600));

      expect(find.text('Ver resultados'), findsOneWidget);
    });
  });

  group('desglose del puntaje en el revelado', () {
    testWidgets('muestra precisión y bonus cuando el bonus es mayor que 0', (
      tester,
    ) async {
      final gateway = _gatewayCon(const [_desafioTexto])
        ..respuesta = respuestaDePrueba(
          distanciaKm: 12,
          puntos: 4381,
          puntosDistancia: 4301,
          puntosBonus: 80,
        );

      await _abrirNivel(tester, gateway);
      await _cerrarPista(tester);
      await _colocarPin(tester);
      await _confirmarYRevelar(tester);

      expect(find.text('4.301 puntos de precisión'), findsOneWidget);
      expect(find.text('+80 por rapidez'), findsOneWidget);
    });

    testWidgets('no muestra línea de bonus cuando es 0', (tester) async {
      final gateway = _gatewayCon(const [_desafioTexto])
        ..respuesta = respuestaDePrueba(
          distanciaKm: 12,
          puntos: 4301,
          puntosDistancia: 4301,
          puntosBonus: 0,
        );

      await _abrirNivel(tester, gateway);
      await _cerrarPista(tester);
      await _colocarPin(tester);
      await _confirmarYRevelar(tester);

      expect(find.text('4.301 puntos de precisión'), findsOneWidget);
      expect(find.byKey(const Key('nivel-juego-puntos-bonus')), findsNothing);
    });
  });
}
