## Context

El panel (React 19 + Vite + Tailwind + `@supabase/supabase-js`, sin capa de
estado global ni router de datos) ya tiene el listado de temáticas
(`/tematicas`, INT-85) y la pantalla de detalle/recorrido de un nivel
(`/niveles/:id`, INT-84, con su "Configuración del nivel": nombre, puntaje
mínimo, umbrales de estrellas). Falta la pantalla intermedia: el listado de
niveles de una temática concreta, punto de entrada para crear niveles y
llegar a su Recorrido.

El esquema ya cubre todo lo necesario: la tabla `niveles` (con `nombre`
opcional desde INT-84), sus políticas RLS de admin (INSERT/UPDATE/DELETE,
INT-77) y la RPC `reordenar_niveles(p_tematica_id, ids_en_orden)` (INT-87,
paralela a `reordenar_tematicas`) ya existen. No se necesita ninguna
migración.

El diseño de referencia (`[Admin] - Niveles.dc.html`, proyecto GeoQuest en
Claude Design) se importó vía el MCP `claude_design`
(`DesignSync.get_file` sobre el proyecto `d83d4c61-…`). El mock es un
componente autocontenido con datos de ejemplo embebidos (JS de
`DCLogic`/`sc-for`/`sc-if`), así que esta sección documenta cómo se traduce
ese comportamiento a componentes React reales sobre Supabase.

## Goals / Non-Goals

**Goals:**
- Pantalla `/tematicas/:id/niveles`: breadcrumb con enlace real a
  `/tematicas`, título "Niveles de «[temática]»", subtítulo con recuento
  (o con el requisito de estrellas de la temática cuando está vacía),
  botón "Nuevo nivel" y aviso de arrastre sobre la lista.
- Fila por nivel: asa de arrastre, posición en badge de 2 dígitos, nombre
  como enlace (o "Nivel N" si no tiene) con "Mínimo {puntaje} pts" y una
  frase de desbloqueo relativa al nivel anterior, badge de preguntas
  (resaltado en ámbar si tiene menos de 3), estado activo/inactivo de solo
  lectura, botón "Recorrido →" y eliminar con confirmación.
- Reorden por arrastre persistido vía `reordenar_niveles`, con reversión y
  error inline si falla.
- Modal centrado "Nuevo nivel" (un único campo: nombre) que crea el nivel
  en la última posición y navega a su Recorrido.
- Modal de confirmación de borrado a medida (no `window.confirm`), que
  recompacta el `orden` de los niveles restantes tras eliminar.
- Habilitar el enlace del nombre de temática en `/tematicas` (INT-85),
  que apunta a esta pantalla.

**Non-Goals:**
- No se edita puntaje mínimo, umbrales de estrellas ni preguntas desde
  este listado: esa configuración vive en el Recorrido (INT-84); el mock
  lo dice explícitamente en la nota bajo la lista y no se toca esa
  pantalla en este cambio.
- No se añade una forma de activar/desactivar un nivel: el propio mock
  trata el estado como derivado/de solo lectura (no hay control para
  cambiarlo) y hoy no existe en ningún sitio, ni siquiera en el Recorrido.
  Se deja constancia en Risks como hueco de producto.
- No se rediseña la navegación lateral del panel (`PanelLayout.tsx`): el
  mock incluye contadores por sección ("Jugadores 4907", "Preguntas 3⚠",
  etc.) que son ambientación del mock estático de cada pantalla, no un
  requisito de esta pantalla — mismo criterio que INT-84/INT-85, que solo
  tocaron el ítem de navegación de su propia pantalla. El ítem "Niveles"
  de la navegación sigue deshabilitado: incluso en el mock apunta a `#`,
  confirmando que no hay (ni lo pide el issue) un listado plano de todos
  los niveles de todas las temáticas.
- No se crea ninguna migración ni política de RLS nueva: tabla, columna
  `nombre` y RPC de reorden ya existen.

## Decisions

**Ruta anidada `/tematicas/:id/niveles`, no una ruta plana `/niveles`.**
Coherente con `/preguntas/:id/editar` y con que los niveles solo tienen
sentido dentro de una temática.

**Breadcrumb con enlace real a `/tematicas`, distinto del de
`NivelRecorrido.tsx`.** El mock enlaza "Temáticas" con un `<a>`. Se
implementa como `<Link to="/tematicas">` de `react-router-dom`. El
breadcrumb se renderiza una sola vez dentro del contenido de la página
(mismo patrón `<nav aria-label="Miga de pan">` de `Tematicas.tsx` /
`NivelRecorrido.tsx`), no en la cabecera fija de `PanelLayout` — el mock
muestra el breadcrumb también en su cabecera sticky, pero esa cabecera es
parte del componente compartido y tocarla afectaría a todas las pantallas
del panel; queda fuera de alcance de este cambio.

**Alta con umbrales en 0, no un asistente de configuración.** El modal
"Nuevo nivel" solo pide el nombre. `puntaje_minimo_superar` y los tres
`umbral_estrella_N` se insertan a `0` (satisface la cadena de checks
ascendente) y `activo = true` (default de la columna). Se crea en la
última posición (`orden` máximo de la temática + 1). Al guardar se navega
a `/niveles/:id` del nivel recién creado — el mock llama a esta acción
"Guardar y configurar" en vez de solo "Guardar", reflejando que el destino
es terminar la configuración ahí.

**Modal "Nuevo nivel" centrado, no un panel lateral como
`Tematicas.tsx`.** El mock lo dibuja como un diálogo centrado de ancho
máximo 460px anclado cerca de arriba, con el nombre de la temática y la
posición que ocupará el nuevo nivel en el copy — no como una edición
completa en panel lateral (que además no aplica: este modal solo crea,
nunca edita).

**Modal de confirmación de borrado a medida, no `window.confirm`.** El
mock especifica un diálogo con icono de aviso, el nombre del nivel, el
recuento de preguntas que se pierden y una nota de que el banco de
preguntas no se ve afectado — más rico que el `window.confirm` usado en
`Tematicas.tsx`. Se implementa como un componente de modal propio,
análogo en estructura al modal "Nuevo nivel" de esta misma pantalla.

**El copy de borrado no menciona el progreso de jugadores.** A diferencia
de `Tematicas.tsx` (que sí lo menciona porque una temática arrastra varios
niveles), el mock de esta pantalla solo advierte de la pérdida del
recorrido de preguntas y sus puntajes, y aclara que el banco de preguntas
no se ve afectado — se sigue el copy del mock tal cual en lugar de
añadir una mención adicional no pedida ni por el issue ni por el diseño.

**Recompactar el `orden` de los niveles restantes al eliminar.** El mock
dice explícitamente "Los niveles siguientes se recolocan en el recorrido
de la temática". Tras el `delete`, se hace un `select` de los niveles
restantes ordenados por `orden` y se llama a
`reordenar_niveles(tematica_id, idsEnOrden)` con esa lista — mismo patrón
que `quitarPreguntaDelRecorrido` en `nivelRecorrido.ts` tras quitar una
pregunta del recorrido.

**Navegación al Recorrido solo desde el nombre o el botón "Recorrido →",
no desde toda la fila.** El mock hace `<a>` el nombre del nivel y añade un
botón "Recorrido →" independiente; la fila en sí (asa, badge de posición,
badge de preguntas, estado, eliminar) no es un único elemento clicable.
Evita capturar clicks pensados para el asa de arrastre o el botón de
eliminar dentro de un contenedor clicable más grande.

**Aviso visual cuando un nivel tiene menos de 3 preguntas.** El mock tiñe
de ámbar el badge de recuento cuando `count < 3` (incluido 0). Se traduce
tal cual: es una señal útil para el admin de qué niveles necesitan más
contenido antes de publicarse, sin lógica de negocio nueva (solo estilo
condicional en el badge ya existente).

**Subtítulo con contexto de desbloqueo cuando la temática no tiene
niveles.** El mock, en el estado vacío, sustituye el recuento por
"Sin niveles todavía · desbloqueo a partir de {estrellas_requeridas}
estrellas en «{temática anterior}»" (u omite esa segunda parte si la
temática es la primera). Igual que en `Tematicas.tsx`, requiere conocer
`estrellas_requeridas` y `orden` de la temática actual, y el nombre de la
temática con `orden - 1` cuando no es la primera. Con niveles, el
subtítulo vuelve al recuento simple: "{n} niveles · {activos} activos ·
{preguntas} preguntas asignadas en total".

**Recuento de preguntas por nivel calculado en cliente.** `niveles` no
tiene columna de recuento; se hace un `select` de `nivel_desafios`
filtrado por los ids de niveles de la temática y se agrupa en cliente,
mismo patrón que el recuento de niveles por temática de `tematicas.ts`.

**Drag-and-drop nativo (HTML5) + botones subir/bajar.** Mismo patrón ya
usado en `Tematicas.tsx` y en el recorrido de preguntas de
`NivelRecorrido.tsx`: sin añadir `@dnd-kit`. Persistencia optimista: se
reordena en cliente y se llama a `reordenar_niveles(tematica_id,
idsEnOrden)` en segundo plano; si falla, se revierte y se muestra un
error inline. El mock no incluye botones subir/bajar (solo arrastre), pero
se mantienen por accesibilidad de teclado, igual que en `Tematicas.tsx` y
`NivelRecorrido.tsx`.

**Enlace del nombre de temática apunta directo a
`/tematicas/:id/niveles`.** Sustituye el `<span>` con tooltip
"Próximamente" de `Tematicas.tsx` (`FilaTematica`) por un `<Link>`.

## Risks / Trade-offs

- [No existe ninguna pantalla para activar/desactivar un nivel] → Aceptado
  (ni el issue ni el mock lo piden aquí); un nivel nuevo nace activo. Si
  se necesita, encajaría como campo en "Configuración del nivel" del
  Recorrido (INT-84), no en este listado.
- [Reordenar con actualización optimista puede desincronizarse si dos
  admins editan a la vez] → Aceptado: mismo supuesto sin multiusuario
  concurrente que el resto del panel.
- [Recompactar el orden al eliminar y reordenar por arrastre comparten la
  misma RPC pero se disparan por separado] → Aceptado: incoherencia
  momentánea solo si ambas operaciones se solapan en la misma sesión, caso
  ya aceptado en el resto del panel (sin multiusuario concurrente).

## Migration Plan

Ninguna. No hay cambios de esquema, RLS ni RPC: todo lo que usa esta
pantalla (`niveles`, sus políticas y `reordenar_niveles`) ya existe en
`main`.
