import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Cuenta atrás del desafío actual de la pantalla de juego: la trajo INT-99 y
/// la afina INT-114.
///
/// D1 de `design.md`: el tiempo no se lleva acumulando avisos de un segundo,
/// sino restando el reloj a un instante de fin que se fija una sola vez. El
/// [Ticker] no cuenta nada —solo avisa de que hay fotograma nuevo—, así que la
/// fracción que enseña la barra es continua y perder fotogramas (la app en
/// segundo plano, una pestaña dormida) no regala tiempo.
///
/// D3: vive fuera de la pantalla para poder probar el modelo de tiempo llamando
/// a métodos, el mismo reparto que `MapaMundiController` frente a `MapaMundi`.
///
/// Sigue siendo presentación: `segundos_transcurridos` y el bonus por rapidez
/// los calcula el servidor desde `intento_desafios.mostrado_en`.
class CuentaAtrasDeDesafio extends ChangeNotifier {
  CuentaAtrasDeDesafio({
    required TickerProvider vsync,
    required this.alAgotarse,
    DateTime Function()? ahora,
  }) : _ahora = ahora ?? DateTime.now {
    _ticker = vsync.createTicker((_) => _recalcular());
  }

  /// Fracción de tiempo por debajo de la cual el desafío está en zona crítica:
  /// la misma quinta parte que ya usaba el color de la barra (D6), para que no
  /// haya dos umbrales rojos distintos.
  static const double fraccionCritica = 0.2;

  /// Suelo de la zona crítica (D6). Con 10 segundos por desafío, una quinta
  /// parte son 2 s: el aviso llegaría cuando ya no queda nada que hacer con él.
  static const Duration sueloCritico = Duration(seconds: 5);

  /// Qué hacer cuando el desafío se queda sin tiempo. Lo decide la pantalla
  /// —confirmar con pin o sin él—; aquí solo se avisa.
  final VoidCallback alAgotarse;

  /// El reloj de pared se inyecta porque `flutter_test` no falsea el `clock`
  /// global de `package:clock` (D2): sin esto, un instante de fin no se puede
  /// probar con `tester.pump`.
  final DateTime Function() _ahora;

  late final Ticker _ticker;

  Duration _total = Duration.zero;
  Duration _restante = Duration.zero;
  DateTime? _fin;

  /// Tiempo completo del desafío en curso. `Duration.zero` antes del primer
  /// [arrancar].
  Duration get total => _total;

  /// Lo que queda, nunca por debajo de cero.
  Duration get restante => _restante;

  /// Con el ticker vivo: ni agotada ni parada.
  bool get corriendo => _ticker.isActive;

  /// Cuánto queda, de 0 a 1. Es lo que rellena la barra, y cambia en cada
  /// fotograma.
  double get fraccion {
    if (_total <= Duration.zero) return 0;
    return (_restante.inMicroseconds / _total.inMicroseconds).clamp(0.0, 1.0);
  }

  /// Segundos para la etiqueta `m:ss`, redondeados hacia arriba (D5): un
  /// desafío de 60 s enseña "1:00" durante el primer segundo completo y "0:01"
  /// durante el último, como cuenta un cronómetro.
  int get segundosParaLaEtiqueta =>
      (_restante.inMicroseconds / Duration.microsecondsPerSecond).ceil();

  /// Cuánto tiene que quedar para estar en zona crítica: la quinta parte del
  /// desafío, o el suelo de 5 s si esa quinta parte se queda corta (D6).
  Duration get umbralCritico {
    if (_total <= Duration.zero) return Duration.zero;
    final quintaParte = Duration(
      microseconds: (_total.inMicroseconds * fraccionCritica).round(),
    );
    return quintaParte > sueloCritico ? quintaParte : sueloCritico;
  }

  /// Zona crítica de tiempo: única fuente del rojo de la barra y del marco de
  /// aviso (D6). No depende de que el ticker siga vivo, para que el instante
  /// entre agotarse el tiempo y entrar el revelado no se vea en teal.
  bool get enZonaCritica => _total > Duration.zero && _restante < umbralCritico;

  /// Arranca —o reinicia— la cuenta atrás del desafío que se acaba de volver el
  /// actual. Fija el instante de fin una sola vez; de ahí en adelante todo se
  /// deriva del reloj.
  void arrancar(Duration total) {
    _ticker.stop();
    _total = total > Duration.zero ? total : Duration.zero;
    _restante = _total;
    _fin = _ahora().add(_total);
    if (_total > Duration.zero) _ticker.start();
    notifyListeners();
  }

  /// Extiende el margen antes del auto-envío (INT-119, comodín "tiempo"): NO
  /// reinicia el desafío, solo adelanta el instante de fin y suma [extra] al
  /// total/restante. Sin efecto sobre `mostrado_en` ni el bonus de rapidez del
  /// servidor —ese cálculo sigue siendo sobre el tiempo real transcurrido—: el
  /// comodín solo pospone el momento del auto-envío, no puntúa.
  void extender(Duration extra) {
    if (extra <= Duration.zero || _fin == null) return;
    _total += extra;
    _restante += extra;
    _fin = _fin!.add(extra);
    notifyListeners();
  }

  /// Deja la cuenta atrás quieta donde esté: se confirmó la respuesta, o la
  /// pantalla se va. Lo que ya se enseñaba sigue en pantalla hasta que entre el
  /// revelado.
  void parar() {
    if (!_ticker.isActive) return;
    _ticker.stop();
    _fin = null;
    notifyListeners();
  }

  void _recalcular() {
    final fin = _fin;
    if (fin == null) return;

    final restante = fin.difference(_ahora());
    if (restante > Duration.zero) {
      _restante = restante;
      notifyListeners();
      return;
    }

    _restante = Duration.zero;
    _ticker.stop();
    _fin = null;
    notifyListeners();
    alAgotarse();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }
}

/// Opacidad del marco de aviso de tiempo crítico (D7).
///
/// Sale del propio tiempo restante en vez de una animación aparte: la cuenta
/// atrás ya repinta cada fotograma, así que el fundido de entrada y el latido
/// salen gratis y son deterministas en tests.
///
/// [entrada] es lo que tarda el marco en aparecer del todo tras cruzar el
/// umbral; [cicloDelLatido] el periodo del latido, lento y de poca amplitud a
/// propósito —el juego se ve a pantalla completa y hay gente sensible al
/// flash—. Con [conLatido] en `false` (el sistema pide reducir animaciones) el
/// marco entra igual y se queda fijo.
double opacidadDelMarcoCritico({
  required Duration restante,
  required Duration umbral,
  bool conLatido = true,
  Duration entrada = const Duration(milliseconds: 240),
  Duration cicloDelLatido = const Duration(milliseconds: 1400),
}) {
  if (umbral <= Duration.zero) return 0;

  final dentro = umbral - restante;
  if (dentro <= Duration.zero) return 0;

  final avance = entrada <= Duration.zero
      ? 1.0
      : (dentro.inMicroseconds / entrada.inMicroseconds).clamp(0.0, 1.0);
  if (!conLatido || cicloDelLatido <= Duration.zero) return avance;

  final fase =
      2 * math.pi * (dentro.inMicroseconds / cicloDelLatido.inMicroseconds);
  final latido = 0.62 + 0.38 * (0.5 + 0.5 * math.sin(fase));
  return avance * latido;
}
