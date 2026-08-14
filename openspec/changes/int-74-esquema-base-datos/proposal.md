## Why

El proyecto de Supabase existe y está vinculado al repo (INT-73), pero no tiene
ninguna tabla. Todo el backend de GeoQuest —RLS (INT-77), cálculo de puntaje
(INT-78), lógica de niveles (INT-79), registro anónimo (INT-75), vistas de
juego y de panel (INT-87, INT-95, INT-96) y las pantallas de app/panel— depende
de que exista primero el modelo de datos: temáticas → niveles → desafíos, y el
progreso del jugador sobre ellos.

## What Changes

- Migración versionada en `backend/supabase/migrations/` que crea el esquema
  completo del juego.
- Tipos enumerados `rol_usuario` (`admin`, `jugador`) y `tipo_desafio`
  (`imagen`, `pregunta_texto`, `video`).
- Ocho tablas: `profiles`, `tematicas`, `niveles`, `desafios`,
  `nivel_desafios`, `intentos_nivel`, `respuestas_desafio`,
  `progreso_usuario_nivel`.
- Claves foráneas, `CHECK` constraints (incluida la exclusividad de columnas
  de `desafios` según su `tipo`) e índices sobre las columnas de FK más
  consultadas.
- Sin RLS, sin funciones/RPC, sin datos de contenido: eso queda para INT-75,
  INT-77, INT-78, INT-79, INT-87, INT-95 y INT-96.

## Capabilities

### New Capabilities
- `game-data-model`: tablas, relaciones y restricciones que modelan
  temáticas, niveles, el banco de desafíos, y el progreso del jugador.

### Modified Capabilities
(ninguna — `backend-environment` ya exige migraciones versionadas; esta
tarea cumple ese requisito existente, no lo cambia)

## Impact

- **Código**: solo `backend/supabase/migrations/` (nuevo fichero). Ningún
  cliente (app, panel) consume estas tablas todavía.
- **Base remota**: `supabase db push` aplica el esquema al proyecto real
  (único entorno existente, sin stack local — decisión D6 de INT-73).
- **Desbloquea**: INT-75, INT-77, INT-78, INT-79, INT-87, INT-95, INT-96 y,
  transitivamente, todas las pantallas de app y panel que leen o escriben
  estas tablas.
