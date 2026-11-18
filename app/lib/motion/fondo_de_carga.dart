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

/// `frameBuilder` para imágenes de red que deben esperar con estilo (INT-152,
/// D7 de `design.md`):
///
/// - si la imagen llega de la caché (`deCache`, p. ej. por la precarga de
///   INT-120), se pinta sin más, sin fondo ni fundido;
/// - si llega de la red, su hueco muestra [FondoDeCarga] hasta el primer
///   fotograma y la imagen entra con un fundido.
///
/// Solo envuelve lo que pinta: no cambia el provider de la imagen, que es la
/// clave de la caché compartida con la precarga.
Widget apareceAlCargar(
  BuildContext context,
  Widget imagen,
  int? fotograma,
  bool deCache,
) {
  if (deCache) return imagen;
  return Stack(
    fit: StackFit.expand,
    children: [
      if (fotograma == null) const FondoDeCarga(key: Key('imagen-cargando')),
      AnimatedOpacity(
        opacity: fotograma == null ? 0 : 1,
        duration: Movimiento.media,
        curve: Movimiento.llegada,
        child: imagen,
      ),
    ],
  );
}
