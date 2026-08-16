## Why

La app móvil (Flutter) todavía arranca en la pantalla por defecto de Flutter: no tiene splash con marca, no gestiona la sesión anónima al abrir, y usa el icono de launcher genérico de Flutter en vez del icono de GeoQuest. INT-88 cubre la primera pantalla que ve el jugador: debe crear o recuperar su sesión anónima en segundo plano y encaminarlo (nombre de usuario o mapa de temáticas) sin fricción, con la marca de GeoQuest visible desde el primer instante — incluido el icono de la app en el propio launcher del dispositivo.

## What Changes

- Nueva pantalla de Splash como ruta inicial de la app, mostrando el logo/branding de GeoQuest mientras se resuelve la sesión.
- Integración con `anonymous_session_service` / `auth_gateway` existentes: si no hay sesión guardada, crea una sesión anónima (Supabase Auth); si ya existe, la recupera sin crear una nueva.
- Enrutamiento post-splash: sin nombre de usuario guardado → pantalla "Nombre de usuario" (placeholder hasta INT-89); con nombre de usuario → Mapa de temáticas (placeholder hasta que exista esa pantalla).
- Tiempo mínimo de permanencia en el splash para evitar parpadeo aunque la sesión resuelva al instante.
- Icono de la app (launcher/home screen) en iOS y Android sustituyendo el icono por defecto de Flutter, acorde al branding de GeoQuest.

## Capabilities

### New Capabilities
- `app-splash`: pantalla de carga inicial de la app — branding, resolución de sesión anónima (crear/recuperar) y enrutamiento a la siguiente pantalla según si el jugador ya tiene nombre de usuario, incluyendo el icono de la app en el launcher del dispositivo.

### Modified Capabilities
_(ninguna — no hay capability existente de app móvil cuyo comportamiento cambie)_

## Impact

- **Código afectado**: `app/lib/main.dart` (ruta inicial), nueva pantalla en `app/lib/screens/` (o equivalente), uso de `app/lib/services/anonymous_session_service.dart` y `app/lib/services/auth_gateway.dart`.
- **Assets**: icono de app en `app/android/app/src/main/res/mipmap-*` y `app/ios/Runner/Assets.xcassets/AppIcon.appiconset/` (y `app/web/icons/` si aplica), generado a partir del logo de GeoQuest (`assets/geoquest-logo.png` del diseño en Claude Design).
- **Dependencias**: probable paquete `flutter_launcher_icons` (dev dependency) para generar el set de iconos nativos a partir de un único artwork.
- **Pantallas dependientes**: "Nombre de usuario" (INT-89) y "Mapa de temáticas" aún no existen — el splash navegará a rutas placeholder hasta que se implementen, sin bloquear esta entrega.
