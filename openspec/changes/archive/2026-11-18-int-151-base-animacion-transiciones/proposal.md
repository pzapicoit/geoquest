## Why

Todas las navegaciones de la app usan la transición estándar del sistema (`MaterialPageRoute` sin personalizar). Splash → login → camino → nivel → resumen no se sienten parte del mismo juego. Además, cada pantalla define sus duraciones y curvas a mano, así que no hay un lenguaje de movimiento común. Esta issue (INT-151) pone esa base y es requisito de INT-152 (pantalla de juego) e INT-153 (camino, resumen y ranking).

## What Changes

- Nuevas dependencias: `animations` (transiciones Material oficiales: shared axis, fade through) y `flutter_animate` (animaciones declarativas encadenadas, que usarán INT-152 e INT-153).
- Nueva base de movimiento en `app/lib/motion/`: duraciones y curvas con nombre y una forma única de saber si el jugador pidió «reducir movimiento».
- Transición propia del juego para las rutas que se apilan (camino → nivel, ranking, comodines): profundidad con escala y fundido (shared axis Z), definida una vez en el tema de la app.
- Transición de relevo para las rutas que sustituyen a la actual (splash → login, login/apodo → camino, nivel → resumen, resumen → reintentar nivel): fundido cruzado (fade through).
- Con «reducir movimiento» activo, ambas transiciones se quedan en un fundido corto sin escala ni desplazamiento.
- En iOS, las rutas apiladas conservan la transición nativa de Cupertino para no perder el gesto de deslizar para volver. Las de relevo sí usan la transición del juego.

## Capabilities

### New Capabilities
- `app-motion`: lenguaje de movimiento común de la app (duraciones, curvas, «reducir movimiento») y transiciones entre pantallas.

### Modified Capabilities
<!-- Ninguna: no cambia ningún requirement existente; las pantallas siguen navegando a los mismos destinos. -->

## Impact

- `app/pubspec.yaml`: `animations`, `flutter_animate`.
- `app/lib/main.dart`: `pageTransitionsTheme` del `ThemeData` y valores por defecto de `flutter_animate`.
- Nuevo `app/lib/motion/` (tokens y rutas).
- Sustitución de `MaterialPageRoute` en los `pushReplacement` de `splash_screen.dart`, `login_screen.dart`, `username_screen.dart`, `nivel_juego_screen.dart` y `resumen_nivel_screen.dart`.
- Sin cambios en backend, datos ni lógica de juego.
