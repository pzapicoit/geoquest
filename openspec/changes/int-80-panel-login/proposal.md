## Why

`panel/` está vacío hoy (solo README): no hay proyecto web, ni cliente de
Supabase, ni una sola pantalla. INT-80 es la primera tarea de la Épica 1
(Panel de administración) y bloquea a INT-82 y INT-85, así que además de la
pantalla de login hay que sentar la base técnica del módulo — sin eso no hay
dónde apoyar el resto de pantallas del panel.

## What Changes

- Bootstrap de `panel/` como app Vite + React + TypeScript con Tailwind CSS
  configurado (decisión de stack ya documentada en `architecture.md`).
- Cliente de Supabase inicializado con la clave publicable, leyendo URL/clave
  desde variables de entorno inyectadas en build (mismo patrón que
  `dart_define.json` en `app/`): sin claves reales en el código versionado.
- Pantalla de login (según diseño de Claude Design, `[Admin] - Login.dc.html`):
  formulario de email/contraseña, sin opción de registro.
- Validación de campos vacíos en cliente antes de llamar a Supabase Auth.
- Llamada a Supabase Auth (email/contraseña); en credenciales inválidas se
  muestra un mensaje explícito y no se crea sesión.
- Redirección a la zona autenticada del panel (placeholder de Home, sin
  contenido — lo llena INT-81) tras login correcto.
- La zona autenticada no es accesible sin sesión válida (redirige a login).
- Configuración de despliegue en Vercel (conecta con el repo; la creación del
  proyecto en Vercel es un paso manual fuera del repo).

## Capabilities

### New Capabilities
- `panel-supabase-client`: inicialización del cliente de Supabase en `panel/`
  desde configuración inyectada en build, con fallo explícito si falta.
  Mismo contrato que `app-supabase-client`, aplicado al panel.
- `panel-login-ui`: la pantalla de login del panel — formulario, validación de
  campos vacíos, llamada a Supabase Auth, mensaje de error explícito en
  credenciales inválidas, redirección tras éxito, y bloqueo de la zona
  autenticada sin sesión.

### Modified Capabilities
_(ninguna — `admin-panel-auth` ya define el contrato de autenticación del
panel (login por email/contraseña, sin autorregistro, independiente del alta
anónima de la app); este cambio lo consume desde el cliente sin alterar sus
requisitos.)_

## Impact

- **`panel/`**: pasa de vacío (solo README) a app Vite+React+TS completa.
  Nuevas dependencias: `react`, `react-dom`, `react-router-dom`, `vite`,
  `typescript`, `tailwindcss`, `@supabase/supabase-js`.
- **Configuración**: nuevo `panel/.env.example` (análogo a
  `backend/.env.example` y `app/dart_define.example.json`); `.env.local` real
  gitignorado.
- **Despliegue**: Vercel. La conexión repo↔proyecto Vercel es manual, fuera
  del alcance de este cambio (se documenta como tarea, no como código).
- **Fuera de alcance**: contenido real del Home/Dashboard (INT-81) — solo se
  crea la ruta protegida como destino del redirect, sin UI propia.
