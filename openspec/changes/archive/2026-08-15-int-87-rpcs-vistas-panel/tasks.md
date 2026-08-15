## 1. Verificación previa

- [x] 1.1 Confirmar contra el proyecto remoto (`pg_constraint`) los nombres reales de los constraints `unique` de `orden` en `tematicas`, `niveles` y `nivel_desafios` creados en INT-74 — confirmados sin cambios: `tematicas_orden_key`, `niveles_tematica_id_orden_key`, `nivel_desafios_nivel_id_orden_key`

## 2. Migración: constraints diferibles

- [x] 2.1 `DROP CONSTRAINT` + `ADD CONSTRAINT ... UNIQUE (...) DEFERRABLE INITIALLY IMMEDIATE` para los 3 constraints de `orden` verificados en 1.1 (`ALTER TABLE ... ALTER CONSTRAINT` solo admite foreign keys en Postgres, confirmado con un intento fallido contra el remoto — ver D1 corregido en design.md)

## 3. RPCs de reorden

- [x] 3.1 `reordenar_tematicas(ids_en_orden uuid[])`: check `is_admin()`, valida conjunto completo, `set constraints ... deferred`, `UPDATE ... FROM unnest(...) WITH ORDINALITY`
- [x] 3.2 `reordenar_niveles(p_tematica_id uuid, ids_en_orden uuid[])`: igual que 3.1, acotado a `tematica_id`
- [x] 3.3 `reordenar_preguntas_nivel(p_nivel_id uuid, ids_en_orden uuid[])`: igual, sobre `nivel_desafios` acotado a `nivel_id`, `ids_en_orden` son `desafio_id`

## 4. Funciones de agregado (métricas y alertas)

- [x] 4.1 `metricas_home()`: `security definer`, check `is_admin()` al principio, calcula `jugadores_totales` / `jugadores_activos_7d` / `partidas_hoy` / `niveles_activos`
- [x] 4.2 `alertas_contenido()`: `security definer`, check `is_admin()` al principio, fila por nivel con tasa de superación < 40% y ≥ 5 intentos (`tipo = 'nivel_baja_tasa'`)
- [x] 4.3 Extender `alertas_contenido()` con fila por desafío activo con contenido vacío según tipo o coordenadas `(0, 0)` (`tipo = 'desafio_incompleto'`) — refactorizado tras revisión adversarial: `campo_faltante` se calcula una vez en un `LATERAL` y el `WHERE` filtra sobre ese resultado, en vez de duplicar la condición en un `CASE` sin `ELSE` y en un `WHERE` aparte

## 5. Vista de uso de desafíos

- [x] 5.1 Vista `desafios_uso`: `LEFT JOIN` de `desafios` con `nivel_desafios` agrupado, `where is_admin()`, `usos = 0` para desafíos sin asignar

## 6. Migración y verificación remota

- [x] 6.1 Escribir la migración completa en `backend/supabase/migrations/`, aplicar con `supabase db push`
- [x] 6.2 `supabase db lint --linked` — sin errores
- [x] 6.3 Verificación manual contra remoto (mismo patrón que INT-77): usuarios de prueba admin y jugador vía Auth API. Jugador rechazado (P0001) en `metricas_home`, `alertas_contenido`, `reordenar_tematicas`, `reordenar_niveles`; `desafios_uso` le devuelve `[]` pese a haber datos. Admin obtiene resultados correctos en las 6 RPC/funciones/vista. Con 22 `intentos_nivel` de fixture sobre 3 niveles (uno activo con tasa 30%, uno idéntico pero inactivo, uno activo con solo 2 intentos), `alertas_contenido` marca `nivel_baja_tasa` únicamente en el primero — excluye correctamente el inactivo y el de muestra insuficiente — y `metricas_home` devuelve `jugadores_activos_7d`/`partidas_hoy`/`niveles_activos` exactos sobre esos datos. Datos y usuarios de prueba borrados al terminar
- [x] 6.4 Verificación manual del reorden con intercambio de posiciones (caso D1/D2 de design.md): swap de 2 temáticas, swap de 2 niveles de una misma temática y swap de 2 desafíos de un nivel, sin error de unicidad; conjunto incompleto/con id ajeno rechazado sin tocar filas

## 7. Documentación

- [x] 7.1 Actualizar `.devplugin/architecture.md`: registrar INT-87 en la fila de `backend/` de la tabla de Módulos
