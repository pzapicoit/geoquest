## Why

Salvo el RLS mínimo de `profiles` (fix de INT-76), el resto del esquema del
juego (`tematicas`, `niveles`, `desafios`, `nivel_desafios`,
`intentos_nivel`, `respuestas_desafio`, `progreso_usuario_nivel`) no tiene
Row Level Security habilitado. Cualquier cliente con una clave anon —
autenticado o con sesión anónima — puede leer y escribir esas tablas
directamente vía REST sin ninguna restricción. Antes de construir el panel
de administración (INT-80) y las RPCs que dependen de roles (INT-87,
INT-95), el esquema necesita que cada usuario solo pueda ver/tocar lo suyo y
que solo los admins gestionen el contenido del juego.

## What Changes

- Habilitar RLS en `tematicas`, `niveles`, `desafios`, `nivel_desafios`,
  `intentos_nivel`, `respuestas_desafio` y `progreso_usuario_nivel`
  (`profiles` ya lo tiene desde INT-76).
- Función auxiliar `is_admin()` (`security definer`, reutilizable en todas
  las policies) que comprueba `profiles.role = 'admin'` para el usuario
  actual.
- Lectura pública (para cualquier `authenticated`) de `tematicas`, `niveles`
  y `nivel_desafios`.
- `desafios` sin policy de lectura para `authenticated`/`anon`: la tabla
  base sigue expuesta a través de PostgREST pero cualquier `select` directo
  es denegado por defecto (los jugadores no deben ver `lat_real`/`lng_real`/
  `nombre_lugar` antes de responder). El acceso de juego llegará vía la
  vista `desafios_para_jugar` de INT-95, fuera de alcance aquí.
- Escritura (`insert`/`update`/`delete`) restringida a `is_admin()` en
  `tematicas`, `niveles`, `desafios` y `nivel_desafios`.
- `intentos_nivel`, `respuestas_desafio` y `progreso_usuario_nivel`:
  visibles y editables únicamente por su propio `usuario_id` (
  `auth.uid()`).
- **BREAKING**: sustituye la policy de `profiles` para permitir `update` de
  la propia fila (`nombre`, `avatar_url`), bloqueando explícitamente
  cualquier cambio de `role` por el propio usuario — hoy no existe ninguna
  policy de `update`, así que ningún cliente puede editar su perfil todavía.
- Asignación manual del primer admin vía SQL/dashboard de Supabase (no hay
  panel de gestión de usuarios todavía) — paso operativo, no migración.
- Verificación de acceso con un usuario admin real y un usuario jugador
  real (sesión anónima y cuenta vinculada), contra el proyecto remoto.

## Capabilities

### New Capabilities

(ninguna — esta change solo añade reglas de acceso sobre capabilities ya
existentes)

### Modified Capabilities

- `game-data-model`: añade RLS a todas las tablas del esquema que aún no lo
  tenían, define `is_admin()`, y sustituye el requisito "profiles tiene RLS
  mínimo y `role` no es auto-editable" (INT-76) por uno que permite `update`
  de la propia fila salvo `role`.

## Impact

- Migraciones SQL nuevas en `backend/supabase/migrations/`.
- Cualquier cliente (app Flutter, panel) que hoy dependa de leer/escribir
  estas tablas sin pasar por RLS empezará a recibir respuestas vacías o
  rechazos si no cumple la policy correspondiente — hoy no hay ningún
  cliente en producción que dependa de ese acceso sin restricciones.
- Bloquea INT-80 (login del panel), INT-87 (RPCs del panel) e INT-95 (vista
  segura de desafíos), que asumen estas policies como prerrequisito.
