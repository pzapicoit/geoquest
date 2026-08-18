import 'dart:math';

import 'package:flutter/material.dart';

import 'entry_motion.dart';

const entryBg = Color(0xFF0A1622);
const entryCard = Color(0xFF16242F);
const entryTeal = Color(0xFF2BC0A8);
const entryBlue = Color(0xFF1B6FA8);
const entryGold = Color(0xFFFFC53D);

/// Fondo oscuro compartido por las pantallas de entrada (primera vez y
/// regreso, INT-108): degradado azul-teal con halos, textura de puntos,
/// ruta punteada en movimiento (`gq-dash`) y un círculo punteado
/// decorativo, tal como en `[App] - Login.dc.html`.
class EntryBackdrop extends StatefulWidget {
  const EntryBackdrop({super.key, required this.child});

  final Widget child;

  @override
  State<EntryBackdrop> createState() => _EntryBackdropState();
}

class _EntryBackdropState extends State<EntryBackdrop>
    with SingleTickerProviderStateMixin {
  final bool _reduceMotion = reduceMotion;

  late final AnimationController _routeController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
    value: _reduceMotion ? 1 : 0,
  );

  @override
  void initState() {
    super.initState();
    if (!_reduceMotion) _routeController.repeat();
  }

  @override
  void dispose() {
    _routeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF102A38), Color(0xFF0B1B27), Color(0xFF08131C)],
          stops: [0, 0.46, 1],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const _HaloGradients(),
          const Positioned.fill(child: CustomPaint(painter: _DotGridPainter())),
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _routeController,
              builder: (context, child) => CustomPaint(
                painter: _EntryRoutesPainter(
                  phase: -300 * _routeController.value,
                ),
              ),
            ),
          ),
          const Positioned(
            top: -140,
            right: -104,
            child: _DashedCircle(diameter: 320),
          ),
          widget.child,
        ],
      ),
    );
  }
}

class _HaloGradients extends StatelessWidget {
  const _HaloGradients();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -1.1),
          radius: 1.1,
          colors: [
            entryTeal.withValues(alpha: 0.22),
            entryTeal.withValues(alpha: 0),
          ],
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-0.75, 0.65),
            radius: 0.9,
            colors: [
              entryBlue.withValues(alpha: 0.18),
              entryBlue.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}

class _DotGridPainter extends CustomPainter {
  const _DotGridPainter();

  static const _spacing = 24.0;
  static const _radius = 1.2;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.07);
    for (var y = _spacing / 2; y < size.height; y += _spacing) {
      for (var x = _spacing / 2; x < size.width; x += _spacing) {
        canvas.drawCircle(Offset(x, y), _radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotGridPainter oldDelegate) => false;
}

/// Las dos rutas de fondo, sobre un lienzo de 390x844 (el viewBox del
/// diseño): una fluye (se desplaza el patrón de guiones), la otra es fija.
class _EntryRoutesPainter extends CustomPainter {
  const _EntryRoutesPainter({required this.phase});

  final double phase;

  static final Path _flowPath = Path()
    ..moveTo(-10, 300)
    ..cubicTo(70, 262, 110, 300, 170, 252)
    ..cubicTo(230, 204, 300, 206, 400, 242);

  static final Path _staticPath = Path()
    ..moveTo(-20, 168)
    ..cubicTo(60, 198, 130, 140, 210, 168)
    ..cubicTo(290, 196, 340, 112, 410, 150);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 390, size.height / 844);

    canvas.drawPath(
      dashedPath(_staticPath, on: 6, off: 12, phase: 0),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );

    canvas.drawPath(
      dashedPath(_flowPath, on: 9, off: 13, phase: phase),
      Paint()
        ..color = entryTeal.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _EntryRoutesPainter oldDelegate) =>
      oldDelegate.phase != phase;
}

class _DashedCircle extends StatelessWidget {
  const _DashedCircle({required this.diameter});

  final double diameter;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: diameter,
      height: diameter,
      child: CustomPaint(painter: _DashedCirclePainter()),
    );
  }
}

class _DashedCirclePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final circle = Path()..addOval(rect);
    canvas.drawPath(
      dashedPath(circle, on: 5, off: 6, phase: 0),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant _DashedCirclePainter oldDelegate) => false;
}

/// Inicial de un apodo para el avatar, con seguridad ante cadenas vacías y
/// sin partir un carácter compuesto (acentos, emoji) a la mitad.
String initialOf(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '?';
  return String.fromCharCode(trimmed.runes.first).toUpperCase();
}

double clampProgress(num value) => min(1.0, max(0.0, value.toDouble()));
