## Context

El mock `[App] - Login.dc.html` (proyecto Claude Design `d83d4c61-3a9e-4fff-b1c4-d2a19fd03ef5`) define dos variantes en el mismo archivo:

- **12a "Entra a jugar"** (primera vez): fondo oscuro azul-teal con halos y rutas punteadas animadas, logo con "pop", campo de apodo con botón de dado, CTA "Empezar a jugar" (deshabilitado si vacío), enlace "Entrar sin cuenta como invitado", campo de contraseña oculto por flag (`showPassword: false`) y bloque de accesos sociales decorativo activado por flag (`showSocial: true`, marcado "Próximamente", sin `onClick`).
- **12b "Regreso"**: mismo lenguaje visual, saludo `¡Hola, {savedName}!`, avatar con inicial y halo pulsante, tarjeta de estadísticas (Récord/Niveles/Racha — datos de ejemplo del mock, no reales), barra de progreso hacia el siguiente nivel (en puntos en el mock), botones "Seguir jugando" / "Cambiar de jugador", y enlace "Vincular una cuenta para no perder el progreso".

Hoy `UsernameScreen` (INT-89) solo cubre el caso "primera vez", con animaciones ya implementadas con buen nivel de detalle en el widget privado `_Hero` (`app/lib/screens/username_screen.dart:309-535`): `AnimationController` por elemento, curvas (`easeOut`, `easeInOut`), `TweenSequence` para el "pop" con overshoot, `CustomPainter` para las rutas punteadas de fondo, y respeto a `disableAnimations` (accesibilidad) tanto para no animar como para no colgar los widget tests. El caso "regreso" no existe: el splash salta directo a `CaminoScreen` (`splash_screen.dart:81-90`).

La investigación de datos confirmó que **no existe** ninguna fuente para "récord global", "racha de días" ni "última partida hace X días" (búsqueda en `app/lib/services/` y en las specs `game-data-model`, `level-progression`, `player-path`). Sí existen, vía `CaminoGateway`/`camino_jugador`: `puntosTotales` (suma histórica de `respuestas_desafio.puntos`), `entradas: List<ParadaCamino>` con `superado` (para contar niveles superados) y, en la parada actual (`esActual`), `nivelNombre`/`tematicaNombre`/`estrellasRequeridas`/`estrellasAcumuladasUsuario`.

## Goals / Non-Goals

**Goals:**
- Reproducir con fidelidad visual y de animación ambos estados del mock (12a y 12b) sobre una única pantalla que decide su estado según si hay apodo guardado.
- Reutilizar sin duplicar la lógica de negocio ya validada de `UsernameScreen` (validación, dado de sugerencias, guardado local+remoto) para el estado "primera vez".
- Construir el resumen de progreso del estado "regreso" exclusivamente con datos reales ya disponibles hoy.
- Mantener el patrón de accesibilidad (`disableAnimations`) y de testabilidad (controllers desactivables) que ya usa `_Hero`.

**Non-Goals:**
- No se implementa contraseña ni login social real (los flags correspondientes se mantienen apagados/decorativos, igual que en el mock).
- No se construye ninguna fuente de datos nueva para "récord global" ni "racha de días" (requeriría esquema/backend nuevo, fuera de alcance de un rediseño visual).
- No se toca el `AccountLinkingService` existente: el enlace "Vincular una cuenta" queda como hueco visual sin acción, igual que el enlace que sustituye.

## Decisions

**1. Una sola pantalla con dos estados, no dos rutas separadas.**
Se crea `app/lib/screens/login_screen.dart` con un widget que recibe (o resuelve internamente) si hay apodo guardado, y renderiza el estado 12a o 12b. Alternativa considerada: mantener `UsernameScreen` intacta y crear una pantalla nueva solo para el regreso. Se descarta porque el mock modela explícitamente un único componente con dos variantes (misma paleta, mismo layout de status bar/notch, mismas animaciones base), y porque ambos estados comparten la transición "Cambiar de jugador → estado primera vez" dentro de la misma pantalla sin una navegación de ida y vuelta innecesaria. `UsernameScreen` se reescribe visualmente pero conserva su lógica pública (validación, `usernameStorage`, `profileGateway`) para minimizar riesgo de regresión.

**2. El splash siempre navega a `LoginScreen`; el estado se decide dentro de la pantalla, no en el splash.**
`SplashScreen._navigateNext()` (`splash_screen.dart:81-90`) deja de bifurcar entre `UsernameScreen`/`CaminoScreen` y pasa a construir siempre `LoginScreen()`, que internamente lee `UsernameStorage` para decidir su estado inicial. Alternativa: que el splash decida el estado y lo pase por constructor. Se descarta porque "Cambiar de jugador" necesita volver a mostrar el estado "primera vez" sin pasar de nuevo por el splash, así que la pantalla ya necesita poder recalcular su propio estado — mantener esa decisión en un solo sitio evita duplicar la regla "hay apodo ⇒ regreso".

**3. Resumen de progreso: solo 3 métricas reales, con reetiquetado semántico.**
Se sustituyen las 3 tarjetas del mock (Récord/Niveles/Racha) por: **Puntos totales** (`CaminoJugador.puntosTotales`), **Niveles superados** (`entradas.where((e) => e.superado).length`) y **Estrellas** (`entradas.fold(0, (t, e) => t + e.estrellasObtenidas)` — el campo existe directamente por parada en `ParadaCamino.estrellasObtenidas`, confirmado durante la implementación; no hizo falta el fallback previsto). La barra de progreso "Siguiente: Nivel X" se re-etiqueta de puntos a estrellas: `estrellasAcumuladasUsuario / estrellasRequeridas`, pero **no** de la parada `esActual` (esa ya está desbloqueada — su fracción saldría por encima del 100%, sin sentido como "progreso hacia desbloquear") sino de la **primera parada con `desbloqueado == false`** recorriendo `entradas` en orden; si no hay ninguna (todos los niveles desbloqueados), se muestra un texto de "todos los niveles desbloqueados" en vez de la barra. Se elimina la línea "Última partida: hace X días" del mock por no existir esa fecha en ningún servicio actual. Alternativa considerada: mostrar valores de ejemplo/placeholder tal cual el mock para no romper el layout — se descarta explícitamente porque mostrar datos inventados como si fueran reales del jugador es el mismo tipo de fallo de fidelidad que INT-107 (ahí con animaciones, aquí con datos), solo que además engañoso de cara al usuario.

**4. Animaciones: mismo patrón que `_Hero`, adaptado a los nuevos keyframes CSS del mock.**
Se implementa un widget de animación análogo a `_Hero` (o se generaliza/extrae si el layout final del "regreso" lo permite) que reproduce, con `AnimationController` + `CurvedAnimation` + respeto a `disableAnimations`:
- `gq-pop` (logo/avatar): `TweenSequence` de escala `0.84→1.04→1.0` sobre `Curves.easeOut`, 800ms — mismo patrón que `_logoScale` actual.
- `gq-rise` (bloques de texto/botones): `Tween(14→0)` + fade sobre `Curves.easeOut`, con los delays escalonados del mock (`.1s`, `.16s`, `.22s`, `.3s`, `.38s`, `.44s`, `.5s` en 12a; `.1s`, `.18s`, `.26s`, `.34s`, `.42s` en 12b) vía `Future.delayed` antes de cada `forward()`, igual que ya hace `_wordmarkController`.
- `gq-float` (insignias "13 niveles"/"Récord 1.240" del estado 12a — nota: estas insignias del header sí son estáticas informativas del juego, no datos de "récord del jugador", se mantienen): `Tween(0→-10/-11)` sobre `Curves.easeInOut` con `repeat(reverse: true)`, duraciones y delay distintos por insignia, igual que `_badgeFloat1`/`_badgeFloat2`.
- `gq-halo4` (anillo pulsante alrededor del logo en 12a y del avatar en 12b): controller en bucle `repeat()` de 2.6s con `scale(.95→1.45)` + `opacity(.45→0)` sobre `Curves.easeOut`.
- `gq-dash` (ruta punteada de fondo): se reutiliza/adapta el `CustomPainter` `_RoutesPainter` ya existente (`username_screen.dart:540-615`), con el controller en bucle simple (`repeat()`, sin reverse) a **12s**, la duración real de `animation:gq-dash 12s linear infinite` en el mock (no los 10s de `_routeController` de la pantalla anterior, que era una animación distinta).
Todos los controllers de una sola pasada arrancan en `value: 1` si `disableAnimations` está activo, replicando `_reduceMotion` de `_Hero`.

**5. Las insignias de cabecera ("13 niveles", "Récord 1.240") del estado 12a son contenido estático del juego, no datos del jugador.**
A diferencia de las estadísticas del estado "regreso" (que sí representan progreso del jugador y por tanto exigen datos reales), estas dos insignias describen el juego en general (número total de niveles disponibles, récord global histórico de cualquier jugador como gancho de marketing) — se mantienen como texto estático de producto, igual que en cualquier pantalla de bienvenida antes de tener sesión. Si más adelante se quiere que "Récord 1.240" sea un dato real (récord global entre todos los jugadores), sería una fuente de datos nueva y una decisión de producto explícita, fuera de este cambio.

## Risks / Trade-offs

- **[Riesgo, resuelto]** El campo exacto de "estrellas obtenidas por parada" en `ParadaCamino` no se confirmó con certeza en la investigación previa. → Confirmado durante la implementación: `ParadaCamino.estrellasObtenidas` existe por parada; no hizo falta el fallback previsto.
- **[Riesgo]** Reescribir `UsernameScreen` visualmente sin tocar su lógica pública podría filtrar comportamiento sutil (p. ej. mensajes de error) si el refactor no es cuidadoso. → **Mitigación**: mantener los tests existentes de `username_screen_test.dart` como red de seguridad, adaptando solo los selectores visuales que cambien, y añadir tests nuevos para el estado "regreso" y para "Cambiar de jugador".
- **[Trade-off]** Al quitar "Récord"/"Racha"/"Última partida" del estado de regreso, la pantalla implementada no será visualmente idéntica al mock en esa tarjeta. Se acepta como trade-off consciente y documentado (ver Decisión 3) en vez de mostrar datos falsos.

## Open Questions

- **Resuelta**: el campo "estrellas obtenidas" por parada existe ya en `ParadaCamino.estrellasObtenidas` (confirmado leyendo `camino_gateway.dart` durante `/execute`).
- **Resuelta**: "Cambiar de jugador" limpia solo el almacenamiento local (`UsernameStorage.clear()`); no toca el perfil remoto (se sobrescribirá cuando se guarde el nuevo apodo). Implementado así en `LoginScreen._onSwitchPlayer`.
