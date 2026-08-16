## 1. Módulo de datos (`lib/niveles.ts`)

- [x] 1.1 `fetchNivelesTematica(tematicaId)`: trae la temática actual
      (nombre, orden, estrellas_requeridas), la temática anterior (nombre,
      solo si `orden > 1`) para el subtítulo del estado vacío, y sus
      niveles (id, nombre, orden, puntaje_minimo_superar, activo)
      ordenados por `orden`, más el recuento de preguntas por nivel
      calculado en cliente a partir de `nivel_desafios`.
- [x] 1.2 `crearNivel(tematicaId, nombre)`: inserta un nivel en la última
      posición (`orden` = máximo existente en esa temática + 1) con
      `puntaje_minimo_superar` y los tres `umbral_estrella_N` en 0;
      devuelve el id creado.
- [x] 1.3 `eliminarNivel(tematicaId, id)`: borra el nivel y luego
      recompacta el `orden` de los niveles restantes de la temática
      llamando a `reordenarNiveles` con la lista restante ordenada (mismo
      patrón que `quitarPreguntaDelRecorrido` en `nivelRecorrido.ts`).
- [x] 1.4 `reordenarNiveles(tematicaId, idsEnOrden)`: invoca la RPC
      `reordenar_niveles`.
- [x] 1.5 Tests unitarios de `lib/niveles.ts` (`niveles.test.ts`): fetch
      con recuento de preguntas y temática anterior, alta con
      orden/umbrales por defecto, eliminación con recompactación de
      orden, y reorden (éxito y error).

## 2. Pantalla `NivelesTematica.tsx`

- [x] 2.1 Breadcrumb "Temáticas › [temática]" (enlace real a `/tematicas`)
      y cabecera con título "Niveles de «[temática]»", subtítulo dinámico
      (recuento, o contexto de desbloqueo si no hay niveles) y botón
      "Nuevo nivel".
- [x] 2.2 Aviso de arrastre sobre la lista ("Arrastra por el asa…").
- [x] 2.3 Fila por nivel: asa de arrastre + botones subir/bajar, badge de
      posición (2 dígitos), nombre como enlace (o "Nivel N") con "Mínimo
      {puntaje} pts" y la frase de desbloqueo relativa al nivel anterior,
      badge de preguntas (resaltado en ámbar si `< 3`), estado
      activo/inactivo de solo lectura, botón "Recorrido →" y botón
      eliminar. Solo el nombre y el botón "Recorrido →" navegan a
      `/niveles/:id`; el resto de la fila no.
- [x] 2.4 Nota bajo la lista aclarando que puntaje/umbrales/preguntas se
      editan dentro del Recorrido.
- [x] 2.5 Reorden por arrastre con actualización optimista y reversión +
      mensaje de error si `reordenarNiveles` falla.
- [x] 2.6 Modal centrado "Nuevo nivel" (campo único: nombre, con el
      nombre de la temática y la posición que ocupará en el copy) que al
      guardar crea el nivel y navega a `/niveles/:id` del nivel recién
      creado.
- [x] 2.7 Modal de confirmación de borrado a medida (recuento de
      preguntas que se pierden, aviso de que el banco de preguntas no se
      ve afectado) y manejo de error de eliminación por fila.
- [x] 2.8 Estado vacío con CTA "Crear el primer nivel" cuando la temática
      no tiene niveles.
- [x] 2.9 Tests de `NivelesTematica.tsx` (`NivelesTematica.test.tsx`):
      listado, nombre por defecto, recuento de preguntas y su resaltado
      por debajo de 3, navegación al Recorrido solo desde nombre/botón,
      alta con navegación automática, reorden y su reversión en error, y
      confirmar/cancelar borrado con recompactación de orden.

## 3. Enrutado y enlace desde Temáticas

- [x] 3.1 Añadir la ruta `/tematicas/:id/niveles` en `App.tsx`.
- [x] 3.2 En `Tematicas.tsx` (`FilaTematica`), sustituir el `<span>` con
      tooltip "Próximamente" por un `<Link>` a `/tematicas/:id/niveles`.
- [x] 3.3 Actualizar `Tematicas.test.tsx` para reflejar el enlace habilitado
      (elimina/ajusta el test que verificaba el estado deshabilitado).

## 4. Verificación

- [x] 4.1 `npm run typecheck`, `npm run lint` y `npm run test` en `panel/`.
- [x] 4.2 `npm run test:coverage` en `panel/` y confirmar que no baja el
      umbral existente.
- [x] 4.3 `npm run format:check` en `panel/`.
