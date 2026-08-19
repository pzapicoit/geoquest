---
type: scope
parent: int-111-panel-jugadores
reason: durante el testing local de INT-111 el usuario pidió poder eliminar jugadores por completo (no solo resetear su progreso) y prohibir alias duplicados entre jugadores
---

## Why

Durante el testing local de la pantalla "Jugadores" salieron dos necesidades que el ticket original no cubría: poder eliminar por completo la cuenta de un jugador desde el panel (no solo reiniciar su progreso), y evitar que dos jugadores compartan el mismo alias — hoy no hay ninguna restricción y ya existen duplicados reales en producción (el alias "Zapi" aparece 6 veces).

## What Changes

- Nueva RPC `eliminar_jugador(p_jugador_id uuid)`: borra la cuenta completa de un jugador (`auth.users`, que en cascada se lleva `profiles` y todo su progreso/historial de juego), gateada por `is_admin()`, auditada en una tabla nueva `auditoria_eliminacion_jugador`.
- Nueva acción "Eliminar jugador" en la pantalla Jugadores del panel, con el mismo patrón de confirmación por escritura de alias que ya usa el reinicio, pero con texto propio que deja claro que se pierde la cuenta entera, no solo el progreso.
- Nueva restricción `UNIQUE` en `profiles.nombre`. La migración primero deduplica los datos existentes (conserva el alias del perfil más antiguo de cada grupo duplicado y añade un sufijo numerado — " (2)", " (3)"... — a los siguientes, respetando el límite de 16 caracteres que ya impone la app) y después crea el índice único.
- **Cambio de comportamiento interno** (no rompe ninguna API pública): el trigger `handle_new_user()` que asigna el alias por defecto en el alta anónima pasa a reintentar con otro candidato si el generado ya existe, para que una alta nunca falle por colisión una vez exista el `UNIQUE`.
- La app (pantalla de apodo, INT-89) distingue el error de "alias ya en uso" (violación de unicidad) del resto de errores y muestra un mensaje específico en vez del genérico de conexión que muestra hoy para cualquier fallo.

## Capabilities

### New Capabilities
- `panel-player-deletion`: eliminación completa de la cuenta de un jugador desde el panel, con confirmación explícita y auditoría.
- `player-alias-uniqueness`: el alias de un jugador es único en todo el sistema — el alta anónima y el cambio de apodo lo respetan, y los datos existentes se normalizan antes de exigirlo.

### Modified Capabilities
(ninguna — `panel-players-listing` no cambia de comportamiento: simplemente deja de listar a un jugador tras eliminarlo, consecuencia directa de `panel-player-deletion`, no un requisito nuevo de listado)

## Impact

- **Backend**: nueva migración con dedupe de `profiles.nombre` + índice `UNIQUE` + reescritura de `handle_new_user()` + nueva RPC `eliminar_jugador` + nueva tabla `auditoria_eliminacion_jugador`.
- **Panel**: nueva acción y modal en `Jugadores.tsx`, nueva función en `jugadores.ts`.
- **App (Flutter)**: `profile_gateway.dart` distingue el error de unicidad; `username_screen.dart` muestra un mensaje específico para ese caso.
