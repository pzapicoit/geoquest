## Why

El panel de administración (`panel/`) no tiene backend propio: toda su lógica
vive en Postgres. Hasta ahora eso cubre CRUD básico (API REST que Supabase
genera sobre tablas + RLS), pero varias pantallas del panel necesitan lógica
que el REST plano no puede dar: reordenar filas de forma atómica, y agregados
de solo lectura (métricas, alertas de contenido, uso de un desafío) que
requieren cruzar varias tablas. INT-87 cubre esa lógica de soporte antes de
que las pantallas que la consumen (INT-81 Home/Dashboard, INT-82
Preguntas/Desafíos - Listado) se implementen.

## What Changes

- Nueva RPC `reordenar_tematicas(ids_en_orden uuid[])`: actualiza `orden` de
  `tematicas` de forma atómica según la posición de cada id en el array.
- Nueva RPC `reordenar_niveles(p_tematica_id uuid, ids_en_orden uuid[])`:
  igual que la anterior, para `niveles` dentro de una temática.
- Nueva RPC `reordenar_preguntas_nivel(p_nivel_id uuid, ids_en_orden
  uuid[])`: igual, para `nivel_desafios` dentro de un nivel.
- Las tres RPC de reorden son solo-admin (`is_admin()`), validan que el
  array recibido contenga exactamente las mismas filas que existen hoy para
  ese padre (ninguna de más, ninguna de menos) antes de tocar nada, y usan
  constraints `orden` diferibles para evitar el choque transitorio de UNIQUE
  al reasignar posiciones en una sola sentencia.
- Nueva función `metricas_home()`: jugadores totales, jugadores con al menos
  un intento en los últimos 7 días, partidas jugadas hoy, niveles activos.
  Consumida por INT-81.
- Nueva función `alertas_contenido()`: niveles con tasa de superación baja
  (con un mínimo de intentos para evitar falsos positivos por muestra
  pequeña) y desafíos activos con datos incompletos según su tipo (sin
  imagen/video/texto, o sin coordenadas válidas). Consumida por INT-81.
- Nueva vista `desafios_uso`: cuántos niveles usa actualmente cada desafío
  del banco, para el listado y el filtro "sin asignar" de INT-82.
- Todas las funciones/vistas nuevas son solo-admin: solo devuelven datos (o
  se ejecutan) para un usuario autenticado con `profiles.role = 'admin'`,
  reutilizando `is_admin()` de INT-77.

## Capabilities

### New Capabilities

- `content-reordering`: RPCs de reorden atómico y solo-admin para
  temáticas, niveles y desafíos-de-nivel.
- `panel-home-metrics`: función `metricas_home()` con los agregados de la
  cabecera del dashboard.
- `content-alerts`: función `alertas_contenido()` con las señales de
  contenido que necesita revisión (niveles de baja superación, desafíos
  incompletos).
- `challenge-usage`: vista `desafios_uso` con el recuento de niveles que
  usan cada desafío del banco.

### Modified Capabilities

_(ninguna — `game-data-model` no cambia sus requisitos: las tablas que leen
y escriben estas RPC/vistas ya existen desde INT-74. `admin-panel-auth`
tampoco cambia: estas funciones reutilizan `is_admin()` tal cual la definió
INT-77, no alteran su contrato.)_

## Impact

- **Base de datos**: nueva migración con 3 RPC de reorden, 2 funciones de
  agregado (`metricas_home`, `alertas_contenido`) y 1 vista
  (`desafios_uso`). Puede requerir volver `deferrable` el constraint
  `unique(orden)`/`unique(tematica_id, orden)`/`unique(nivel_id, orden)` de
  `tematicas`/`niveles`/`nivel_desafios` (creados en INT-74) para que el
  reorden en una sola sentencia no choque consigo mismo — se decide en
  design.md.
- **Panel (React)**: consumidor futuro de estas RPC/vistas desde INT-81
  (Home) e INT-82 (listado de preguntas/desafíos); su integración no es
  parte de este ticket.
- **Fuera de alcance**: vistas equivalentes para Jugadores/Ranking (aún sin
  diseñar, quedan para cuando existan esas pantallas).
