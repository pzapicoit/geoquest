## Why

INT-78 calcula y persiste el puntaje de cada respuesta individual
(`respuestas_desafio.puntos`), pero nada cierra el intento completo todavía:
`intentos_nivel.puntaje_total`/`superado`/`estrellas_obtenidas` se quedan en
sus valores por defecto (0/false/0) para siempre, y `progreso_usuario_nivel`
nunca se crea ni se actualiza, así que ningún nivel ni temática se
desbloquea nunca más allá de los que vengan pre-sembrados. INT-79 cierra ese
hueco: al terminar un intento, agrega el puntaje, decide si el nivel queda
superado, calcula estrellas, actualiza el progreso agregado del jugador y
desbloquea lo que corresponda.

## What Changes

- Nueva RPC `cerrar_intento_nivel(p_intento_id)`: suma los `puntos` de
  `respuestas_desafio` del intento, pero solo los que correspondan a
  desafíos asignados al nivel del intento vía `nivel_desafios` (nunca a un
  `nivel_id` fijo en `desafios`, que no existe — D3 de INT-74). Exige que el
  intento tenga una respuesta por cada fila de `nivel_desafios` del nivel
  antes de cerrarlo.
- Compara el puntaje agregado contra `niveles.puntaje_minimo_superar` para
  marcar `superado`, y si queda superado, calcula `estrellas_obtenidas`
  (1-3) según `umbral_estrella_1/2/3`. Persiste los tres valores en la
  propia fila de `intentos_nivel`.
- Actualiza (upsert) `progreso_usuario_nivel` para ese usuario/nivel
  quedándose siempre con el mejor puntaje y las mejores estrellas vistas
  hasta ahora (nunca empeora un resultado previo al rejugar).
- Si el nivel queda superado, desbloquea (upsert `desbloqueado = true`) el
  siguiente nivel de la misma temática, si existe.
- Si la suma de `mejores_estrellas` del jugador en los niveles de la
  temática alcanza `estrellas_requeridas` de la siguiente temática,
  desbloquea el primer nivel de esa siguiente temática.
- Sin límite de intentos: rejugar un nivel ya superado es idempotente sobre
  el progreso — nunca se pierde el mejor resultado ni un desbloqueo previo.

## Capabilities

### New Capabilities
- `level-progression`: cierre de un intento de nivel — agregación de
  puntaje, decisión de superación, cálculo de estrellas, actualización del
  mejor progreso del jugador y desbloqueo de nivel/temática siguiente.

### Modified Capabilities
_(ninguna — `game-data-model` y `challenge-scoring` no cambian sus
requisitos: las tablas/columnas que usa esta RPC ya existen desde INT-74, y
la RLS de INT-77 sobre `progreso_usuario_nivel`/`intentos_nivel` ya permite
las lecturas/escrituras que la RPC hace en nombre del propio usuario)._

## Impact

- **Base de datos**: nueva migración con 1 función RPC
  (`cerrar_intento_nivel`). No cambia ninguna tabla ni policy — reutiliza
  las columnas de `intentos_nivel`/`progreso_usuario_nivel` ya creadas por
  INT-74.
- **App (Flutter)**: consumidor futuro de la RPC al terminar la secuencia de
  desafíos de un nivel (la integración de la app no es parte de este
  ticket).
- **Fuera de alcance**: qué desbloquea el primer nivel de la primera
  temática para un jugador nuevo (no hay intento previo que lo dispare); se
  asume que queda resuelto por seed/otro ticket, no por esta RPC.
