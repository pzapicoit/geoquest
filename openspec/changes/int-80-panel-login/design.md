## Context

`panel/` no tiene hoy ni proyecto ni código, solo un README con la lista de
pantallas futuras. El stack (React 19 + Vite + TypeScript, Tailwind CSS,
despliegue en Vercel) se decidió esta sesión y ya está en
`.devplugin/architecture.md`. No hay backend propio: panel y app hablan
directo con Supabase usando la clave publicable, y RLS (ya aplicado en
INT-77, `Done`) es la única frontera de seguridad — el panel no necesita
lógica de autorización propia más allá de "hay sesión o no la hay". El
diseño visual de la pantalla de login ya existe en Claude Design
(`[Admin] - Login.dc.html`).

## Goals / Non-Goals

**Goals:**
- Scaffold reproducible de `panel/` (Vite + React + TS + Tailwind).
- Cliente de Supabase inicializado desde configuración por entorno, sin
  secretos en el repo.
- Pantalla de login funcional: formulario, validación de campos vacíos,
  autenticación contra Supabase Auth, mensaje de error explícito, redirect a
  la zona autenticada tras éxito.
- Enrutamiento mínimo: `/login` público, resto de rutas protegidas
  (redirigen a `/login` sin sesión).

**Non-Goals:**
- Contenido real del Home/Dashboard — solo existe como placeholder, destino
  del redirect. Lo construye INT-81.
- Gestión de roles o permisos en el cliente — RLS ya decide qué puede
  hacer cada usuario en el backend.
- "Olvidé mi contraseña" — no está en el checklist de INT-80.
- Crear el proyecto en Vercel — paso manual fuera del repo, documentado como
  tarea pero no automatizado aquí.

## Decisions

- **Vite + React + TS, no Next.js**: sin backend propio, el SSR de Next no
  aporta nada; una SPA reduce superficie y build.
- **Tailwind, no CSS plano ni librería de componentes**: el diseño ya viene
  maquetado en HTML/CSS desde Claude Design — traducción casi directa a
  utilidades. Una librería de componentes obligaría a reinterpretar ese
  diseño en los componentes de la librería, coste innecesario para una sola
  pantalla.
- **`react-router-dom`**: estándar de facto para enrutamiento en SPA de
  React; permite una ruta protegida simple como componente wrapper.
- **Sesión gestionada por `supabase-js` (persistencia por defecto en
  `localStorage`)**, no un store propio: reinventar la gestión de sesión no
  aporta nada que la librería no resuelva ya, y es coherente con "no hay
  backend propio".
- **Config por variables de entorno de Vite** (`import.meta.env.VITE_*`),
  con `panel/.env.example` versionado y `.env.local` gitignorado — mismo
  patrón que `dart_define.json`/`dart_define.example.json` en `app/` y
  `.env.example` en `backend/`.
- **Ruta protegida como componente wrapper** (`RequireAuth`) que comprueba
  sesión antes de renderizar hijos, en vez de auth a nivel de framework/
  middleware — no aplica sin SSR.
- **Vercel para despliegue**: Supabase no ofrece hosting de frontend; Vercel
  da deploy automático por push a `main` y preview por PR sin configuración
  adicional para un proyecto Vite.

## Risks / Trade-offs

- [Sesión en `localStorage` es superficie de XSS] → Mitigación: es el
  comportamiento por defecto y soportado de `supabase-js`; no se introduce
  almacenamiento custom de tokens que añada más riesgo.
- [El redirect post-login aterriza en un placeholder sin contenido real] →
  Mitigación: se documenta explícitamente como fuera de alcance; INT-81 lo
  reemplaza. El placeholder solo demuestra que el flujo de auth funciona.
- [Sin "olvidé mi contraseña", un admin bloqueado depende de un reset manual
  vía dashboard de Supabase] → Mitigación: aceptable para v1 — las cuentas
  admin ya se crean a mano (INT-75/77); se puede añadir como ticket futuro.
- [Sin proyecto de Vercel creado, no hay URL real de despliegue hasta un
  paso manual] → Mitigación: queda como tarea explícita en `tasks.md`, no
  bloquea el desarrollo ni la verificación local.

## Migration Plan

No hay datos que migrar — `panel/` es nuevo. Pasos de despliegue: crear
proyecto en Vercel apuntando a `panel/` como root directory, configurar
`VITE_SUPABASE_URL`/`VITE_SUPABASE_PUBLISHABLE_KEY` en Vercel, y verificar el primer
deploy.

## Open Questions

- ¿El placeholder de Home necesita ya el layout general del panel (nav/
  sidebar) que reutilizarán INT-81 a INT-86, o basta una pantalla vacía
  autenticada? Se opta por lo mínimo (pantalla vacía con confirmación de
  sesión) para no anticipar decisiones de layout ajenas a INT-80.
- Nombre del proyecto y dominio en Vercel — se decide al crearlo, no bloquea
  el código.
