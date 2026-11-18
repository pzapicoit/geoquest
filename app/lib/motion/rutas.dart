import 'package:animations/animations.dart';
import 'package:flutter/cupertino.dart';
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

/// Transición nativa de iOS para las rutas apiladas, que conserva el gesto de
/// deslizar desde el borde para volver (D3 de `design.md`). Con «reducir
/// movimiento» se queda en un fundido: la de Cupertino no lo consulta y
/// desplazaría la pantalla igualmente.
class TransicionNativaDeIOS extends PageTransitionsBuilder {
  const TransicionNativaDeIOS();

  static const _cupertino = CupertinoPageTransitionsBuilder();

  @override
  Duration get transitionDuration => _cupertino.transitionDuration;

  @override
  Duration get reverseTransitionDuration =>
      _cupertino.reverseTransitionDuration;

  /// Lo que la nueva pantalla le hace a la de debajo cuando esta no comparte
  /// transición (por ejemplo, el camino, que llega por [rutaDeRelevo]).
  /// Cupertino la desplaza a un lado sin mirar «reducir movimiento»; con el
  /// ajuste activo se devuelve `null` y la de debajo usa su propio fundido.
  ///
  /// Es una función estática, siempre la misma referencia: `didChangeNext`
  /// compara delegados con `!=` para decidir si aplicarlo.
  static Widget? _delegadoSinMovimientoReducido(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    bool allowSnapshotting,
    Widget? child,
  ) {
    if (movimientoReducido(context)) return null;
    return CupertinoPageTransition.delegatedTransition(
      context,
      animation,
      secondaryAnimation,
      allowSnapshotting,
      child,
    );
  }

  @override
  DelegatedTransitionBuilder? get delegatedTransition =>
      _delegadoSinMovimientoReducido;

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
    return _cupertino.buildTransitions(
      route,
      context,
      animation,
      secondaryAnimation,
      child,
    );
  }
}

/// Transiciones de las rutas apiladas de la app (D2/D3 de `design.md`): la
/// del juego en todas partes salvo en la app nativa de iOS, que conserva la
/// suya por el gesto de volver.
///
/// En web, también en el navegador de un iPhone, se usa la del juego: allí el
/// gesto de volver es el del propio navegador, no el de Cupertino.
PageTransitionsTheme temaDeTransiciones({required bool web}) {
  const juego = TransicionDeProfundidad();
  return PageTransitionsTheme(
    builders: {
      for (final plataforma in TargetPlatform.values) plataforma: juego,
      if (!web) TargetPlatform.iOS: const TransicionNativaDeIOS(),
    },
  );
}

/// Ruta para sustituir la pantalla actual por otra (`pushReplacement`): un
/// fundido cruzado en todas las plataformas, porque al relevar una pantalla
/// no hay jerarquía que expresar.
///
/// No lleva el gesto de volver de iOS: el resumen y el nivel reintentado
/// vuelven al camino con sus propios botones (D3 de `design.md`).
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
