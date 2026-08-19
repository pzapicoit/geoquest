## Context

Delta de `int-113-generacion-preguntas-ia`, ya archivado y desplegado. El wizard
funciona y las dos Edge Functions están verificadas contra el proyecto remoto;
lo que falta es que el estilo visual de cada temática deje de ser algo que el
admin reescribe de memoria en cada tanda.

Restricciones heredadas que condicionan este delta:

- `tematicas` ya tiene RLS por tabla (lectura para autenticados, escritura solo
  admin, vía `is_admin()`), así que una columna nueva no necesita policies.
- El formulario de temáticas es un **panel lateral**, no una pantalla aparte
  (`panel-topics-form`).
- La función de imagen ya recibe `indicaciones` (las de la tanda), añadidas al
  arreglar el caso de «Banderas» durante el testing de INT-113.
- Todo cambio de esquema va por migración versionada; no hay stack local.

## Goals / Non-Goals

**Goals:**

- Que el estilo de ilustración de una temática se decida una vez y se aplique
  siempre, sin depender de que el admin lo recuerde.
- Que el admin vea, antes de gastar en imágenes, con qué estilo se van a generar.
- No romper nada de lo que ya funciona: sin prompt, comportamiento idéntico.

**Non-Goals:**

- Que el prompt de la temática influya en **qué** lugares se proponen. Eso lo
  deduce la IA del banco de la temática y funciona; meter aquí un segundo canal
  para lo mismo solo crea contradicciones.
- Plantillas, historial de versiones o variables dentro del prompt.
- Prompt por dificultad, o por desafío individual.
- Tocar la app del jugador: el campo es de administración.

## Decisions

### D1 · Una columna de texto en `tematicas`, no una tabla aparte

`alter table tematicas add column prompt_imagen text`, nullable.

*Por qué:* es un texto por temática, sin historial ni multiplicidad. Una tabla
`tematica_prompts` añadiría un join y una FK para modelar exactamente un dato
por fila. Nullable en vez de `default ''` para que "no configurado" y "configurado
como vacío" no sean dos estados distintos que luego hay que distinguir.

### D2 · El estilo de la temática y las indicaciones de la tanda son dos campos, no uno concatenado

La función recibe `estiloTematica` e `indicaciones` por separado y los compone
ella, cada uno con su papel: el estilo decide qué y cómo se dibuja en esa
temática, las indicaciones lo matizan para esta tanda.

*Por qué:* concatenarlos en el cliente perdería la distinción justo donde
importa. Si el estilo dice "la bandera sobre fondo neutro" y la tanda dice
"países del hemisferio sur", el modelo tiene que saber cuál gobierna el motivo y
cuál el contenido. Además, separados se leen en los logs de la función.

### D3 · Solo afecta a la imagen, no a la propuesta de texto

*Por qué:* el tipo de respuesta ya se deduce del banco de la temática, y eso
quedó verificado en INT-113 (en «Banderas» propone países, en «Peliculas»
títulos). Si el prompt de la temática entrara también en la propuesta de texto,
habría dos fuentes para la misma decisión y ninguna manera de saber cuál manda
cuando se contradigan.

### D4 · El wizard muestra el estilo en modo lectura, no editable

En el paso 1, bajo el selector de temática, se muestra el prompt que se va a
aplicar; si no hay, se dice y se señala dónde se define.

*Por qué:* el paso siguiente cuesta dinero. Que el admin descubra el estilo
aplicado al ver las imágenes ya generadas es descubrirlo tarde. Editable ahí
sería un segundo sitio donde cambiar lo mismo, y la pregunta de si el cambio se
guarda en la temática o solo para esta tanda no tiene buena respuesta — para eso
ya están las indicaciones extra.

### D5 · `fetchTematicasParaPregunta` devuelve el prompt

El wizard ya carga las temáticas por ahí; se le añade el campo en vez de hacer
una consulta nueva al elegir temática.

*Por qué:* una petición menos y el dato está disponible en el instante en que se
cambia el selector, que es cuando hay que mostrarlo.

## Risks / Trade-offs

- **Un prompt de temática mal escrito degrada todas sus imágenes futuras, en
  silencio** → por eso el paso 1 lo muestra siempre antes de generar, y las
  indicaciones extra siguen permitiendo desviarse en una tanda concreta sin
  tocar la temática.
- **Contradicción entre estilo de temática e indicaciones de tanda** ("fondo
  neutro" vs "en su plaza principal") → se manda la jerarquía explícita en el
  prompt (el estilo gobierna el motivo), pero un modelo puede resolverlo mal.
  Es visible en la previsualización antes de guardar el lote.
- **El campo puede acabar usado como cajón de sastre** (contenido, dificultad,
  reglas de juego) cuando solo gobierna la imagen → la etiqueta y el texto de
  ayuda del formulario lo dicen explícitamente.
- **Migración sobre el único entorno** → es `add column` nullable: no reescribe
  filas, no rompe lectores existentes y es reversible con `drop column`.

## Migration Plan

1. `supabase db push` desde `backend/` aplica la migración al proyecto remoto.
2. `supabase functions deploy generar-imagen-lugar`.
3. Panel: despliegue habitual de Vercel al mergear.
4. Rollback: `drop column prompt_imagen` y revertir el PR. Nada depende del
   campo para funcionar; sin él se vuelve al comportamiento actual.

## Open Questions

- Ninguna que bloquee. Queda por ver, con uso real, si el estilo por temática
  basta o si «Peliculas» acabará pidiendo estilo por desafío; eso se decide
  cuando aparezca, no ahora.
