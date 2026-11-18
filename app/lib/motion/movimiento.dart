import 'package:flutter/widgets.dart';

/// Lenguaje de movimiento común de la app (INT-151, `app-motion`).
///
/// Las transiciones entre pantallas y las animaciones nuevas sacan de aquí
/// sus duraciones y curvas en vez de escribirlas a mano en cada pantalla, para
/// que el juego se mueva con un mismo ritmo de punta a punta.
abstract final class Movimiento {
  /// Respuestas inmediatas: pulsaciones, cambios de estado pequeños.
  static const rapida = Duration(milliseconds: 150);

  /// Elementos que aparecen o se van dentro de una pantalla.
  static const media = Duration(milliseconds: 300);

  /// Transición completa entre dos pantallas.
  static const pantalla = Duration(milliseconds: 400);

  /// Entradas con protagonismo (logo, hojas de resultado).
  static const entrada = Duration(milliseconds: 700);

  /// Movimiento que empieza y termina dentro de la pantalla.
  static const Curve estandar = Curves.easeInOutCubic;

  /// Algo que llega: arranca rápido y se posa suave.
  static const Curve llegada = Curves.easeOutCubic;

  /// Algo que se va: arranca suave y sale rápido.
  static const Curve salida = Curves.easeInCubic;

  /// Llegada con un pequeño sobrepaso, para momentos de juego.
  static const Curve rebote = Curves.easeOutBack;

  /// Relleno detrás de las transiciones. Todas las pantallas del juego son
  /// oscuras: con el `canvasColor` claro por defecto se vería un destello
  /// blanco entre dos pantallas oscuras.
  static const Color fondoDeTransicion = Color(0xFF0A1622);
}

/// Si el jugador ha pedido «reducir movimiento» en el sistema.
///
/// Va por `MediaQuery` y no por `platformDispatcher` para que un test lo pueda
/// forzar envolviendo la pantalla en un `MediaQuery` con `disableAnimations`.
bool movimientoReducido(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;
