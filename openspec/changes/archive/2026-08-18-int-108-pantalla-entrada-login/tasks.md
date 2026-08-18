## 1. Investigación previa (bloqueante para el resto)

- [x] 1.1 Confirmar en `app/lib/services/camino_gateway.dart` el campo exacto para estrellas obtenidas por parada (agregable en `ParadaCamino`) o, si no existe, confirmar el fallback (`estrellasAcumuladasUsuario` de la parada `esActual`) que se usará para la tarjeta "Estrellas". → `ParadaCamino.estrellasObtenidas` existe por parada; se usa `entradas.fold(0, (t, e) => t + e.estrellasObtenidas)`.
- [x] 1.2 Confirmar el nombre exacto del campo `superado` en `ParadaCamino` para el conteo de "Niveles superados". → confirmado (`ParadaCamino.superado`).

## 2. Widget de animaciones compartido

- [x] 2.1 Extraer/generalizar el patrón de animación de `_Hero` en widgets reutilizables (`app/lib/screens/entry_motion.dart`: `PopIn`, `RiseIn`, `FloatLoop`, `HaloPulse`) y fondo compartido (`entry_backdrop.dart`: `EntryBackdrop`, rutas punteadas animadas, halos, textura de puntos, círculo punteado).
- [x] 2.2 Mantener el respeto a `disableAnimations` (`reduceMotion` en `entry_motion.dart`), para ambos estados.

## 3. Estado "primera vez" (rediseño de `UsernameScreen`)

- [x] 3.1 Rediseñar visualmente `app/lib/screens/username_screen.dart` según el mock 12a.
- [x] 3.2 Retirar el enlace "¿Ya tienes una cuenta? Iniciar sesión".
- [x] 3.3 Añadir la acción "Entrar sin cuenta como invitado" (`Key('guest-link')`), reutilizando `_onStart()`.
- [x] 3.4 Añadir el bloque decorativo de accesos sociales (`SocialPlaceholderRow`, sin `onClick`). Contraseña no implementada.
- [x] 3.5 Aplicar `PopIn`/`RiseIn`/`FloatLoop`/`HaloPulse`/`EntryBackdrop` a este estado.
- [x] 3.6 Adaptado `app/test/username_screen_test.dart`: eliminado el test del enlace retirado y el de la chip de sugerencia (esa UI no existe en el mock nuevo, ya cubierta por el botón de dado); añadido el test de "invitado".

## 4. Estado "regreso" (nueva pantalla de bienvenida)

- [x] 4.1 Creado `app/lib/screens/login_screen.dart` (`LoginScreen`) que decide entre estados leyendo `UsernameStorage.read()`.
- [x] 4.2 Implementado el layout del estado "regreso" (saludo, avatar con inicial y halo).
- [x] 4.3 Implementada la tarjeta de progreso con datos reales (`_ProgressCard`): puntos totales, niveles superados, estrellas, y barra hacia el siguiente nivel bloqueado (`_NextLevelProgress`, en estrellas). Nota de implementación: la barra usa el **primer nivel con `desbloqueado == false`** (no la parada `esActual`, que ya está desbloqueada) — es la lectura correcta de "progreso hacia desbloquear el siguiente nivel". Sin "récord global", "racha" ni "última partida".
- [x] 4.4 "Seguir jugando" → `CaminoScreen` (`Key('continue-button')`).
- [x] 4.5 "Cambiar de jugador" → borra `UsernameStorage` y vuelve al estado "primera vez" (`Key('switch-player-button')`).
- [x] 4.6 Enlace "Vincular una cuenta..." sin acción (`Key('link-account')`, `GhostLink`).
- [x] 4.7 Animaciones aplicadas al estado "regreso".
- [x] 4.8 Tests nuevos en `app/test/login_screen_test.dart` (saludo, progreso real, continuar, cambiar de jugador, enlace sin efecto).

## 5. Enrutamiento desde el splash

- [x] 5.1 `SplashScreen._navigateNext()` navega siempre a `LoginScreen`.
- [x] 5.2 `app/test/splash_screen_test.dart` actualizado (bienvenida de regreso en vez de salto directo a `CaminoScreen`).

## 6. Verificación final

- [x] 6.1 `flutter test` — 236/236 tests, sin regresiones. `flutter analyze` sin issues. `dart format` aplicado.
- [ ] 6.2 Pendiente: prueba manual en dispositivo/simulador (primera vez con/sin invitado, regreso con seguir/cambiar) — a validar en testing local.

## 7. Ajustes de la revisión adversarial (APROBADO, con hallazgos menores)

- [x] 7.1 `design.md` decía 10s para la duración de `gq-dash`; el mock real usa 12s (`animation:gq-dash 12s linear infinite`) y el código ya implementaba 12s — se corrigió el texto de `design.md`, no el código.
- [x] 7.2 La tarjeta de progreso se quedaba en el spinner de carga para siempre si `CaminoGateway.fetchCamino()` fallaba. Se añadió `_ProgressCardError` con reintento (`Key('retry-progress')`) y test correspondiente en `login_screen_test.dart`.
