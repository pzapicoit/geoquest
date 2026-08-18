## Context

`SplashScreen` (`app/lib/screens/splash_screen.dart`) resuelve la sesión anónima y navega siempre a `LoginScreen` (INT-108). Su presentación (`_SplashChrome`) es una `Column` estática: `Container` con el logo, wordmark con `TextStyle` por defecto, tagline y una `LinearProgressIndicator` genérica sobre fondo sólido `#0E1620`.

El mock de referencia `[App] - Splash.dc.html` (reimportado desde el proyecto Claude Design de GeoQuest para este change) ofrece dos direcciones, "1a Mapa nocturno" y "1c Arcade", con una pregunta abierta sin resolver sobre cuál adoptar. Se adopta **1a**: es la que ya coincide con el código actual (fondo `#0E1620`, wordmark "Geo" blanco + "Quest" teal, tagline en mayúsculas espaciadas) y con la estética de `EntryBackdrop`/`entry_motion.dart` construida en INT-108 para las pantallas de entrada. La dirección 1c (gradiente claro, sellos de viaje flotando) no tiene ningún precedente en el resto de la app.

INT-108 ya extrajo, a partir del mismo lenguaje de animación (`gq-pop`, `gq-rise`, `gq-halo4`, `gq-dash`), un conjunto de widgets reutilizables en `app/lib/screens/entry_motion.dart` (`PopIn`, `RiseIn`, `FloatLoop`, `HaloPulse`, `dashedPath`) y un fondo compartido en `entry_backdrop.dart` (`EntryBackdrop`), ambos ya usados en `login_screen.dart`/`username_screen.dart`. El propio proposal de INT-108 identifica este issue nombrándolo explícitamente como el fallo a no repetir.

## Goals / Non-Goals

**Goals:**
- Reproducir con fidelidad la dirección 1a del mock: fondo, logo animado con halo, wordmark/tagline con entrada escalonada, tipografía de marca (`Baloo 2`/`Outfit`).
- Reutilizar `EntryBackdrop`/`entry_motion.dart` en vez de duplicar fondo o lógica de animación ya existente.
- Mantener sin cambios toda la lógica funcional ya cubierta por la spec `app-splash` (resolución de sesión, tiempo mínimo, enrutamiento, reintento).
- Respetar `disableAnimations` (accesibilidad) para no colgar `pumpAndSettle()` en los tests, igual que ya hacen `entry_motion.dart` y `entry_backdrop.dart`.

**Non-Goals:**
- No se implementa la dirección "1c Arcade" del mock.
- No se añade el asset `login-art.jpg` (pertenece al mock de INT-108, no al de este splash — confirmado leyendo `[App] - Splash.dc.html`, que solo referencia `assets/geoquest-logo.png`).
- No se reproduce el `{{progressLabel}}`/porcentaje numérico del mock: no existe ninguna señal real de progreso que lo respalde (la resolución de sesión es una única operación asíncrona, no una serie de pasos medibles) — mostrarlo sería un dato inventado, el mismo tipo de fallo de fidelidad que motivó este issue.
- No se rediseña el copy del estado de error (`_ErrorCard`): mismo texto y misma acción de reintento, solo cambia el fondo sobre el que se apoya.

## Decisions

**1. Fondo: reutilizar `EntryBackdrop` tal cual, sin crear una tercera variante de fondo oscuro.**
El mock 1a compone su fondo con dos radial-gradients (teal arriba, azul abajo) + textura de puntos + rutas punteadas animadas — visualmente de la misma familia que el degradado + halos + `_DotGridPainter` + `_EntryRoutesPainter` que ya implementa `EntryBackdrop`. Alternativa considerada: reproducir pixel a pixel los `radial-gradient` exactos del mock (centros/radios distintos a los de `EntryBackdrop`). Se descarta: la diferencia es menor (posición de los halos, tamaño de la rejilla de puntos: 26px en el mock vs 24px en `EntryBackdrop`) y da más valor de producto tener un único fondo de "entrada" consistente entre splash, login y nombre de usuario que triplicar código de `CustomPainter` casi idéntico por un ajuste centesimal. Se documenta como trade-off consciente (ver Riesgos).

**2. Halo del logo: extender `HaloPulse` con un parámetro `delay` opcional, en vez de crear un widget nuevo solo para el splash.**
El mock 1a anima dos anillos concéntricos alrededor del logo (`gq-halo`, 2.6s ease-out infinito, el segundo con 0.9s de retardo). `HaloPulse` ya implementa exactamente esta curva (`Tween(0.95→1.45)`, opacidad `0.45→0`, 2600ms, `repeat()`) pero solo admite una instancia sin retardo de inicio. Se añade `delay = Duration.zero` a su constructor (con `Future.delayed` antes de `_controller.repeat()`, igual patrón que ya usan `PopIn`/`RiseIn`/`FloatLoop` en el mismo archivo) para poder apilar dos `HaloPulse` con delays `0` y `900ms`. Por defecto no cambia el comportamiento de los usos existentes en `login_screen.dart`/`username_screen.dart`. Alternativa descartada: escribir un `_SplashHalo` privado duplicando la lógica — no se justifica frente a una extensión de una línea sobre un widget ya compartido para este mismo propósito.

**3. Wordmark/tagline/tarjeta inferior: `RiseIn` con los delays del mock, tipografía `GoogleFonts.baloo2`/`GoogleFonts.outfit` ya establecida en el resto de la app.**
Se sustituye el `TextStyle` por defecto del wordmark y la tagline por las mismas familias que usan `login_screen.dart`/`username_screen.dart`/`camino_screen.dart` (el paquete `google_fonts` ya es una dependencia y no se añade nada nuevo). Delays tomados directamente del mock: wordmark `.15s`, tagline `.28s`, panel inferior `.4s`.

**4. Barra de progreso: indeterminada con degradado y brillo en bucle, sin porcentaje numérico.**
El mock expone `{{progressWidth}}`/`{{progressLabel}}` como props editables del canvas de diseño (con un valor de ejemplo, 72%), no como un dato real de ninguna fuente. Como no existe ninguna señal de progreso medible en `AnonymousSessionService.ensureSession()` (es un único `Future`, no una secuencia de pasos), se implementa un widget propio del splash (no se generaliza a `entry_motion.dart` por ser específico de esta pantalla) con: spinner en bucle (reutilizando el mismo giro simple que ya haría un `CircularProgressIndicator` pequeño, sin necesidad de un widget nuevo), una barra con degradado teal→azul de ancho fijo ilustrativo y un brillo (`shine`) que recorre la barra en bucle (`AnimationController.repeat()`, 1.8s, `Tween` de posición sobre un `ShaderMask`/`Transform.translate`, igual técnica que el borde atenuado de INT-105). Alternativa descartada: `LinearProgressIndicator(value: null)` — no admite degradado de color propio, y perdería la fidelidad visual del mock sin ganar nada a cambio (la honestidad sobre "no hay progreso medible" se preserva igual sin mostrar ningún número).
Etiqueta y consejo: se mantiene el texto de ejemplo del mock como copy genérico y verídico, no como dato de partida — `loadingLabel` pasa de "Cargando tu ruta" (implica una ruta ya cargada, que no existe en esta fase) a un texto neutro de esta fase (p. ej. "Preparando tu partida"); el `tip` por defecto del mock ("Acércate a menos de 30 m de cada parada para desbloquear su pregunta.") es una instrucción de juego genuinamente cierta para cualquier partida, se mantiene igual.

**5. Estado de error: mismo `_ErrorCard`, restilizado sobre `EntryBackdrop`.**
No cambia texto, iconografía ni el botón "Reintentar" — el mock no define ningún estado de error, así que se conserva el diseño actual del `_ErrorCard` ajustando solo colores para legibilidad sobre el nuevo fondo (ya son claros sobre oscuro, cambia poco).

## Risks / Trade-offs

- **[Trade-off]** El fondo reutilizado (`EntryBackdrop`) no es pixel-perfect respecto a los radial-gradients exactos de `[App] - Splash.dc.html` (ver Decisión 1). Se acepta a cambio de consistencia visual entre las tres pantallas de entrada y de no triplicar un `CustomPainter` casi idéntico.
- **[Riesgo]** Añadir `delay` a `HaloPulse` es un cambio en un widget compartido por tres pantallas (splash, login, username). → **Mitigación**: el parámetro es opcional con default `Duration.zero`, que reproduce exactamente el comportamiento actual; no se toca ningún call-site existente.
- **[Riesgo]** Las animaciones en bucle infinito (halos, brillo de la barra) podrían colgar `pumpAndSettle()` en los tests igual que ya le pasaba a `_Hero` antes de tratarlo. → **Mitigación**: se activa `disableAnimations: true` en cada test (ya presente en `splash_screen_test.dart` setUp) y todos los widgets de `entry_motion.dart`, más el nuevo widget de la barra, arrancan en su valor final cuando `reduceMotion` es verdadero.

## Open Questions

(ninguna — la única decisión pendiente que dejaba el mock, 1a vs 1c, se resuelve en este documento a favor de 1a)
