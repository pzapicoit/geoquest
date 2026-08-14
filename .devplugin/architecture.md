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
| `app/` | Flutter + `supabase_flutter` | pendiente |
| `panel/` | web, pendiente de definir | pendiente (INT-80) |

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

### panel/

Por definir en INT-80.

## Exenciones

Las tareas de infraestructura sin código de aplicación (crear el proyecto,
linkar, documentar, configurar CI) se marcan `exempt` en las métricas, con razón.
No tiene sentido exigir cobertura a un `config.toml`.
