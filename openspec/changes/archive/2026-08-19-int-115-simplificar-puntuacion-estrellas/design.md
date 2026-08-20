## Context

Hoy `dificultad_defaults.{puntaje_minimo_superar,umbral_estrella_2,umbral_estrella_3}` y sus 3 overrides equivalentes en `camino`, más `camino.estrellas_requeridas`, son enteros absolutos sembrados/tecleados a mano. Ninguno de los dos depende de `preguntas_por_partida`, así que cambiarlo (el único knob real) desincroniza silenciosamente el máximo alcanzable de los umbrales. Los valores sembrados además se calcularon sobre `preguntas × 5000` (sin el bonus de rapidez de INT-99), por lo que los porcentajes reales ya están descuadrados entre dificultades hoy mismo.

`calcular_puntaje(distancia_km, segundos_transcurridos, segundos_por_desafio)` (INT-99, `20260818110000_temporizador_desafio_bonus_rapidez.sql:79`) ya es la única fuente de verdad del máximo por desafío: con distancia 0 y tiempo 0 devuelve `v_max + v_bonus_max = 5000 + 500 = 5500` para cualquier `segundos_por_desafio > 0` (la fracción de tiempo da 1 sin importar el denominador). `cerrar_intento_parada` (`20260818122000_dificultad_camino_rpcs_vistas.sql:119`) ya cuenta el número real de desafíos de la selección persistida (`intento_desafios`) antes de agregar el puntaje — ese conteo, no la config vigente, es la fuente correcta del tamaño de la parada para este cierre concreto.

## Goals / Non-Goals

**Goals:**
- Eliminar todo almacenamiento de umbrales de estrellas y de `estrellas_requeridas`; ambos se calculan en tiempo de lectura.
- Que el máximo por desafío se derive siempre de `calcular_puntaje`, sin ningún literal `5500`.
- Que el panel deje de ofrecer los campos eliminados y muestre en su lugar un bloque informativo derivado, recalculado en vivo.
- Preservar exactamente el contrato de respuesta que ya consume la app (`puntaje_minimo_superar`, `mejor_puntaje_anterior`, `estrellas_requeridas` vía `camino_jugador`), añadiendo solo el campo nuevo `puntaje_maximo`.

**Non-Goals:**
- No se toca `resumen_nivel_screen.dart` ni ninguna pantalla de la app para consumir `puntaje_maximo` (queda como candidato de seguimiento, ver nota de producto del issue).
- No se cambian las constantes de `calcular_puntaje` (`v_max`, `v_piso`, `v_bonus_max`) ni la fórmula de bonus por rapidez.
- No se re-calculan estrellas ni desbloqueos ya persistidos en intentos/progreso pasados.

## Decisions

### D1. Los umbrales se calculan sobre el tamaño real del intento (`intento_desafios`), no sobre la config vigente
`cerrar_intento_parada` ya cuenta `v_total_desafios` desde `intento_desafios` para verificar que el intento esté completo. Esa misma cifra —no `preguntas_por_partida` vigente en `camino`/`dificultad_defaults`— es la que se pasa a `umbrales_parada(dificultad, v_total_desafios)`. Alternativa descartada: usar el `preguntas_por_partida` efectivo vigente en el momento del cierre — se descarta porque un admin podría cambiarlo entre el `iniciar_intento_parada` y el `cerrar_intento_parada` de una partida en curso, cambiando retroactivamente el resultado de un intento ya jugado con un número fijo de preguntas.

### D2. Tres funciones SQL nuevas, todas `immutable`
- `puntaje_maximo_por_desafio()` → `calcular_puntaje(0, 0, 60)`. El `60` es arbitrario (cualquier `s > 0` da el mismo resultado, ver Context); se documenta en el comentario de la migración para que no se lea como un límite real.
- `estrellas_requeridas_por_orden(orden integer)` → `floor((orden - 1) * 3 * 0.6)::integer`.
- `umbrales_parada(dificultad, preguntas_por_partida integer)` → `table(maximo, minimo, umbral_estrella_2, umbral_estrella_3)`, con los porcentajes por dificultad como `case` interno (45/65/82, 50/68/85, 55/72/88, 58/76/91, 62/80/94) y `floor` en los tres umbrales.

Alternativa descartada: guardar los porcentajes en una tabla nueva. Se descarta porque el issue pide explícitamente que la curva "viva como constante en código" — no hay pantalla de admin para editarla, y una tabla sugeriría lo contrario.

### D3. `estrellas_requeridas` no se materializa ni con una columna generada
Postgres permite columnas `GENERATED ALWAYS AS (...) STORED`, que se recalculan solas — encajaría con "recolocar sin tocar nada". Se descarta de todas formas porque sigue siendo una columna almacenada en el sentido literal que los criterios de aceptación prohíben, y porque `camino_jugador` ya necesita la fórmula como expresión de lectura (no como columna) para combinarla con `desbloqueado`. Se opta por exponerla solo como expresión calculada: en `camino_jugador` (ya existe, solo cambia su cuerpo) y en una vista nueva `camino_panel` para el listado del panel (ver D4).

### D4. Vista `camino_panel` para el listado del admin
El panel no puede pedir a PostgREST una expresión SQL arbitraria sobre `camino` — necesita una vista o un RPC. `camino_jugador` no sirve para el panel: es por-usuario (`auth.uid()`) y no tiene sentido para un admin que no está jugando. Se crea `camino_panel` (misma RLS que `camino` hoy: lectura para cualquier autenticado, ver `game-data-model`) con `id, orden, tematica_id, tematica_nombre, dificultad, nombre, activo, preguntas_por_partida, segundos_por_desafio, estrellas_requeridas` (esta última vía `estrellas_requeridas_por_orden(orden)`), ordenada por `orden`. `panel/src/lib/camino.ts` pasa a leer de esta vista en vez de hacer el join `camino`+`tematicas` a mano en TypeScript — simplifica `fetchCamino()` a una sola consulta.

### D5. El panel pide los umbrales derivados al backend (RPC), no los recalcula con constantes propias
El bloque informativo (Dificultades y Camino) necesita el máximo por desafío y los tres umbrales. Duplicar el máximo (5500) en TypeScript violaría el criterio "ningún literal 5500 en ningún punto del código". Se expone `umbrales_parada` como función `security invoker` invocable vía `supabase.rpc('umbrales_parada', { p_dificultad, p_preguntas_por_partida })` — de solo lectura, sin efectos secundarios, permitida para cualquier autenticado (igual que ya se puede leer `dificultad_defaults`/`camino`). El panel la llama una vez por dificultad al cargar, y de nuevo cada vez que el admin cambia `preguntas_por_partida` en un formulario, antes de guardar.

`estrellas_requeridas_por_orden`, en cambio, sí se replica como una función pura en TypeScript (`Math.floor((orden - 1) * 3 * 0.6)`) en vez de pedirse por RPC: no depende de ninguna constante de puntuación (no hay riesgo de duplicar el `5500` prohibido), su único insumo (`orden`) ya viaja en cada fila de `camino_panel`, y evita una consulta de red por fila solo para pintar un número que ya se puede derivar localmente. Se documenta la fórmula en un único sitio (`panel/src/lib/camino.ts`) para que quede claro que debe permanecer sincronizada con `estrellas_requeridas_por_orden`.

### D6. `CREATE OR REPLACE VIEW camino_jugador` en vez de drop+create
La migración de INT-106 tuvo que hacer `drop view` + `create view` porque cambiaba nombres de columna. Aquí el nombre de columna (`estrellas_requeridas`) y su posición no cambian, solo la expresión que la produce — `CREATE OR REPLACE VIEW` lo permite sin dependencias que romper.

## Risks / Trade-offs

- **[Riesgo]** La fórmula de `estrellas_requeridas` vive duplicada en SQL (`estrellas_requeridas_por_orden`) y TypeScript (panel) → **Mitigación**: es aritmética trivial de un solo argumento (`orden`), sin ninguna constante de puntuación; un test de panel que compare ambos resultados para varios `orden` detecta cualquier desincronización.
- **[Riesgo]** `cerrar_intento_parada` cambia su orden de resolución (antes: umbrales primero, total_desafios después; ahora: `camino_id`/dificultad primero, total_desafios, luego umbrales) → **Mitigación**: los tests existentes de `level-progression` ya cubren los casos de intento incompleto/completo; se mantiene el mismo conjunto de excepciones (parada sin desafíos, intento incompleto).
- **[Riesgo]** Migración destructiva (`drop column` en 2 tablas) sin backfill de vuelta → **Mitigación**: es intencional (ver "Non-Goals"); los datos actuales de `intentos_nivel.estrellas_obtenidas`/`progreso_usuario_nivel` no dependen de las columnas eliminadas, solo se leyeron en el momento del cierre pasado.

## Migration Plan

1. Migración nueva: crear `puntaje_maximo_por_desafio()`, `estrellas_requeridas_por_orden(orden)`, `umbrales_parada(dificultad, preguntas_por_partida)`; `grant execute ... to authenticated` en las 3 (lectura pública para autenticados, igual que hoy `dificultad_defaults`/`camino`).
2. Misma migración: `create or replace function cerrar_intento_parada` con la nueva resolución (D1) y `puntaje_maximo` en la respuesta.
3. Misma migración: `create or replace view camino_jugador` sustituyendo `c.estrellas_requeridas` por `estrellas_requeridas_por_orden(c.orden)` en las dos apariciones (columna propia y cálculo de `desbloqueado`).
4. Misma migración: `create view camino_panel` (D4).
5. Misma migración, al final: `alter table dificultad_defaults drop column` × 3 (+ sus 2 checks, que se van solos con las columnas) y `alter table camino drop column` × 4 (+ sus 2 checks) — en ese orden, después de que las funciones/vistas que las sustituyen ya existan.
6. Panel: actualizar `lib/dificultadDefaults.ts`, `pages/DificultadDefaults.tsx`, `lib/camino.ts`, `pages/Camino.tsx` y sus tests en el mismo cambio (no hay periodo de compatibilidad — el panel se despliega junto con la migración).
7. Rollback: si hiciera falta revertir, restaurar las 5 columnas con sus valores sembrados originales (están en el historial de migraciones) y volver a los `create or replace` anteriores de `cerrar_intento_parada`/`camino_jugador` — no hay dato nuevo que perder porque nada de lo eliminado se escribía tras el seed inicial salvo por la propia UI del panel que este cambio retira.

## Open Questions

Ninguna: el issue ya fija los porcentajes por dificultad, la fórmula de `estrellas_requeridas` y el redondeo (`floor`) a aplicar en los tres casos.
