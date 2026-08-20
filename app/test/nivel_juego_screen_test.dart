import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geoquest/mapa/mapa_mundi.dart';
import 'package:geoquest/screens/nivel_juego_screen.dart';
import 'package:geoquest/services/comodines_gateway.dart';
import 'package:geoquest/services/nivel_juego_gateway.dart';

import 'fakes/fake_comodines_gateway.dart';
import 'fakes/fake_nivel_juego_gateway.dart';
import 'fakes/mundo_de_prueba.dart';

const _desafioImagen = DesafioJuego(
  id: 'd1',
  nombre: 'Torre Eiffel',
  tipo: TipoDesafio.imagen,
  activo: true,
  imagenUrl: 'https://example.com/foto.jpg',
);

const _desafioVideo = DesafioJuego(
  id: 'd2',
  nombre: 'Coliseo de Roma',
  tipo: TipoDesafio.video,
  activo: true,
  videoUrl: 'https://example.com/clip.mp4',
);

const _desafioTexto = DesafioJuego(
  id: 'd3',
  nombre: 'Charles Darwin',
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
Widget _appConCamino(
  NivelJuegoGateway gateway, {
  String? nivelNombre,
  DateTime Function()? ahora,
  bool reducirAnimaciones = false,
  ComodinesGateway? comodinesGateway,
}) {
  return MaterialApp(
    builder: reducirAnimaciones
        ? (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          )
        : null,
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
                  // Sin comodinesGateway explícito, cada apertura recibe su
                  // propio falso (semilla 1/1/1/0): así los tests que no
                  // ejercitan la bandeja no dependen unos de otros.
                  comodinesGateway: comodinesGateway ?? FakeComodinesGateway(),
                  cargadorDeMundo: cargarMundoDePrueba,
                  ahora: ahora,
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
  bool reducirAnimaciones = false,
  ComodinesGateway? comodinesGateway,
}) async {
  tester.view.physicalSize = _movil;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    _appConCamino(
      gateway,
      nivelNombre: nivelNombre,
      // La cuenta atrás cuelga de un instante de fin de reloj de pared
      // (INT-114, D1), así que el reloj del test tiene que ser el del binding:
      // es el que avanza con `tester.pump`.
      ahora: () => tester.binding.clock.now(),
      reducirAnimaciones: reducirAnimaciones,
      comodinesGateway: comodinesGateway,
    ),
  );
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
  String objetivoGlobal = 'Objetivo de prueba',
}) => FakeNivelJuegoGateway(
  IntentoNivel(
    intentoId: 'i1',
    desafios: desafios,
    segundosPorDesafio: segundosPorDesafio,
    objetivoGlobal: objetivoGlobal,
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

/// Relleno de la barra de cuenta atrás en este momento, de 0 a 1. Cambia en
/// cada fotograma, no una vez por segundo (INT-114).
double _fraccionDeLaCuentaAtras(WidgetTester tester) {
  return tester
      .widget<LinearProgressIndicator>(
        find.descendant(
          of: find.byKey(const Key('nivel-juego-cuenta-atras')),
          matching: find.byType(LinearProgressIndicator),
        ),
      )
      .value!;
}

/// Opacidad con la que se pinta el marco de tiempo crítico, o `null` si no hay
/// marco en pantalla.
double? _opacidadDelMarco(WidgetTester tester) {
  final marco = find.byKey(const Key('nivel-juego-marco-critico'));
  if (marco.evaluate().isEmpty) return null;

  final decoracion =
      tester.widget<DecoratedBox>(marco).decoration as BoxDecoration;
  return (decoracion.border! as Border).top.color.a;
}

/// ¿Cae [p] dentro del área visible de una pantalla de tamaño [pantalla] cuyas
/// cuatro esquinas están redondeadas con radio [radio]?
bool _dentroDeLaPantalla(Offset p, Size pantalla, double radio) {
  if (p.dx < -1e-9 ||
      p.dy < -1e-9 ||
      p.dx > pantalla.width + 1e-9 ||
      p.dy > pantalla.height + 1e-9) {
    return false;
  }
  if (radio <= 0) return true;

  final izquierda = p.dx < radio;
  final derecha = p.dx > pantalla.width - radio;
  final arriba = p.dy < radio;
  final abajo = p.dy > pantalla.height - radio;
  // Fuera de las cuatro esquinas manda el canto recto, que ya se comprobó.
  if (!(izquierda || derecha) || !(arriba || abajo)) return true;

  final centro = Offset(
    izquierda ? radio : pantalla.width - radio,
    arriba ? radio : pantalla.height - radio,
  );
  return (p - centro).distance <= radio + 1e-9;
}

/// Puntos del contorno de un rectángulo de esquinas redondeadas: los cuatro
/// arcos y los cuatro tramos rectos.
List<Offset> _contornoRedondeado(Rect caja, double radio, {int pasos = 90}) {
  final centros = <Offset>[
    Offset(caja.left + radio, caja.top + radio),
    Offset(caja.right - radio, caja.top + radio),
    Offset(caja.right - radio, caja.bottom - radio),
    Offset(caja.left + radio, caja.bottom - radio),
  ];

  final puntos = <Offset>[];
  for (var esquina = 0; esquina < 4; esquina++) {
    final desde = math.pi + esquina * math.pi / 2;
    for (var i = 0; i <= pasos; i++) {
      final angulo = desde + (math.pi / 2) * i / pasos;
      puntos.add(
        centros[esquina] + Offset(math.cos(angulo), math.sin(angulo)) * radio,
      );
    }
  }
  for (var i = 0; i <= pasos; i++) {
    final t = i / pasos;
    final y = caja.top + radio + (caja.height - 2 * radio) * t;
    final x = caja.left + radio + (caja.width - 2 * radio) * t;
    puntos.addAll([
      Offset(caja.left, y),
      Offset(caja.right, y),
      Offset(x, caja.top),
      Offset(x, caja.bottom),
    ]);
  }
  return puntos;
}

/// Deja la cuenta atrás justo al empezar un segundo entero, para que lo que
/// venga después caiga dentro de ese mismo segundo sin depender de cuánto
/// tardó el arranque de la pantalla.
Future<void> _alinearConElSegundo(WidgetTester tester) async {
  final desde = _etiquetaDeLaCuentaAtras(tester);
  for (var i = 0; i < 25; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (_etiquetaDeLaCuentaAtras(tester) != desde) return;
  }
  fail('la cuenta atrás no cambió de segundo en 1,25 s');
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

    testWidgets('salir mientras carga el intento no revienta', (tester) async {
      // La cuenta atrás es `late final` y solo arranca cuando responde la RPC:
      // si el jugador se va antes, se construye dentro del propio `dispose`.
      final gateway = _gatewayCon(const [_desafioTexto])
        ..pausaAlIniciar = Completer<void>();

      await tester.pumpWidget(_appConCamino(gateway));
      await tester.tap(find.text('Ir al nivel'));
      await _asentar(tester);
      expect(find.byType(CircularProgressIndicator), findsWidgets);

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pump();
      gateway.pausaAlIniciar!.complete();
      await tester.pump();

      expect(tester.takeException(), isNull);
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

    testWidgets('muestra el objetivo global de la temática sin el nombre del '
        'desafío, para los tres tipos de contenido', (tester) async {
      final gateway = _gatewayCon(const [
        _desafioImagen,
        _desafioVideo,
        _desafioTexto,
      ], objetivoGlobal: '¿Dónde está este monumento?');

      await _abrirNivel(tester, gateway);
      expect(find.text('¿Dónde está este monumento?'), findsOneWidget);
      expect(find.text('Torre Eiffel'), findsNothing);

      await _cerrarPista(tester);
      await _colocarPin(tester);
      await _confirmarYRevelar(tester);
      await _avanzarDesdeElRevelado(tester);

      expect(find.text('¿Dónde está este monumento?'), findsOneWidget);
      expect(find.text('Coliseo de Roma'), findsNothing);

      await _cerrarPista(tester);
      await _colocarPin(tester);
      await _confirmarYRevelar(tester);
      await _avanzarDesdeElRevelado(tester);

      expect(find.text('¿Dónde está este monumento?'), findsOneWidget);
      expect(find.text('Charles Darwin'), findsNothing);
    });

    testWidgets(
      'el revelado muestra el nombre del desafío junto al lugar real',
      (tester) async {
        final gateway = _gatewayCon(const [_desafioImagen, _desafioVideo])
          ..respuesta = respuestaDePrueba(nombreLugar: 'París, Francia');

        await _abrirNivel(tester, gateway);
        await _cerrarPista(tester);
        await _colocarPin(tester);
        await _confirmarYRevelar(tester);

        expect(find.text('Torre Eiffel'), findsOneWidget);
        expect(find.text('París, Francia'), findsOneWidget);

        gateway.respuesta = respuestaDePrueba(nombreLugar: 'Roma, Italia');
        await _avanzarDesdeElRevelado(tester);
        await _cerrarPista(tester);
        await _colocarPin(tester);
        await _confirmarYRevelar(tester);

        expect(find.text('Coliseo de Roma'), findsOneWidget);
        expect(find.text('Roma, Italia'), findsOneWidget);
      },
    );

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
      // 60 s por desafío a propósito: con 10 s, la mitad del tiempo y el suelo
      // de 5 s de la zona crítica caen en el mismo instante (D6), y el test
      // quedaría midiendo el filo entre ámbar y rojo.
      final gateway = _gatewayCon(const [
        _desafioTexto,
      ], segundosPorDesafio: 60);

      await _abrirNivel(tester, gateway);
      await tester.pump(const Duration(seconds: 30));

      expect(_etiquetaDeLaCuentaAtras(tester), '0:30');
      expect(_colorDeLaCuentaAtrasEnPantalla(tester), _goldDeLaCuentaAtras);
    });

    testWidgets('con pocos segundos por desafío el rojo llega por el suelo', (
      tester,
    ) async {
      final gateway = _gatewayCon(const [
        _desafioTexto,
      ], segundosPorDesafio: 10);

      await _abrirNivel(tester, gateway);
      await tester.pump(const Duration(seconds: 6));

      // Queda algo menos de 4 s: más de una quinta parte, pero por debajo del
      // suelo de 5 s, así que la barra ya está en rojo (D6).
      expect(_etiquetaDeLaCuentaAtras(tester), '0:04');
      expect(_colorDeLaCuentaAtrasEnPantalla(tester), _rojoDeLaCuentaAtras);
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

    testWidgets('la barra avanza entre un segundo y el siguiente', (
      tester,
    ) async {
      await _abrirNivel(
        tester,
        _gatewayCon(const [_desafioTexto], segundosPorDesafio: 60),
      );
      await _alinearConElSegundo(tester);

      final etiqueta = _etiquetaDeLaCuentaAtras(tester);
      final alEmpezarElSegundo = _fraccionDeLaCuentaAtras(tester);

      await tester.pump(const Duration(milliseconds: 300));

      // La barra se ha movido dentro del mismo segundo, y el número no: es lo
      // que quita el tirón sin dejar una etiqueta ilegible (D5 de INT-114).
      expect(_fraccionDeLaCuentaAtras(tester), lessThan(alEmpezarElSegundo));
      expect(_etiquetaDeLaCuentaAtras(tester), etiqueta);
    });

    testWidgets('volver de segundo plano no regala el tiempo perdido', (
      tester,
    ) async {
      await _abrirNivel(
        tester,
        _gatewayCon(const [_desafioTexto], segundosPorDesafio: 60),
      );

      // Ocho segundos de reloj real con un solo fotograma al volver: el tiempo
      // restante sale del reloj, no de los fotogramas entregados (D1).
      await tester.pump(const Duration(seconds: 8));

      expect(_etiquetaDeLaCuentaAtras(tester), '0:52');
    });
  });

  group('marco de tiempo crítico', () {
    testWidgets('no hay marco mientras queda tiempo de sobra', (tester) async {
      await _abrirNivel(
        tester,
        _gatewayCon(const [_desafioTexto], segundosPorDesafio: 60),
      );

      expect(_opacidadDelMarco(tester), isNull);

      await tester.pump(const Duration(seconds: 40));

      expect(_opacidadDelMarco(tester), isNull);
    });

    testWidgets('aparece al cruzar el umbral, y lo hace con un fundido', (
      tester,
    ) async {
      await _abrirNivel(
        tester,
        _gatewayCon(const [_desafioTexto], segundosPorDesafio: 60),
      );

      // Justo antes del umbral (una quinta parte de 60 s son 12 s) y de ahí a
      // pasitos, para pillar el primer fotograma dentro de la zona crítica sin
      // depender de cuánto tardó el arranque.
      await tester.pump(const Duration(seconds: 47));
      expect(_opacidadDelMarco(tester), isNull);

      double? alEncenderse;
      for (var i = 0; i < 20 && alEncenderse == null; i++) {
        await tester.pump(const Duration(milliseconds: 80));
        alEncenderse = _opacidadDelMarco(tester);
      }

      expect(alEncenderse, isNotNull);
      expect(alEncenderse!, lessThan(0.35));
      // Marco y barra se encienden con el mismo umbral, no con dos (D6).
      expect(_colorDeLaCuentaAtrasEnPantalla(tester), _rojoDeLaCuentaAtras);

      await tester.pump(const Duration(milliseconds: 300));

      expect(_opacidadDelMarco(tester), greaterThan(0.6));
    });

    testWidgets('cabe dentro de una pantalla con esquinas redondeadas', (
      tester,
    ) async {
      await _abrirNivel(
        tester,
        _gatewayCon(const [_desafioTexto], segundosPorDesafio: 60),
      );
      await tester.pump(const Duration(seconds: 48));

      final marco = find.byKey(const Key('nivel-juego-marco-critico'));
      final trazos = <BoxDecoration>[
        for (final caja in tester.widgetList<DecoratedBox>(
          find.descendant(
            of: marco,
            matching: find.byType(DecoratedBox),
            matchRoot: true,
          ),
        ))
          caja.decoration as BoxDecoration,
      ];
      final radios = [
        for (final trazo in trazos)
          (trazo.borderRadius! as BorderRadius).topLeft.x,
      ];

      expect(trazos, hasLength(2));
      // Algo más gordo que el trazo de 3 px con el que no se veía.
      expect((trazos.first.border! as Border).top.width, greaterThan(3));

      // Metido hacia dentro por los cuatro lados.
      final caja = tester.getRect(marco);
      final pantalla = tester.getRect(find.byType(MapaMundi).first);
      expect(caja.left, greaterThan(pantalla.left));
      expect(caja.top, greaterThan(pantalla.top));
      expect(caja.right, lessThan(pantalla.right));
      expect(caja.bottom, lessThan(pantalla.bottom));

      // Y lo que de verdad pide la spec: que quepa entero. No se comprueba
      // contra las constantes elegidas —eso solo repetiría el código— sino
      // muestreando el contorno de los DOS trazos, que comparten rectángulo,
      // contra el área visible de pantallas con distintos redondeos. Un iPhone
      // reciente ronda los 55.
      for (final radioDePantalla in const [0.0, 40.0, 55.0, 60.0]) {
        for (final radio in radios) {
          final fuera =
              _contornoRedondeado(caja.shift(-pantalla.topLeft), radio)
                  .where(
                    (p) =>
                        !_dentroDeLaPantalla(p, pantalla.size, radioDePantalla),
                  )
                  .toList();

          expect(
            fuera,
            isEmpty,
            reason:
                'con esquinas de radio $radioDePantalla, el trazo de radio '
                '$radio se sale por ${fuera.length} puntos '
                '(p. ej. ${fuera.take(1).join()})',
          );
        }
      }
    });

    testWidgets('no intercepta el toque que coloca el pin', (tester) async {
      await _abrirNivel(
        tester,
        _gatewayCon(const [_desafioTexto], segundosPorDesafio: 60),
      );
      await _cerrarPista(tester);
      await tester.pump(const Duration(seconds: 48));
      expect(_opacidadDelMarco(tester), isNotNull);

      // Un toque justo encima del marco, en el canto izquierdo de la pantalla.
      await tester.tapAt(const Offset(4, 520));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.byKey(const Key('nivel-juego-indicacion-con-pin')),
        findsOneWidget,
      );
      expect(_opacidadDelMarco(tester), isNotNull);
    });

    testWidgets('confirmar lo apaga y el revelado no lo trae de vuelta', (
      tester,
    ) async {
      final gateway = _gatewayCon(const [_desafioTexto], segundosPorDesafio: 60)
        ..respuesta = respuestaDePrueba(distanciaKm: 12, puntos: 1200);

      await _abrirNivel(tester, gateway);
      await _cerrarPista(tester);
      await _colocarPin(tester);
      await tester.pump(const Duration(seconds: 48));
      expect(_opacidadDelMarco(tester), isNotNull);

      await _confirmarYRevelar(tester);

      expect(_opacidadDelMarco(tester), isNull);
    });

    testWidgets('agotarse el tiempo lo apaga junto con la barra', (
      tester,
    ) async {
      final gateway = _gatewayCon(const [_desafioTexto], segundosPorDesafio: 3)
        ..respuesta = respuestaDePrueba(distanciaKm: 12, puntos: 1200);

      await _abrirNivel(tester, gateway);
      await _cerrarPista(tester);
      await _colocarPin(tester);

      // Con 3 s por desafío el suelo de 5 s deja el marco encendido de salida.
      expect(_opacidadDelMarco(tester), isNotNull);

      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(milliseconds: 5600));

      expect(find.byKey(const Key('nivel-juego-cuenta-atras')), findsNothing);
      expect(_opacidadDelMarco(tester), isNull);
    });

    testWidgets('el desafío siguiente arranca sin marco', (tester) async {
      final gateway = _gatewayCon(
        const [_desafioTexto, _desafioImagen],
        segundosPorDesafio: 30,
      )..respuesta = respuestaDePrueba(distanciaKm: 12, puntos: 1200);

      await _abrirNivel(tester, gateway);
      await _cerrarPista(tester);
      await _colocarPin(tester);
      await tester.pump(const Duration(seconds: 25));
      expect(_opacidadDelMarco(tester), isNotNull);

      await _confirmarYRevelar(tester);
      await _avanzarDesdeElRevelado(tester);

      expect(_etiquetaDeLaCuentaAtras(tester), '0:30');
      expect(_opacidadDelMarco(tester), isNull);
    });

    testWidgets('con animaciones reducidas el marco no late', (tester) async {
      await _abrirNivel(
        tester,
        _gatewayCon(const [_desafioTexto], segundosPorDesafio: 60),
        reducirAnimaciones: true,
      );
      await tester.pump(const Duration(seconds: 48));

      expect(_opacidadDelMarco(tester), 1);

      await tester.pump(const Duration(milliseconds: 300));

      expect(_opacidadDelMarco(tester), 1);
    });
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

  group('bandeja de comodines (INT-119)', () {
    testWidgets('empieza plegada en la fase de adivinar', (tester) async {
      await _abrirNivel(tester, _gatewayCon(const [_desafioTexto]));
      await _cerrarPista(tester);

      expect(
        find.byKey(const Key('bandeja-comodines-pestana')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('bandeja-comodines-fila')), findsNothing);
    });

    testWidgets('no se enseña mientras la pista está abierta', (tester) async {
      await _abrirNivel(tester, _gatewayCon(const [_desafioTexto]));

      expect(find.byKey(const Key('bandeja-comodines-pestana')), findsNothing);
    });

    testWidgets('se despliega al tocar la pestaña, con los 4 tipos', (
      tester,
    ) async {
      await _abrirNivel(tester, _gatewayCon(const [_desafioTexto]));
      await _cerrarPista(tester);

      await tester.tap(find.byKey(const Key('bandeja-comodines-pestana')));
      await tester.pump();

      expect(find.byKey(const Key('bandeja-comodines-fila')), findsOneWidget);
      for (final tipo in ['tiempo', 'pais', 'km1000', 'km500']) {
        expect(find.byKey(Key('bandeja-comodines-$tipo')), findsOneWidget);
      }
    });

    testWidgets('tocar fuera repliega la bandeja desplegada', (tester) async {
      await _abrirNivel(tester, _gatewayCon(const [_desafioTexto]));
      await _cerrarPista(tester);
      await tester.tap(find.byKey(const Key('bandeja-comodines-pestana')));
      await tester.pump();

      // Un punto lejos de la bandeja (que cuelga del borde derecho).
      await tester.tapAt(const Offset(20, 300));
      await tester.pump();

      expect(find.byKey(const Key('bandeja-comodines-fila')), findsNothing);
      expect(
        find.byKey(const Key('bandeja-comodines-pestana')),
        findsOneWidget,
      );
    });

    testWidgets('un comodín sin inventario no responde al toque', (
      tester,
    ) async {
      final comodines = FakeComodinesGateway(
        inventario: inventarioDePrueba(km500: 0),
      );
      await _abrirNivel(
        tester,
        _gatewayCon(const [_desafioTexto]),
        comodinesGateway: comodines,
      );
      await _cerrarPista(tester);
      await tester.tap(find.byKey(const Key('bandeja-comodines-pestana')));
      await tester.pump();

      await tester.tap(find.byKey(const Key('bandeja-comodines-km500')));
      await tester.pump();

      expect(comodines.usosEnviados, isEmpty);
    });

    testWidgets(
      'usar un comodín deja el resto deshabilitados para el resto del intento',
      (tester) async {
        final comodines = FakeComodinesGateway()
          ..resultadoUso = const ResultadoTiempo(extraSegundos: 15);
        await _abrirNivel(
          tester,
          _gatewayCon(const [_desafioTexto]),
          comodinesGateway: comodines,
        );
        await _cerrarPista(tester);
        await tester.tap(find.byKey(const Key('bandeja-comodines-pestana')));
        await tester.pump();

        await tester.tap(find.byKey(const Key('bandeja-comodines-tiempo')));
        await _asentar(tester);

        expect(comodines.usosEnviados, hasLength(1));

        // Reabrir y comprobar que el resto (con inventario) ya no responde.
        await tester.tap(find.byKey(const Key('bandeja-comodines-pestana')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('bandeja-comodines-km1000')));
        await tester.pump();

        expect(comodines.usosEnviados, hasLength(1));
      },
    );

    testWidgets('usar el comodín tiempo extiende la cuenta atrás', (
      tester,
    ) async {
      final comodines = FakeComodinesGateway()
        ..resultadoUso = const ResultadoTiempo(extraSegundos: 15);
      await _abrirNivel(
        tester,
        _gatewayCon(const [_desafioTexto]),
        comodinesGateway: comodines,
      );
      await _cerrarPista(tester);

      final antes = tester
          .widget<Text>(
            find.byKey(const Key('nivel-juego-cuenta-atras-etiqueta')),
          )
          .data;

      await tester.tap(find.byKey(const Key('bandeja-comodines-pestana')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('bandeja-comodines-tiempo')));
      await _asentar(tester);

      final despues = tester
          .widget<Text>(
            find.byKey(const Key('nivel-juego-cuenta-atras-etiqueta')),
          )
          .data;

      expect(comodines.usosEnviados.single.tipo, ComodinTipo.tiempo);
      expect(despues, isNot(antes));
    });

    testWidgets('usar el comodín país avisa con el país recibido', (
      tester,
    ) async {
      final comodines = FakeComodinesGateway()
        ..resultadoUso = const ResultadoPais(pais: 'Perú');
      await _abrirNivel(
        tester,
        _gatewayCon(const [_desafioTexto]),
        comodinesGateway: comodines,
      );
      await _cerrarPista(tester);

      await tester.tap(find.byKey(const Key('bandeja-comodines-pestana')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('bandeja-comodines-pais')));
      await _asentar(tester);

      expect(comodines.usosEnviados.single.tipo, ComodinTipo.pais);
      expect(find.byKey(const Key('nivel-juego-aviso')), findsOneWidget);
      expect(find.textContaining('Perú'), findsOneWidget);
    });

    testWidgets('usar un comodín de radio dibuja el círculo en el mapa', (
      tester,
    ) async {
      final comodines = FakeComodinesGateway()
        ..resultadoUso = const ResultadoRadio(
          tipo: ComodinTipo.km1000,
          lat: 41.8902,
          lng: 12.4922,
          radioKm: 1000,
        );
      await _abrirNivel(
        tester,
        _gatewayCon(const [_desafioTexto]),
        comodinesGateway: comodines,
      );
      await _cerrarPista(tester);

      expect(find.byKey(const Key('mapa-circulo-radio')), findsNothing);

      await tester.tap(find.byKey(const Key('bandeja-comodines-pestana')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('bandeja-comodines-km1000')));
      await _asentar(tester);

      expect(comodines.usosEnviados.single.tipo, ComodinTipo.km1000);
      expect(find.byKey(const Key('mapa-circulo-radio')), findsOneWidget);
    });

    testWidgets('un rechazo con motivo conocido avisa sin romper la pantalla', (
      tester,
    ) async {
      final comodines = FakeComodinesGateway()
        ..throwOnNextUsar = const ComodinRechazadoException(
          MotivoRechazoComodin.paisNoDisponible,
          'pais_no_disponible',
        );
      await _abrirNivel(
        tester,
        _gatewayCon(const [_desafioTexto]),
        comodinesGateway: comodines,
      );
      await _cerrarPista(tester);

      await tester.tap(find.byKey(const Key('bandeja-comodines-pestana')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('bandeja-comodines-pais')));
      await _asentar(tester);

      expect(find.textContaining('no tiene país registrado'), findsOneWidget);

      // El rechazo por país no disponible no marca el intento como
      // comodín-usado (D4/D5 de `design.md`): el resto sigue disponible.
      await tester.tap(find.byKey(const Key('bandeja-comodines-pestana')));
      await tester.pump();
      expect(find.byKey(const Key('bandeja-comodines-tiempo')), findsOneWidget);
    });
  });
}
