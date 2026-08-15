## Why

El jugador debe poder abrir la app y jugar de inmediato, sin pantalla de registro ni credenciales, y sin que se le vuelva a pedir acceso al reabrir la app en el mismo dispositivo. El panel de administración, al ser de uso interno, necesita en cambio un login tradicional con email y contraseña. Ahora mismo el proyecto no tiene ningún mecanismo de autenticación configurado (INT-73/INT-74 dejaron el entorno Supabase y el esquema de juego, pero no auth), así que ambos flujos hay que definirlos desde cero.

## What Changes

- Habilitar el proveedor de "anonymous sign-ins" en Supabase Auth para el proyecto.
- Al primer arranque de la app, crear una sesión anónima automáticamente (sin pantalla de registro) y persistirla de forma segura en el dispositivo, de modo que reabrir la app no vuelva a pedir acceso.
- Trigger en base de datos que cree la fila en `profiles` también para usuarios anónimos, con nombre por defecto (p. ej. "Jugador1234") **y el UUID del dispositivo que originó el alta**, como identificador provisional mientras no haya cuenta vinculada.
- Soporte para vincular más adelante una identidad Google/Apple sobre la sesión anónima (`linkIdentity`) sin perder el progreso acumulado.
- Login normal por email/contraseña para el panel de administración, como flujo de auth independiente y no anónimo.
- **Fuera de alcance**: la pantalla de login del panel (INT-80) y las políticas de RLS por rol (INT-77) — este cambio cubre la configuración y lógica de autenticación, no las pantallas ni las políticas de acceso a datos.

## Capabilities

### New Capabilities
- `player-anonymous-auth`: sesión anónima automática para el jugador, persistencia en el dispositivo, creación de perfil por defecto vía trigger (nombre y UUID del dispositivo), y vinculación posterior de una identidad Google/Apple conservando el progreso.
- `admin-panel-auth`: autenticación por email/contraseña para el panel de administración, como flujo separado y no anónimo.

### Modified Capabilities
(ninguna — no se modifican requisitos de `app-supabase-client`, `backend-environment` ni `game-data-model`)

## Impact

- **Supabase Auth**: habilitar proveedor anónimo; configurar `linkIdentity` para Google/Apple.
- **Base de datos**: nuevo trigger sobre `auth.users` (o equivalente) que crea la fila en `profiles` para altas anónimas; nueva columna `device_id` en `profiles`.
- **App Flutter**: inicialización de sesión anónima en el arranque, generación/lectura del UUID del dispositivo, persistencia segura de la sesión, y flujo de vinculación de cuenta.
- **Panel de administración**: flujo de login email/contraseña (backend de auth; la pantalla concreta se implementa en INT-80).
- Dependencias: `app-supabase-client` (cliente ya inicializado) y `game-data-model` (tabla `profiles` ya existente).
