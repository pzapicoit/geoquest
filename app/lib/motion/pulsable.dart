import 'package:flutter/widgets.dart';

import 'movimiento.dart';

/// Escala a la baja mientras se mantiene pulsado, para que un botón responda
/// al dedo antes de que su acción tenga efecto (INT-152, D5 de `design.md`).
///
/// Escucha con un `Listener`, que no compite con los reconocedores de gestos
/// del botón que envuelve. Deshabilitado, o con «reducir movimiento», no
/// cambia de escala.
class Pulsable extends StatefulWidget {
  const Pulsable({super.key, required this.child, this.habilitado = true});

  final Widget child;
  final bool habilitado;

  /// Escala mientras está pulsado.
  static const double escalaPulsado = 0.96;

  @override
  State<Pulsable> createState() => _PulsableState();
}

class _PulsableState extends State<Pulsable> {
  bool _pulsado = false;

  void _marcar(bool pulsado) {
    if (_pulsado != pulsado) setState(() => _pulsado = pulsado);
  }

  @override
  void didUpdateWidget(Pulsable anterior) {
    super.didUpdateWidget(anterior);
    if (!widget.habilitado) _pulsado = false;
  }

  @override
  Widget build(BuildContext context) {
    final reacciona = widget.habilitado && !movimientoReducido(context);
    return Listener(
      onPointerDown: reacciona ? (_) => _marcar(true) : null,
      onPointerUp: (_) => _marcar(false),
      onPointerCancel: (_) => _marcar(false),
      child: AnimatedScale(
        scale: _pulsado && reacciona ? Pulsable.escalaPulsado : 1,
        duration: Movimiento.rapida,
        curve: Movimiento.estandar,
        child: widget.child,
      ),
    );
  }
}
