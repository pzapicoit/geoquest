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
| `backend/` | Supabase CLI, SQL | linkado, sin esquema (INT-74) |
| `app/` | Flutter 3.47 + `supabase_flutter` | cliente conectado, sin UI de juego |
| `panel/` | web, pendiente de definir | pendiente (INT-80) |

## Flujo de base de datos

**Remote-first.** Las migraciones se escriben en local y se aplican al proyecto
remoto con `supabase db push`. No hay stack local con Docker: se difiere hasta
INT-77, donde probar políticas RLS exigirá usuarios y sesiones desechables.

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
| Tests | `supabase db lint` sobre las migraciones |
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
disponibles. **Falta el SDK de Android**, necesario antes de INT-88.

### panel/

Por definir en INT-80.

## Exenciones

Las tareas de infraestructura sin código de aplicación (crear el proyecto,
linkar, documentar, configurar CI) se marcan `exempt` en las métricas, con razón.
No tiene sentido exigir cobertura a un `config.toml`.
