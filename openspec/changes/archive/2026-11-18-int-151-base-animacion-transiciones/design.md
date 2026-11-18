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

**D3. La app nativa de iOS conserva Cupertino en las rutas apiladas; la web no.**
Un `PageTransitionsBuilder` que no sea el de Cupertino pierde el gesto de deslizar desde el borde para volver, que en iOS es un hábito muy arraigado (ranking y comodines). En la app nativa de iOS el tema usa `TransicionNativaDeIOS`, que delega en `CupertinoPageTransitionsBuilder` (con su duración de 500 ms y sus curvas) pero cambia a un fundido con «reducir movimiento», porque Cupertino no lo consulta.
En web, Flutter deduce la plataforma del navegador, y un iPhone sale como `TargetPlatform.iOS`. Allí el gesto de volver es el del navegador, así que `temaDeTransiciones(web: kIsWeb)` usa la transición del juego en todas las plataformas.
Las rutas de relevo (`PageRouteBuilder`) no llevan el gesto de Cupertino. Se pierde en dos sitios que antes lo tenían en iOS: el resumen y el nivel reintentado, que quedan sobre el camino. Se acepta: el resumen vuelve al camino con sus botones, y en el nivel deslizar sacaba al jugador de la partida sin confirmar «Salir».

**D4. Base de movimiento en `app/lib/motion/movimiento.dart`.**
- `abstract final class Movimiento` con duraciones (`rapida` 150 ms, `media` 300 ms, `pantalla` 400 ms, `entrada` 700 ms) y curvas (`estandar` = `Curves.easeInOutCubic`, `llegada` = `Curves.easeOutCubic`, `salida` = `Curves.easeInCubic`, `rebote` = `Curves.easeOutBack`).
- `bool movimientoReducido(BuildContext context)` lee `MediaQuery.maybeDisableAnimationsOf(context) ?? false`. Va por `MediaQuery` y no por `platformDispatcher` porque así los tests lo pueden forzar con `MediaQuery(data: …disableAnimations: true)`.
- `entry_motion.dart` no se toca: su getter `reduceMotion` se lee en `initState`, donde no hay `MediaQuery`. Migrarlo es trabajo de INT-152/153 cuando toquen esas piezas; la spec obliga a usar `movimientoReducido` en código nuevo o modificado. La lectura directa de `MediaQuery` en `nivel_juego_screen.dart` (marco de tiempo crítico) sí pasa a `movimientoReducido` en este cambio.

**D5. «Reducir movimiento» se resuelve dentro del `transitionsBuilder`.**
Tanto `TransicionDeProfundidad` como `rutaDeRelevo` consultan `movimientoReducido(context)` al construir la transición y, si está activo, devuelven solo un `FadeTransition` con la misma animación. La duración de la ruta queda fija al crearla (`Movimiento.pantalla`); con reducir movimiento el efecto es un fundido de 400 ms. Es aceptable porque el criterio pide un fundido, no un corte.

**D6. Valores por defecto de `flutter_animate` en `main.dart`.**
`Animate.defaultDuration = Movimiento.media` y `Animate.defaultCurve = Movimiento.llegada` antes de `runApp`. Así INT-152/153 heredan el lenguaje común con solo escribir `.animate().fadeIn()`. La dependencia se añade aquí para que la base quede completa en un solo cambio.

## Risks / Trade-offs

- [`animations` 3.0.0 arrastra `material_ui`/`cupertino_ui` como dependencias transitivas] → Se verifica que `flutter analyze` y el build web pasan; si hubiera conflicto, se fija `animations` 2.x, que ofrece la misma API.
- [Los tests que esperaban la transición por defecto pueden necesitar más `pump`] → Todas las transiciones son finitas (400 ms) y `pumpAndSettle()` las espera. Se ejecuta la suite completa.
- [`SharedAxisTransition` escalada pinta un fondo de relleno (`fillColor`)] → Se pasa el color de fondo oscuro de la app para evitar el destello blanco entre pantallas oscuras.
- [El fundido de 400 ms con «reducir movimiento» puede sentirse lento] → Si en la validación se nota, se usa `Movimiento.rapida` para la duración inversa; no cambia la spec.

- [Si «reducir movimiento» cambia con una ruta abierta, el `transitionsBuilder` cambia de tipo de widget] → No se pierde estado: `ModalRoute` cuelga la página de una `GlobalKey` (`_subtreeKey`), así que el subárbol se traslada en vez de rehacerse.
- [`fondoDeTransicion` (#0A1622) no es exactamente el fondo de todas las pantallas (`_ink` #0E1620, degradado del camino)] → Solo se ve en los bordes durante la escala; la diferencia es mínima y evita el destello blanco, que era el riesgo real.
- [Android pierde `PredictiveBackPageTransitionsBuilder`] → Hoy no tiene efecto: el manifiesto no activa `enableOnBackInvokedCallback`. Si se activa en el futuro, habrá que dar a `TransicionDeProfundidad` soporte de vuelta predictiva.

## Migration Plan

Sin migración de datos. Revertir es quitar el `pageTransitionsTheme`, volver a `MaterialPageRoute` en los 5 `pushReplacement` y quitar las dos dependencias.
