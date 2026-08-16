## Context

El panel (React 19 + Vite + Tailwind + `@supabase/supabase-js`, sin capa de
estado global ni router de datos) ya tiene el banco de preguntas
(`/preguntas`, `/preguntas/nueva`, `/preguntas/:id/editar`, INT-82/INT-83).
El modelo `tematicas → niveles → nivel_desafios → desafios`, la RPC
admin-only `reordenar_tematicas(ids_en_orden)` y el bucket de Storage
`challenge-media` (lectura pública, escritura solo admin) ya existen
(INT-74, INT-76, INT-87). No hay todavía pantalla de `Temáticas` ni de
`Niveles` — ambos ítems de navegación siguen deshabilitados en
`PanelLayout`. `Niveles` (listado dentro de una temática, INT-86) sigue sin
construirse, así que esta pantalla es la primera que expone `tematicas` en
el panel.

El diseño de referencia vive en Claude Design
(`[Admin] - Temáticas.dc.html`, proyecto GeoQuest) e incluye el listado con
drag handle, el panel lateral de alta/edición y el diálogo de confirmación
de borrado con su copy exacto.

## Goals / Non-Goals

**Goals:**
- Pantalla `/tematicas`: listado con reorden por drag-and-drop persistido
  vía `reordenar_tematicas`.
- Alta/edición en panel lateral (nombre, portada con previsualización,
  estrellas requeridas condicionadas a la posición, estado activo/inactivo).
- Subida de la imagen de portada reutilizando el bucket `challenge-media`
  bajo un prefijo nuevo (`tematicas/{tematica_id}.{extension}`).
- Eliminación con confirmación, mostrando el copy del diseño (niveles,
  asignaciones de preguntas y progreso de jugadores que se pierden; el
  banco de preguntas permanece intacto).
- Estado vacío con CTA y habilitación del enlace "Temáticas" en la nav.

**Non-Goals:**
- No se construye la pantalla de listado de niveles de una temática
  (INT-86). El nombre de cada fila queda preparado para enlazar ahí, pero
  se muestra deshabilitado ("Próximamente") en vez de apuntar a una ruta
  sin implementar.
- No se crea un bucket de Storage nuevo ni se tocan las políticas de RLS
  de `challenge-media`: se reutiliza tal cual con un prefijo de ruta
  distinto.
- No se añade ninguna librería de drag-and-drop ni de gestión de estado.
- No se recalcula automáticamente `estrellas_requeridas` de ninguna
  temática al reordenar (ver Risks).

## Decisions

**Drag-and-drop nativo (HTML5), sin dependencia nueva.** Mismo patrón que
INT-84 (`NivelRecorrido.tsx`): `draggable` + `onDragStart`/`onDragOver`/
`onDrop` sobre las filas, sin `@dnd-kit` ni librería equivalente. El repo
solo tiene 6 dependencias de producción y es una lista de un solo eje.

**Persistencia optimista del reorden.** Al soltar, la lista local se
reordena de inmediato y se llama a `reordenar_tematicas` en segundo plano;
si falla, se revierte al orden previo y se muestra un error inline. Mismo
patrón que `Preguntas.tsx`/`NivelRecorrido.tsx`, sin introducir una
librería de fetching/cache.

**Reutilizar `challenge-media` con un prefijo nuevo, en vez de un bucket
dedicado.** La portada de temática es una imagen estática con los mismos
límites que ya aplica el bucket (jpg/png/webp, 50 MiB) y las mismas reglas
de acceso (lectura pública, escritura solo admin). Crear un bucket
`topic-covers` exigiría duplicar las cuatro policies de RLS de
INT-76 para un contenido funcionalmente idéntico. Se sube bajo
`tematicas/{tematica_id}.{extension}` (paralelo a `{tipo}/{desafio_id}.{extension}`
de los desafíos) y se documenta como requisito ADDED en el delta de
`challenge-media-storage` para que el prefijo quede como contrato
explícito y no solo como convención implícita en el código.

**Recuento de niveles por temática calculado en cliente.** `tematicas` no
tiene columna de recuento; se obtiene con un `select` agrupado sobre
`niveles` (mismo enfoque que `fetchNivelesParaAsignar` en
`preguntaForm.ts`), evitando una vista o columna derivada nueva para un
dato que solo se lee en esta pantalla.

**Campo "estrellas requeridas" oculto y forzado a 0 en la primera
posición.** La RPC/lógica de desbloqueo (INT-79) nunca lee
`estrellas_requeridas` de la temática en `orden = 1` — la primera está
siempre desbloqueada por diseño del esquema. El formulario oculta el campo
cuando la temática editada ocupa (o va a ocupar, si es nueva) la posición 1
y persiste `0`, igual que hace el mock de diseño, para no dejar un valor
visualmente inconsistente con "Sin requisito" en el listado.

**Validación de imagen acotada a este módulo.** Se añade un validador de
mimetype/tamaño en `tematicas.ts` en vez de reutilizar
`validarArchivoMedia` de `preguntaForm.ts` (que también contempla vídeo):
la portada de temática solo admite imagen, y evita acoplar un módulo de
dominio a otro por una función de ~10 líneas.

**Enlace del nombre deshabilitado hasta INT-86.** Igual que el breadcrumb
sin enlaces de INT-84: se muestra el nombre con estilo de "próximamente"
(tooltip) en vez de un `<Link>` a una ruta que no existe todavía. Cuando
INT-86 exista, se puede convertir en enlace real sin tocar el resto de la
pantalla.

## Risks / Trade-offs

- [Drag-and-drop HTML5 nativo no es accesible por teclado] → Se mantienen
  botones de "subir/bajar posición" por fila junto al asa de arrastre,
  igual que en INT-84.
- [Reordenar con optimistic update puede desincronizarse si dos admins
  editan a la vez] → Aceptado: no hay multiusuario concurrente real en
  este panel (mismo supuesto que el resto de pantallas).
- [Al reordenar, la temática que deja de ser la primera conserva el valor
  de `estrellas_requeridas` que tenía antes (potencialmente `0`)] →
  Aceptado: el admin lo edita manualmente si hace falta; no se recalcula
  automáticamente para evitar un efecto secundario implícito y sorprendente
  al arrastrar.

## Migration Plan

Sin migraciones de esquema ni de Storage: la RPC de reorden, la tabla
`tematicas` y el bucket ya existen. El único cambio de "infraestructura" es
documental — el delta de `challenge-media-storage` que añade el prefijo
`tematicas/` como ruta válida del bucket existente.
