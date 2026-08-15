## 1. Scaffold del proyecto

- [x] 1.1 Crear el proyecto Vite (`react-ts`) dentro de `panel/`, conservando
      la lista de issues del README actual (moverla a un lugar razonable del
      nuevo README, no perderla)
- [x] 1.2 Instalar y configurar Tailwind CSS (`tailwind.config`,
      `postcss.config`, directivas en el CSS de entrada)
- [x] 1.3 Instalar `react-router-dom`
- [x] 1.4 Instalar `@supabase/supabase-js`
- [x] 1.5 Configurar ESLint + Prettier + `tsconfig` estricto

## 2. Configuración de entorno

- [x] 2.1 Crear `panel/.env.example` con `VITE_SUPABASE_URL` y
      `VITE_SUPABASE_PUBLISHABLE_KEY` de ejemplo
- [x] 2.2 Añadir `panel/.env.local` al `.gitignore` del repo (verificar que
      ya esté cubierto o añadirlo)
- [x] 2.3 Documentar en `panel/README.md` cómo configurar las variables,
      igual que `backend/.env.example` / `app/dart_define.example.json`

## 3. Cliente Supabase (`panel-supabase-client`)

- [x] 3.1 Inicializar el cliente de Supabase leyendo `import.meta.env.VITE_*`
- [x] 3.2 Fallar de forma explícita al arrancar (mensaje que nombra la
      variable ausente) si falta la URL o la clave
- [x] 3.3 Exponer el cliente como singleton importable desde el resto del
      panel

## 4. Enrutamiento y protección (`panel-login-ui`)

- [x] 4.1 Configurar el router: ruta pública `/login` y resto de rutas bajo
      un layout protegido
- [x] 4.2 Implementar `RequireAuth`: comprueba la sesión de Supabase y
      redirige a `/login` si no existe
- [x] 4.3 Crear una pantalla Home placeholder (sin contenido de INT-81) como
      destino protegido tras el login

## 5. Pantalla de login

- [x] 5.1 Importar el diseño desde Claude Design (MCP `claude_design`,
      proyecto `d83d4c61-3a9e-4fff-b1c4-d2a19fd03ef5`, fichero
      `[Admin] - Login.dc.html`, junto con `assets/geoquest-logo.png`,
      `image-slot.js` y `support.js`) — colores/tipografía tomados también
      de `GeoQuest Branding.dc.html`; logo y foto de fondo no se pudieron
      traer completos (superan el límite de 256 KB de la herramienta de
      importación), ver nota en `panel/README.md`
- [x] 5.2 Traducir el maquetado a componente React con Tailwind
- [x] 5.3 Formulario controlado (email, contraseña), sin opción de registro
      visible
- [x] 5.4 Validación en cliente: email y contraseña no vacíos antes de
      enviar; si faltan, mostrar error de validación sin llamar a Supabase
      Auth
- [x] 5.5 Llamar a `supabase.auth.signInWithPassword` en el envío
- [x] 5.6 Mostrar mensaje de error explícito en credenciales inválidas, sin
      crear sesión, permaneciendo en `/login`
- [x] 5.7 Redirigir a Home (ruta protegida) tras login correcto

## 6. Despliegue

- [x] 6.1 Configurar build command / output directory para Vercel si hace
      falta (`vercel.json` o config del propio proyecto)
- [x] 6.2 Documentar en `panel/README.md` los pasos manuales para crear el
      proyecto en Vercel y configurar sus variables de entorno
- [ ] 6.3 (Manual, fuera del repo) Crear el proyecto en Vercel apuntando a
      `panel/` y verificar el primer deploy

## 7. Calidad

- [x] 7.1 Configurar Vitest + React Testing Library
- [x] 7.2 Tests del formulario de login: render, validación de campos
      vacíos, error de credenciales inválidas, redirect en éxito
- [x] 7.3 Tests de inicialización del cliente Supabase (config presente /
      ausente) — extraída a `resolveSupabaseConfig` (`supabaseConfig.ts`)
      para poder testearla sin `vi.resetModules`/import dinámico
- [x] 7.4 Test de `RequireAuth`: redirige sin sesión
- [x] 7.5 `eslint`, `prettier --check` y `tsc --noEmit` sin errores
- [x] 7.6 Actualizar `panel/README.md` reemplazando la fila "pendiente" del
      módulo por el estado real
