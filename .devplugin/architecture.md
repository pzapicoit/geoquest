# Arquitectura — GeoQuest

## Forma del sistema

Tres piezas y un único backend:

```
app/ (Flutter)  ─┐
                 ├─→  Supabase  xhrntgsdlnwrvwehqfgl  (eu-west-1)
panel/ (web)    ─┘     Postgres 17.6 · Auth · Storage · PostgREST
```

**No hay backend custom.** La app de jugador y el panel de administración
consumen el mismo proyecto de Supabase directamente, vía REST y RPC. Toda la
lógica de negocio que no puede vivir en el cliente vive como función o vista en
Postgres, no como servicio aparte.

Consecuencia directa: la frontera de seguridad es **Row Level Security**, no una
capa de API intermedia. Cualquier dato que un cliente no deba ver tiene que estar
protegido por política, porque el cliente habla con la base sin intermediarios.

## Reparto de claves

| Clave | Consumidores | Se salta RLS |
|---|---|---|
| `sb_publishable_…` | `app/`, `panel/` | No |
| `sb_secret_…` | scripts de `backend/` | Sí |

La clave secreta no entra en ningún artefacto distribuible. El panel, pese a ser
administración, usa la publicable: sus privilegios salen de políticas RLS sobre
el rol del usuario autenticado.

## Módulos

| Carpeta | Stack | Estado |
|---|---|---|
| `backend/` | Supabase CLI, SQL | esquema del juego (INT-74) + alta anónima y trigger de perfil (INT-75) + Storage de media de desafíos (INT-76) + RLS en todo el esquema del juego (INT-77) + cálculo de distancia/puntaje al responder un desafío (INT-78) + superación de nivel, estrellas y desbloqueos al cerrar un intento (INT-79) + RPCs de reorden y vistas/funciones de métricas y alertas para el panel (INT-87) + `actividad_reciente()` para el feed de altas/niveles superados del Home del panel (INT-81) + camino como secuencia propia de niveles y desbloqueo por estrellas acumuladas en el camino, sustituyendo el desbloqueo por temática (INT-98) + vista `camino_jugador` con el camino completo y el progreso del jugador autenticado, para la Home de la app (INT-96) + vista `desafios_para_jugar` y RPC `iniciar_intento_nivel` para leer contenido de desafío sin exponer su ubicación real y arrancar un intento con sus desafíos seleccionados (INT-95) |
| `app/` | Flutter 3.47 + `supabase_flutter` + `google_fonts` | sesión anónima automática en el arranque (INT-75) + splash con branding e icono de app (INT-88) + pantalla de apodo con guardado en `profiles` (INT-89), sin Mapa de temáticas real todavía |
| `panel/` | React 19 + Vite + TypeScript, Tailwind CSS | login (INT-80) + Home/dashboard con layout fijo, métricas, accesos rápidos, actividad reciente y alertas de contenido (INT-81) + pantalla "Camino" para gestionar la secuencia global de niveles (INT-98), desplegado en https://geoquest-seven-omega.vercel.app/ |

## Flujo de base de datos

**Remote-first.** Las migraciones se escriben en local y se aplican al proyecto
remoto con `supabase db push`. No hay stack local con Docker.

Las políticas RLS también se pueden probar contra el remoto: se crean usuarios de
prueba por la API de Auth, se obtienen sus JWT y se lanzan peticiones como ellos.
Lo que se pierde es menor —usuarios que se acumulan en `auth.users` y setup
destructivo sobre el único entorno—, así que Docker queda **sin fecha**: se
instala si y cuando probar RLS resulte incómodo, no por calendario.

Todo cambio de esquema va por migración versionada. Nunca a mano por el SQL
editor: `supabase db reset --linked` reconstruye la base solo desde las
migraciones del repo, y se lleva por delante cualquier cambio manual.

Consecuencia de no tener segundo entorno: el proyecto remoto es el único que
existe, así que **el contenido de trabajo debe ser reproducible desde
`backend/supabase/seed.sql`**. Lo que solo viva dentro de la base se pierde en el
primer reset.

## Herramientas de calidad

Declaradas para los gates de `/execute`.

### backend/

| Gate | Herramienta |
|---|---|
| Tests | `supabase db lint --linked` sobre las migraciones (remoto, sin Docker) |
| Cobertura | no aplica — no hay código de aplicación |
| Quality | `supabase db lint`, revisión de que todo cambio va por migración |

Cuando exista esquema (INT-74) conviene revisar si merece la pena pgTAP para las
políticas RLS. Las políticas son exactamente el tipo de cosa que se rompe en
silencio, así que probablemente sí.

### app/

| Gate | Herramienta |
|---|---|
| Tests | `flutter test` |
| Cobertura | `flutter test --coverage`, umbral por definir |
| Quality | `flutter analyze`, `dart format --set-exit-if-changed` |

La configuración se inyecta con `--dart-define-from-file=dart_define.json`. Ese
fichero está gitignorado; la plantilla es `dart_define.example.json`.

Herramientas de máquina: Flutter 3.47.0 / Dart 3.13.0, Xcode 26.6 y Chrome
disponibles.

**iOS primero.** El desarrollo arranca por iOS; Android queda para más adelante.
El proyecto Flutter ya incluye la plataforma `android/`, así que activarlo es
solo instalar el SDK de Android — no hay que tocar el proyecto.

### panel/

| Gate | Herramienta |
|---|---|
| Tests | Vitest + React Testing Library |
| Cobertura | `vitest run --coverage`, umbral por definir |
| Quality | ESLint, Prettier, `tsc --noEmit` |

**Stack:** React 19 + Vite + TypeScript, Tailwind CSS, desplegado en Vercel.

Decidido en INT-80 frente a Next.js y Flutter Web. No hay backend propio —
panel y app hablan directo con Supabase con la clave publicable, RLS es la
única frontera de seguridad — así que el SSR de Next.js no aporta nada aquí:
una SPA basta. El diseño de las pantallas del panel llega ya maquetado en
HTML/CSS desde Claude Design, lo que hace de React+Tailwind una traducción casi
directa; Flutter Web habría significado reimplementar ese layout como widgets
Dart sin ganar reuso real de lógica con `app/`, porque la lógica de negocio
vive en Postgres, no en el cliente.

Supabase no ofrece hosting de frontend (solo Postgres, Auth, Storage, Edge
Functions), así que el panel se despliega en Vercel: conecta directo con el
repo, deploy en cada push a `main` y preview automático por PR.

**URL:** https://geoquest-seven-omega.vercel.app/

## Exenciones

Las tareas de infraestructura sin código de aplicación (crear el proyecto,
linkar, documentar, configurar CI) se marcan `exempt` en las métricas, con razón.
No tiene sentido exigir cobertura a un `config.toml`.
