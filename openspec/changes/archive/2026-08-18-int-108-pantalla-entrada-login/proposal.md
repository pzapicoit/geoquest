## Why

El mock `[App] - Login.dc.html` (INT-108) rediseña la pantalla de entrada de la app con una estética oscura alineada al resto del juego, y — a diferencia del mock anterior de INT-89 — cubre **dos estados en el mismo archivo**: "primera vez" (captura de apodo) y "regreso" (bienvenida a un jugador ya reconocido). Hoy ese segundo estado no existe: cuando ya hay un apodo guardado, el splash salta directo a `CaminoScreen` sin ninguna pantalla intermedia. Además, el enlace "Iniciar sesión" que dejó `UsernameScreen` (INT-89) sin implementar desaparece en el nuevo mock, sustituido por un acceso rápido "como invitado" (primera vez) y por un hueco de "vincular cuenta" (regreso).

## What Changes

- Se sustituye la pantalla de captura de apodo (`UsernameScreen`, INT-89) por una nueva pantalla con la estética oscura del mock (fondo azul-teal con halos, rutas punteadas animadas, tarjetas `#16242F`), reutilizando la lógica existente de validación/guardado/`ProfileGateway.updateNickname`.
- Se añade una acción rápida "Entrar sin cuenta como invitado": asigna un apodo aleatorio del banco de sugerencias y completa el mismo flujo de guardado+navegación que el botón principal, sin obligar a escribir nada.
- **BREAKING (comportamiento de usuario)**: se retira el enlace "¿Ya tienes una cuenta? Iniciar sesión" (`onTap` vacío, requisito de `app-username`) — no existe en el nuevo mock. Se sustituye conceptualmente por el hueco "Vincular una cuenta para no perder el progreso" en el nuevo estado de regreso (también sin acción, mismo patrón de "hueco preparado para el futuro").
- Se crea el nuevo estado "regreso": cuando ya hay apodo guardado, el splash deja de saltar directo a `CaminoScreen` y muestra esta pantalla con saludo personalizado, avatar con inicial, un resumen de progreso y dos acciones: "Seguir jugando" (→ `CaminoScreen`) y "Cambiar de jugador" (limpia el apodo local y vuelve al estado "primera vez" para introducir uno nuevo).
- El resumen de progreso del estado "regreso" se limita a datos reales ya disponibles hoy vía `CaminoGateway` (puntos totales, niveles superados, estrellas acumuladas, nombre/temática del siguiente nivel y fracción de estrellas hacia su desbloqueo). Se **descartan** del mock "Récord" global y "Racha de días" y la línea "Última partida: hace X días": no existe ninguna fuente de datos para ellos hoy (confirmado por búsqueda en `app/lib/services/` y en las specs `game-data-model`, `level-progression`, `player-path`) y construirla es trabajo de backend fuera del alcance de un rediseño visual. Quedan como candidatos a una futura tarea si se decide instrumentarlos.
- Los campos de contraseña y accesos sociales (Google/Apple) del mock están apagados/decorativos por diseño (`showPassword: false`, `showSocial: true` pero marcados "Próximamente", sin `onClick`): se reproducen visualmente los accesos sociales como placeholders no interactivos y **no** se implementa contraseña (no hay backend de contraseña; coincide con el flujo 100% de apodo + sesión anónima ya vigente).
- Todas las animaciones del mock (pop del logo, fade-rise escalonado de los bloques de texto, insignias flotando en bucle, halo pulsante alrededor de logo/avatar, ruta de fondo punteada en movimiento) se implementan con fidelidad usando el mismo patrón de `AnimationController`/`CurvedAnimation`/`CustomPainter` con respeto a `disableAnimations` (accesibilidad) que ya usa `_Hero` en `username_screen.dart` — no se repite el fallo de INT-107 (implementación estática que ignoró las animaciones del mock).

## Capabilities

### New Capabilities
- `app-login`: pantalla de bienvenida para el jugador que ya tiene apodo guardado ("regreso") — saludo personalizado, resumen de progreso con datos reales, continuar partida o cambiar de jugador, hueco de vinculación de cuenta.

### Modified Capabilities
- `app-username`: se rediseña visualmente la pantalla de captura de apodo según el nuevo mock (tema oscuro, animaciones renovadas); se retira el requisito del enlace "Iniciar sesión" sin implementar; se añade el requisito de acceso rápido "entrar como invitado".
- `app-splash`: cambia el requisito de enrutamiento cuando ya existe un apodo guardado — en vez de navegar directo a `CaminoScreen`, navega a la nueva pantalla de `app-login` (estado "regreso").

## Impact

- **Código**: `app/lib/screens/username_screen.dart` (rediseño visual + nueva acción invitado), nuevo `app/lib/screens/login_screen.dart` o similar (estado "regreso"), `app/lib/screens/splash_screen.dart` (cambia el destino de `_navigateNext()` cuando `username != null`), `app/lib/services/camino_gateway.dart` (posible extensión de lectura para derivar niveles superados/estrellas totales si no viene ya agregado).
- **Specs**: nueva `openspec/specs/app-login/spec.md`; deltas sobre `openspec/specs/app-username/spec.md` y `openspec/specs/app-splash/spec.md`.
- **Sin cambios de backend/esquema**: todo el resumen de progreso usa datos que `camino_jugador` ya expone; no se toca Supabase.
- **Tests**: se adaptan/renombran los tests de `username_screen` y se añaden tests para el nuevo estado "regreso" y para el cambio de ruta del splash.
