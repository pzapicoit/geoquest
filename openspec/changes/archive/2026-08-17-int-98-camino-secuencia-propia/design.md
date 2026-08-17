## Context

El esquema actual (`INT-74`) modela `tematicas → niveles → desafios`, con desbloqueo (`INT-79`, función `cerrar_intento_nivel`) en dos niveles: siguiente nivel de la misma temática por `orden`, y siguiente temática por estrellas acumuladas (`tematicas.estrellas_requeridas`). Esta función ya está desplegada en producción (migración `20260815182216_superacion_nivel_estrellas.sql`) y tiene spec archivada en `openspec/specs/level-progression/spec.md`.

El proyecto está en fase temprana (sin usuarios reales todavía), por lo que no hace falta preservar datos existentes de `tematicas.estrellas_requeridas` ni de `progreso_usuario_nivel` al migrar — se puede reescribir el esquema y la función directamente.

## Goals / Non-Goals

**Goals:**
- Modelar el camino como secuencia propia (`camino`), desacoplada de la agrupación por temática.
- Un único mecanismo de desbloqueo: estrellas acumuladas en todo el camino recorrido vs. umbral por posición.
- Dar a `niveles` el dato (`preguntas_por_partida`) que necesitará `INT-95` para seleccionar preguntas al azar.
- Dar al admin una pantalla para definir el orden del camino.

**Non-Goals:**
- No se implementa el RPC `iniciar_intento_nivel` ni la selección aleatoria de preguntas (`INT-95`).
- No se implementa la vista del camino del jugador (`INT-96`) ni la pantalla Home de la app (`INT-90`).
- No se preserva ni migra el valor histórico de `tematicas.estrellas_requeridas`: se elimina.
- No se resuelve reordenación con drag&drop entre temáticas distintas en el mismo gesto (el admin añade/reordena posiciones del camino una a una, igual que ya hace `reordenar_niveles`/`reordenar_preguntas_nivel`).

## Decisions

### 1. `camino` es una tabla propia con FK a `niveles`, no una columna en `niveles`
Una columna `niveles.posicion_camino` forzaría que cada nivel aparezca como máximo una vez en el camino y acoplaría la tabla de contenido (`niveles`) a la secuencia de juego. Una tabla dedicada permite, a futuro, que un nivel aparezca en más de una posición sin romper el modelo de contenido, y mantiene `niveles` como banco de contenido puro (igual que `desafios` es banco independiente de `nivel_desafios`).

```sql
create table camino (
  id uuid primary key default gen_random_uuid(),
  orden integer not null unique,
  nivel_id uuid not null references niveles(id) on delete cascade,
  estrellas_requeridas integer not null default 0,
  created_at timestamptz not null default now()
);
```

Alternativa descartada: reutilizar `niveles.orden` global en vez de crear `camino` — implicaría renumerar todos los niveles cada vez que se intercala una temática, y perdería la separación entre "orden de creación/gestión dentro de una temática" (que el panel de temáticas sigue necesitando) y "orden de juego".

### 2. El umbral de desbloqueo vive en `camino.estrellas_requeridas` (por posición), no en `niveles` ni en `tematicas`
Sustituye a `tematicas.estrellas_requeridas`. Se elimina esa columna: ya no tiene consumidor una vez que el desbloqueo es por posición del camino. `orden = 1` del camino nace con `estrellas_requeridas = 0` (primera posición, sin requisito), igual que hoy la primera temática no exige estrellas.

### 3. Desbloqueo: solo estrellas acumuladas, no exige completar la posición anterior
Decisión de producto confirmada: al cerrar un intento, se recalcula el total de `mejores_estrellas` del usuario sumado sobre todos los niveles que aparecen en `camino`, y se desbloquean **todas** las posiciones de `camino` cuyo `estrellas_requeridas` sea `<=` ese total (no solo "la siguiente"), evitando que un salto grande de estrellas en una sesión deje posiciones bloqueadas de forma artificial.

Trade-off aceptado (señalado como observación de producto): un jugador puede saltarse niveles intermedios sin jugarlos si acumula estrellas suficientes en otros. Si el equipo quisiera exigir progresión estrictamente secuencial más adelante, sería un cambio de requirement en `level-progression`, no de esquema.

### 4. `preguntas_por_partida` en `niveles`, con constraint respecto al tamaño del pool
Se añade `niveles.preguntas_por_partida integer` (nullable: `null` = usar todas las preguntas del pool, comportamiento actual). Cuando se define, el panel (`panel-level-detail`) debe impedir guardar un valor mayor que el número de preguntas ya asignadas en `nivel_desafios` para ese nivel, para que `INT-95` nunca reciba una configuración imposible de satisfacer.

### 5. Migración de datos: recreación limpia, no backfill
Como no hay usuarios reales, la migración: (a) crea `camino` vacía, (b) siembra una fila por cada nivel existente ordenado por `(tematicas.orden, niveles.orden)` con `estrellas_requeridas = 0` (desbloqueo abierto por defecto, a reconfigurar manualmente desde la nueva pantalla del panel), (c) elimina `tematicas.estrellas_requeridas`, (d) reescribe `cerrar_intento_nivel`. No se transforma `progreso_usuario_nivel` existente (puede haber alguna fila de pruebas manuales; se acepta que quede con `desbloqueado` desactualizado hasta el próximo intento cerrado, que recalcula todo el camino).

## Risks / Trade-offs

- [Riesgo] Reescribir `cerrar_intento_nivel` es un cambio de comportamiento sobre una función ya en producción → Mitigación: cubierto por delta de spec `level-progression` con escenarios explícitos, y por los mismos gates de verificación (tests + revisión adversarial) que el resto del flujo.
- [Riesgo] Eliminar `tematicas.estrellas_requeridas` es irreversible una vez desplegado → Mitigación: aceptable por ausencia de datos reales; si se revirtiera, se recrearía como columna nueva sin pérdida funcional (no se necesita el valor histórico).
- [Trade-off] Desbloqueo no secuencial permite "saltarse" niveles → aceptado explícitamente como decisión de producto (ver Decisión 3).

## Open Questions

Ninguna pendiente: la única decisión abierta en la issue original (si `estrellas_requeridas` queda obsoleto) se resolvió — se mantiene el mecanismo de estrellas, pero re-escalado de temática a posición del camino.
