import 'dart:async';

import 'package:flutter/widgets.dart';

import 'movimiento.dart';

/// Cómo entra y sale un elemento con [Presencia].
enum EstiloDePresencia {
  /// Fundido de opacidad.
  fundido,

  /// Fundido y desplazamiento desde [Presencia.desde].
  deslizar,
}

/// Anima la entrada **y la salida** de un elemento que se muestra u oculta
/// según [visible] (INT-152, D1 de `design.md`).
///
/// Al pasar [visible] a `false` guarda el último hijo que pintó y lo anima
/// hacia fuera antes de dejar de pintarlo: así el estado de la pantalla puede
/// cambiar en el acto (por ejemplo, borrar el revelado) sin que el elemento
/// desaparezca de golpe.
///
/// Mientras sale, o mientras espera su [retraso] de entrada, no recibe toques
/// ni se anuncia al lector de pantalla: un elemento que se va no debe poder
/// pulsarse dos veces. Con «reducir movimiento» los dos estilos se quedan en un
/// fundido.
class Presencia extends StatefulWidget {
  const Presencia({
    super.key,
    required this.visible,
    required this.child,
    this.estilo = EstiloDePresencia.fundido,
    this.desde = const Offset(0, 40),
    this.retraso = Duration.zero,
    this.duracion = Movimiento.media,
    this.curva = Movimiento.llegada,
  });

  final bool visible;
  final Widget child;
  final EstiloDePresencia estilo;

  /// Desplazamiento de partida (y de llegada al salir) para
  /// [EstiloDePresencia.deslizar], en píxeles lógicos.
  final Offset desde;

  /// Espera antes de empezar a entrar cada vez que [visible] pasa a `true`.
  final Duration retraso;

  final Duration duracion;
  final Curve curva;

  @override
  State<Presencia> createState() => _PresenciaState();
}

class _PresenciaState extends State<Presencia>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controlador = AnimationController(
    vsync: this,
    duration: widget.duracion,
  );

  late final CurvedAnimation _avance = CurvedAnimation(
    parent: _controlador,
    curve: widget.curva,
    reverseCurve: widget.curva.flipped,
  );

  late Widget _ultimoHijo;
  Timer? _espera;

  @override
  void initState() {
    super.initState();
    // Aquí y no en la declaración: un `late` con inicializador se evaluaría la
    // primera vez que se lee, que es al ocultarse, cuando `widget.child` ya es
    // el hijo nuevo y no el que se estaba viendo.
    _ultimoHijo = widget.child;
    _controlador.addStatusListener((_) {
      if (mounted) setState(() {});
    });
    if (widget.visible) _entrar();
  }

  @override
  void didUpdateWidget(Presencia anterior) {
    super.didUpdateWidget(anterior);
    _controlador.duration = widget.duracion;
    if (widget.visible) _ultimoHijo = widget.child;
    if (widget.visible == anterior.visible) return;
    if (widget.visible) {
      _entrar();
    } else {
      _espera?.cancel();
      _controlador.reverse();
    }
  }

  void _entrar() {
    _espera?.cancel();
    if (widget.retraso == Duration.zero) {
      _controlador.forward();
      return;
    }
    _espera = Timer(widget.retraso, () {
      if (mounted && widget.visible) _controlador.forward();
    });
  }

  @override
  void dispose() {
    _espera?.cancel();
    _avance.dispose();
    _controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible && _controlador.isDismissed) {
      return const SizedBox.shrink();
    }

    final inerte = !widget.visible || _controlador.isDismissed;
    final deslizar =
        widget.estilo == EstiloDePresencia.deslizar &&
        !movimientoReducido(context);

    // Mismo árbol con y sin desplazamiento: si cambiara de forma al activar
    // «reducir movimiento» a media partida, el hijo se rehará y perdería su
    // estado.
    return IgnorePointer(
      ignoring: inerte,
      child: ExcludeSemantics(
        excluding: inerte,
        child: FadeTransition(
          opacity: _avance,
          child: AnimatedBuilder(
            animation: _avance,
            builder: (context, hijo) => Transform.translate(
              offset: deslizar
                  ? widget.desde * (1 - _avance.value)
                  : Offset.zero,
              child: hijo,
            ),
            child: widget.visible ? widget.child : _ultimoHijo,
          ),
        ),
      ),
    );
  }
}
