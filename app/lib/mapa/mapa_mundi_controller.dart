import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Offset, Size;

import 'mercator.dart';

/// Un punto del planeta. Es lo que la pantalla de juego manda a
/// `responder_desafio`.
@immutable
class Coordenada {
  const Coordenada({required this.latitud, required this.longitud});

  final double latitud;
  final double longitud;

  @override
  bool operator ==(Object other) =>
      other is Coordenada &&
      other.latitud == latitud &&
      other.longitud == longitud;

  @override
  int get hashCode => Object.hash(latitud, longitud);

  @override
  String toString() => 'Coordenada($latitud, $longitud)';
}

/// Cámara y pin del mapa de juego.
///
/// D5 de `design.md` (INT-92): el widget dibuja y traduce gestos, pero las
/// reglas —hasta dónde se puede acercar, hasta dónde arrastrar, qué
/// coordenada hay bajo un dedo— viven aquí, fuera de él. Así se prueban
/// llamando a métodos en vez de simulando pellizcos, y INT-93 tendrá dónde
/// apoyarse para encuadrar dos pines a la vez.
class MapaMundiController extends ChangeNotifier {
  /// Cuánto se puede acercar respecto al encuadre inicial. 14× deja unos
  /// 3,5 km por píxel, muy por debajo del error de un dedo.
  static const double factorZoomMaximo = 14;

  /// Cuánto cambia el zoom con cada pulsación de los botones, igual que el
  /// `zoomBy(1.7)` del mockup.
  static const double factorBotonZoom = 1.7;

  Size _tamano = Size.zero;

  /// Lado en píxeles del cuadrado que ocupa el mundo entero.
  double _escala = 0;

  /// Posición en pantalla de la esquina noroeste del mundo.
  Offset _desplazamiento = Offset.zero;

  Coordenada? _pin;

  Size get tamano => _tamano;
  double get escala => _escala;
  Offset get desplazamiento => _desplazamiento;
  Coordenada? get pin => _pin;
  bool get tienePin => _pin != null;
  bool get listo => _tamano.width > 0 && _tamano.height > 0;

  /// Escala a la que el mundo entero cabe en pantalla. Es el tope de alejar:
  /// el mockup no dejaba ver el mundo completo de un vistazo y aquí sí,
  /// porque situarse en el globo es el primer gesto del jugador.
  double get escalaMinima => math.min(_tamano.width, _tamano.height);

  /// Encuadre de partida del diseño: el mundo llena la altura.
  double get escalaInicial => math.max(_tamano.height, escalaMinima);

  double get escalaMaxima => escalaInicial * factorZoomMaximo;

  /// Se llama desde el layout. La primera vez fija el encuadre inicial; en
  /// los siguientes (rotación, teclado) conserva zoom y centro dentro de los
  /// límites nuevos.
  void ajustarTamano(Size tamano) {
    if (tamano == _tamano || tamano.isEmpty) return;

    final primeraVez = !listo;
    final centroAnterior = primeraVez ? null : _centroNormalizado();
    _tamano = tamano;

    if (primeraVez) {
      _escala = escalaInicial;
      _desplazamiento = Offset(
        (_tamano.width - _escala) / 2,
        (_tamano.height - _escala) / 2,
      );
    } else {
      _escala = _escala.clamp(escalaMinima, escalaMaxima);
      _centrarEn(centroAnterior!);
    }

    _recortarDesplazamiento();
    notifyListeners();
  }

  /// Punto de pantalla donde cae una coordenada, o `null` si la cámara aún
  /// no tiene tamaño.
  Offset? coordenadasAPantalla(Coordenada coordenada) {
    if (!listo) return null;
    return Offset(
      Mercator.xDeLongitud(coordenada.longitud) * _escala + _desplazamiento.dx,
      Mercator.yDeLatitud(coordenada.latitud) * _escala + _desplazamiento.dy,
    );
  }

  /// Coordenada bajo un punto de pantalla, o `null` si ese punto cae fuera
  /// del mundo — al alejar del todo sobran franjas a los lados, y ahí no hay
  /// planeta que marcar.
  Coordenada? pantallaACoordenadas(Offset punto) {
    if (!listo || _escala <= 0) return null;

    final x = (punto.dx - _desplazamiento.dx) / _escala;
    final y = (punto.dy - _desplazamiento.dy) / _escala;
    if (x < 0 || x > 1 || y < 0 || y > 1) return null;

    return Coordenada(
      latitud: Mercator.latitudDeY(y),
      longitud: Mercator.normalizarLongitud(Mercator.longitudDeX(x)),
    );
  }

  /// Coloca el pin bajo un punto de pantalla. Devuelve `false` si ese punto
  /// no cae sobre el mundo, en cuyo caso el pin no se mueve.
  bool colocarPinEn(Offset punto) {
    final coordenada = pantallaACoordenadas(punto);
    if (coordenada == null) return false;
    _pin = coordenada;
    notifyListeners();
    return true;
  }

  void colocarPin(Coordenada coordenada) {
    _pin = Coordenada(
      latitud: coordenada.latitud.clamp(
        -Mercator.latitudMaxima,
        Mercator.latitudMaxima,
      ),
      longitud: Mercator.normalizarLongitud(coordenada.longitud),
    );
    notifyListeners();
  }

  void limpiarPin() {
    if (_pin == null) return;
    _pin = null;
    notifyListeners();
  }

  void desplazar(Offset delta) {
    if (!listo || delta == Offset.zero) return;
    _desplazamiento += delta;
    _recortarDesplazamiento();
    notifyListeners();
  }

  /// Cambia el zoom manteniendo quieto el punto de pantalla [foco].
  void zoomEn(double factor, Offset foco) {
    if (!listo || factor <= 0) return;

    final nueva = (_escala * factor).clamp(escalaMinima, escalaMaxima);
    if (nueva == _escala) return;

    _desplazamiento = foco - (foco - _desplazamiento) * (nueva / _escala);
    _escala = nueva;
    _recortarDesplazamiento();
    notifyListeners();
  }

  void acercar() => zoomEn(factorBotonZoom, _centroDePantalla());

  void alejar() => zoomEn(1 / factorBotonZoom, _centroDePantalla());

  Offset _centroDePantalla() => Offset(_tamano.width / 2, _tamano.height / 2);

  Offset _centroNormalizado() {
    final centro = _centroDePantalla();
    return Offset(
      (centro.dx - _desplazamiento.dx) / _escala,
      (centro.dy - _desplazamiento.dy) / _escala,
    );
  }

  void _centrarEn(Offset puntoNormalizado) {
    final centro = _centroDePantalla();
    _desplazamiento = Offset(
      centro.dx - puntoNormalizado.dx * _escala,
      centro.dy - puntoNormalizado.dy * _escala,
    );
  }

  /// En cada eje: si el mundo es mayor que la pantalla se pega a los bordes
  /// y no deja hueco; si es menor, se queda centrado y no se puede mover.
  void _recortarDesplazamiento() {
    _desplazamiento = Offset(
      _recortarEje(_desplazamiento.dx, _tamano.width),
      _recortarEje(_desplazamiento.dy, _tamano.height),
    );
  }

  double _recortarEje(double valor, double disponible) {
    if (_escala <= disponible) return (disponible - _escala) / 2;
    return valor.clamp(disponible - _escala, 0.0);
  }
}
