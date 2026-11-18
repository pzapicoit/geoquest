## Context

- Hay 8 navegaciones con `MaterialPageRoute` sin personalizar: 3 `push` desde `camino_screen.dart` (ranking, comodines, nivel) y 5 `pushReplacement` (splash → login, login → camino, apodo → camino, nivel → resumen, resumen → reintentar nivel).
- El `ThemeData` de `main.dart` solo define el `colorScheme`; no hay `pageTransitionsTheme`.
- `entry_motion.dart` ya tiene piezas de animación (PopIn, RiseIn, FloatLoop, HaloPulse) y un getter global `reduceMotion` que lee `platformDispatcher`. Otras pantallas leen `MediaQuery.of(context).disableAnimations`. Las dos formas conviven.
- La app se prueba sobre todo en web (`flutter run -d web-server`) y se distribuye en Android e iOS.
- Los widget tests de varias pantallas empujan su pantalla con `MaterialPageRoute` y esperan con `pumpAndSettle()`.

## Goals / Non-Goals

**Goals:**
- Base de movimiento común (duraciones, curvas, «reducir movimiento») que reutilicen INT-152 e INT-153.
- Ninguna navegación con la transición por defecto, salvo la excepción de iOS para las rutas apiladas (D3).
- Cambio mínimo en las pantallas: tocar solo las líneas de navegación.

**Non-Goals:**
- Animar elementos dentro de las pantallas: es INT-152 e INT-153.
- Transiciones compartidas de elementos entre pantallas (`Hero`, container transform): se valorarán en INT-153 para parada → nivel.
- Diálogos y hojas modales (`showDialog`, `showModalBottomSheet`): se quedan como están.
- Reescribir `entry_motion.dart`.

## Decisions

**D1. Paquete `animations` para las transiciones, en vez de escribirlas a mano.**
Es el paquete oficial de Flutter con los patrones de movimiento de Material (shared axis, fade through), probado y mantenido. Escribir a mano el mismo efecto con `PageRouteBuilder` + `Tween` repetiría código que ya existe. Versión resuelta: `animations` 3.0.0.

**D2. Rutas apiladas: transición global en el tema; rutas de relevo: helper explícito.**
- Para los `push` se define `pageTransitionsTheme` en el `ThemeData` con un `PageTransitionsBuilder` propio (`TransicionDeProfundidad`) que envuelve `SharedAxisTransition` de tipo `scaled`. Así los tres `push` del camino (y cualquier `MaterialPageRoute` futura) heredan la transición sin tocar su código.
- Los `pushReplacement` pasan a usar `rutaDeRelevo(builder)` (`app/lib/motion/rutas.dart`), un `PageRouteBuilder` con `FadeThroughTransition`. Al sustituir una pantalla no hay jerarquía que expresar, y un fundido cruzado lo comunica mejor que la profundidad.
- Alternativa descartada: un helper para todo y quitar `MaterialPageRoute` de las 8 llamadas. Exige más cambios y deja sin cubrir las rutas futuras que alguien escriba con `MaterialPageRoute`.

**D3. iOS conserva Cupertino en las rutas apiladas.**
Un `PageTransitionsBuilder` que no sea el de Cupertino pierde el gesto de deslizar desde el borde para volver, que en iOS es un hábito muy arraigado (ranking y comodines). En iOS el tema usa `CupertinoPageTransitionsBuilder` para los `push`. Las rutas de relevo usan el fundido cruzado también en iOS: ahí no hay gesto de volver que perder.
Si se prefiere la misma transición en todas las plataformas, basta con cambiar una línea del tema. Lo decidirá el usuario al aprobar la propuesta.

**D4. Base de movimiento en `app/lib/motion/movimiento.dart`.**
- `abstract final class Movimiento` con duraciones (`rapida` 150 ms, `media` 300 ms, `pantalla` 400 ms, `entrada` 700 ms) y curvas (`estandar` = `Curves.easeInOutCubic`, `llegada` = `Curves.easeOutCubic`, `salida` = `Curves.easeInCubic`, `rebote` = `Curves.easeOutBack`).
- `bool movimientoReducido(BuildContext context)` lee `MediaQuery.maybeDisableAnimationsOf(context) ?? false`. Va por `MediaQuery` y no por `platformDispatcher` porque así los tests lo pueden forzar con `MediaQuery(data: …disableAnimations: true)`.
- `entry_motion.dart` no se toca: su getter sigue funcionando y migrarlo es trabajo de INT-152/153 si tocan esas piezas.

**D5. «Reducir movimiento» se resuelve dentro del `transitionsBuilder`.**
Tanto `TransicionDeProfundidad` como `rutaDeRelevo` consultan `movimientoReducido(context)` al construir la transición y, si está activo, devuelven solo un `FadeTransition` con la misma animación. La duración de la ruta queda fija al crearla (`Movimiento.pantalla`); con reducir movimiento el efecto es un fundido de 400 ms. Es aceptable porque el criterio pide un fundido, no un corte.

**D6. Valores por defecto de `flutter_animate` en `main.dart`.**
`Animate.defaultDuration = Movimiento.media` y `Animate.defaultCurve = Movimiento.llegada` antes de `runApp`. Así INT-152/153 heredan el lenguaje común con solo escribir `.animate().fadeIn()`. La dependencia se añade aquí para que la base quede completa en un solo cambio.

## Risks / Trade-offs

- [`animations` 3.0.0 arrastra `material_ui`/`cupertino_ui` como dependencias transitivas] → Se verifica que `flutter analyze` y el build web pasan; si hubiera conflicto, se fija `animations` 2.x, que ofrece la misma API.
- [Los tests que esperaban la transición por defecto pueden necesitar más `pump`] → Todas las transiciones son finitas (400 ms) y `pumpAndSettle()` las espera. Se ejecuta la suite completa.
- [`SharedAxisTransition` escalada pinta un fondo de relleno (`fillColor`)] → Se pasa el color de fondo oscuro de la app para evitar el destello blanco entre pantallas oscuras.
- [El fundido de 400 ms con «reducir movimiento» puede sentirse lento] → Si en la validación se nota, se usa `Movimiento.rapida` para la duración inversa; no cambia la spec.

## Migration Plan

Sin migración de datos. Revertir es quitar el `pageTransitionsTheme`, volver a `MaterialPageRoute` en los 5 `pushReplacement` y quitar las dos dependencias.
