# INT-73 — Crear proyecto en Supabase y configurar entorno

## Why

GeoQuest no tiene backend custom: la app de jugador y el panel de administración
hablan directamente con Supabase vía REST y RPC. Eso convierte al proyecto de
Supabase en la única pieza de infraestructura del producto, y hoy existe pero no
está conectado a nada — sin link local, sin migraciones versionadas, sin claves
repartidas y sin forma reproducible de levantar el entorno.

Hasta que esto esté cerrado, INT-74 (esquema) e INT-76 (storage) están bloqueados,
y con ellos toda la cadena de backend.

## What Changes

- Se versiona el entorno de Supabase en `backend/` con el CLI: `config.toml`,
  carpeta de migraciones y link al proyecto remoto `xhrntgsdlnwrvwehqfgl`.
- Se define el reparto de claves entre los tres consumidores (app, panel, CLI),
  con una separación explícita entre clave publicable y clave secreta.
- **BREAKING respecto al enunciado del issue**: se adoptan las claves nuevas de
  Supabase (`sb_publishable_…` / `sb_secret_…`) en lugar de las legacy
  (`SUPABASE_ANON_KEY` / `SUPABASE_SERVICE_ROLE_KEY`), y se desactivan las legacy.
  Motivo en `design.md`.
- Se documenta en `backend/README.md` cómo levantar el entorno local.
- La app Flutter arranca con un cliente Supabase inicializado y una pantalla de
  verificación de conectividad.
- Se deja constancia en `.devplugin/architecture.md` de que app y panel comparten
  el mismo proyecto Supabase, sin backend intermedio.

## Capabilities

### New Capabilities

- `backend-environment`: el entorno de Supabase es reproducible desde el repo —
  link al proyecto remoto, migraciones versionadas, arranque local y reparto de
  claves por consumidor.
- `app-supabase-client`: la app Flutter inicializa un cliente Supabase con la
  clave publicable y expone su estado de conectividad.

### Modified Capabilities

Ninguna. No hay specs previas en `openspec/specs/`.

## Impact

- **Nuevo**: `backend/supabase/` (config, migraciones), `backend/.env.example`,
  `backend/README.md`, `app/` (proyecto Flutter), `.devplugin/architecture.md`.
- **Dependencias nuevas**: Supabase CLI, Docker (solo para el stack local),
  Flutter SDK, paquete `supabase_flutter`.
- **Desbloquea**: INT-74 (esquema) e INT-76 (storage).
- **Condiciona**: INT-77 (RLS) — al no haber clave secreta en el panel, los
  privilegios de administración tendrán que salir de políticas RLS sobre un claim
  de rol, no de saltarse RLS.
- **Prerrequisitos de máquina no cubiertos por código**: Docker Desktop y Flutter
  SDK no están instalados/arrancados en el equipo actual.
