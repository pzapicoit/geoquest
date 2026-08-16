## Context

`app/lib/main.dart` ya tiene un `SessionGate` (INT-75) que resuelve la sesión anónima vía `AnonymousSessionService` + `AuthGateway` inyectable, y hoy navega a `ConnectivityScreen` (pantalla provisional de diagnóstico, marcada explícitamente en el código como "la sustituye el splash real en INT-88"). No existe todavía ninguna pantalla de "Nombre de usuario" (INT-89) ni "Mapa de temáticas" — ambas están fuera del alcance de este cambio. El icono de la app en Android/iOS es hoy el placeholder por defecto de Flutter.

## Goals / Non-Goals

**Goals:**
- Sustituir `ConnectivityScreen` como destino de `SessionGate` por un splash con branding real y tiempo mínimo de permanencia.
- Añadir la decisión de enrutamiento post-sesión según exista o no un nombre de usuario guardado localmente.
- Sustituir el icono de launcher/home screen por el de GeoQuest en Android e iOS.

**Non-Goals:**
- Implementar la pantalla real "Nombre de usuario" (INT-89) ni el Mapa de temáticas — se navega a rutas placeholder mínimas hasta que existan esas historias.
- Cambiar la lógica de creación/recuperación de sesión anónima (`AnonymousSessionService`), que ya cumple lo pedido y se reutiliza tal cual.
- Vincular cuenta (`linkIdentity`) — fuera de alcance de splash.

## Decisions

- **Reutilizar `SessionGate` tal cual, solo cambiar su destino final.** `AnonymousSessionService`/`AuthGateway` ya cubren crear-o-recuperar sesión y el estado de error con reintento (`_Status`); no hay motivo para reescribirlos. El nuevo `SplashScreen` se limita a la presentación (logo) y al tiempo mínimo; el enrutamiento por nombre de usuario se resuelve en un segundo paso tras `AnonymousSessionReady`.
- **Nuevo `UsernameStorage` con `shared_preferences`, mismo patrón que `DeviceIdService`.** Sigue el patrón ya establecido en el repo (clase con `_prefsKey` y método async), en vez de introducir una dependencia nueva de almacenamiento.
- **Tiempo mínimo con `Future.wait([sessionFuture, Future.delayed(minDuration)])`.** Evita temporizadores manuales o `Timer` separados; reutiliza el mismo `FutureBuilder` que ya usa `SessionGate`.
- **Rutas placeholder para "Nombre de usuario" y "Mapa de temáticas".** Un `Scaffold` mínimo con el nombre de la pantalla, para no bloquear esta entrega ni inventar UI de historias que no se han diseñado todavía; se sustituyen cuando se implementen INT-89 y el Mapa de temáticas.
- **Icono de app con `flutter_launcher_icons`.** En vez de sustituir manualmente cada resolución en `android/app/src/main/res/mipmap-*` e `ios/Runner/Assets.xcassets/AppIcon.appiconset/`, se añade como dev dependency, se configura en `pubspec.yaml` apuntando a un único artwork (`assets/icon/icon.png`, exportado del logo de GeoQuest) y se genera el set completo con `dart run flutter_launcher_icons`. Reduce el riesgo de que falte alguna resolución.

## Risks / Trade-offs

- **No existe todavía diseño específico para el "adaptive icon" de Android (foreground/background separados)** → Mitigación: usar el mismo artwork como icono simple si el diseño no aporta capas separadas; queda como ajuste menor si el diseño de Claude Design las incluye.
- **Las rutas placeholder de "Nombre de usuario" y "Mapa de temáticas" podrían dar falsa sensación de completitud** → Mitigación: nombrarlas explícitamente como placeholder en el código y no marcarlas como implementación de INT-89.
- **Cambiar el destino de `SessionGate` podría romper `session_gate_test.dart`** → Mitigación: revisar y actualizar ese test para que aserte sobre el nuevo destino (splash/enrutamiento) en vez de `ConnectivityScreen`.
