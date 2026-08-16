## 1. Base de datos

- [x] 1.1 Migración: `alter table niveles add column nombre text;` (nullable,
      sin default), sin cambios de RLS.

## 2. Capa de datos (panel/src/lib)

- [x] 2.1 `nivelRecorrido.ts`: `fetchNivelRecorrido(id)` — trae el nivel
      (con `nombre`, `orden`, `puntaje_minimo_superar`,
      `umbral_estrella_1/2/3`), su temática (`tematicas.nombre`) y sus
      preguntas asignadas ordenadas por `orden` (join `nivel_desafios` +
      `desafios`: tipo, nombre_lugar, imagen_url).
- [x] 2.2 `guardarConfiguracionNivel(id, config)` — valida orden ascendente
      de umbrales y actualiza la fila de `niveles`.
- [x] 2.3 `fetchPreguntasNoAsignadas(nivelId)` — preguntas del banco
      (`desafios`) cuyo `id` no aparece en `nivel_desafios` para ese nivel.
- [x] 2.4 `agregarPreguntaAlRecorrido(nivelId, desafioId)` — inserta en
      `nivel_desafios` con `orden = max(orden) + 1` para ese nivel.
- [x] 2.5 `quitarPreguntaDelRecorrido(nivelId, desafioId)` — borra la fila de
      `nivel_desafios` y llama a `reordenar_preguntas_nivel` con los
      `desafio_id` restantes para compactar el `orden`.
- [x] 2.6 `reordenarRecorrido(nivelId, idsEnOrden)` — llama a la RPC
      `reordenar_preguntas_nivel`.

## 3. Pantalla `NivelRecorrido`

- [x] 3.1 Ruta `/niveles/:id` en `App.tsx` (dentro de `RequireAuth` +
      `PanelLayout`, igual que `/preguntas/:id/editar`).
- [x] 3.2 Breadcrumb informativo "Temáticas > [temática] > [nivel]" (texto,
      sin enlaces); "[nivel]" usa `nombre` si existe, si no "Nivel {orden}".
- [x] 3.3 Tarjeta "Configuración del nivel": campos nombre/umbrales,
      validación de orden ascendente, botón "Guardar cambios" con estados de
      carga/error (patrón de `PreguntaForm.tsx`).
- [x] 3.4 Contador "X preguntas en este recorrido".
- [x] 3.5 Lista arrastrable (HTML5 `draggable`) de preguntas asignadas:
      posición, miniatura (imagen o ícono según tipo, reutilizando el
      patrón de `Miniatura`/`IconoTipo` de `Preguntas.tsx`), nombre del
      lugar, badge de tipo; botones "subir"/"bajar" como alternativa
      accesible al arrastre.
- [x] 3.6 Acción "Quitar del recorrido" por fila, con confirmación y manejo
      de error de fila (patrón `rowErrors` de `Preguntas.tsx`).
- [x] 3.7 Botón "Añadir pregunta existente": panel embebido con buscador +
      lista con checkbox sobre `fetchPreguntasNoAsignadas`, inserta al
      confirmar.
- [x] 3.8 Botón "Crear pregunta nueva" que navega a `/preguntas/nueva`.
- [x] 3.9 Estado vacío del recorrido con ambas llamadas a la acción.

## 4. Tests

- [x] 4.1 Tests de `nivelRecorrido.ts` (carga, guardado de configuración,
      validación de umbrales, añadir/quitar/reordenar preguntas).
- [x] 4.2 Tests de `NivelRecorrido.tsx` (render de configuración, guardado,
      añadir/quitar pregunta, reorden, estado vacío, breadcrumb).

## 5. Verificación

- [x] 5.1 `npm run typecheck`, `npm run lint`, `npm run test:coverage` en
      `panel/`.
- [ ] 5.2 Prueba manual local: crear/editar configuración de un nivel,
      añadir/quitar/reordenar preguntas de su recorrido.
