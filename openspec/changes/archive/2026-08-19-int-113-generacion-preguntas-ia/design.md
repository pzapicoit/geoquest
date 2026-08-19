## Context

El panel escribe hoy en `desafios` directamente con la clave publicable, y RLS es
la única frontera de seguridad (`.devplugin/architecture.md`). Esta tarea
introduce la primera dependencia de un tercero con credencial —OpenAI— y por
tanto el primer trozo de código server-side del proyecto: una clave de OpenAI en
el bundle del panel sería pública para cualquiera que abra las devtools.

Restricciones que condicionan el diseño:

- **`desafios` no cambia.** Una fila de `tipo = 'imagen'` exige
  `imagen_url IS NOT NULL` y `texto_pregunta IS NULL` por CHECK
  (`20260814190311_create_game_schema.sql`). Sin migración en esta tarea.
- **El bucket ya tiene su convención y sus políticas** (`challenge-media`,
  `imagen/{desafio_id}.{extension}`, escritura solo `profiles.role = 'admin'`).
- **No hay stack local con Docker** (remote-first). `supabase functions serve`
  necesita Docker, así que la validación de las funciones se hace desplegadas
  contra el proyecto remoto.
- **El tiempo de ejecución de una Edge Function está acotado.** Ilustrar 20
  lugares en una sola invocación no cabe.
- **Gates de calidad existentes**: Vitest + ESLint + `tsc` en `panel/`; el
  backend no tenía toolchain de código hasta ahora. Deno 2.9.4 está instalado en
  la máquina.
- La maqueta `[Admin] - Preguntas - Generar con IA.dc.html` es el contrato visual;
  el chrome real (sidebar, header) sale de `PanelLayout`, no de la maqueta.

## Goals / Non-Goals

**Goals:**

- Que un admin cree una tanda de 3 a 20 preguntas de tipo imagen para una
  temática y dificultad, revisando lugar por lugar antes de gastar en imágenes y
  antes de tocar el banco.
- Que la API key de OpenAI nunca salga del runtime de las Edge Functions.
- Que la lógica que puede equivocarse en silencio —normalización de nombres,
  distancia entre coordenadas, filtrado de duplicados, contabilidad del lote—
  viva en código con tests unitarios.
- Que el fallo de una sola imagen no tire la tanda entera.

**Non-Goals:**

- Sistema de créditos de IA (la maqueta lo dibuja; el producto no lo tiene).
- Generar desafíos de tipo `video` o `pregunta_texto` con IA.
- Persistir la descripción textual que genera la IA (exigiría cambiar el modelo
  de datos).
- Editar los candidatos propuestos (nombre, coordenadas) dentro del wizard: se
  aprueban o se descartan. Retocar se hace luego en el formulario de la pregunta.
- Historial o auditoría de tandas generadas.
- Cola en servidor ni reanudación de una tanda a medias tras cerrar el navegador.

## Decisions

### D1 · Dos Edge Functions finas, una invocación por imagen

`proponer-lugares` (texto, una invocación por ronda) y `generar-imagen-lugar`
(imagen, **una invocación por lugar**). El cliente orquesta el bucle de
imágenes.

*Por qué:* el límite de duración de una Edge Function hace inviable ilustrar 20
lugares en una sola llamada. Trocear por imagen además da progreso real por
tarjeta, reintento individual y aislamiento de fallos —justo lo que la maqueta
dibuja en el paso 3.

*Alternativas:* (a) una única función que ilustre el lote entero → choca con el
timeout y convierte cualquier fallo en fallo total; (b) cola en base de datos +
worker → resuelve un problema que no tenemos (nadie cierra el navegador a
propósito a mitad de tanda) al precio de tabla, estados y limpieza de huérfanos.

### D2 · La lógica de negocio vive en el panel; las funciones solo hablan con OpenAI

Deduplicación, rondas extra, contabilidad del lote y mapeo de errores a mensajes
se implementan en `panel/src/lib/` (TypeScript, Vitest). Las funciones se limitan
a: autorizar, construir el prompt, llamar a OpenAI, validar la forma de la
respuesta y devolverla.

*Por qué:* es la parte que se rompe en silencio (¿"Torre Eiffel" y "Eiffel
Tower" son el mismo lugar?) y el repo ya tiene gates de test para TypeScript de
panel, no para Deno. Mantener las funciones tontas también las hace triviales de
revisar: sin secretos de negocio, solo custodia de credencial.

*Alternativa:* meter el dedup en la función, que consultaría `desafios` ella
misma. Menos redondeos cliente-servidor, pero mueve lógica crítica a un runtime
sin cobertura de tests y duplica el conocimiento del modelo de datos.

### D3 · El prompt se construye dentro de la función

El cliente envía parámetros (temática, dificultad, cantidad, exclusiones,
indicaciones extra), nunca el prompt completo. Las indicaciones extra del admin
se insertan como preferencias del usuario, sin poder sustituir las instrucciones
de formato ni las de exclusión.

*Por qué:* si el cliente mandara el prompt, la función sería un proxy genérico de
OpenAI con la clave del proyecto detrás. Aunque solo la invoquen admins, no hay
razón para dar esa superficie.

### D4 · El wizard vive en estado de cliente; nada intermedio en el backend

Candidatos e imágenes viven en el estado de React hasta la confirmación. Las
imágenes se guardan como `Blob` con su `URL.createObjectURL` para la
previsualización, y se liberan al desmontar o descartar la tanda.

*Por qué:* no crear filas ni objetos de storage hasta que el admin confirma
significa cero huérfanos que limpiar. Una tanda de 20 imágenes WebP de 1024 px
ronda los 10 MB en memoria: asumible para una pantalla de escritorio de
administración.

*Alternativa:* subir las imágenes a un prefijo temporal del bucket y moverlas al
confirmar. Añade limpieza de huérfanos y rutas fuera de la convención del spec de
storage, a cambio de una memoria que no es problema.

### D5 · Autorización con el JWT del invocador, sin clave de servicio

La función crea un cliente Supabase con la clave publicable **y el header
`Authorization` de la petición**, y consulta `profiles.role` del propio usuario.
La política `profiles_select_own` (INT-76/D5) permite exactamente esa lectura.
No se usa la clave secreta en ningún punto.

*Por qué:* la comprobación se apoya en la misma frontera que el resto del sistema
(RLS) en lugar de introducir un segundo mecanismo. Y una función con clave
secreta que se saltase RLS sería el eslabón más peligroso del proyecto.

### D6 · La imagen la sube el navegador, no la función

La función devuelve la imagen en línea (base64 + MIME). Al confirmar el lote, el
panel genera el `desafio_id`, sube el `Blob` a `challenge-media` reutilizando
`subirMediaDesafio` de `panel/src/lib/preguntaForm.ts`, y luego inserta la fila.

*Por qué:* la ruta de escritura a storage ya existe, está cubierta por RLS de
admin y por el spec `challenge-media-storage`. Duplicarla en Deno sería
reimplementar la convención en un segundo sitio. Además el orden
"subir → insertar" es obligado: el CHECK exige `imagen_url` no nulo.

### D7 · WebP 1024×1024, calidad media

Se pide a OpenAI WebP cuadrado de 1024 px con calidad media. El bucket acepta
`image/webp`.

*Por qué:* WebP pesa una fracción de PNG para el mismo tamaño visible, lo que
importa tres veces —memoria del wizard, subida al bucket y descarga en la app del
jugador—. 1024 px cuadrado encaja con las portadas que ya usa el juego, y la
calidad media es indistinguible en un móvil al precio más bajo.

### D8 · Secreto `geo_open_api`; modelos por variable de entorno

- Clave: `geo_open_api` (el nombre que ya usa Pablo en el proyecto).
- Modelos: `GEOQUEST_MODELO_TEXTO` y `GEOQUEST_MODELO_IMAGEN`, con defaults
  documentados en `backend/README.md` (texto: un modelo de razonamiento general
  de OpenAI con salida estructurada; imagen: `gpt-image-1`).

*Por qué:* el catálogo de modelos de OpenAI cambia más rápido que este panel.
Con el modelo en entorno, probar otro es `supabase secrets set` y una invocación,
sin PR ni redeploy de código.

### D9 · Deduplicación: nombre normalizado + 10 km, y hasta dos rondas extra

Normalizar = minúsculas, sin acentos (NFD + descarte de diacríticos), sin signos
de puntuación, espacios colapsados. Distancia = haversine; umbral 10 km.
Se compara contra los desafíos de **esa** temática y contra los candidatos ya
aceptados del lote. Si faltan candidatos, se repite la llamada con la exclusión
ampliada, máximo 2 rondas extra; después se entrega lo conseguido con un aviso.

*Por qué:* el nombre solo no basta ("Eiffel Tower"), y la coordenada sola tampoco
(dos monumentos distintos a 3 km en el centro de Roma serían el mismo). El tope
de rondas evita el bucle infinito cuando la temática está agotada, que es el modo
de fallo real: pedir 20 "Monumentos" cuando quedan 6 sin usar.

*Alternativa:* delegar en la IA la comprobación de duplicados. Es exactamente lo
que no se puede verificar; el filtro determinista es la red de seguridad.

### D10 · Concurrencia de 3 imágenes, con tiempo de espera acotado

El bucle de ilustración mantiene 3 invocaciones en vuelo. Cada llamada se corta
con `AbortController`.

*Por qué:* secuencial, 20 imágenes son una espera larguísima; sin límite, se
disparan 20 invocaciones y el rate limit de OpenAI empieza a devolver errores que
el admin lee como "la IA falla". Tres es suficiente para que el progreso se sienta
continuo.

### D11 · `activo` sale del toggle "Publicar activas", por defecto activado

Se implementa el toggle de la maqueta y su valor decide `activo` en el `insert`.

*Por qué:* el admin acaba de revisar nombre, coordenadas e ilustración de cada
candidato; obligar a un segundo repaso en el listado sería fricción sin
información nueva. Queda la red de seguridad de siempre: el listado filtra por
estado y permite desactivar en línea. Es una constante de una línea si Pablo
prefiere lo contrario.

### D12 · Errores con código propio en la función, traducción en el panel

Conjunto cerrado —`no_autorizado`, `secreto_no_configurado`, `peticion_invalida`,
`respuesta_invalida`, `openai_error`— y un mapa a mensajes en castellano en
`panel/src/lib/iaPreguntas.ts`, testeado.

*Por qué:* lo pide el issue explícitamente (nada de errores crudos de OpenAI en
pantalla) y evita el patrón de adivinar el motivo del fallo leyendo strings.

### D13 · Gates de calidad de las funciones: `deno check` y `deno lint`

Se añaden al gate de quality del backend. Los tests siguen siendo Vitest en el
panel, donde vive la lógica (D2).

*Por qué:* Deno ya está instalado, `deno check` detecta lo que un `tsc` detecta en
el panel, y no exige Docker. Montar `deno test` para las funciones sería testear
un `fetch` a OpenAI, es decir, un mock de la parte que no falla sola.

### D14 · Divergencias con la maqueta, resueltas

| Maqueta | Implementación | Motivo |
|---|---|---|
| Dificultades Fácil/Media/Difícil/**Mixta** | Los 5 valores del enum `dificultad` | El catálogo real es de 5 (INT-106) y el issue pide una dificultad por tanda |
| Columna "Enunciado" | Se muestra en revisión, no se persiste | CHECK: `tipo = 'imagen'` ⇒ `texto_pregunta IS NULL` |
| Tarjeta "Créditos IA" | Aviso de coste aproximado en el paso 2 | No existe sistema de créditos; el issue pide avisar del coste |
| Sidebar con Niveles/Ranking | `PanelLayout` real | Los niveles se retiraron en INT-106 |
| Contador 3–20 | Contador 3–20 | Se prefiere a los saltos 5/10/15/20 del issue: los incluye |

## Risks / Trade-offs

- **Coordenadas alucinadas con nombre correcto** → la revisión muestra las
  coordenadas, el juego puntúa por distancia y el listado permite corregir o
  desactivar. Aun así es el fallo más probable de esta feature: un lugar real con
  su pin a 200 km. Mitigación aceptada, no eliminada (ver Open Questions).
- **El default del modelo de texto puede no estar habilitado en la cuenta de
  OpenAI** → llega como `openai_error` con mensaje propio, y se corrige con
  `supabase secrets set GEOQUEST_MODELO_TEXTO=...` sin tocar código.
- **Coste real por click** → el paso 2 dice cuántas imágenes y cuánto cuestan
  aproximadamente antes de lanzarlas; el paso 1 aclara que no gasta nada.
- **Rate limit de OpenAI con la concurrencia** → 3 en vuelo y reintento por
  tarjeta desde la propia UI.
- **20 imágenes en memoria del navegador** → WebP de calidad media y liberación
  de los `objectURL` al descartar la tanda o desmontar la pantalla.
- **Primer código Deno del repo** → gates nuevos (`deno check`, `deno lint`) y
  despliegue documentado en `backend/README.md`; sin ellos, el backend deja de
  tener puerta de calidad para esta parte.
- **Indicaciones extra como vector de prompt injection** → solo las escriben
  admins, la función conserva sus instrucciones de formato y valida la salida
  (rango de coordenadas, forma del JSON) antes de devolverla.
- **Validación local imposible sin desplegar** (no hay Docker) → las funciones se
  despliegan al proyecto remoto para probarlas; es el mismo compromiso remote-first
  que ya rige las migraciones.

## Migration Plan

1. `supabase secrets set geo_open_api=... --project-ref xhrntgsdlnwrvwehqfgl`.
   Hoy GeoQuest no tiene ningún custom secret: el `geo_open_api` existente está en
   el proyecto vecino Nomad Travel, creado ahí por error, y conviene retirarlo de
   allí (`supabase secrets unset`). Lo hace Pablo; la clave no pasa por el repo ni
   por la conversación.
2. `supabase functions deploy proponer-lugares generar-imagen-lugar` desde
   `backend/`.
3. Panel: el despliegue es el habitual de Vercel al mergear a `main`; en local
   basta `npm run dev`.
4. Sin migración de base de datos, así que **sin rollback de esquema**. Revertir =
   revertir el PR (el botón "Generar con IA" desaparece) y, si se quiere,
   `supabase functions delete`. Las preguntas ya creadas por IA son filas
   normales de `desafios` y no se distinguen de las manuales.

## Open Questions

- **Modelo de texto por defecto**: se fija uno en `backend/README.md`, pero la
  cuenta de OpenAI es de Pablo y él sabe qué modelos tiene habilitados. Si el
  default no está disponible, es un `secrets set`.
- **¿Merece la pena un mapa por candidato?** Reutilizar `MapaVistaPrevia` en la
  revisión pondría el pin de cada candidato sobre el mundo y convertiría la
  coordenada alucinada en algo visible de un vistazo. No está en la maqueta y no
  entra en esta tanda; queda como mejora obvia si el fallo aparece en uso real.
- **`activo` por defecto** (D11): se implementa el toggle de la maqueta con
  default activado. Si Pablo prefiere que las tandas de IA entren inactivas, es
  cambiar la constante inicial.
