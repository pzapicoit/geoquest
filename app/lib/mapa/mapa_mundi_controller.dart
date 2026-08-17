import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show EdgeInsets, Offset, Size;

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

/// Encuadre del mapa: cuánto mide el mundo en pantalla y dónde cae su esquina
/// noroeste.
///
/// D5 de `design.md` (INT-93): sacarlo a un valor propio es lo que permite
/// animar el paso del encuadre del jugador al que enseña los dos pines, sin
/// meter una animación dentro del controlador —que no tiene `vsync`—.
@immutable
class CamaraMapa {
  const CamaraMapa({required this.escala, required this.desplazamiento});

  /// Lado en píxeles del cuadrado que ocupa el mundo entero.
  final double escala;

  /// Posición en pantalla de la esquina noroeste del mundo.
  final Offset desplazamiento;

  /// Punto de pantalla donde cae una coordenada con este encuadre.
  Offset puntoDe(Coordenada coordenada) => Offset(
    Mercator.xDeLongitud(coordenada.longitud) * escala + desplazamiento.dx,
    Mercator.yDeLatitud(coordenada.latitud) * escala + desplazamiento.dy,
  );

  /// Encuadre intermedio entre dos, para animar la transición. La escala se
  /// interpola linealmente, como hace `reveal-map.js`.
  static CamaraMapa interpolar(CamaraMapa desde, CamaraMapa hasta, double t) {
    return CamaraMapa(
      escala: desde.escala + (hasta.escala - desde.escala) * t,
      desplazamiento: Offset.lerp(
        desde.desplazamiento,
        hasta.desplazamiento,
        t,
      )!,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CamaraMapa &&
      other.escala == escala &&
      other.desplazamiento == desplazamiento;

  @override
  int get hashCode => Object.hash(escala, desplazamiento);

  @override
  String toString() => 'CamaraMapa($escala, $desplazamiento)';
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

  /// Área útil mínima que se le concede a un encuadre. Con márgenes más
  /// grandes que la pantalla el encuadre sigue siendo un número, en vez de un
  /// `NaN` por dividir entre cero.
  static const double _areaMinima = 80;

  /// Suelo del tamaño de lo que se encuadra, en fracción de mundo (≈40 m):
  /// dos coordenadas iguales pedirían una escala infinita.
  static const double _tramoMinimo = 1e-6;

  Size _tamano = Size.zero;

  /// Lado en píxeles del cuadrado que ocupa el mundo entero.
  double _escala = 0;

  /// Posición en pantalla de la esquina noroeste del mundo.
  Offset _desplazamiento = Offset.zero;

  Coordenada? _pin;

  /// Ubicación real del desafío, que solo se conoce tras responder (INT-93).
  Coordenada? _pinReal;

  /// Cuánto de la línea entre los dos pines está trazado, de 0 a 1.
  double _progresoDeLaLinea = 0;

  Size get tamano => _tamano;
  double get escala => _escala;
  Offset get desplazamiento => _desplazamiento;
  Coordenada? get pin => _pin;
  Coordenada? get pinReal => _pinReal;
  double get progresoDeLaLinea => _progresoDeLaLinea;
  bool get tienePin => _pin != null;
  bool get listo => _tamano.width > 0 && _tamano.height > 0;

  CamaraMapa get camara =>
      CamaraMapa(escala: _escala, desplazamiento: _desplazamiento);

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
      _encuadrarDeInicio();
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
    return camara.puntoDe(coordenada);
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

  /// Enseña la ubicación real del desafío junto al pin del jugador (INT-93).
  void revelarUbicacion(Coordenada coordenada) {
    _pinReal = Coordenada(
      latitud: coordenada.latitud.clamp(
        -Mercator.latitudMaxima,
        Mercator.latitudMaxima,
      ),
      longitud: Mercator.normalizarLongitud(coordenada.longitud),
    );
    notifyListeners();
  }

  /// Cuánto de la línea entre los dos pines está trazado. Lo mueve la
  /// animación del revelado, fotograma a fotograma.
  set progresoDeLaLinea(double valor) {
    final acotado = valor.clamp(0.0, 1.0);
    if (acotado == _progresoDeLaLinea) return;
    _progresoDeLaLinea = acotado;
    notifyListeners();
  }

  void limpiarRevelado() {
    if (_pinReal == null && _progresoDeLaLinea == 0) return;
    _pinReal = null;
    _progresoDeLaLinea = 0;
    notifyListeners();
  }

  /// Encuadre que deja [coordenadas] dentro del área que queda al descontar
  /// [margenes], con los mismos topes de zoom y desplazamiento que cualquier
  /// gesto (D5 de `design.md`).
  ///
  /// Los márgenes no son simétricos a propósito: en el revelado la hoja de
  /// resultado ocupa la parte de abajo, y un pin detrás de ella sería
  /// justamente el fallo que el encuadre viene a evitar.
  CamaraMapa camaraPara(
    Iterable<Coordenada> coordenadas, {
    EdgeInsets margenes = EdgeInsets.zero,
  }) {
    if (!listo || coordenadas.isEmpty) return camara;

    var minimoX = double.infinity;
    var maximoX = double.negativeInfinity;
    var minimoY = double.infinity;
    var maximoY = double.negativeInfinity;
    for (final coordenada in coordenadas) {
      final x = Mercator.xDeLongitud(coordenada.longitud);
      final y = Mercator.yDeLatitud(coordenada.latitud);
      minimoX = math.min(minimoX, x);
      maximoX = math.max(maximoX, x);
      minimoY = math.min(minimoY, y);
      maximoY = math.max(maximoY, y);
    }

    final ancho = math.max(_tamano.width - margenes.horizontal, _areaMinima);
    final alto = math.max(_tamano.height - margenes.vertical, _areaMinima);
    final tramoX = math.max(maximoX - minimoX, _tramoMinimo);
    final tramoY = math.max(maximoY - minimoY, _tramoMinimo);

    final escala = math
        .min(ancho / tramoX, alto / tramoY)
        .clamp(escalaMinima, escalaMaxima);
    final centroX = (minimoX + maximoX) / 2;
    final centroY = (minimoY + maximoY) / 2;

    return CamaraMapa(
      escala: escala,
      desplazamiento: Offset(
        _recortarEje(
          margenes.left + ancho / 2 - centroX * escala,
          _tamano.width,
          escala,
        ),
        _recortarEje(
          margenes.top + alto / 2 - centroY * escala,
          _tamano.height,
          escala,
        ),
      ),
    );
  }

  /// Adopta un encuadre calculado, sin pasar por los gestos del jugador.
  void aplicarCamara(CamaraMapa nueva) {
    if (!listo) return;

    final escala = nueva.escala.clamp(escalaMinima, escalaMaxima);
    final desplazamiento = Offset(
      _recortarEje(nueva.desplazamiento.dx, _tamano.width, escala),
      _recortarEje(nueva.desplazamiento.dy, _tamano.height, escala),
    );
    if (escala == _escala && desplazamiento == _desplazamiento) return;

    _escala = escala;
    _desplazamiento = desplazamiento;
    notifyListeners();
  }

  /// Vuelve al encuadre de partida. Se usa al pasar de desafío: heredar el
  /// zoom del revelado anterior dejaría al jugador mirando de cerca una
  /// respuesta que ya no le sirve.
  void reiniciarEncuadre() {
    if (!listo) return;
    _encuadrarDeInicio();
    _recortarDesplazamiento();
    notifyListeners();
  }

  void _encuadrarDeInicio() {
    _escala = escalaInicial;
    _desplazamiento = Offset(
      (_tamano.width - _escala) / 2,
      (_tamano.height - _escala) / 2,
    );
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
      _recortarEje(_desplazamiento.dx, _tamano.width, _escala),
      _recortarEje(_desplazamiento.dy, _tamano.height, _escala),
    );
  }

  double _recortarEje(double valor, double disponible, double escala) {
    if (escala <= disponible) return (disponible - escala) / 2;
    return valor.clamp(disponible - escala, 0.0);
  }
}
