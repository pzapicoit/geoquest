import 'package:animations/animations.dart';
import 'package:flutter/material.dart';

import 'movimiento.dart';

/// Transición de las pantallas que se apilan sobre la actual (camino → nivel,
/// ranking, comodines): la nueva pantalla llega desde el fondo con escala y
/// fundido, y la de debajo se aleja (INT-151, `app-motion`).
///
/// Se registra en el `pageTransitionsTheme` de la app, así que cualquier
/// `MaterialPageRoute` la hereda sin tocar el punto de navegación.
class TransicionDeProfundidad extends PageTransitionsBuilder {
  const TransicionDeProfundidad();

  @override
  Duration get transitionDuration => Movimiento.pantalla;

  @override
  Duration get reverseTransitionDuration => Movimiento.pantalla;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (movimientoReducido(context)) {
      return FadeTransition(opacity: animation, child: child);
    }
    return SharedAxisTransition(
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      transitionType: SharedAxisTransitionType.scaled,
      fillColor: Movimiento.fondoDeTransicion,
      child: child,
    );
  }
}

/// Ruta para sustituir la pantalla actual por otra (`pushReplacement`): un
/// fundido cruzado en todas las plataformas, porque al relevar una pantalla
/// no hay jerarquía que expresar ni gesto de volver que conservar.
Route<T> rutaDeRelevo<T>(WidgetBuilder builder) {
  return PageRouteBuilder<T>(
    transitionDuration: Movimiento.pantalla,
    reverseTransitionDuration: Movimiento.pantalla,
    pageBuilder: (context, _, _) => builder(context),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (movimientoReducido(context)) {
        return FadeTransition(opacity: animation, child: child);
      }
      return FadeThroughTransition(
        animation: animation,
        secondaryAnimation: secondaryAnimation,
        fillColor: Movimiento.fondoDeTransicion,
        child: child,
      );
    },
  );
}
