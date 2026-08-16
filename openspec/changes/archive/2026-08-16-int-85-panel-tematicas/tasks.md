## 1. Capa de datos (panel/src/lib/tematicas.ts)

- [x] 1.1 `fetchTematicas()` — trae todas las temáticas ordenadas por
      `orden`, junto con el recuento de niveles de cada una (agregado sobre
      `niveles.tematica_id`).
- [x] 1.2 `validarImagenPortada(file)` — valida mimetype
      (`image/jpeg`/`image/png`) y tamaño máximo (4 MB), devolviendo un
      mensaje de error o `null`.
- [x] 1.3 `subirPortadaTematica(id, file)` — sube el archivo a
      `tematicas/{id}.{extension}` en el bucket `challenge-media` y
      devuelve la URL pública.
- [x] 1.4 `guardarTematica(input)` — crea o actualiza la fila de
      `tematicas`; si la posición (existente o de alta) es `orden = 1`,
      persiste `estrellas_requeridas = 0` sin importar el valor del
      formulario. Al crear, asigna `orden = max(orden) + 1`.
- [x] 1.5 `eliminarTematica(id)` — borra la fila de `tematicas` (cascada ya
      cubierta por las FK de `niveles`/`nivel_desafios`/`intentos_nivel`/
      `progreso_usuario_nivel`); propaga el error tal cual si la borra
      falla.
- [x] 1.6 `reordenarTematicas(idsEnOrden)` — llama a la RPC
      `reordenar_tematicas`.

## 2. Pantalla `Tematicas` — listado

- [x] 2.1 Ruta `/tematicas` en `App.tsx` (dentro de `RequireAuth` +
      `PanelLayout`) y habilita el enlace "Temáticas" en
      `PanelLayout.tsx`.
- [x] 2.2 Listado con fila por temática: portada, nombre (con indicación
      "Próximamente" en vez de enlace — INT-86 aún no existe), requisito
      de estrellas ("Sin requisito" si `orden = 1`), recuento de niveles,
      estado activo/inactivo, acciones editar/eliminar.
- [x] 2.3 Reorden por arrastre (HTML5 `draggable`, mismo patrón que
      `NivelRecorrido.tsx`): actualización optimista de la lista local +
      llamada a `reordenarTematicas`, con revert y mensaje de error si
      falla.
- [x] 2.4 Estado vacío con CTA "Crear la primera temática" cuando no hay
      ninguna.

## 3. Panel lateral de alta/edición

- [x] 3.1 Botón "Nueva temática" y acción "Editar" por fila abren el panel
      lateral (overlay + panel deslizante, mismo patrón visual del
      diseño), precargado en modo edición.
- [x] 3.2 Campo nombre (obligatorio) y campo de portada con subida +
      previsualización (usa `validarImagenPortada`/`subirPortadaTematica`;
      obligatoria al crear, opcional al editar).
- [x] 3.3 Campo "Estrellas requeridas": oculto cuando la temática editada
      (o la que se va a crear) ocupa la posición 1; visible con validación
      `>= 0` en el resto de casos.
- [x] 3.4 Toggle de estado activo/inactivo (activo por defecto al crear).
- [x] 3.5 Guardar (crea/actualiza vía `guardarTematica`, cierra el panel y
      refresca el listado; en error, mantiene el panel abierto con los
      datos y muestra el mensaje) y Cancelar (cierra sin persistir).

## 4. Eliminación con confirmación

- [x] 4.1 Diálogo de confirmación con el copy del diseño: advierte del
      borrado en cascada de los niveles de la temática, sus asignaciones
      de preguntas y el progreso de jugadores, aclarando que el banco de
      preguntas no se ve afectado.
- [x] 4.2 Confirmar invoca `eliminarTematica` y refresca el listado;
      cancelar cierra el diálogo sin cambios.

## 5. Tests

- [x] 5.1 Tests de `tematicas.ts`: listado con recuento de niveles,
      validación/subida de portada, guardar (incluyendo forzado de
      `estrellas_requeridas = 0` en `orden = 1`), eliminar, reordenar.
- [x] 5.2 Tests de `Tematicas.tsx`: render del listado, estado vacío,
      alta/edición en el panel lateral, campo de estrellas
      oculto/visible según posición, reorden por arrastre (con y sin
      error), eliminación con confirmación, enlace de nav habilitado.

## 6. Verificación

- [x] 6.1 `npm run typecheck`, `npm run lint`, `npm run test:coverage` en
      `panel/`.
- [ ] 6.2 Prueba manual local: crear, editar, reordenar y eliminar
      temáticas; verificar el campo de estrellas oculto en la primera
      posición y el estado vacío inicial.
