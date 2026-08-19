## 1. Migración: funciones derivadas

- [x] 1.1 Crear migración `backend/supabase/migrations/<timestamp>_umbrales_estrellas_derivados.sql` con cabecera explicando el motivo (INT-115) y referencia a este design.md.
- [x] 1.2 `create function puntaje_maximo_por_desafio() returns integer immutable` = `calcular_puntaje(0, 0, 60)`, con comentario aclarando que el `60` es arbitrario.
- [x] 1.3 `create function estrellas_requeridas_por_orden(p_orden integer) returns integer immutable` = `floor((p_orden - 1) * 3 * 0.6)::integer`.
- [x] 1.4 `create function umbrales_parada(p_dificultad dificultad, p_preguntas_por_partida integer) returns table(maximo integer, minimo integer, umbral_estrella_2 integer, umbral_estrella_3 integer) immutable`, con los porcentajes fijos por dificultad (45/65/82, 50/68/85, 55/72/88, 58/76/91, 62/80/94) y `floor` en los tres umbrales.
- [x] 1.5 `grant execute` de las 3 funciones a `authenticated`.

## 2. Migración: `cerrar_intento_parada` y vistas

- [x] 2.1 `create or replace function cerrar_intento_parada`: resolver `camino_id`/`dificultad` primero, calcular `v_total_desafios` desde `intento_desafios`, y solo entonces llamar a `umbrales_parada(dificultad, v_total_desafios)` para obtener máximo/mínimo/★2/★3.
- [x] 2.2 Actualizar el bloque de desbloqueo de `cerrar_intento_parada`: `where estrellas_requeridas_por_orden(c.orden) <= v_estrellas_acumuladas_camino` en vez de `c.estrellas_requeridas`.
- [x] 2.3 Añadir `puntaje_maximo` a la respuesta `jsonb_build_object` de `cerrar_intento_parada`.
- [x] 2.4 `create or replace view camino_jugador`: sustituir las dos apariciones de `c.estrellas_requeridas` por `estrellas_requeridas_por_orden(c.orden)`.
- [x] 2.5 `create view camino_panel`: `id, orden, tematica_id, tematica_nombre, dificultad, nombre, activo, preguntas_por_partida, segundos_por_desafio, estrellas_requeridas_por_orden(orden) as estrellas_requeridas`, join con `tematicas`, ordenada por `orden`, misma RLS efectiva que `camino` (autenticados).

## 3. Migración: eliminar columnas almacenadas

- [x] 3.1 `alter table dificultad_defaults drop column puntaje_minimo_superar, drop column umbral_estrella_2, drop column umbral_estrella_3` (los 2 checks de orden ascendente desaparecen con las columnas).
- [x] 3.2 `alter table camino drop column puntaje_minimo_superar, drop column umbral_estrella_2, drop column umbral_estrella_3, drop column estrellas_requeridas` (los 2 checks de orden ascendente desaparecen con las columnas).
- [x] 3.3 Grep del repo entero por el literal `5500` tras la migración: confirmar que no aparece en ningún `.sql`/`.ts`/`.dart` (solo puede seguir en comentarios históricos de migraciones ya archivadas, no en código nuevo).

## 4. Panel: `lib/dificultadDefaults.ts`

- [x] 4.1 Reducir `DificultadDefault`, `DificultadDefaultRow` y `GuardarDificultadDefaultInput` a `preguntasPorPartida`/`segundosPorDesafio`.
- [x] 4.2 Reducir la query de `fetchDificultadDefaults` a esas 2 columnas.
- [x] 4.3 Reducir `validarDificultadDefault` a los 2 checks de entero positivo (quitar la validación de orden ascendente).
- [x] 4.4 Reducir el `update` de `guardarDificultadDefault` a esas 2 columnas.
- [x] 4.5 Añadir `fetchUmbralesParada(dificultad, preguntasPorPartida)` que llame a `supabase.rpc('umbrales_parada', { p_dificultad: dificultad, p_preguntas_por_partida: preguntasPorPartida })` y devuelva `{ maximo, minimo, umbralEstrella2, umbralEstrella3 }` (compartida con `camino.ts`).

## 5. Panel: `pages/DificultadDefaults.tsx`

- [x] 5.1 Quitar las 3 columnas/inputs de umbral de `FormFila`, `aForm`, la tabla y `handleGuardar`.
- [x] 5.2 Añadir, por fila, un bloque de solo lectura con el resultado de `fetchUmbralesParada` para el `preguntasPorPartida` actual del formulario (máximo, ★1, ★2, ★3).
- [x] 5.3 Recalcular ese bloque cuando cambie el campo `preguntasPorPartida` del formulario, antes de guardar (debounce de 250ms).

## 6. Panel: `lib/camino.ts`

- [x] 6.1 Quitar `puntajeMinimoSuperar`/`umbralEstrella2`/`umbralEstrella3` de `OverridesParada` y `CaminoRow`; quitar `estrellasRequeridas` de `PosicionCamino` y `CaminoRow`.
- [x] 6.2 Reescribir `fetchCamino()` para leer de la vista `camino_panel` (una sola consulta, sin el join manual a `tematicas`); `estrellasRequeridas` no se guarda en `PosicionCamino` en absoluto — se deriva siempre de `orden` en el momento de pintar (ver 6.3), para que un reorden optimista en el cliente no muestre un valor congelado.
- [x] 6.3 Añadir helper puro `calcularEstrellasRequeridas(orden: number): number` = `Math.floor((orden - 1) * 3 * 0.6)`, documentado como espejo de `estrellas_requeridas_por_orden`.
- [x] 6.4 Quitar `estrellas_requeridas: 0` del `insert` de `agregarParadaAlCamino`.
- [x] 6.5 Eliminar `actualizarEstrellasRequeridas` (export completo).
- [x] 6.6 Reducir `validarOverrides` a los 2 checks de entero positivo (quitar la validación de orden ascendente entre umbrales).
- [x] 6.7 Reducir el `update` de `actualizarOverridesParada` a `preguntas_por_partida`/`segundos_por_desafio`.
- [x] 6.8 Reutilizar `fetchUmbralesParada` de `dificultadDefaults.ts` desde `Camino.tsx` (mismo RPC que 4.5, sin duplicar).

## 7. Panel: `pages/Camino.tsx`

- [x] 7.1 Quitar la columna/input "Estrellas para desbloquear", `estrellasEditando`, `guardandoEstrellasIds` y `handleEstrellasBlur`; mostrar en su lugar `calcularEstrellasRequeridas(posicion.orden)` en solo lectura.
- [x] 7.2 Quitar `estrellasRequeridas: 0` del objeto optimista en `handleAgregar`.
- [x] 7.3 Reducir `PanelOverrides` a los 2 campos (`preguntasPorPartida`, `segundosPorDesafio`).
- [x] 7.4 Añadir el bloque informativo de umbrales derivados dentro de `PanelOverrides` (`BloqueUmbralesParada`: máximo, ★1/★2/★3 en puntos y %, "posición X de Y"), usando el `preguntasPorPartida` efectivo del formulario en curso (override si está relleno, si no el default de esa dificultad).
- [x] 7.5 Recalcular ese bloque cuando cambie `form.preguntasPorPartida`, antes de "Guardar overrides" (debounce de 250ms).

## 8. Tests de panel

- [x] 8.1 Actualizar `panel/src/lib/dificultadDefaults.test.ts`: quitar casos de los 3 campos eliminados y de la validación de orden ascendente; añadir test de `fetchUmbralesParada`.
- [x] 8.2 Actualizar `panel/src/lib/camino.test.ts`: quitar casos de los overrides de umbral y de `actualizarEstrellasRequeridas`; añadir test de `calcularEstrellasRequeridas` para varias posiciones (incluida `orden = 1` → 0).
- [x] 8.3 Actualizar `panel/src/pages/Camino.test.tsx`: quitar aserciones sobre el input de estrellas y los 3 campos de umbral en overrides; añadir aserciones sobre el bloque informativo y su recálculo en vivo. `npx vitest run` completo: 268/268 tests en verde.

## 9. Verificación de la app (sin cambios de código esperados)

- [x] 9.1 Ejecutar `app/test/resumen_nivel_screen_test.dart` y `app/test/nivel_juego_gateway_test.dart` sin modificar código de producción; confirman que siguen en verde con la nueva respuesta de `cerrar_intento_parada` (que añade `puntaje_maximo` pero no quita ni renombra nada existente).
- [x] 9.2 Ejecutar `app/test/camino_screen_test.dart` y el resto de tests que consumen `camino_gateway.dart`/`estrellas_requeridas`; confirman que siguen en verde (el contrato de columna de `camino_jugador` no cambia). `flutter test` completo: 320/320 en verde, sin tocar código de la app.

## 10. Verificación de aceptación

Migración aplicada al proyecto remoto (`supabase db push`, único entorno del
proyecto — confirmado con el usuario antes de ejecutar). Verificado en vivo
vía REST con un JWT de sesión anónima (sin mutar datos de partidas reales):

- [x] 10.1 Confirmado por introspección real: `select puntaje_minimo_superar` sobre `dificultad_defaults` devuelve `42703 column ... does not exist`; `select *` sobre `dificultad_defaults`/`camino` solo devuelve las columnas esperadas (2 overrides en cada una, sin umbrales ni `estrellas_requeridas`).
- [x] 10.2 `umbrales_parada` invocada para las 5 dificultades con sus `preguntas_por_partida` reales devuelve exactamente la tabla del proposal (p. ej. facil/8 → 44000/19800/28600/36080); por construcción (cada umbral es `floor(pct × maximo)` con `pct ≤ 1`) ningún umbral puede superar el máximo para ningún `preguntas_por_partida`.
- [x] 10.3 No verificado insertando en la tabla real (evita mutar el camino de producción). Verificado por construcción + inspección: `camino_panel`/`camino_jugador` llaman a `estrellas_requeridas_por_orden(c.orden)` en cada lectura, sin caché ni columna almacenada — confirmado contra `estrellas_requeridas_por_orden` para `orden` 1..10 (0,1,3,5,7,9,10,12,14,16) y contra las 5 primeras filas reales de `camino_panel`, cuyo `estrellas_requeridas` coincide con esa misma fórmula aplicada a su `orden` actual.
- [x] 10.4 Confirmado con los valores reales devueltos por `umbrales_parada`: ★3 > ★2 > mínimo en las 5 dificultades, y el porcentaje de ★3 (82/85/88/91/94%) crece monótonamente de Fácil a Muy difícil.
- [x] 10.5 Verificado por inspección del SQL (no se ejecutó un intento real): `camino_jugador.desbloqueado` sigue siendo `coalesce(pun.desbloqueado, false) OR estrellas_requeridas_por_orden(c.orden) <= ea.total` — el `OR` no se tocó, así que una posición ya desbloqueada en `progreso_usuario_nivel` se conserva sin importar el nuevo requisito derivado.
