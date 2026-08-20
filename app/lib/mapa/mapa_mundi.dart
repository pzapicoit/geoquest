import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show PointMode;

import 'package:flutter/gestures.dart' show kDoubleTapTimeout;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show OverflowBoxFit;
import 'package:google_fonts/google_fonts.dart';

import 'circulo_radio.dart';
import 'gran_circulo.dart';
import 'guiones.dart';
import 'mapa_mundi_controller.dart';
import 'mundo_geometria.dart';

const Color _fueraDelMundo = Color(0xFF0B1A24);
const Color _oceano = Color(0xFF0F2632);
const Color _tierra = Color(0xFF20323D);
const Color _frontera = Color(0x472BC0A8);
const Color _reticula = Color(0x1A2BC0A8);
const Color _pinRelleno = Color(0xFFFF5A5F);
const Color _pinHalo = Color(0x38FF5A5F);
const Color _pinRotulo = Color(0xFFFF9B9E);
const Color _pinRealRelleno = Color(0xFF2BC0A8);
const Color _pinRealHalo = Color(0x382BC0A8);
const Color _pinRealRotulo = Color(0xFF7FE3D2);
const Color _pinBorde = Color(0xFFFFFDF8);
const Color _lineaDelRevelado = Color(0xFFFFC53D);
const Color _circuloRadioTrazo = Color(0xFF2BC0A8);
const Color _circuloRadioRelleno = Color(0x1A2BC0A8);

typedef CargadorDeMundo = Future<MundoGeometria> Function();

/// Mapa mundial a pantalla completa donde el jugador marca su respuesta.
///
/// Dibuja la geometría empaquetada en la app (INT-92, D1 de `design.md`): sin
/// teselas, sin red y sin un solo topónimo, porque adivinar en GeoQuest
/// consiste en reconocer la forma de la costa.
///
/// Cuando el controlador tiene ubicación real (INT-93) dibuja además el
/// segundo pin y la línea punteada entre los dos.
class MapaMundi extends StatefulWidget {
  const MapaMundi({
    super.key,
    required this.controller,
    this.cargador,
    this.interactivo = true,
  });

  final MapaMundiController controller;

  /// Inyectable para poder montar el mapa en tests sin leer el asset real.
  final CargadorDeMundo? cargador;

  /// Con `false` el mapa no acepta gestos ni enseña los botones de zoom: la
  /// jugada ya está cerrada y el encuadre lo decide la pantalla (INT-93).
  final bool interactivo;

  @override
  State<MapaMundi> createState() => _MapaMundiState();
}

class _MapaMundiState extends State<MapaMundi>
    with SingleTickerProviderStateMixin {
  /// Distancia máxima entre los dos toques para que cuenten como doble toque.
  ///
  /// Más ajustada que el `kDoubleTapSlop` (100) del framework a propósito
  /// (D9 de `design.md` de INT-114): el segundo toque también mueve el pin, y
  /// con esa holgura el pin daría un salto visible antes de acercar.
  static const double _slopDelDobleToque = 40;

  late Future<MundoGeometria> _mundo;
  double _escalaDelGesto = 1;

  /// Acercamiento del doble toque (D12): animado y corto, para que se lea como
  /// un movimiento de cámara y no como un salto.
  late final AnimationController _acercamiento = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  )..addListener(_alAvanzarElAcercamiento);

  CamaraMapa? _camaraAntesDelAcercamiento;
  CamaraMapa? _camaraDelAcercamiento;

  /// Dónde cayó el toque anterior, mientras su plazo siga vivo. Es lo que
  /// convierte dos toques en un doble toque sin registrar un
  /// `DoubleTapGestureRecognizer`, que retrasaría el pin (D9).
  Offset? _ultimoToque;

  /// El pin que había **antes** de ese toque anterior. Un doble toque solo
  /// acerca, así que al confirmarse hay que devolver el mapa aquí (DD3 del
  /// delta 1): el primer toque de la pareja ya había colocado pin, porque no
  /// puede esperar a saber si viene un segundo.
  Coordenada? _pinAntesDelUltimoToque;

  Timer? _plazoDelDobleToque;

  @override
  void initState() {
    super.initState();
    _mundo = (widget.cargador ?? cargarMundo)();
  }

  @override
  void didUpdateWidget(MapaMundi anterior) {
    super.didUpdateWidget(anterior);
    // La jugada se acaba de cerrar: de aquí en adelante el encuadre lo lleva la
    // coreografía del revelado, y una animación viva se pelearía con ella.
    if (anterior.interactivo && !widget.interactivo) {
      _pararElAcercamiento();
      _olvidarElToque();
    }
  }

  @override
  void dispose() {
    _plazoDelDobleToque?.cancel();
    _acercamiento.dispose();
    super.dispose();
  }

  void _alTocar(TapUpDetails detalles) {
    final punto = detalles.localPosition;
    final anterior = _ultimoToque;
    final pinAntes = _pinAntesDelUltimoToque;
    _olvidarElToque();

    if (anterior != null && (punto - anterior).distance <= _slopDelDobleToque) {
      // Doble toque: solo acerca. Acercarse a mirar y responder son dos
      // intenciones distintas (DD3 del delta 1), así que el pin que colocó el
      // primer toque se deshace y el mapa vuelve al que hubiera antes del
      // gesto —si había uno, sobrevive—.
      if (pinAntes == null) {
        widget.controller.limpiarPin();
      } else {
        widget.controller.colocarPin(pinAntes);
      }
      _acercarSobre(punto);
      return;
    }

    // Un toque suelto coloca el pin en cuanto se levanta el dedo, sin esperar a
    // descartar que venga un segundo (D9): es la acción principal de la
    // pantalla de juego.
    _pinAntesDelUltimoToque = widget.controller.pin;
    widget.controller.colocarPinEn(punto);
    _ultimoToque = punto;
    _plazoDelDobleToque = Timer(kDoubleTapTimeout, _olvidarElToque);
  }

  void _olvidarElToque() {
    _plazoDelDobleToque?.cancel();
    _plazoDelDobleToque = null;
    _ultimoToque = null;
    // El pin recordado muere con el toque recordado (DD4): si no, un
    // `limpiarPin` de la pantalla al avanzar de desafío podría revivirse.
    _pinAntesDelUltimoToque = null;
  }

  void _acercarSobre(Offset foco) {
    final destino = widget.controller.camaraDeZoomEn(
      MapaMundiController.factorDobleToque,
      foco,
    );
    // Ya en el tope de acercar: no hay a dónde ir, y animar hacia el mismo
    // encuadre solo daría un tirón.
    if (destino == null) return;

    _camaraAntesDelAcercamiento = widget.controller.camara;
    _camaraDelAcercamiento = destino;
    _acercamiento.forward(from: 0);
  }

  void _alAvanzarElAcercamiento() {
    final desde = _camaraAntesDelAcercamiento;
    final hasta = _camaraDelAcercamiento;
    if (desde == null || hasta == null) return;

    widget.controller.aplicarCamara(
      CamaraMapa.interpolar(
        desde,
        hasta,
        Curves.easeOutCubic.transform(_acercamiento.value),
      ),
    );
  }

  void _pararElAcercamiento() {
    if (!_acercamiento.isAnimating) return;
    _acercamiento.stop();
    _camaraAntesDelAcercamiento = null;
    _camaraDelAcercamiento = null;
  }

  void _alEmpezarGesto(ScaleStartDetails detalles) {
    // Un pellizco o un arrastre manda sobre la animación en curso.
    _pararElAcercamiento();
    _escalaDelGesto = 1;
  }

  void _alActualizarGesto(ScaleUpdateDetails detalles) {
    if (detalles.scale != _escalaDelGesto && _escalaDelGesto > 0) {
      widget.controller.zoomEn(
        detalles.scale / _escalaDelGesto,
        detalles.localFocalPoint,
      );
      _escalaDelGesto = detalles.scale;
    }
    widget.controller.desplazar(detalles.focalPointDelta);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MundoGeometria>(
      future: _mundo,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const ColoredBox(
            color: _fueraDelMundo,
            child: Center(
              child: SizedBox(
                key: Key('mapa-cargando'),
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Color(0xFF2BC0A8),
                ),
              ),
            ),
          );
        }
        if (snapshot.hasError) {
          return const _MundoNoDisponible();
        }

        return LayoutBuilder(
          builder: (context, restricciones) {
            final tamano = restricciones.biggest;
            // El controlador notifica a sus oyentes, así que no se puede
            // tocar en pleno build: se ajusta justo después del fotograma.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) widget.controller.ajustarTamano(tamano);
            });

            final mapa = AnimatedBuilder(
              animation: widget.controller,
              builder: (context, _) {
                final controller = widget.controller;
                final pin = controller.pin;
                final pinReal = controller.pinReal;
                final centroRadio = controller.centroRadio;
                final radioKm = controller.radioKm;

                return Stack(
                  children: [
                    Positioned.fill(
                      child: RepaintBoundary(
                        child: CustomPaint(
                          painter: _PintorMundo(
                            geometria: snapshot.data!,
                            escala: controller.escala,
                            desplazamiento: controller.desplazamiento,
                          ),
                          size: Size.infinite,
                        ),
                      ),
                    ),
                    if (centroRadio != null && radioKm != null)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            key: const Key('mapa-circulo-radio'),
                            painter: _PintorCirculoDeRadio(
                              centro: centroRadio,
                              radioKm: radioKm,
                              camara: controller.camara,
                            ),
                            size: Size.infinite,
                          ),
                        ),
                      ),
                    if (pin != null && pinReal != null)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: _PintorLineaDelRevelado(
                              desde: pin,
                              hasta: pinReal,
                              avance: controller.progresoDeLaLinea,
                              camara: controller.camara,
                            ),
                            size: Size.infinite,
                          ),
                        ),
                      ),
                    if (pin != null)
                      _PinDelMapa(
                        punto: controller.coordenadasAPantalla(pin),
                        coordenada: pin,
                        relleno: _pinRelleno,
                        halo: _pinHalo,
                        // El rótulo solo hace falta cuando hay otro pin del
                        // que distinguirlo.
                        rotulo: pinReal == null ? null : 'Tu pin',
                        colorDelRotulo: _pinRotulo,
                        // Por debajo del pin para que nunca se solape con el
                        // rótulo del pin real, que va por encima (INT-104).
                        rotuloDebajo: pinReal != null,
                      ),
                    if (pinReal != null)
                      _PinDelMapa(
                        clave: const Key('mapa-pin-real'),
                        punto: controller.coordenadasAPantalla(pinReal),
                        coordenada: pinReal,
                        relleno: _pinRealRelleno,
                        halo: _pinRealHalo,
                        rotulo: controller.nombrePinReal,
                        colorDelRotulo: _pinRealRotulo,
                      ),
                    if (widget.interactivo)
                      _BotonesDeZoom(controller: controller),
                  ],
                );
              },
            );

            if (!widget.interactivo) return mapa;

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: _alTocar,
              onScaleStart: _alEmpezarGesto,
              onScaleUpdate: _alActualizarGesto,
              child: mapa,
            );
          },
        );
      },
    );
  }
}

class _MundoNoDisponible extends StatelessWidget {
  const _MundoNoDisponible();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _fueraDelMundo,
      child: Center(
        child: Text(
          'No se ha podido cargar el mapa',
          key: const Key('mapa-error'),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// Dibuja el mundo con una única transformación del canvas sobre unos `Path`
/// que se construyen una sola vez (D3/D7 de `design.md`): arrastrar solo
/// cambia la traslación, y el pin —que late— vive fuera del pintor.
class _PintorMundo extends CustomPainter {
  const _PintorMundo({
    required this.geometria,
    required this.escala,
    required this.desplazamiento,
  });

  final MundoGeometria geometria;
  final double escala;
  final Offset desplazamiento;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _fueraDelMundo);
    if (escala <= 0) return;

    canvas.save();
    canvas.translate(desplazamiento.dx, desplazamiento.dy);
    canvas.scale(escala);

    // El grosor se divide por la escala para que la línea mida siempre lo
    // mismo en pantalla, como el `non-scaling-stroke` del mockup.
    final grosor = 0.6 / escala;

    canvas.drawRect(const Rect.fromLTWH(0, 0, 1, 1), Paint()..color = _oceano);
    canvas.drawPath(
      geometria.reticula,
      Paint()
        ..color = _reticula
        ..style = PaintingStyle.stroke
        ..strokeWidth = grosor,
    );
    canvas.drawPath(geometria.tierra, Paint()..color = _tierra);
    canvas.drawPath(
      geometria.tierra,
      Paint()
        ..color = _frontera
        ..style = PaintingStyle.stroke
        ..strokeWidth = grosor,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_PintorMundo anterior) =>
      anterior.escala != escala ||
      anterior.desplazamiento != desplazamiento ||
      anterior.geometria != geometria;
}

/// Pin del mapa: la punta clavada en el punto, un halo que late y una entrada
/// con rebote al colocarse.
///
/// D7 de `design.md` (INT-93): el mismo dibujo sirve para el pin del jugador y
/// para el de la ubicación real, que en el diseño solo se diferencian en el
/// color y en el rótulo de encima.
class _PinDelMapa extends StatelessWidget {
  const _PinDelMapa({
    required this.punto,
    required this.coordenada,
    required this.relleno,
    required this.halo,
    this.rotulo,
    this.colorDelRotulo,
    this.rotuloDebajo = false,
    this.clave,
  });

  static const double _lado = 160;
  static const double _alturaPin = 45;
  static const double _anchoPin = 34;

  /// Ancho máximo del rótulo, independiente del cuadro fijo del pin: un
  /// nombre de lugar puede necesitar más sitio que los 160px de [_lado]
  /// (INT-104, D2 de `design.md`).
  static const double _anchoRotulo = 200;

  final Offset? punto;
  final Coordenada coordenada;
  final Color relleno;
  final Color halo;
  final String? rotulo;
  final Color? colorDelRotulo;

  /// Con `true` el rótulo se dibuja por debajo del pin en vez de por
  /// encima, para que los rótulos del pin del jugador y el real nunca se
  /// solapen entre sí, caigan donde caigan (INT-104, D6 de `design.md`).
  final bool rotuloDebajo;

  final Key? clave;

  @override
  Widget build(BuildContext context) {
    if (punto == null) return const SizedBox.shrink();

    return Positioned(
      key: clave,
      left: punto!.dx - _lado / 2,
      top: punto!.dy - _lado / 2,
      width: _lado,
      height: _lado,
      child: IgnorePointer(
        child: TweenAnimationBuilder<double>(
          // La clave cambia con cada coordenada nueva, así que reposicionar
          // el pin lo vuelve a animar en su sitio.
          key: ValueKey(coordenada),
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutBack,
          builder: (context, entrada, _) => Stack(
            alignment: Alignment.center,
            children: [
              _HaloDelPin(color: halo),
              Align(
                alignment: Alignment.center,
                child: Transform.translate(
                  offset: const Offset(0, -_alturaPin / 2),
                  child: Transform.scale(
                    scale: entrada,
                    alignment: Alignment.bottomCenter,
                    child: SizedBox(
                      width: _anchoPin,
                      height: _alturaPin,
                      child: CustomPaint(painter: _PintorPin(relleno: relleno)),
                    ),
                  ),
                ),
              ),
              if (rotulo != null)
                Positioned(
                  top: rotuloDebajo ? null : _lado / 2 - _alturaPin - 26,
                  bottom: rotuloDebajo ? _lado / 2 - _alturaPin - 26 : null,
                  left: 0,
                  right: 0,
                  child: Opacity(
                    opacity: entrada.clamp(0.0, 1.0),
                    child: OverflowBox(
                      maxWidth: _anchoRotulo,
                      alignment: Alignment.center,
                      // Sin esto, la altura infinita que le llega desde este
                      // lado del `Stack` —solo `top` o solo `bottom` está
                      // fijado— haría que la caja intentara crecer sin
                      // límite (`OverflowBoxFit.max` es el valor por
                      // defecto).
                      fit: OverflowBoxFit.deferToChild,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0E1620)
                              .withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.14),
                          ),
                        ),
                        child: Text(
                          rotulo!.toUpperCase(),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            color: colorDelRotulo,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.4,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Línea punteada entre el pin del jugador y la ubicación real, trazada poco a
/// poco (D6 de `design.md`).
///
/// Se pinta en espacio de pantalla, no dentro de la transformación del mundo,
/// para que los guiones midan lo mismo a cualquier zoom.
class _PintorLineaDelRevelado extends CustomPainter {
  const _PintorLineaDelRevelado({
    required this.desde,
    required this.hasta,
    required this.avance,
    required this.camara,
  });

  final Coordenada desde;
  final Coordenada hasta;
  final double avance;
  final CamaraMapa camara;

  @override
  void paint(Canvas canvas, Size size) {
    if (avance <= 0 || camara.escala <= 0) return;

    final pincel = Paint()
      ..color = _lineaDelRevelado
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    for (final tramo in partirEnElAntimeridiano(
      interpolarGranCirculo(desde, hasta, avance: avance),
    )) {
      final guiones = trocearEnGuiones([
        for (final coordenada in tramo) camara.puntoDe(coordenada),
      ]);
      if (guiones.isEmpty) continue;

      canvas.drawPoints(PointMode.lines, [
        for (final guion in guiones) ...[guion.$1, guion.$2],
      ], pincel);
    }
  }

  @override
  bool shouldRepaint(_PintorLineaDelRevelado anterior) =>
      anterior.desde != desde ||
      anterior.hasta != hasta ||
      anterior.avance != avance ||
      anterior.camara != camara;
}

/// Círculo de acierto de un comodín `km1000`/`km500` (INT-119, D7 de
/// `design.md`): centrado en la posición real del objetivo, mientras el
/// jugador sigue en la fase de adivinar de ese desafío.
///
/// Se pinta en espacio de pantalla, mismo motivo que
/// [_PintorLineaDelRevelado]: el grosor del trazo no depende del zoom.
class _PintorCirculoDeRadio extends CustomPainter {
  const _PintorCirculoDeRadio({
    required this.centro,
    required this.radioKm,
    required this.camara,
  });

  final Coordenada centro;
  final double radioKm;
  final CamaraMapa camara;

  @override
  void paint(Canvas canvas, Size size) {
    if (camara.escala <= 0) return;

    final tramos = partirEnElAntimeridiano(puntosDelCirculo(centro, radioKm));

    // Con el círculo entero en un solo tramo (el caso normal, sin cruzar el
    // antimeridiano) se puede cerrar el contorno y rellenarlo. Partido en
    // varios tramos el relleno de cada trozo por separado no dibujaría el
    // círculo sino una forma sin sentido, así que ahí se deja solo el trazo.
    final relleno = tramos.length == 1;

    for (final tramo in tramos) {
      if (tramo.length < 2) continue;

      final puntos = [
        for (final coordenada in tramo) camara.puntoDe(coordenada),
      ];
      final trazado = Path()..addPolygon(puntos, relleno);

      if (relleno) {
        canvas.drawPath(trazado, Paint()..color = _circuloRadioRelleno);
      }
      canvas.drawPath(
        trazado,
        Paint()
          ..color = _circuloRadioTrazo
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4,
      );
    }
  }

  @override
  bool shouldRepaint(_PintorCirculoDeRadio anterior) =>
      anterior.centro != centro ||
      anterior.radioKm != radioKm ||
      anterior.camara != camara;
}

class _HaloDelPin extends StatefulWidget {
  const _HaloDelPin({required this.color});

  final Color color;

  @override
  State<_HaloDelPin> createState() => _HaloDelPinState();
}

class _HaloDelPinState extends State<_HaloDelPin>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controlador = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat();

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controlador,
      builder: (context, _) {
        final t = _controlador.value;
        return Transform.scale(
          scale: 0.7 + t * 1.4,
          child: Opacity(
            opacity: (0.85 * (1 - t)).clamp(0.0, 1.0),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PintorPin extends CustomPainter {
  const _PintorPin({required this.relleno});

  final Color relleno;

  @override
  void paint(Canvas canvas, Size size) {
    // Gota clásica: la punta abajo del todo y un círculo arriba, unidos por
    // las dos tangentes que salen de la punta.
    final radio = size.width * 0.4;
    final centro = Offset(size.width / 2, radio + size.height * 0.045);
    final punta = Offset(size.width / 2, size.height);
    final distancia = punta.dy - centro.dy;
    final beta = math.acos((radio / distancia).clamp(-1.0, 1.0));

    final desde = math.pi / 2 + beta;
    final gota = Path()
      ..moveTo(punta.dx, punta.dy)
      ..lineTo(
        centro.dx + radio * math.cos(desde),
        centro.dy + radio * math.sin(desde),
      )
      ..arcTo(
        Rect.fromCircle(center: centro, radius: radio),
        desde,
        2 * math.pi - 2 * beta,
        false,
      )
      ..close();

    canvas
      ..drawPath(gota, Paint()..color = relleno)
      ..drawPath(
        gota,
        Paint()
          ..color = _pinBorde
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..strokeJoin = StrokeJoin.round,
      )
      ..drawCircle(centro, radio * 0.38, Paint()..color = _pinBorde);
  }

  @override
  bool shouldRepaint(_PintorPin anterior) => anterior.relleno != relleno;
}

class _BotonesDeZoom extends StatelessWidget {
  const _BotonesDeZoom({required this.controller});

  final MapaMundiController controller;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 14,
      top: 0,
      bottom: 0,
      child: Center(
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0E1620).withValues(alpha: 0.72),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _BotonDeZoom(
                clave: const Key('mapa-acercar'),
                etiqueta: 'Acercar',
                simbolo: '+',
                onPressed: controller.acercar,
              ),
              Container(
                height: 1,
                width: 24,
                color: Colors.white.withValues(alpha: 0.14),
              ),
              _BotonDeZoom(
                clave: const Key('mapa-alejar'),
                etiqueta: 'Alejar',
                simbolo: '−',
                onPressed: controller.alejar,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BotonDeZoom extends StatelessWidget {
  const _BotonDeZoom({
    required this.clave,
    required this.etiqueta,
    required this.simbolo,
    required this.onPressed,
  });

  final Key clave;
  final String etiqueta;
  final String simbolo;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: etiqueta,
      child: InkWell(
        key: clave,
        onTap: onPressed,
        borderRadius: BorderRadius.circular(13),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Center(
            child: Text(
              simbolo,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w600,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
