import 'package:flutter_test/flutter_test.dart';
import 'package:geoquest/screens/cuenta_atras_de_desafio.dart';

/// Reloj de pared bajo control del test: la pieza lo recibe inyectado justo
/// para esto (D2 de `design.md`), porque `flutter_test` no falsea el reloj
/// global. Moverlo a mano es además la única forma de reproducir "pasó tiempo
/// real sin que se entregara ningún fotograma".
late DateTime _reloj;

/// Los tests son `testWidgets` sin árbol: hace falta el binding para que el
/// `Ticker` de la cuenta atrás reciba fotogramas con `tester.pump`.
///
/// La cuenta atrás se libera dentro del propio cuerpo del test, y no con un
/// `addTearDown`, porque `flutter_test` comprueba que no queden animaciones
/// vivas antes de correr los tearDown.
Future<void> _conCuentaAtras(
  Future<void> Function(CuentaAtrasDeDesafio cuenta, List<void> avisos) cuerpo,
) async {
  _reloj = DateTime.utc(2026, 8, 19, 12);
  final avisos = <void>[];
  final cuenta = CuentaAtrasDeDesafio(
    vsync: const TestVSync(),
    ahora: () => _reloj,
    alAgotarse: () => avisos.add(null),
  );
  try {
    await cuerpo(cuenta, avisos);
  } finally {
    cuenta.dispose();
  }
}

/// Avanza el reloj de pared y entrega un fotograma, como un frame normal.
Future<void> _correr(WidgetTester tester, Duration cuanto) async {
  _reloj = _reloj.add(cuanto);
  await tester.pump();
}

void main() {
  group('arranque', () {
    testWidgets('arranca con el tiempo completo del desafío', (tester) async {
      await _conCuentaAtras((cuenta, _) async {
        cuenta.arrancar(const Duration(seconds: 60));

        expect(cuenta.total, const Duration(seconds: 60));
        expect(cuenta.restante, const Duration(seconds: 60));
        expect(cuenta.fraccion, 1);
        expect(cuenta.segundosParaLaEtiqueta, 60);
        expect(cuenta.enZonaCritica, isFalse);
        expect(cuenta.corriendo, isTrue);
      });
    });

    testWidgets('arrancar de nuevo reinicia el tiempo del desafío anterior', (
      tester,
    ) async {
      await _conCuentaAtras((cuenta, _) async {
        cuenta.arrancar(const Duration(seconds: 60));
        await _correr(tester, const Duration(seconds: 50));
        expect(cuenta.restante, const Duration(seconds: 10));

        cuenta.arrancar(const Duration(seconds: 30));

        expect(cuenta.restante, const Duration(seconds: 30));
        expect(cuenta.enZonaCritica, isFalse);
        expect(cuenta.corriendo, isTrue);
      });
    });

    testWidgets('un desafío sin tiempo no arranca nada', (tester) async {
      await _conCuentaAtras((cuenta, avisos) async {
        cuenta.arrancar(Duration.zero);

        expect(cuenta.corriendo, isFalse);
        expect(cuenta.fraccion, 0);
        expect(cuenta.enZonaCritica, isFalse);
        expect(cuenta.umbralCritico, Duration.zero);
        expect(avisos, isEmpty);
      });
    });
  });

  group('tiempo continuo', () {
    testWidgets('la fracción cambia entre un segundo y el siguiente', (
      tester,
    ) async {
      await _conCuentaAtras((cuenta, _) async {
        cuenta.arrancar(const Duration(seconds: 60));

        await _correr(tester, const Duration(seconds: 10));
        final enElSegundoEntero = cuenta.fraccion;

        await _correr(tester, const Duration(milliseconds: 500));

        expect(cuenta.fraccion, lessThan(enElSegundoEntero));
        expect(cuenta.fraccion, closeTo(49.5 / 60, 1e-9));
      });
    });

    testWidgets('la etiqueta no se mueve dentro del mismo segundo', (
      tester,
    ) async {
      await _conCuentaAtras((cuenta, _) async {
        cuenta.arrancar(const Duration(seconds: 60));

        await _correr(tester, const Duration(seconds: 10));
        expect(cuenta.segundosParaLaEtiqueta, 50);

        await _correr(tester, const Duration(milliseconds: 500));

        // 49,5 s siguen siendo "0:50" en un cronómetro: la etiqueta redondea
        // hacia arriba (D5), así que enseña el segundo que se está gastando.
        expect(cuenta.segundosParaLaEtiqueta, 50);
      });
    });

    testWidgets('la etiqueta enseña el último segundo hasta agotarlo', (
      tester,
    ) async {
      await _conCuentaAtras((cuenta, _) async {
        cuenta.arrancar(const Duration(seconds: 60));

        await _correr(tester, const Duration(milliseconds: 59500));

        expect(cuenta.segundosParaLaEtiqueta, 1);
      });
    });

    testWidgets('un salto de reloj sin fotogramas no regala tiempo', (
      tester,
    ) async {
      await _conCuentaAtras((cuenta, _) async {
        cuenta.arrancar(const Duration(seconds: 60));

        // Ocho segundos de reloj real con un único fotograma al volver: es lo
        // que pasa al dejar la app en segundo plano (D1).
        await _correr(tester, const Duration(seconds: 8));

        expect(cuenta.restante, const Duration(seconds: 52));
      });
    });

    testWidgets('cada fotograma avisa, y eso es lo que repinta la barra', (
      tester,
    ) async {
      await _conCuentaAtras((cuenta, _) async {
        var avisadas = 0;
        cuenta.addListener(() => avisadas++);

        cuenta.arrancar(const Duration(seconds: 60));
        expect(avisadas, 1);

        await _correr(tester, const Duration(milliseconds: 16));
        await _correr(tester, const Duration(milliseconds: 16));

        expect(avisadas, 3);
      });
    });
  });

  group('zona crítica', () {
    testWidgets('el umbral es la quinta parte del desafío', (tester) async {
      await _conCuentaAtras((cuenta, _) async {
        cuenta.arrancar(const Duration(seconds: 60));

        expect(cuenta.umbralCritico, const Duration(seconds: 12));

        await _correr(tester, const Duration(milliseconds: 47900));
        expect(cuenta.enZonaCritica, isFalse);

        await _correr(tester, const Duration(milliseconds: 200));

        expect(cuenta.restante, const Duration(milliseconds: 11900));
        expect(cuenta.enZonaCritica, isTrue);
      });
    });

    testWidgets('con pocos segundos por desafío manda el suelo de 5 s', (
      tester,
    ) async {
      await _conCuentaAtras((cuenta, _) async {
        cuenta.arrancar(const Duration(seconds: 10));

        // Una quinta parte serían 2 s, que no dan tiempo a reaccionar (D6).
        expect(cuenta.umbralCritico, CuentaAtrasDeDesafio.sueloCritico);

        await _correr(tester, const Duration(seconds: 6));

        expect(cuenta.restante, const Duration(seconds: 4));
        expect(cuenta.fraccion, closeTo(0.4, 1e-9));
        expect(cuenta.enZonaCritica, isTrue);
      });
    });

    testWidgets('justo en el umbral todavía no es zona crítica', (
      tester,
    ) async {
      await _conCuentaAtras((cuenta, _) async {
        cuenta.arrancar(const Duration(seconds: 10));

        await _correr(tester, const Duration(seconds: 5));

        expect(cuenta.restante, CuentaAtrasDeDesafio.sueloCritico);
        expect(cuenta.enZonaCritica, isFalse);
      });
    });

    testWidgets('el tiempo agotado sigue contando como zona crítica', (
      tester,
    ) async {
      await _conCuentaAtras((cuenta, _) async {
        cuenta.arrancar(const Duration(seconds: 10));

        await _correr(tester, const Duration(seconds: 10));

        // Entre agotarse el tiempo y entrar el revelado la barra se queda un
        // instante en pantalla: en rojo a 0:00, no en teal.
        expect(cuenta.restante, Duration.zero);
        expect(cuenta.enZonaCritica, isTrue);
      });
    });
  });

  group('agotarse', () {
    testWidgets('avisa una sola vez y deja de correr', (tester) async {
      await _conCuentaAtras((cuenta, avisos) async {
        cuenta.arrancar(const Duration(seconds: 10));

        await _correr(tester, const Duration(seconds: 10));

        expect(cuenta.restante, Duration.zero);
        expect(cuenta.fraccion, 0);
        expect(cuenta.segundosParaLaEtiqueta, 0);
        expect(cuenta.corriendo, isFalse);
        expect(avisos, hasLength(1));

        await _correr(tester, const Duration(seconds: 5));

        expect(avisos, hasLength(1));
      });
    });

    testWidgets('pasarse del tiempo no deja la fracción en negativo', (
      tester,
    ) async {
      await _conCuentaAtras((cuenta, _) async {
        cuenta.arrancar(const Duration(seconds: 10));

        await _correr(tester, const Duration(seconds: 40));

        expect(cuenta.restante, Duration.zero);
        expect(cuenta.fraccion, 0);
      });
    });

    testWidgets('parar deja el tiempo quieto y no avisa de agotado', (
      tester,
    ) async {
      await _conCuentaAtras((cuenta, avisos) async {
        cuenta.arrancar(const Duration(seconds: 60));

        await _correr(tester, const Duration(seconds: 20));
        cuenta.parar();
        await _correr(tester, const Duration(seconds: 60));

        expect(cuenta.restante, const Duration(seconds: 40));
        expect(cuenta.corriendo, isFalse);
        expect(avisos, isEmpty);
      });
    });
  });

  group('extender', () {
    testWidgets('suma la duración al restante y al total sin reiniciar', (
      tester,
    ) async {
      await _conCuentaAtras((cuenta, avisos) async {
        cuenta.arrancar(const Duration(seconds: 60));
        await _correr(tester, const Duration(seconds: 50));
        expect(cuenta.restante, const Duration(seconds: 10));

        cuenta.extender(const Duration(seconds: 15));

        expect(cuenta.restante, const Duration(seconds: 25));
        expect(cuenta.total, const Duration(seconds: 75));
        expect(cuenta.corriendo, isTrue);
        expect(avisos, isEmpty);
      });
    });

    testWidgets('el tiempo extendido de verdad retrasa el auto-envío', (
      tester,
    ) async {
      await _conCuentaAtras((cuenta, avisos) async {
        cuenta.arrancar(const Duration(seconds: 10));
        cuenta.extender(const Duration(seconds: 15));

        await _correr(tester, const Duration(seconds: 10));
        expect(avisos, isEmpty, reason: 'los 10s originales ya no bastan');

        await _correr(tester, const Duration(seconds: 15));
        expect(avisos, hasLength(1));
      });
    });

    testWidgets('extender un desafío ya agotado no hace nada', (tester) async {
      await _conCuentaAtras((cuenta, avisos) async {
        cuenta.arrancar(const Duration(seconds: 10));
        await _correr(tester, const Duration(seconds: 10));
        expect(avisos, hasLength(1));

        cuenta.extender(const Duration(seconds: 15));

        expect(cuenta.restante, Duration.zero);
        expect(cuenta.corriendo, isFalse);
      });
    });

    testWidgets('extender tras parar no revive la cuenta atrás', (
      tester,
    ) async {
      await _conCuentaAtras((cuenta, avisos) async {
        cuenta.arrancar(const Duration(seconds: 60));
        cuenta.parar();

        cuenta.extender(const Duration(seconds: 15));

        expect(cuenta.corriendo, isFalse);
        expect(avisos, isEmpty);
      });
    });
  });

  group('opacidad del marco crítico', () {
    const umbral = Duration(seconds: 12);

    test('fuera de la zona crítica no se dibuja', () {
      expect(
        opacidadDelMarcoCritico(
          restante: const Duration(seconds: 13),
          umbral: umbral,
        ),
        0,
      );
      expect(
        opacidadDelMarcoCritico(
          restante: const Duration(seconds: 13),
          umbral: Duration.zero,
        ),
        0,
      );
    });

    test('entra con un fundido en vez de aparecer de golpe', () {
      final justoAlCruzar = opacidadDelMarcoCritico(
        restante: umbral - const Duration(milliseconds: 20),
        umbral: umbral,
        conLatido: false,
      );
      final aMediaEntrada = opacidadDelMarcoCritico(
        restante: umbral - const Duration(milliseconds: 120),
        umbral: umbral,
        conLatido: false,
      );
      final yaDentro = opacidadDelMarcoCritico(
        restante: umbral - const Duration(milliseconds: 400),
        umbral: umbral,
        conLatido: false,
      );

      expect(justoAlCruzar, closeTo(20 / 240, 1e-9));
      expect(aMediaEntrada, closeTo(0.5, 1e-9));
      expect(yaDentro, 1);
    });

    test('el latido se mueve despacio y nunca se apaga del todo', () {
      final muestras = <double>[
        for (var ms = 300; ms <= 3000; ms += 50)
          opacidadDelMarcoCritico(
            restante: umbral - Duration(milliseconds: ms),
            umbral: umbral,
          ),
      ];

      // Ni parpadeo ni marco fantasma: la opacidad se queda dentro de una
      // banda estrecha y alta (D7).
      expect(muestras.reduce((a, b) => a < b ? a : b), greaterThan(0.6));
      expect(muestras.reduce((a, b) => a > b ? a : b), lessThanOrEqualTo(1));
      expect(muestras.any((o) => o < 0.999), isTrue);
    });

    test('sin animaciones el marco se queda fijo', () {
      for (var ms = 300; ms <= 3000; ms += 50) {
        expect(
          opacidadDelMarcoCritico(
            restante: umbral - Duration(milliseconds: ms),
            umbral: umbral,
            conLatido: false,
          ),
          1,
        );
      }
    });
  });
}
