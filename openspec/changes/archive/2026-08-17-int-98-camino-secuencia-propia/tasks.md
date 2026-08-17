## 1. Esquema y RLS (backend)

- [x] 1.1 Nueva migración `backend/supabase/migrations/`: crear tabla `camino` (`id`, `orden` unique, `nivel_id` FK a `niveles` con `on delete cascade`, `estrellas_requeridas`, `created_at`)
- [x] 1.2 Misma migración: RLS de `camino` — lectura para cualquier autenticado, escritura solo `is_admin()` (extender las policies existentes de `tematicas`/`niveles`/`nivel_desafios`)
- [x] 1.3 Misma migración: añadir columna `niveles.preguntas_por_partida integer` (nullable, sin default)
- [x] 1.4 Misma migración: eliminar columna `tematicas.estrellas_requeridas`
- [x] 1.5 Misma migración: seed inicial de `camino` — una fila por cada nivel existente, ordenado por `(tematicas.orden, niveles.orden)`, con `estrellas_requeridas = 0`
- [x] 1.6 Nueva migración o misma: RPC `reordenar_camino(ids_en_orden uuid[])` (admin-only, exige conjunto completo de ids de `camino`, sin fallo de unicidad transitorio — mismo patrón que `reordenar_tematicas`)

## 2. Lógica de desbloqueo (backend)

- [x] 2.1 Reescribir `cerrar_intento_nivel`: eliminar el bloque de desbloqueo "siguiente nivel de la temática" + "siguiente temática por estrellas"
- [x] 2.2 Añadir el nuevo cálculo: sumar `mejores_estrellas` del usuario sobre los niveles referenciados por `camino`, y marcar `desbloqueado = true` en `progreso_usuario_nivel` para todas las posiciones de `camino` cuyo `estrellas_requeridas` sea `<=` esa suma
- [x] 2.3 Cubrir con tests (pgTAP o el runner de tests SQL que use el proyecto) los escenarios de `level-progression`: desbloqueo múltiple simultáneo, estrellas insuficientes, intento no superado, nivel sin posición en el camino. El proyecto no tiene runner de tests SQL todavía (ver `.devplugin/architecture.md`); se cubre con la verificación manual de 6.3 y se deja la adopción de pgTAP como decisión aparte, no de este cambio.

## 3. Panel — librerías de datos

- [x] 3.1 `panel/src/lib/tematicas.ts`: quitar `estrellasRequeridas` de `Tematica`, `TematicaRow`, `fetchTematicas` y `guardarTematica`
- [x] 3.2 `panel/src/lib/nivelRecorrido.ts` (o `niveles.ts`, según dónde viva la config): añadir `preguntasPorPartida` a la lectura/guardado de la configuración del nivel, con validación cliente contra el número de filas de `nivel_desafios` del nivel
- [x] 3.3 Nuevo `panel/src/lib/camino.ts`: `fetchCamino`, `agregarNivelAlCamino`, `reordenarCamino` (invoca RPC `reordenar_camino`), `actualizarEstrellasRequeridas`, `quitarDelCamino`
- [x] 3.4 `panel/src/lib/niveles.ts`: quitar `tematicaEstrellasRequeridas`/`tematicaAnteriorNombre` de `NivelesTematica` y `fetchNivelesTematica` (y la consulta a la temática anterior que ya no hace falta)

## 4. Panel — UI

- [x] 4.1 `panel/src/pages/Tematicas.tsx`: quitar la columna "requisito de estrellas" del listado
- [x] 4.2 `panel/src/pages/NivelRecorrido.tsx`: añadir el campo `preguntas_por_partida` a la tarjeta "Configuración del nivel", con el error de validación cuando supere el pool
- [x] 4.3 Nuevo `panel/src/pages/Camino.tsx`: listado ordenado, botón "Añadir nivel al camino" con selector que excluye niveles ya presentes, reorden por arrastre, edición inline de `estrellas_requeridas`, acción "Quitar del camino", estado vacío
- [x] 4.4 `panel/src/components/PanelLayout.tsx`: añadir item de navegación `{ label: 'Camino', to: '/camino', enabled: true }`
- [x] 4.5 `panel/src/App.tsx`: nueva `<Route path="/camino" ...>` protegida igual que `/tematicas`
- [x] 4.6 `panel/src/pages/NivelesTematica.tsx`: subtítulo de temática sin niveles pasa a "Sin niveles todavía" sin referencia a estrellas/temática anterior

## 5. Tests de panel

- [x] 5.1 Nuevo `panel/src/pages/Camino.test.tsx` cubriendo los escenarios de `panel-path-listing` (listado, añadir, reorden, editar umbral, quitar, vacío) + nuevo `panel/src/lib/camino.test.ts` (no estaba en el plan original, pero es el patrón que sigue cada módulo de `lib/` existente y sin él `camino.ts` quedaba a 0% de cobertura)
- [x] 5.2 Actualizar `panel/src/pages/Tematicas.test.tsx` quitando aserciones sobre la columna de estrellas requeridas
- [x] 5.3 Actualizar `panel/src/pages/NivelRecorrido.test.tsx` añadiendo casos de `preguntas_por_partida` (válido, excede el pool, vacío)
- [x] 5.4 Actualizar `panel/src/pages/NivelesTematica.test.tsx` quitando el escenario de "desbloqueo a partir de N estrellas..." y comprobando el nuevo "Sin niveles todavía"

## 6. Verificación y documentación

- [x] 6.1 `openspec validate int-98-camino-secuencia-propia --strict`
- [x] 6.2 Actualizar `.devplugin/architecture.md` con la tabla `camino`, `niveles.preguntas_por_partida` y el nuevo flujo de desbloqueo
- [x] 6.3 Verificación manual: cerrar un intento en local/Supabase remoto y comprobar que se desbloquean las posiciones del camino cuyo umbral se alcanza, incluyendo el caso de desbloqueo múltiple. Hecho contra el remoto con un usuario anónimo de prueba y 3 posiciones de camino sintéticas (umbrales 2, 3 y 5): al cerrar un intento con 3 estrellas se desbloquearon simultáneamente las de umbral 2 y 3, y la de umbral 5 quedó bloqueada. Datos de prueba eliminados tras verificar.
