## Context

El panel (INT-81) ya tiene `PanelLayout` (nav lateral + header) y el patrón
de página establecido en `Home.tsx`/`dashboard.ts`: un módulo en
`panel/src/lib/` con funciones `fetchX()` que envuelven `supabase.from(...)`/
`supabase.rpc(...)` y devuelven objetos camelCase, y una página en
`panel/src/pages/` que consume esos fetchers con `useEffect`/`useState`
(sin librería de fetching de datos, sin store global).

El esquema relevante (`game-data-model`, `challenge-usage`) ya existe:
`desafios` (banco, sin FK a nivel), `nivel_desafios` (asignación N:M
desafío↔nivel con `orden` propio), `niveles` (FK a `tematicas`). Un admin
puede leer `desafios` directamente (RLS ya lo permite) y borrar filas de
`desafios`, `nivel_desafios`, etc. `nivel_desafios.desafio_id` y
`respuestas_desafio.desafio_id` referencian `desafios` con
`on delete restrict`, así que Postgres rechaza borrar un desafío en uso o
con historial de respuestas.

El mockup de Claude Design (`[Admin] - Preguntas - Listado.dc.html`) modela
cada fila como una asignación desafío↔nivel (columnas "Temática › Nivel" +
"Orden"), pero el checklist del issue pide una fila por desafío con
indicador de reutilización y un filtro "sin asignar" — confirmado con el
usuario que el modelo correcto es **una fila por desafío del banco**, no
por asignación (ver decisión D1).

## Goals / Non-Goals

**Goals:**
- Listar el banco completo de desafíos con búsqueda, filtros combinables y
  paginación, en el mismo estilo visual que el mockup (colores, tipografía,
  badges de tipo, estado vacío).
- Mostrar cuántos niveles usan cada desafío y el detalle de cuáles.
- Permitir borrar un desafío del banco, con confirmación y manejo legible
  del error cuando la base de datos lo rechaza por estar referenciado.
- Habilitar la entrada de navegación "Preguntas/Desafíos".

**Non-Goals:**
- Crear o editar desafíos (INT-83). "Nueva pregunta" y "Editar" quedan
  deshabilitados con el mismo patrón `aria-disabled`/"Próximamente" que ya
  usa `Home.tsx` para sus accesos rápidos.
- Reordenar desafíos dentro de un nivel (ya cubierto por
  `reordenar_preguntas_nivel`, capability `content-reordering`, y vive en la
  pantalla de detalle del nivel — INT-84).
- Paginación/filtrado en servidor: se trae el banco completo (lecturas
  ligeras, sin joins pesados) y se pagina/filtra en cliente, igual que hace
  el propio mockup y en línea con el volumen esperado (banco de un solo
  proyecto de contenido, no miles de filas).
- Rediseño del sidebar (agrupación "Contenido", badges de conteo, caja
  "Estado del juego" del mockup): mismo alcance que INT-81, que ya optó por
  mantener el `PanelLayout` existente en vez de replicar el sidebar más
  elaborado de los mockups.

## Decisions

**D1 — Una fila por desafío, no por asignación a nivel.**
El mockup usa datos de demostración donde cada desafío pasa a estar en un
único nivel, así que nunca ejercita la reutilización. El checklist del
issue ("en cuántos niveles se usa... con detalle al pasar el cursor o al
abrir", "sin asignar a ningún nivel") solo tiene sentido con una fila por
desafío. Se sustituyen las columnas "Temática › Nivel" y "Orden" del
mockup por una columna "Usado en" (N niveles / "Sin asignar") con detalle
en un desplegable (no tooltip nativo, para que sea accesible por teclado y
testeable con Testing Library) que lista cada `Temática · Nivel`.
Alternativa descartada: replicar el mockup literalmente (una fila por
asignación) — se descartó por no cubrir el requisito explícito del issue y
por confundir al admin con el mismo desafío repetido N veces.

**D2 — Todo en cliente: un único fetch trae desafíos + asignaciones.**
`fetchPreguntas()` en `panel/src/lib/preguntas.ts` hace 4 consultas batch
(igual que `resolveNivelEtiquetas`/`resolveDesafioEtiquetas` en
`dashboard.ts`): `desafios` (todas las filas), `nivel_desafios` (todas),
`niveles`, `tematicas`; arma en memoria, por desafío, la lista de
`{ tematicaId, tematicaNombre, nivelId, nivelOrden }`. Búsqueda, filtros y
paginación son estado de React en `Preguntas.tsx`, recalculado en cada
render (no hay `useMemo` complejo: el dataset es pequeño, igual que
`Home.tsx` no lo usa para actividad/alertas).
Alternativa descartada: una vista SQL nueva tipo `desafios_uso` extendida
con el detalle de niveles. Se descarta para no tocar el backend (fuera del
alcance de este issue) cuando componer en cliente ya resuelve el caso con
el volumen de datos esperado.

**D3 — Eliminar: sin deshabilitado proactivo, se confía en el error de la
base de datos.**
Un desafío con `usos = 0` (sin `nivel_desafios`) puede aun así tener
`respuestas_desafio` históricas (si se jugó y luego se desasignó del
nivel), y `on delete restrict` lo rechazaría igualmente. Deshabilitar
"Eliminar" solo cuando `usos > 0` daría una falsa sensación de "borrable"
en ese caso. En su lugar: confirmación (`window.confirm`, coherente con la
ausencia de una librería de modales en el proyecto) → `delete` sobre
`desafios` → si Postgres devuelve el código de FK violation
(`23503`), mostrar "No se puede eliminar: esta pregunta está en uso o
tiene respuestas registradas de jugadores." en vez de propagar el error
crudo; en éxito, quitar la fila del estado local sin refetch completo.

**D4 — "Editar" y "Nueva pregunta" deshabilitados, mismo patrón que Home.**
Botones/enlaces con `aria-disabled="true"`, `title="Próximamente"` y sin
`onClick`/navegación, igual que los 3 accesos rápidos de `Home.tsx`. No se
introduce ningún patrón nuevo de "próximamente".

**D5 — Miniatura: imagen real para `tipo = 'imagen'`, ícono para el resto.**
El checklist pide "miniatura (imagen/ícono de video/ícono de texto)": para
`imagen` se renderiza `<img src={imagen_url}>` (con `onError` a un
fallback de ícono, ya que el admin puede haber borrado el archivo de
Storage); para `video`/`pregunta_texto` se usa un ícono SVG por tipo, igual
estilo que el mockup.

## Risks / Trade-offs

- [Fetch client-side de todo el banco] → si el banco crece a miles de
  filas, la pantalla cargará todo en memoria. Mitigación: fuera de alcance
  ahora (Non-Goals); si ocurre, migrar a paginación server-side es un
  cambio localizado a `preguntas.ts` sin tocar el layout de `Preguntas.tsx`.
- [Detectar `23503` para el mensaje de error de borrado] → depende del
  código de error que expone `postgrest-js` en `error.code`; si cambia de
  formato, el usuario vería el mensaje genérico de error en vez del
  específico. Mitigación: test unitario que fija el contrato del mock
  (`error.code === '23503'`).
- [Imagen rota si `imagen_url` apunta a un archivo borrado de Storage] →
  fallback a ícono vía `onError` del `<img>`, cubierto por Non-Goals de
  validar Storage en este issue.
