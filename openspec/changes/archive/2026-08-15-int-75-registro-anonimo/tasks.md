## 1. Supabase Auth

- [x] 1.1 Habilitar el proveedor "Anonymous Sign-ins" (y "manual linking") en la configuración de Auth del proyecto. `config.toml` actualizado; activado en el dashboard del proyecto remoto por el usuario (no se usó `supabase config push` para no arriesgar `site_url`/`redirect_urls`).
- [x] 1.2 Confirmar/crear al menos una cuenta de administrador de prueba (email/contraseña) con `profiles.role = 'admin'`. Creada vía Admin API: `admin-test@geoquest.dev`.

## 2. Base de datos

- [x] 2.1 Migración: columna `device_id uuid` en `profiles` (nullable).
- [x] 2.2 Migración: función `handle_new_user()` que inserta en `profiles` (nombre por defecto "JugadorNNNN" para altas anónimas, rol `jugador`, y `device_id` leído de `raw_user_meta_data->>'device_id'`).
- [x] 2.3 Migración: trigger `after insert on auth.users` que llama a `handle_new_user()`.
- [x] 2.4 Probar el trigger manualmente (insertar un usuario de prueba vía `signInAnonymously` con `data: {'device_id': ...}` contra el proyecto remoto y verificar nombre + `device_id` en `profiles`). Verificado por API: perfil creado con nombre "JugadorNNNN" y `device_id` correcto.

## 3. App Flutter — sesión anónima

- [x] 3.1 Añadir dependencia `uuid` y generar un UUID v4 en el primer arranque si no existe uno persistido en el dispositivo.
- [x] 3.2 En el arranque (`main.dart` o servicio dedicado), si `Supabase.instance.client.auth.currentSession` es `null`, llamar a `signInAnonymously(data: {'device_id': uuid})` antes de navegar a la home.
- [x] 3.3 Manejar el error de `signInAnonymously()` (sin conexión, proveedor deshabilitado) con un estado explícito y opción de reintentar, reutilizando el patrón de `ConnectivityScreen`.
- [x] 3.4 Verificar que reabrir la app con sesión ya persistida no dispara una nueva alta anónima ni regenera el UUID de dispositivo (usa la sesión y el UUID ya persistidos). Verificado con test automatizado y en el simulador de iOS (ver 5.1).

## 4. App Flutter — vinculación de cuenta

- [x] 4.1 Implementar flujo de vinculación de identidad Google/Apple sobre la sesión anónima activa (`linkIdentity`).
- [x] 4.2 Manejar el caso de identidad ya vinculada a otra cuenta: mostrar mensaje explícito y no perder la sesión anónima original.

## 5. Verificación end-to-end

- [x] 5.1 Probar manualmente: abrir app → jugar como anónimo → cerrar y reabrir (sigue logueado, mismo `user id`). Probado en el simulador de iOS (iPhone 17 Pro): mismo `user id` (`f70aa19d-...`) y mismo `device_id` tras parar y relanzar la app por completo.
- [ ] 5.2 Probar manualmente: vincular cuenta Google/Apple sobre la sesión anónima → el progreso previo se mantiene bajo el mismo `user id`. **Bloqueado**: requiere credenciales OAuth de Google/Apple dadas de alta en Google Cloud Console / Apple Developer y configuradas en el dashboard de Auth — fuera del alcance que se puede completar sin esas cuentas externas. El código (`AccountLinkingService`) está listo y cubierto por tests; queda como seguimiento para cuando existan esas credenciales.
- [x] 5.3 Probar manualmente: login del panel con email/contraseña (éxito y credenciales inválidas). Verificado por API contra `admin-test@geoquest.dev`: login correcto devuelve sesión no anónima; contraseña incorrecta devuelve `invalid_credentials` sin sesión.
