import 'package:flutter/widgets.dart';

import 'movimiento.dart';

/// Hueco que espera contenido (una imagen que todavía no ha llegado): un
/// brillo que lo barre en bucle (INT-152, D7 de `design.md`). Con «reducir
/// movimiento» se queda quieto, en el color de base.
class FondoDeCarga extends StatefulWidget {
  const FondoDeCarga({
    super.key,
    this.base = const Color(0xFF16242F),
    this.brillo = const Color(0xFF223744),
  });

  final Color base;
  final Color brillo;

  static const duracionDelBarrido = Duration(milliseconds: 1400);

  @override
  State<FondoDeCarga> createState() => _FondoDeCargaState();
}

class _FondoDeCargaState extends State<FondoDeCarga>
    with SingleTickerProviderStateMixin {
  late final AnimationController _barrido = AnimationController(
    vsync: this,
    duration: FondoDeCarga.duracionDelBarrido,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (movimientoReducido(context)) {
      _barrido.stop();
    } else if (!_barrido.isAnimating) {
      _barrido.repeat();
    }
  }

  @override
  void dispose() {
    _barrido.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (movimientoReducido(context)) {
      return ColoredBox(color: widget.base);
    }
    return AnimatedBuilder(
      animation: _barrido,
      builder: (context, _) {
        final x = -3 + 4 * _barrido.value;
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(x, -0.3),
              end: Alignment(x + 2, 0.3),
              colors: [widget.base, widget.brillo, widget.base],
            ),
          ),
        );
      },
    );
  }
}
