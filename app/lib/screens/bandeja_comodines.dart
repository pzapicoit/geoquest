import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/comodines_gateway.dart';

const _ink = Color(0xFF0E1620);
const _gold = Color(0xFFFFC53D);

/// Bandeja de comodines de la pantalla de juego (INT-119): una pestaña
/// pegada al borde derecho, plegada por defecto, que se despliega hacia la
/// izquierda en una fila con los 4 tipos.
///
/// Vive en su propio archivo (como `CuentaAtrasDeDesafio` o
/// `MapaMundiController`/`MapaMundi`) porque tiene estado de interacción
/// propio —plegada/desplegada— separado del resto de la pantalla de juego, y
/// así se puede montar y probar sola.
///
/// `pais` sin dato disponible para el desafío actual (D4 de `design.md`) NO
/// se puede detectar aquí de antemano: `desafios_para_jugar`/
/// `iniciar_intento_parada` (ya implementados en el backend, ver
/// `nivel_juego_gateway.dart`) nunca exponen `pais` al cliente antes de
/// consumir el comodín —solo lo hace el propio `usar_comodin`, que sirve a
/// la vez de "consulta" y de "consumo"—. El requirement "Comodín país sin
/// dato disponible" de `app-game-screen/spec.md` pide un icono deshabilitado
/// para ese caso concreto; sin ese dato en el cliente no se puede pintar
/// deshabilitado de antemano, así que aquí `pais` se ofrece habilitado igual
/// que el resto (si hay inventario y no se ha usado ya un comodín en el
/// intento) y el caso "sin país registrado" se resuelve como un rechazo
/// normal de `usar_comodin` (`pais_no_disponible`, ver
/// `_NivelJuegoScreenState._usarComodin` en `nivel_juego_screen.dart`), sin
/// tocar el inventario ni la marca de comodín-usado. Documentado también en
/// el reporte final de esta tarea.
class BandejaComodines extends StatefulWidget {
  const BandejaComodines({
    super.key,
    required this.inventario,
    required this.usadoEnEsteIntento,
    required this.procesando,
    required this.onUsar,
  });

  /// `null` mientras se carga el inventario por primera vez: la bandeja no
  /// se enseña todavía, para no ofrecer un comodín con una cantidad que aún
  /// no se conoce.
  final InventarioComodines? inventario;

  /// Ya se consumió un comodín (de cualquier tipo) en el intento en curso
  /// (D2 de `design.md`): deshabilita los 4, tengan o no inventario.
  final bool usadoEnEsteIntento;

  /// Esperando la respuesta de `usar_comodin`: deshabilita los 4 mientras
  /// dura, para no poder lanzar dos consumos a la vez.
  final bool procesando;

  final void Function(ComodinTipo tipo) onUsar;

  @override
  State<BandejaComodines> createState() => _BandejaComodinesState();
}

class _BandejaComodinesState extends State<BandejaComodines> {
  bool _desplegada = false;

  /// Posición vertical de la bandeja, en fracción de `Alignment` (-1 arriba,
  /// 1 abajo). Por debajo del centro (donde están los botones de zoom del
  /// mapa, `_BotonesDeZoom` en `mapa_mundi.dart`) y arrastrable por el
  /// jugador (feedback tras probar la primera versión: quedaba demasiado
  /// arriba y fija).
  double _fraccionY = 0.35;

  void _alternar() => setState(() => _desplegada = !_desplegada);

  void _cerrar() {
    if (_desplegada) setState(() => _desplegada = false);
  }

  void _usar(ComodinTipo tipo) {
    _cerrar();
    widget.onUsar(tipo);
  }

  void _arrastrar(DragUpdateDetails detalles, double altoDisponible) {
    if (altoDisponible <= 0) return;
    setState(() {
      _fraccionY = (_fraccionY + detalles.delta.dy / (altoDisponible / 2))
          .clamp(-0.85, 0.85);
    });
  }

  @override
  Widget build(BuildContext context) {
    final inventario = widget.inventario;
    if (inventario == null) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            // Tocar fuera de la bandeja la repliega (requirement "Bandeja de
            // comodines sobre el mapa"): una capa transparente detrás de la
            // pestaña/fila, solo mientras está desplegada -- plegada no debe
            // robarle ningún toque al mapa que hay debajo.
            if (_desplegada)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _cerrar,
                ),
              ),
            Align(
              alignment: Alignment(1, _fraccionY),
              child: GestureDetector(
                onVerticalDragUpdate: (detalles) =>
                    _arrastrar(detalles, constraints.maxHeight),
                child: _desplegada
                    ? _FilaDesplegada(
                        inventario: inventario,
                        usadoEnEsteIntento: widget.usadoEnEsteIntento,
                        procesando: widget.procesando,
                        onUsar: _usar,
                        onCerrar: _cerrar,
                      )
                    : _PestanaPlegada(onTap: _alternar),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PestanaPlegada extends StatelessWidget {
  const _PestanaPlegada({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Comodines',
      child: InkWell(
        key: const Key('bandeja-comodines-pestana'),
        onTap: onTap,
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
        child: Container(
          padding: const EdgeInsets.fromLTRB(6, 10, 10, 10),
          decoration: BoxDecoration(
            color: _ink.withValues(alpha: 0.72),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(16),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.chevron_left_rounded,
                color: Colors.white.withValues(alpha: 0.7),
                size: 18,
              ),
              const SizedBox(width: 2),
              Image.asset(
                'assets/comodines/generico.png',
                width: 26,
                height: 26,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilaDesplegada extends StatelessWidget {
  const _FilaDesplegada({
    required this.inventario,
    required this.usadoEnEsteIntento,
    required this.procesando,
    required this.onUsar,
    required this.onCerrar,
  });

  final InventarioComodines inventario;
  final bool usadoEnEsteIntento;
  final bool procesando;
  final void Function(ComodinTipo tipo) onUsar;
  final VoidCallback onCerrar;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('bandeja-comodines-fila'),
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _ink.withValues(alpha: 0.82),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final tipo in ComodinTipo.values) ...[
            _IconoComodin(
              tipo: tipo,
              cantidad: inventario.cantidadDe(tipo),
              habilitado:
                  !procesando &&
                  !usadoEnEsteIntento &&
                  inventario.cantidadDe(tipo) > 0,
              onTap: () => onUsar(tipo),
            ),
            const SizedBox(width: 8),
          ],
          _BotonCerrarBandeja(onTap: onCerrar),
        ],
      ),
    );
  }
}

class _IconoComodin extends StatelessWidget {
  const _IconoComodin({
    required this.tipo,
    required this.cantidad,
    required this.habilitado,
    required this.onTap,
  });

  final ComodinTipo tipo;
  final int cantidad;
  final bool habilitado;
  final VoidCallback onTap;

  /// Sin caja de fondo alrededor (feedback tras probar la primera versión:
  /// con el asset ya sin fondo blanco propio, una caja encima sobraba) y más
  /// grande que la primera versión (44px) para que se distinga bien sobre el
  /// mapa.
  static const double _tamano = 56;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: habilitado,
      label: '${_etiqueta(tipo)}, $cantidad disponibles',
      child: InkWell(
        key: Key('bandeja-comodines-${tipo.aTexto}'),
        onTap: habilitado ? onTap : null,
        borderRadius: BorderRadius.circular(13),
        child: Opacity(
          opacity: habilitado ? 1 : 0.38,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Image.asset(
                _assetIcono(tipo),
                width: _tamano,
                height: _tamano,
                fit: BoxFit.contain,
              ),
              Positioned(
                right: -6,
                top: -6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  constraints: const BoxConstraints(minWidth: 18),
                  decoration: BoxDecoration(
                    color: _gold,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: _ink, width: 1.5),
                  ),
                  child: Text(
                    '$cantidad',
                    key: Key('bandeja-comodines-${tipo.aTexto}-cantidad'),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.baloo2(
                      color: _ink,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
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

class _BotonCerrarBandeja extends StatelessWidget {
  const _BotonCerrarBandeja({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Cerrar comodines',
      child: InkWell(
        key: const Key('bandeja-comodines-cerrar'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: SizedBox(
          width: 32,
          height: 44,
          child: Icon(
            Icons.close_rounded,
            color: Colors.white.withValues(alpha: 0.7),
            size: 18,
          ),
        ),
      ),
    );
  }
}

String _assetIcono(ComodinTipo tipo) => switch (tipo) {
  ComodinTipo.tiempo => 'assets/comodines/icono_tiempo.png',
  ComodinTipo.pais => 'assets/comodines/icono_pais.png',
  ComodinTipo.km1000 => 'assets/comodines/icono_km1000.png',
  ComodinTipo.km500 => 'assets/comodines/icono_km500.png',
};

String _etiqueta(ComodinTipo tipo) => switch (tipo) {
  ComodinTipo.tiempo => 'Comodín tiempo: sin límite para esta pregunta',
  ComodinTipo.pais => 'Comodín país: revela el país del objetivo',
  ComodinTipo.km1000 => 'Comodín radio 500 km',
  ComodinTipo.km500 => 'Comodín radio 150 km',
};
