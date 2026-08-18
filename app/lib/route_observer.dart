import 'package:flutter/widgets.dart';

/// Observador compartido del `Navigator` raíz (INT-94, D6 de `design.md`):
/// permite que una pantalla sepa cuándo vuelve a ser la visible tras
/// cualquier cadena de `push`/`pushReplacement` por encima suyo, en vez de
/// depender del completado de un único `Future` de `push`, que un
/// `pushReplacement` posterior resuelve en cuanto reemplaza esa ruta —mucho
/// antes de que el jugador realmente vuelva.
final routeObserver = RouteObserver<PageRoute<dynamic>>();
