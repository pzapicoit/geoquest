## 1. Dependencias y base de movimiento

- [x] 1.1 Añadir `animations` y `flutter_animate` a `app/pubspec.yaml` y verificar que `flutter pub get` y `flutter analyze` pasan
- [x] 1.2 Crear `app/lib/motion/movimiento.dart` con `Movimiento` (duraciones y curvas) y `movimientoReducido(BuildContext)`
- [x] 1.3 Tests unitarios de `movimientoReducido` con y sin `disableAnimations` en el `MediaQuery`

## 2. Transiciones

- [x] 2.1 Crear `app/lib/motion/rutas.dart` con `TransicionDeProfundidad` (`PageTransitionsBuilder` sobre `SharedAxisTransition` escalada) y `rutaDeRelevo` (`PageRouteBuilder` con `FadeThroughTransition`), ambos con solo un fundido si hay «reducir movimiento»
- [x] 2.2 Widget tests: la profundidad usa `SharedAxisTransition`, el relevo usa `FadeThroughTransition`, con reducir movimiento solo hay `FadeTransition` (sin escala), y `pumpAndSettle()` termina en ambos casos
- [x] 2.3 Definir `pageTransitionsTheme` en `main.dart`: `TransicionDeProfundidad` en Android, web, macOS, Windows, Linux y Fuchsia; `CupertinoPageTransitionsBuilder` en iOS
- [x] 2.4 Fijar `Animate.defaultDuration` y `Animate.defaultCurve` desde `Movimiento` en `main.dart`

## 3. Navegaciones

- [x] 3.1 Sustituir `MaterialPageRoute` por `rutaDeRelevo` en los `pushReplacement` de `splash_screen.dart`, `login_screen.dart`, `username_screen.dart`, `nivel_juego_screen.dart` y `resumen_nivel_screen.dart`
- [x] 3.2 Comprobar con grep que no queda ningún `pushReplacement` con `MaterialPageRoute` en `app/lib`

## 4. Verificación

- [x] 4.1 Ejecutar la suite completa de `flutter test` y corregir los tests que dependieran de la transición por defecto
- [ ] 4.2 Prueba manual en web: splash → login → camino → nivel → resumen → camino, y camino → ranking/comodines → atrás; repetir con «reducir movimiento» activo
