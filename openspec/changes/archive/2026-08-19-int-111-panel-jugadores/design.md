## Context

El panel ya tiene 3 RPCs `security definer` gateadas por `is_admin()` que agregan sobre todos los jugadores para alimentar pantallas de panel (`metricas_home`, `alertas_contenido`, `actividad_reciente`, INT-87) y una vista con el mismo patrón (`desafios_uso`). Las pantallas de listado existentes del panel (`Preguntas.tsx`, `Tematicas.tsx`) traen todo el conjunto en una consulta y filtran/ordenan/paginan en cliente — no hay precedente de paginación server-side en este panel.

El modelo de datos de jugador es más limitado que el mock: `profiles` solo tiene `id`, `nombre`, `avatar_url`, `role` (los jugadores son anónimos, sin email). No existe ningún concepto de "estado de cuenta" (activo/inactivo/suspendido) ni de sesión. La puntuación es por distancia al lugar real (`respuestas_desafio.puntos`), no un booleano de acierto — no hay un "% de acierto" nativo como el que muestra el mock.

## Goals / Non-Goals

**Goals:**
- Listar jugadores con datos reales agregados: alias, parada más avanzada, puntos totales, tasa de superación, última partida.
- Permitir a un admin reiniciar el progreso completo de un jugador (niveles, estrellas, puntos e historial de intentos) de forma atómica y auditada.
- Reproducir la estructura visual del mock (cabecera, KPIs, tabla, paginación, modal de confirmación) con los datos que sí existen.

**Non-Goals:**
- Estado de cuenta (activo/inactivo/suspendido) y la acción "Suspender cuenta" del mock — no hay soporte de datos ni lo pide el ticket.
- Selección múltiple / acciones en lote y exportar CSV — no los pide el ticket; se dejan para una historia futura si se decide construir esa base.
- Reinicio selectivo por temática/nivel o de dos niveles (solo progreso vs. progreso+estadísticas como en el mock) — se implementa un único reinicio total; el modelo de datos no distingue progreso de "estadísticas históricas" como filas separadas.
- Paginación server-side — se sigue el patrón ya usado por `Preguntas.tsx`/`Tematicas.tsx` (cliente).

## Decisions

**D1 — `jugadores_listado()` como RPC `security definer`, no vista.**
Sigue el patrón mayoritario de INT-87/INT-109 (`metricas_home`, `alertas_contenido`, `actividad_reciente`, `clasificacion_global`) en vez del patrón de `desafios_uso` (vista con `where is_admin()`). Sin parámetros, agrega sobre todos los jugadores con `role = 'jugador'`:
- `niveles_superados`: `count(*)` de `progreso_usuario_nivel` con `superado`.
- `parada_maxima`: `max(camino.orden)` entre los niveles superados del jugador (join `progreso_usuario_nivel` → `niveles` → `camino`), o `null` si no ha superado ninguno. Sustituye al "Nivel N" del mock (que en el mock es un contador de nivel plano; aquí es la posición más avanzada en el camino).
- `puntos_totales`: `sum(respuestas_desafio.puntos)` vía `intentos_nivel.usuario_id`, misma agregación que `clasificacion_global` (INT-109) — consistente con el ranking.
- `tasa_superacion`: `niveles_superados / niveles intentados` (nivel_id distintos en `intentos_nivel`), `null` si no hay ningún intento. Sustituye al "% de acierto" del mock: no existe un booleano de acierto por respuesta (la puntuación es por distancia), así que se redefine como tasa de superación de niveles — mismo concepto que ya usa `alertas_contenido` para "nivel con baja tasa de superación".
- `ultima_partida`: `max(intentos_nivel.fecha)`.

Filtrado, orden y paginación ocurren en el cliente (React), igual que `Preguntas.tsx`/`Tematicas.tsx`: no hay precedente de paginación server-side en este panel y el volumen de jugadores no lo justifica todavía.

**D2 — `reiniciar_progreso_jugador(p_jugador_id uuid)` como RPC `security definer`, borrado real (no "soft reset").**
En una única función transaccional (atomicidad por defecto de una función plpgsql):
1. Verifica `is_admin()`.
2. Verifica que `p_jugador_id` existe en `profiles` con `role = 'jugador'` (nunca se puede reiniciar una cuenta admin).
3. Inserta una fila en `auditoria_reinicio_progreso` con el alias actual del jugador (snapshot, ver D3) *antes* de borrar nada.
4. Borra `progreso_usuario_nivel where usuario_id = p_jugador_id` (vuelve el camino a "sin superar, sin estrellas").
5. Borra `intentos_nivel where usuario_id = p_jugador_id` (cascada a `respuestas_desafio` por FK existente `on delete cascade`) — pone los puntos totales y el historial de partidas a cero.
La cuenta (`profiles`/`auth.users`), el alias y el acceso del jugador no se tocan: solo se borra progreso y actividad de juego.

Alternativa descartada: dos ámbitos de reinicio como en el mock ("Solo progreso" vs. "Progreso y estadísticas"). El modelo de datos no separa "progreso" de "estadísticas históricas" en tablas distintas — `progreso_usuario_nivel` ya combina superación, estrellas y mejor puntaje. Introducir esa distinción exigiría un modelo nuevo sin que el ticket lo pida explícitamente; se deja fuera de alcance.

**D3 — Tabla de auditoría `auditoria_reinicio_progreso` sin FK de borrado en cascada sobre `jugador_id`.**
Columnas: `id uuid pk`, `admin_id uuid references profiles(id)`, `jugador_id uuid` (sin FK — si la cuenta del jugador se elimina más adelante por otra vía, el registro de auditoría debe sobrevivir), `alias_jugador text` (snapshot del alias en el momento del reinicio, para que el historial sea legible aunque el jugador cambie de alias o se borre la cuenta), `creado_en timestamptz default now()`. RLS: solo lectura para `is_admin()`, sin insert/update/delete directos (solo la RPC, que corre con privilegios de `postgres`, escribe en ella).

**D4 — Confirmación por escritura del alias, no solo una casilla.**
El mock usa una casilla "Entiendo que no se puede deshacer". Dado que aquí la acción borra datos de verdad (no es una simulación en memoria como en el mock), el modal exige teclear el alias exacto del jugador para habilitar el botón "Reiniciar progreso" — salvaguarda de UX contra un clic accidental sobre la fila equivocada en una tabla larga. La seguridad real de la operación la da el gate `is_admin()` en el servidor, no esta comprobación de cliente.

## Risks / Trade-offs

- [Riesgo] Reinicio ejecutado sobre el jugador equivocado, es irreversible → Mitigación: confirmación por escritura exacta del alias (D4) + la RPC valida `role = 'jugador'` antes de tocar nada.
- [Riesgo] Filtrado/orden/paginación 100% en cliente no escala si la base de jugadores crece mucho → Mitigación: aceptable ahora, mismo patrón que `Preguntas.tsx`/`Tematicas.tsx`; migrar a server-side sería un ticket futuro si el volumen lo exige.
- [Riesgo] "Tasa de superación" y "parada máxima" no son visualmente idénticos al "% acierto"/"Nivel N" del mock → Mitigación: son la sustitución más honesta con datos reales disponibles; se documenta explícitamente aquí y en la propuesta para que quien revise el mock entienda el porqué del cambio.
- [Riesgo] Borrar `intentos_nivel` de un jugador con muchas partidas puede ser una operación algo pesada → Mitigación: hay índice `intentos_nivel_usuario_id_idx` ya creado (INT-74); volumen esperado por jugador es bajo (decenas/cientos de intentos, no miles).

## Migration Plan

Una única migración SQL nueva (tabla + RLS + las 2 RPCs), sin migración de datos. Se aplica igual que el resto de migraciones del proyecto (`supabase db push` / pipeline existente). No hay rollback de los reinicios ya ejecutados (son irreversibles por diseño); el rollback de esquema, si hiciera falta, es un `drop function`/`drop table` estándar.
