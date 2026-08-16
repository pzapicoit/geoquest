## 1. Icono de la app

- [x] 1.1 Exportar/obtener el artwork del icono desde el diseño de Claude Design (logo de GeoQuest) y guardarlo en `app/assets/icon/icon.png`
- [x] 1.2 Añadir `flutter_launcher_icons` como dev dependency y configurarlo en `pubspec.yaml` apuntando a ese artwork (Android + iOS)
- [x] 1.3 Generar el set de iconos con `dart run flutter_launcher_icons` y verificar que sustituye el icono por defecto de Flutter en `android/app/src/main/res/mipmap-*` e `ios/Runner/Assets.xcassets/AppIcon.appiconset/`

## 2. Almacenamiento de nombre de usuario

- [x] 2.1 Crear `UsernameStorage` (patrón `DeviceIdService`, `shared_preferences`) con métodos para leer y guardar el nombre de usuario local

## 3. Pantalla de Splash

- [x] 3.1 Crear `SplashScreen` con el logo/branding de GeoQuest, usando el diseño `[App] - Splash.dc.html` importado desde Claude Design
- [x] 3.2 Envolver la resolución de sesión de `SessionGate` con un tiempo mínimo de permanencia (`Future.wait` con `Future.delayed`) antes de navegar
- [x] 3.3 Tras `AnonymousSessionReady`, consultar `UsernameStorage` y navegar a la pantalla "Nombre de usuario" (placeholder) si no hay nombre guardado, o al Mapa de temáticas (placeholder) si ya lo hay
- [x] 3.4 Crear las rutas placeholder mínimas de "Nombre de usuario" y "Mapa de temáticas" (Scaffold simple), señalizadas como provisionales hasta INT-89 y la historia del mapa
- [x] 3.5 Retirar `ConnectivityScreen` de la ruta de arranque (queda sustituida por el splash real)

## 4. Tests

- [x] 4.1 Actualizar `app/test/session_gate_test.dart` para asertar sobre el nuevo destino tras `AnonymousSessionReady` en vez de `ConnectivityScreen`
- [x] 4.2 Añadir tests de `UsernameStorage` (guardar/leer, patrón de `device_id_service_test.dart`)
- [x] 4.3 Añadir tests del enrutamiento del splash: sin nombre de usuario → pantalla "Nombre de usuario"; con nombre de usuario → Mapa de temáticas
- [x] 4.4 Añadir test del tiempo mínimo de splash (la navegación no ocurre antes del mínimo aunque la sesión resuelva al instante)
