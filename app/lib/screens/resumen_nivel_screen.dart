import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../mapa/mapa_mundi.dart';
import '../services/comodines_gateway.dart';
import '../services/nivel_juego_gateway.dart';
import 'nivel_juego_screen.dart' show NivelJuegoScreen, formatearPuntaje;

const _ink = Color(0xFF0E1620);
const _teal = Color(0xFF2BC0A8);
const _azul = Color(0xFF1B6FA8);
const _gold = Color(0xFFFFC53D);
const _goldClaro = Color(0xFFFFE9A8);

const _coloresConfeti = [
  _gold,
  _teal,
  _azul,
  Color(0xFFFF5A5F),
  Color(0xFF7C5CFF),
  _goldClaro,
];

/// Tamaño de la caja y de la estrella para cada uno de los 3 huecos: el del
/// medio, más grande, como en el mockup.
const _tamanosEstrella = [(78.0, 58.0), (104.0, 82.0), (78.0, 58.0)];

/// Resumen del intento al terminar todos los desafíos de un nivel (INT-94),
/// fiel a `[App] - Resumen del nivel.dc.html` de Claude Design: superado
/// (estrellas rellenándose una a una, confeti con las 3, aviso de récord) o
/// no superado (cuánto faltó para el mínimo, con opción de reintentar).
class ResumenNivelScreen extends StatefulWidget {
  const ResumenNivelScreen({
    super.key,
    required this.resultado,
    required this.caminoId,
    required this.totalDesafios,
    required this.gateway,
    this.comodinesGateway,
    this.nivelNombre,
    this.nivelOrden,
    this.tematicaNombre,
    this.cargadorDeMundo,
  });

  final ResultadoIntento resultado;
  final String caminoId;
  final int totalDesafios;
  final NivelJuegoGateway gateway;

  /// Inyectable, reenviado a `NivelJuegoScreen` al reintentar (INT-119).
  final ComodinesGateway? comodinesGateway;
  final String? nivelNombre;
  final int? nivelOrden;
  final String? tematicaNombre;
  final CargadorDeMundo? cargadorDeMundo;

  @override
  State<ResumenNivelScreen> createState() => _ResumenNivelScreenState();
}

class _ResumenNivelScreenState extends State<ResumenNivelScreen> {
  final List<Timer> _timers = [];

  /// Cuántas estrellas lleva encendidas la animación (0..estrellas).
  int _estrellasMostradas = 0;
  bool _confettiVisible = false;

  /// Cambia en cada repetición, para que `_Confeti` (que solo se dispara una
  /// vez en su propio `initState`) se reconstruya desde cero.
  int _ronda = 0;

  int get _estrellas => widget.resultado.estrellas.clamp(0, 3);

  bool get _isRecord {
    final anterior = widget.resultado.mejorPuntajeAnterior;
    return widget.resultado.superado &&
        anterior != null &&
        widget.resultado.puntajeTotal > anterior;
  }

  @override
  void initState() {
    super.initState();
    if (widget.resultado.superado) _lanzar();
  }

  @override
  void dispose() {
    for (final timer in _timers) {
      timer.cancel();
    }
    super.dispose();
  }

  /// Lanza —o relanza, desde "Repetir animación"— la coreografía de
  /// estrellas y confeti, con los tiempos del mockup: 420 ms + 480 ms por
  /// estrella, confeti 240 ms después de la última si son las 3 (D8 de
  /// `design.md`).
  void _lanzar() {
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
    setState(() {
      _estrellasMostradas = 0;
      _confettiVisible = false;
      _ronda++;
    });

    for (var i = 1; i <= _estrellas; i++) {
      final retraso = Duration(milliseconds: 420 + (i - 1) * 480);
      _timers.add(
        Timer(retraso, () {
          if (mounted) setState(() => _estrellasMostradas = i);
        }),
      );
    }

    if (_estrellas == 3) {
      final retraso = Duration(milliseconds: 420 + 2 * 480 + 240);
      _timers.add(
        Timer(retraso, () {
          if (mounted) setState(() => _confettiVisible = true);
        }),
      );
    }
  }

  void _reintentar() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => NivelJuegoScreen(
          caminoId: widget.caminoId,
          nivelNombre: widget.nivelNombre,
          nivelOrden: widget.nivelOrden,
          tematicaNombre: widget.tematicaNombre,
          gateway: widget.gateway,
          comodinesGateway: widget.comodinesGateway,
          cargadorDeMundo: widget.cargadorDeMundo,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final superado = widget.resultado.superado;

    return Scaffold(
      backgroundColor: _ink,
      body: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -1.1),
                    radius: 0.9,
                    colors: [
                      (superado ? _teal : _azul).withValues(alpha: 0.22),
                      (superado ? _teal : _azul).withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_confettiVisible)
            Positioned.fill(
              key: ValueKey('confeti-$_ronda'),
              child: IgnorePointer(child: _Confeti()),
            ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(26, 12, 26, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _Pill(
                    superado: superado,
                    nivelOrden: widget.nivelOrden,
                    tematicaNombre: widget.tematicaNombre,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    superado ? '¡Nivel superado!' : '¡Casi lo tienes!',
                    key: const Key('resumen-nivel-titulo'),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.baloo2(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    superado
                        ? '${widget.nivelNombre ?? 'Este nivel'} · '
                              '${widget.totalDesafios} desafíos completados'
                        : '${widget.nivelNombre ?? 'Este nivel'} · sin '
                              'penalización, puedes reintentarlo cuando quieras',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 34),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (var i = 0; i < 3; i++) ...[
                        if (i > 0) const SizedBox(width: 10),
                        _Estrella(
                          key: Key('resumen-nivel-estrella-$i'),
                          on: superado && i < _estrellasMostradas,
                          tamanoCaja: _tamanosEstrella[i].$1,
                          tamanoEstrella: _tamanosEstrella[i].$2,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'PUNTOS DEL INTENTO',
                    style: GoogleFonts.outfit(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // `FittedBox` en vez de un tamaño fijo: "999.999" en un
                  // teléfono estrecho no debe desbordar la fila (a
                  // diferencia de las tarjetas del revelado, aquí no hay
                  // una `Expanded` que la recorte).
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          formatearPuntaje(widget.resultado.puntajeTotal),
                          key: const Key('resumen-nivel-puntaje'),
                          style: GoogleFonts.baloo2(
                            color: superado ? _goldClaro : Colors.white,
                            fontSize: 62,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'pts',
                          style: GoogleFonts.outfit(
                            color: superado
                                ? _gold.withValues(alpha: 0.6)
                                : Colors.white.withValues(alpha: 0.4),
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (superado && _isRecord) ...[
                    const SizedBox(height: 18),
                    _Retrasado(
                      retraso: const Duration(milliseconds: 1500),
                      child: _TarjetaDeRecord(
                        puntajeTotal: widget.resultado.puntajeTotal,
                        mejorPuntajeAnterior:
                            widget.resultado.mejorPuntajeAnterior!,
                      ),
                    ),
                  ],
                  if (!superado) ...[
                    const SizedBox(height: 24),
                    _TarjetaCuantoFalto(
                      puntajeTotal: widget.resultado.puntajeTotal,
                      puntajeMinimoSuperar:
                          widget.resultado.puntajeMinimoSuperar,
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [_teal, _azul],
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0xA60B4266),
                            offset: Offset(0, 7),
                          ),
                        ],
                      ),
                      child: TextButton(
                        key: Key(
                          superado
                              ? 'resumen-nivel-continuar'
                              : 'resumen-nivel-reintentar',
                        ),
                        onPressed: superado
                            ? () => Navigator.of(context).pop()
                            : _reintentar,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 22),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: Text(
                          superado ? 'Continuar' : 'Reintentar',
                          style: GoogleFonts.baloo2(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (superado)
                    TextButton(
                      key: const Key('resumen-nivel-repetir'),
                      onPressed: _lanzar,
                      child: Text(
                        'Repetir animación',
                        style: GoogleFonts.outfit(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: TextButton(
                        key: const Key('resumen-nivel-volver'),
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          'Volver al camino',
                          style: GoogleFonts.outfit(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                            decorationColor: Colors.white.withValues(
                              alpha: 0.35,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pill "Nivel N · Zona" superior. En estado no superado usa un tono neutro
/// en vez del teal de celebración.
class _Pill extends StatelessWidget {
  const _Pill({
    required this.superado,
    required this.nivelOrden,
    required this.tematicaNombre,
  });

  final bool superado;
  final int? nivelOrden;
  final String? tematicaNombre;

  @override
  Widget build(BuildContext context) {
    final partes = [
      if (nivelOrden != null) 'Nivel $nivelOrden',
      ?tematicaNombre,
    ];
    final texto = partes.isEmpty ? 'Nivel' : partes.join(' · ');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: superado
            ? _teal.withValues(alpha: 0.14)
            : Colors.white.withValues(alpha: 0.07),
        border: Border.all(
          color: superado
              ? _teal.withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.16),
        ),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: superado ? _teal : const Color(0xFF7FA8C4),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              texto.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                color: superado
                    ? const Color(0xFF7FE3D2)
                    : Colors.white.withValues(alpha: 0.6),
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Un hueco de estrella: apagada, o encendida con el pop y el halo del
/// mockup cuando `on` pasa de `false` a `true`.
class _Estrella extends StatefulWidget {
  const _Estrella({
    super.key,
    required this.on,
    required this.tamanoCaja,
    required this.tamanoEstrella,
  });

  final bool on;
  final double tamanoCaja;
  final double tamanoEstrella;

  @override
  State<_Estrella> createState() => _EstrellaState();
}

class _EstrellaState extends State<_Estrella>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controlador = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 580),
  );

  @override
  void initState() {
    super.initState();
    if (widget.on) _controlador.value = 1;
  }

  @override
  void didUpdateWidget(covariant _Estrella oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.on && !oldWidget.on) {
      _controlador.forward(from: 0);
    } else if (!widget.on && oldWidget.on) {
      _controlador.value = 0;
    }
  }

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.on) {
      return SizedBox(
        width: widget.tamanoCaja,
        height: widget.tamanoCaja,
        child: Center(
          child: Text(
            '★',
            style: TextStyle(
              fontSize: widget.tamanoEstrella,
              color: Colors.white.withValues(alpha: 0.13),
            ),
          ),
        ),
      );
    }

    return AnimatedBuilder(
      animation: _controlador,
      builder: (context, _) {
        final valor = _controlador.value.clamp(0.0, 1.0);
        final escala = Curves.easeOutBack.transform(valor);
        final halo = 1 - Curves.easeOut.transform(valor);

        return SizedBox(
          width: widget.tamanoCaja,
          height: widget.tamanoCaja,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: (halo * 0.55).clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: 0.7 + 1.2 * valor,
                  child: Container(
                    width: widget.tamanoCaja,
                    height: widget.tamanoCaja,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _gold.withValues(alpha: 0.3),
                    ),
                  ),
                ),
              ),
              Transform.scale(
                scale: escala.clamp(0.0, 1.3),
                child: Text(
                  '★',
                  style: TextStyle(
                    fontSize: widget.tamanoEstrella,
                    color: _gold,
                    shadows: const [
                      Shadow(color: Color(0x8C996E00), offset: Offset(0, 4)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Envuelve a `child` con una entrada retrasada (opacidad + escala), para el
/// aviso de récord que aparece 1,5 s después de arrancar la coreografía.
class _Retrasado extends StatefulWidget {
  const _Retrasado({required this.retraso, required this.child});

  final Duration retraso;
  final Widget child;

  @override
  State<_Retrasado> createState() => _RetrasadoState();
}

class _RetrasadoState extends State<_Retrasado> {
  bool _visible = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.retraso, () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !_visible,
      child: AnimatedOpacity(
        opacity: _visible ? 1 : 0,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOut,
        child: AnimatedScale(
          scale: _visible ? 1 : 0.85,
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutBack,
          child: widget.child,
        ),
      ),
    );
  }
}

class _TarjetaDeRecord extends StatelessWidget {
  const _TarjetaDeRecord({
    required this.puntajeTotal,
    required this.mejorPuntajeAnterior,
  });

  final int puntajeTotal;
  final int mejorPuntajeAnterior;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('resumen-nivel-record'),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_gold.withValues(alpha: 0.2), _gold.withValues(alpha: 0.1)],
        ),
        border: Border.all(color: _gold.withValues(alpha: 0.55), width: 1.5),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              color: _gold,
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            child: const Icon(
              Icons.emoji_events_rounded,
              color: Color(0xFF5E4200),
              size: 19,
            ),
          ),
          const SizedBox(width: 11),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '¡Nuevo récord personal!',
                  style: GoogleFonts.baloo2(
                    color: _goldClaro,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '+${formatearPuntaje(puntajeTotal - mejorPuntajeAnterior)} '
                  'más que tu mejor intento '
                  '(${formatearPuntaje(mejorPuntajeAnterior)} pts)',
                  style: GoogleFonts.outfit(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta de "cuánto faltó" del estado no superado: puntos que faltaron,
/// mínimo del nivel y una barra de progreso hacia ese mínimo.
class _TarjetaCuantoFalto extends StatelessWidget {
  const _TarjetaCuantoFalto({
    required this.puntajeTotal,
    required this.puntajeMinimoSuperar,
  });

  final int puntajeTotal;
  final int puntajeMinimoSuperar;

  @override
  Widget build(BuildContext context) {
    final faltan = math.max(0, puntajeMinimoSuperar - puntajeTotal);
    final pct = puntajeMinimoSuperar > 0
        ? (puntajeTotal / puntajeMinimoSuperar * 100).clamp(0, 100)
        : 100.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: Colors.white.withValues(alpha: 0.11)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  'Te faltaron ${formatearPuntaje(faltan)} puntos',
                  key: const Key('resumen-nivel-faltan'),
                  style: GoogleFonts.baloo2(
                    color: const Color(0xFF7FE3D2),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                'mín. ${formatearPuntaje(puntajeMinimoSuperar)}',
                style: GoogleFonts.outfit(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: Stack(
              children: [
                Container(
                  height: 10,
                  color: Colors.white.withValues(alpha: 0.1),
                ),
                FractionallySizedBox(
                  widthFactor: pct / 100,
                  child: Container(
                    height: 10,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [_teal, _azul]),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 11),
          Text(
            'Ya tienes el ${pct.round()}% del mínimo de este nivel. '
            '¡Estás cerca!',
            style: GoogleFonts.outfit(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 13,
              fontWeight: FontWeight.w400,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

/// Confeti de la celebración con 3 estrellas: 30 piezas cayendo una vez,
/// con el mismo generador pseudoaleatorio determinista (seno del índice)
/// que `[App] - Resumen del nivel.dc.html` (D9 de `design.md`), para no
/// añadir un paquete nuevo por una animación de un solo uso.
class _Confeti extends StatefulWidget {
  @override
  State<_Confeti> createState() => _ConfetiState();
}

class _ConfetiState extends State<_Confeti>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controlador = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4400),
  )..forward();

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  double _pseudoAleatorio(int i, double n, double m) =>
      (math.sin(i * 12.9898 + n) * 43758.5453) % 1 * m;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, restricciones) {
        return AnimatedBuilder(
          animation: _controlador,
          builder: (context, _) {
            final transcurridoMs = _controlador.value * 4400;
            return Stack(
              children: [
                for (var i = 0; i < 30; i++)
                  _piezaConfeti(i, restricciones, transcurridoMs),
              ],
            );
          },
        );
      },
    );
  }

  Widget _piezaConfeti(int i, BoxConstraints restricciones, double ms) {
    final esRedonda = i % 4 == 0;
    final izquierdaPct = 4 + _pseudoAleatorio(i, 1, 92);
    final arribaPx = -40 - _pseudoAleatorio(i, 2, 120);
    final ancho = esRedonda ? 9.0 : 5 + _pseudoAleatorio(i, 3, 4);
    final alto = esRedonda ? 9.0 : 11 + _pseudoAleatorio(i, 4, 9);
    final duracionMs = (2.1 + _pseudoAleatorio(i, 5, 1.5)) * 1000;
    final retrasoMs = _pseudoAleatorio(i, 6, 0.7) * 1000;
    final swaySegundos = 1.4 + _pseudoAleatorio(i, 7, 1.2);

    final progreso = ((ms - retrasoMs) / duracionMs).clamp(0.0, 1.0);
    if (progreso <= 0) return const SizedBox.shrink();

    final caida =
        arribaPx + (restricciones.maxHeight - arribaPx + 40) * progreso;
    final opacidad = progreso < 0.85 ? 1.0 : (1 - progreso) / 0.15;
    final vaivenT = (ms / 1000) / swaySegundos * math.pi;
    final vaivenX = math.sin(vaivenT + i) * 17;

    return Positioned(
      left: restricciones.maxWidth * izquierdaPct / 100,
      top: caida,
      child: Opacity(
        opacity: opacidad.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(vaivenX, 0),
          child: Container(
            width: ancho,
            height: alto,
            decoration: BoxDecoration(
              color: _coloresConfeti[i % _coloresConfeti.length],
              borderRadius: BorderRadius.circular(esRedonda ? 99 : 2),
            ),
          ),
        ),
      ),
    );
  }
}
