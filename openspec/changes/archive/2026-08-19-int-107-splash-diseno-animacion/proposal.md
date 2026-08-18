## Why

`app/lib/screens/splash_screen.dart` (INT-88) es una `Column` totalmente estática: logo en un `Container` fijo, wordmark, tagline y una `LinearProgressIndicator` genérica. No usa ningún `AnimationController` ni widget `Animated*`, y no reproduce el fondo ni la tipografía de marca (`Baloo 2`/`Outfit`) que ya sí llevan las pantallas de entrada rediseñadas en INT-108. El propio proposal de INT-108 señala este hueco explícitamente ("no se repite el fallo de INT-107 de ignorar las animaciones del mock") y, de paso, dejó ya construidas en `entry_motion.dart`/`entry_backdrop.dart` las piezas de animación y fondo reutilizables que el splash necesita.

Se reimportó el mock `[App] - Splash.dc.html` (proyecto Claude Design de GeoQuest) para verificar el alcance exacto: **corrige una imprecisión de la descripción original del issue** — el mock no importa ningún `assets/login-art.jpg` (ese asset pertenece al mock `[App] - Login.dc.html` de INT-108); solo usa `assets/geoquest-logo.png`. `support.js` tampoco lleva lógica de animación propia: es el runtime genérico de Claude Design, y todas las animaciones del mock son keyframes CSS puros (`gq-pop`, `gq-halo`, `gq-dash`, `gq-draw`, `gq-rise`, `gq-shine`, `gq-spin`).

El mock deja además dos direcciones sin decidir ("1a Mapa nocturno" y "1c Arcade"), con una pregunta abierta sin responder ("¿seguimos con 1a o con 1c?"). La dirección **1a** es la que ya está adoptada de facto: mismo fondo oscuro (`#0E1620`), mismo tratamiento de wordmark ("Geo" blanco + "Quest" teal) y misma tagline en mayúsculas que ya existen en el código actual, y es coherente con la estética de `EntryBackdrop` (INT-108) usada en el resto de pantallas de entrada. La dirección 1c (gradiente claro, sellos de viaje flotando) no tiene ningún precedente en el resto de la app y se descarta.

## What Changes

- Se sustituye el fondo plano (`Scaffold` con `backgroundColor` sólido) por `EntryBackdrop` (INT-108): degradado azul-teal, halos radiales, textura de puntos y ruta punteada animada — mismo lenguaje visual que login/nombre de usuario, en vez de una tercera implementación de fondo distinta.
- El logo pasa a animarse con `PopIn` (escala con overshoot + fade, ya extraído en `entry_motion.dart`) y un anillo pulsante doble alrededor (`gq-halo`), reutilizando `HaloPulse` — se le añade un parámetro opcional `delay` (por defecto `Duration.zero`, sin tocar los usos existentes en login/nombre de usuario) para poder escalonar el segundo anillo como en el mock.
- El wordmark y la tagline pasan a animarse con `RiseIn` (fade + subida de 14px) con los mismos retardos escalonados del mock, y adoptan la tipografía de marca ya establecida en el resto de la app (`GoogleFonts.baloo2` para el wordmark, `GoogleFonts.outfit` para la tagline), en vez del `TextStyle` por defecto actual.
- El indicador de carga inferior se rediseña como una fila con spinner + etiqueta y una barra de progreso con degradado teal→azul y un brillo (`shine`) en bucle, también con entrada `RiseIn`. **No** se reproduce el `{{progressLabel}}`/porcentaje numérico del mock: la resolución de sesión es una única operación asíncrona sin sub-pasos medibles, y mostrar un porcentaje inventado repetiría el mismo problema de fidelidad que motivó este issue (datos/estado no reales), solo que aquí con una cifra en vez de con una animación — la barra queda indeterminada, solo comunica "hay actividad".
- Se añade una tarjeta de consejo (icono `?` + texto) con un tip de juego genérico y verídico (reutilizando el texto por defecto del propio mock, que no depende de ninguna partida concreta).
- El estado de error (`_ErrorCard`, ya cubierto por la spec y sin cambios de comportamiento) se reestiliza para encajar sobre el nuevo fondo oscuro, sin alterar su lógica de reintento.
- Todas las animaciones nuevas respetan `disableAnimations` (accesibilidad), siguiendo el mismo patrón ya usado en `entry_motion.dart`, para no romper `pumpAndSettle()` en los tests.

## Capabilities

### New Capabilities
(ninguna)

### Modified Capabilities
- `app-splash`: se añade el requisito de que la primera pantalla reproduzca el diseño visual y las animaciones de entrada de su propio mock de referencia (branding, fondo, tipografía y movimiento), sin alterar ninguno de los requisitos funcionales existentes (resolución de sesión, tiempo mínimo, enrutamiento, estado de error).

## Impact

- **Código**: `app/lib/screens/splash_screen.dart` (reescritura visual completa de `_SplashChrome`/`_ErrorCard`), `app/lib/screens/entry_motion.dart` (se añade parámetro opcional `delay` a `HaloPulse`), sin cambios en `entry_backdrop.dart` (se reutiliza tal cual).
- **Specs**: delta sobre `openspec/specs/app-splash/spec.md` (nuevo requisito de fidelidad visual/animación; ningún requisito existente cambia).
- **Sin cambios de backend**: no toca `AnonymousSessionService`, `CaminoGateway` ni ningún servicio — es un cambio puramente de presentación.
- **Tests**: `app/test/splash_screen_test.dart` sigue validando comportamiento (sesión, enrutamiento, error, tiempo mínimo) tal cual, con `disableAnimations: true` ya activo; se añaden únicamente los tests nuevos que haga falta para cubrir el estado visual (p. ej. presencia de la tarjeta de consejo).
