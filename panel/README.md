# panel

Panel de administración web: gestión de temáticas, niveles, recorridos y desafíos.

## Stack

React 19 + Vite + TypeScript, Tailwind CSS. SPA sin backend propio: habla
directo con Supabase (misma instancia que `app/`) usando la clave publicable;
RLS es la frontera de seguridad. Decisión completa en
`../.devplugin/architecture.md`.

## Desarrollo local

```bash
npm install
cp .env.example .env.local   # rellena con los valores reales de Supabase
npm run dev
```

## Comandos

| Comando                           | Qué hace                                      |
| --------------------------------- | --------------------------------------------- |
| `npm run dev`                     | Servidor de desarrollo                        |
| `npm run build`                   | Build de producción (`tsc -b` + `vite build`) |
| `npm run preview`                 | Sirve el build de producción en local         |
| `npm run typecheck`               | `tsc -b --noEmit`                             |
| `npm run lint`                    | ESLint                                        |
| `npm run format` / `format:check` | Prettier                                      |
| `npm test`                        | Vitest                                        |
| `npm run test:coverage`           | Vitest con cobertura (v8)                     |

## Despliegue

**URL:** https://geoquest-seven-omega.vercel.app/

Vercel, conectado al repo (`panel/` como root directory). Variables de
entorno a configurar en el proyecto de Vercel:

- `VITE_SUPABASE_URL`
- `VITE_SUPABASE_PUBLISHABLE_KEY`

`vercel.json` añade el rewrite necesario para que las rutas de
`react-router-dom` (ej. `/login`) no den 404 al recargar o enlazar
directamente.

## Issues en Linear

| Issue  | Título                                        |
| ------ | --------------------------------------------- |
| INT-80 | Pantalla de login (usuario y contraseña)      |
| INT-81 | Home / Dashboard                              |
| INT-82 | Preguntas / Desafíos - Listado                |
| INT-83 | Preguntas / Desafíos - Crear/Editar           |
| INT-84 | Nivel - Recorrido (configuración y preguntas) |
| INT-85 | Temáticas (listado y crear/editar)            |
| INT-86 | Niveles (listado dentro de una temática)      |

Depende de INT-87 (RPCs y vistas de soporte) en `backend/`.
