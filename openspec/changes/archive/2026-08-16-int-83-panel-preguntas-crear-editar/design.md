## Context

El listado (INT-82) ya estableció el patrón de página del panel: un módulo
en `panel/src/lib/` con funciones `fetchX()`/`accionX()` que envuelven
`supabase.from(...)` y devuelven objetos camelCase, y una página en
`panel/src/pages/` con `useState`/`useEffect` (sin librería de fetching de
datos, sin store global, sin librería de formularios).

El esquema ya soporta todo lo que pide el issue, sin cambios de backend:

- `desafios(id, tipo, imagen_url, video_url, texto_pregunta, lat_real,
  lng_real, nombre_lugar, activo)`, con un `check` que exige exactamente uno
  de `imagen_url`/`video_url`/`texto_pregunta` según `tipo`, y
  `lat_real`/`lng_real` acotados por rango a nivel de base de datos.
- `nivel_desafios(nivel_id, desafio_id, orden)`, PK compuesta, `unique
  (nivel_id, orden)` — asignar una pregunta a un nivel es sencillamente
  insertar una fila con el siguiente `orden` libre de ese nivel.
- Bucket `challenge-media` (INT-76): `image/jpeg|png|webp` y `video/mp4`
  únicamente, 50 MiB máx., ruta `{tipo}/{desafio_id}.{extension}`, admin-only
  para escritura.
- RLS ya restringe `insert`/`update`/`delete` de `desafios`/`nivel_desafios`
  a `is_admin()` — el mismo admin autenticado que usa el panel.

El mockup de Claude Design (`[Admin] - Preguntas - Nueva.dc.html`) trae un
`<map-preview lat lng>` (custom element) que carga `d3`, `topojson-client` y
el GeoJSON de `world-atlas` **desde unpkg/jsdelivr en tiempo de ejecución**
vía `<script>` inyectados con SRI. Ese patrón es razonable para una preview
aislada en Claude Design, pero no encaja en el panel: introduciría una
dependencia de red externa en cada apertura del formulario, sin control de
versión ni bundling (ver D2).

## Goals / Non-Goals

**Goals:**
- Crear y editar una pregunta del banco con el mismo look&feel que el
  mockup: selector de tipo excluyente, upload+preview de imagen/vídeo,
  textarea de texto, lat/lng con validación y preview de mapa no
  interactivo, nombre del lugar, estado activo/inactivo.
- Permitir asignar la pregunta a uno o varios niveles al crearla.
- Habilitar "Nueva pregunta" y "Editar" en el listado (INT-82).

**Non-Goals:**
- Reordenar o desasignar niveles desde este formulario una vez creada la
  pregunta — eso vive en la pantalla de detalle del nivel (INT-84,
  `reordenar_preguntas_nivel`). En edición, la sección "Asignar a nivel(es)"
  no se muestra (ver D3).
- Recorte/redimensionado de imagen o vídeo en cliente: se sube el archivo
  tal cual, validando solo tipo MIME y tamaño.
- Mapa interactivo (click para fijar lat/lng): el issue pide explícitamente
  que sea de solo lectura; lat/lng se editan por los campos numéricos.
- Borrar el archivo anterior de Storage al reemplazar la media de una
  pregunta en edición (ver Risks).

## Decisions

**D1 — El id del desafío se genera en cliente antes de subir media.**
La convención de ruta de `challenge-media` es `{tipo}/{desafio_id}.{ext}`,
pero al crear una pregunta el `id` todavía no existe en la base de datos
(`gen_random_uuid()` corre en el `insert`). Se genera el `id` en cliente con
`crypto.randomUUID()`, se sube el archivo a esa ruta primero y luego se hace
`insert` en `desafios` pasando ese mismo `id` explícito (la columna solo
tiene un `default`, no `generated always`, así que aceptar un valor
explícito es válido). En edición el `id` ya existe, así que solo cambia la
ruta cuando el `tipo` cambia (imagen ↔ vídeo).
Alternativa descartada: insertar primero la fila con
`imagen_url`/`video_url` provisional y hacer `update` tras subir el
archivo — dos escrituras a `desafios` en vez de una, sin beneficio real.

**D2 — Mapa de vista previa: componente React con `d3-geo` +
`topojson-client` como dependencias de build, datos de `world-atlas`
vendorizados en `src/assets` (sin fetch a CDN en runtime).**
Se replica el mismo resultado visual que `map-preview.js` (proyección
Natural Earth, silueta de continentes, país bajo el pin resaltado,
coordenadas legibles) pero como componente React tipado (`MapaVistaPrevia`,
props `lat`/`lng`) en vez de un custom element, y con el JSON de países
(`countries-110m.json`, ~100 KB) copiado a `src/assets/world-110m.json` en
vez de traerlo de `jsdelivr` en cada carga del formulario. `d3-geo` +
`topojson-client` (no el paquete `d3` completo) añaden ~35 KB al bundle,
razonable para una preview estática de un panel interno.
Alternativas descartadas: (a) replicar literalmente la carga por CDN — mala
práctica en un panel de producción (dependencia de red externa, sin control
de versión, falla si el CDN no responde); (b) mapa sin silueta de
continentes (solo graticule + pin) — más simple y cero dependencias nuevas,
pero pierde la referencia visual del mockup sin ninguna ganancia real
(el JSON vendorizado ya elimina el problema de la dependencia de red).

**D3 — "Asignar a nivel(es) ahora" solo aparece en modo creación.**
El checklist del issue dice literalmente "selector múltiple para añadir la
pregunta directamente a uno o varios niveles **al crearla**". Editar
asignaciones de niveles ya tiene su lugar (pantalla de detalle del nivel,
INT-84) y mezclar ambos flujos en este formulario duplicaría
responsabilidad. En edición, el formulario solo muestra los campos propios
del desafío; sus asignaciones existentes no se tocan.

**D4 — Asignar a un nivel = `insert` en `nivel_desafios` con
`orden = max(orden) + 1` de ese nivel (1 si no tiene ninguna).**
No existe (ni hace falta) una RPC para "añadir al final"; con las
asignaciones de todos los niveles ya cargadas para pintar el selector (ver
D5), calcular el siguiente `orden` por nivel es una reducción en cliente.
Las inserciones a varios niveles se lanzan en paralelo tras crear el
desafío; si una falla (p. ej. condición de carrera de `unique (nivel_id,
orden)` con otro admin concurrente) se reporta el error de esa asignación
sin deshacer la creación de la pregunta ni las demás asignaciones.

**D5 — El selector de niveles reutiliza `niveles`/`tematicas`/
`nivel_desafios`, sin el campo `state` decorativo del mockup.**
El mockup pinta un badge "Publicado/Borrador/Con errores" por nivel que no
existe en el esquema (`niveles` solo tiene `activo`). Se sustituye por
`{tematicaNombre} · Nivel {orden} · {n} preguntas`, igual que el desplegable
de "Usado en" de `Preguntas.tsx`, y un badge Activo/Inactivo si
`niveles.activo` es relevante — mismo criterio que INT-82 (D1: los datos de
demostración del mockup no reflejan el modelo real).

**D6 — Una sola página `PreguntaForm.tsx` para crear y editar, ruteada por
`/preguntas/nueva` y `/preguntas/:id/editar`.**
Mismo formulario, mismas validaciones; en edición se precarga con
`fetchPregunta(id)` y se omite la sección de asignación (D3). Evita
duplicar el formulario completo en dos archivos.

**D7 — Tipo de vídeo aceptado: solo `video/mp4`, tamaño según el bucket
(50 MiB), no las cifras decorativas del mockup.**
El mockup muestra copys de ejemplo ("MP4 o WebM · máximo 20 s · hasta 40
MB", "hasta 4 MB" para imagen) que no corresponden a la configuración real
del bucket `challenge-media` (INT-76): `image/jpeg|png|webp` +
`video/mp4`, 50 MiB para cualquiera de los dos. La validación de cliente
(tipo MIME y tamaño) usa los límites reales para no mostrar un mensaje que
luego Storage contradice; no se valida duración de vídeo ni dimensiones de
imagen en cliente (fuera de alcance, Storage no lo exige tampoco).

## Risks / Trade-offs

- [Subida de media antes del `insert`] → si el `insert` en `desafios` falla
  tras subir el archivo (p. ej. `nombre_lugar` vacío detectado solo por un
  `check` que el cliente no replicó), el archivo queda huérfano en
  `challenge-media`. Mitigación: la validación de campos obligatorios ocurre
  en cliente antes de subir nada; el huérfano solo puede quedar por un error
  de red/servidor en el propio `insert`, un caso residual aceptado (mismo
  nivel de riesgo que cualquier subida a Storage sin transacción cruzada).
- [Reemplazar media en edición no borra el archivo anterior] → si el tipo
  cambia (imagen → vídeo) o se sube un archivo distinto, el objeto viejo en
  `challenge-media` queda en el bucket sin referencia. Mitigación: fuera de
  alcance de este issue (no lo pide el checklist); documentado como
  limpieza pendiente si el volumen de archivos huérfanos importa.
- [`d3-geo`/`topojson-client` nuevas dependencias] → aumentan el bundle del
  panel (~35 KB) y el JSON vendorizado (~100 KB) se sirve como asset
  estático. Mitigación: es una pantalla de administración interna, no el
  bundle de la app de jugador; el tamaño no es crítico.
- [Inserciones a `nivel_desafios` en paralelo] → una condición de carrera
  con otro admin asignando al mismo nivel a la vez podría chocar contra
  `unique (nivel_id, orden)` en una de las llamadas. Mitigación: se reporta
  el error de esa asignación puntual sin deshacer el resto (ver D4); volumen
  de admins concurrentes esperado es mínimo.
