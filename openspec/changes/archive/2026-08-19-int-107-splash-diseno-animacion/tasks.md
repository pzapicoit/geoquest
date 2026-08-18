## 1. Preparación

- [x] 1.1 Añadir `assets/branding/geoquest-logo.png` sin cambios (ya existe) — confirmar que no hace falta ningún asset nuevo (`login-art.jpg` no aplica a este mock).
- [x] 1.2 Extender `HaloPulse` en `entry_motion.dart` con parámetro opcional `delay` (default `Duration.zero`), arrancando `_controller.repeat()` tras `Future.delayed(widget.delay, ...)` cuando `!_reduceMotion`. Verificar que `login_screen.dart`/`username_screen.dart` siguen compilando sin cambios.

## 2. Fondo y logo

- [x] 2.1 Envolver el `Scaffold`/`body` de `SplashScreen` con `EntryBackdrop` en vez del `Container` de color sólido actual.
- [x] 2.2 Envolver el logo (`Image.asset('assets/branding/geoquest-logo.png')`) en `PopIn`.
- [x] 2.3 Añadir dos `HaloPulse` (delay `0` y `900ms`) detrás del logo, con `color: entryTeal` y radio ajustado al tamaño del logo (118px).

## 3. Wordmark y tagline

- [x] 3.1 Sustituir el `TextStyle` del wordmark ("Geo"+"Quest") por `GoogleFonts.baloo2`, envuelto en `RiseIn(delay: 150ms)`.
- [x] 3.2 Sustituir el `TextStyle` de la tagline por `GoogleFonts.outfit`, envuelto en `RiseIn(delay: 280ms)`.

## 4. Panel inferior (carga y consejo)

- [x] 4.1 Crear el widget de barra de progreso indeterminada (spinner + etiqueta "Preparando tu partida" + barra con degradado `entryTeal`→`entryBlue` y brillo en bucle de 1.8s), sin porcentaje numérico, respetando `reduceMotion`.
- [x] 4.2 Añadir la tarjeta de consejo (icono `?` + texto del tip por defecto del mock).
- [x] 4.3 Envolver todo el panel inferior en `RiseIn(delay: 400ms)`.
- [x] 4.4 Restilizar `_ErrorCard` para el nuevo fondo oscuro (mismo texto, mismo botón "Reintentar", sin cambios de comportamiento).

## 5. Tests

- [x] 5.1 Ejecutar `flutter test app/test/splash_screen_test.dart` y confirmar que los tests existentes siguen pasando. Un test (`permanece el tiempo mínimo...`) sí requirió un ajuste mínimo: dependía implícitamente de que el `LinearProgressIndicator` indeterminado antiguo ignorase `disableAnimations` para forzar a `pumpAndSettle()` a bombear frames el tiempo suficiente; al respetar `reduceMotion` correctamente en las animaciones nuevas, se añadió un `pump()` explícito del tiempo mínimo restante antes de asentar.
- [x] 5.2 Añadir un test que compruebe que la tarjeta de consejo se muestra.
- [x] 5.3 Añadir un test que compruebe que, con `disableAnimations: true`, el splash renderiza sin colgar `pumpAndSettle()` (cubre los bucles infinitos del halo y del brillo).

## 6. Verificación visual

- [ ] 6.1 Ejecutar la app y comparar visualmente el splash contra la dirección "1a" de `[App] - Splash.dc.html` (fondo, logo, wordmark, tagline, panel inferior). **Bloqueado**: `flutter run` en el simulador iOS falla con "No Xcode build settings have been found" / no hay `Podfile` en `ios/` — problema de configuración local de Xcode preexistente (no introducido por este cambio; `git status` confirma que `ios/` no tiene cambios de este change), coherente con el chore reciente "actualiza el esquema de Xcode tras abrir el proyecto localmente". Pendiente de que el usuario lo pruebe en local/dispositivo durante el testing local.
- [x] 6.2 Confirmar con `flutter analyze`/`dart format` que no quedan advertencias en los archivos tocados.
