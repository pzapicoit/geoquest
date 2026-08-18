import 'package:flutter/material.dart';

/// Utilidades de animación compartidas entre las pantallas de entrada
/// (primera vez y regreso, INT-108): reproducen con fidelidad los
/// keyframes CSS del mock `[App] - Login.dc.html` (`gq-pop`, `gq-rise`,
/// `gq-float`, `gq-halo4`) sin repetir el fallo de INT-107 de ignorarlos.
///
/// Todas respetan "reducir movimiento" del sistema — y de paso evitan que
/// los widget tests se cuelguen en `pumpAndSettle()` con animaciones en
/// bucle infinito, igual que ya hacía `_Hero` en `username_screen.dart`.
bool get reduceMotion => WidgetsBinding
    .instance
    .platformDispatcher
    .accessibilityFeatures
    .disableAnimations;

/// "Pop" de entrada con ligero overshoot + fade, como `gq-pop`.
class PopIn extends StatefulWidget {
  const PopIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 800),
  });

  final Widget child;
  final Duration delay;
  final Duration duration;

  @override
  State<PopIn> createState() => _PopInState();
}

class _PopInState extends State<PopIn> with SingleTickerProviderStateMixin {
  final bool _reduceMotion = reduceMotion;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: _reduceMotion ? 1 : 0,
  );

  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0.84, end: 1.04), weight: 60),
    TweenSequenceItem(tween: Tween(begin: 1.04, end: 1.0), weight: 40),
  ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

  late final Animation<double> _opacity = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, 0.6),
  );

  @override
  void initState() {
    super.initState();
    if (_reduceMotion) return;
    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}

/// Sube 14px con fade, como `gq-rise`. Pensado para encadenar retrasos
/// escalonados entre bloques de una misma pantalla.
class RiseIn extends StatefulWidget {
  const RiseIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 700),
  });

  final Widget child;
  final Duration delay;
  final Duration duration;

  @override
  State<RiseIn> createState() => _RiseInState();
}

class _RiseInState extends State<RiseIn> with SingleTickerProviderStateMixin {
  final bool _reduceMotion = reduceMotion;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: _reduceMotion ? 1 : 0,
  );

  late final Animation<double> _rise = Tween<double>(
    begin: 14,
    end: 0,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

  @override
  void initState() {
    super.initState();
    if (_reduceMotion) return;
    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Opacity(
        opacity: _controller.value,
        child: Transform.translate(
          offset: Offset(0, _rise.value),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

/// Flotación vertical en bucle ping-pong, como `gq-float`.
class FloatLoop extends StatefulWidget {
  const FloatLoop({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 6000),
    this.distance = 10,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final double distance;

  @override
  State<FloatLoop> createState() => _FloatLoopState();
}

class _FloatLoopState extends State<FloatLoop>
    with SingleTickerProviderStateMixin {
  final bool _reduceMotion = reduceMotion;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  late final Animation<double> _float = Tween<double>(
    begin: 0,
    end: -widget.distance,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void initState() {
    super.initState();
    if (_reduceMotion) return;
    if (widget.delay == Duration.zero) {
      _controller.repeat(reverse: true);
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _controller.repeat(reverse: true);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _float,
      builder: (context, child) =>
          Transform.translate(offset: Offset(0, _float.value), child: child),
      child: widget.child,
    );
  }
}

/// Anillo pulsante en bucle detrás del `child`, como `gq-halo4`.
class HaloPulse extends StatefulWidget {
  const HaloPulse({
    super.key,
    required this.child,
    required this.color,
    this.inset = -9,
    this.borderRadius = const BorderRadius.all(Radius.circular(30)),
  });

  final Widget child;
  final Color color;
  final double inset;
  final BorderRadius borderRadius;

  @override
  State<HaloPulse> createState() => _HaloPulseState();
}

class _HaloPulseState extends State<HaloPulse>
    with SingleTickerProviderStateMixin {
  final bool _reduceMotion = reduceMotion;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  late final Animation<double> _scale = Tween<double>(
    begin: 0.95,
    end: 1.45,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

  late final Animation<double> _opacity = Tween<double>(
    begin: 0.45,
    end: 0,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

  @override
  void initState() {
    super.initState();
    if (!_reduceMotion) _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        if (!_reduceMotion)
          Positioned(
            top: widget.inset,
            left: widget.inset,
            right: widget.inset,
            bottom: widget.inset,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => Opacity(
                opacity: _opacity.value,
                child: Transform.scale(
                  scale: _scale.value,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: widget.borderRadius,
                      border: Border.all(color: widget.color, width: 2.5),
                    ),
                  ),
                ),
              ),
            ),
          ),
        widget.child,
      ],
    );
  }
}

/// Recorre `source` alternando tramos dibujados/vacíos (`on`/`off`),
/// desplazados por `phase`. Compartido por los `CustomPainter` de rutas y
/// círculos punteados de fondo.
Path dashedPath(
  Path source, {
  required double on,
  required double off,
  required double phase,
}) {
  final dest = Path();
  final cycle = on + off;
  var normalizedPhase = phase % cycle;
  if (normalizedPhase < 0) normalizedPhase += cycle;

  for (final metric in source.computeMetrics()) {
    var distance = -normalizedPhase;
    var drawing = normalizedPhase < on;
    while (distance < metric.length) {
      final segmentLength = drawing ? on : off;
      final segmentEnd = distance + segmentLength;
      if (drawing) {
        final start = distance.clamp(0.0, metric.length);
        final end = segmentEnd.clamp(0.0, metric.length);
        if (end > start) {
          dest.addPath(metric.extractPath(start, end), Offset.zero);
        }
      }
      distance = segmentEnd;
      drawing = !drawing;
    }
  }
  return dest;
}
