---
type: scope
parent: int-113-generacion-preguntas-ia
reason: "el usuario pidió poder guardar en cada temática un prompt de imagen que la generación con IA use siempre al ilustrar sus preguntas"
---

## Why

Probando INT-113 apareció una carencia concreta: el estilo que necesita cada
temática es distinto y **estable**, pero hoy solo se puede expresar en las
"indicaciones extra" de la tanda, que hay que reescribir de memoria cada vez.

El caso que lo destapó: en «Banderas» la ilustración debe ser la bandera sobre
fondo neutro. Sin decirlo, la IA la dibuja dentro de una escena con plaza,
palmeras y coches — que además de romper la coherencia visual con las 20
banderas que ya hay en el banco, **da pistas de más** en una pregunta cuyo único
dato debería ser la bandera. Y lo mismo pasará con cualquier temática de estilo
propio: «Peliculas» pide fotograma, «Museos» pedirá interior.

Que ese estilo viva en la temática y no en la cabeza del admin lo convierte en
una decisión que se toma una vez.

## What Changes

- **`tematicas` gana una columna** `prompt_imagen` (texto, opcional): las
  indicaciones de estilo que la generación con IA aplica siempre al ilustrar
  preguntas de esa temática.
- **El formulario de temáticas gana ese campo**, opcional, con una explicación de
  para qué sirve y ejemplos.
- **La generación con IA lo usa en cada imagen** de la temática elegida, sin que
  el admin tenga que recordarlo. Las indicaciones extra de la tanda siguen
  existiendo y se suman: el prompt de la temática es el estilo permanente, las
  indicaciones son el matiz de esta tanda.
- **El wizard muestra el estilo de la temática** que va a aplicar, en modo
  lectura, para que el admin sepa con qué se va a ilustrar antes de gastar.
- Si la temática no tiene prompt, el comportamiento es exactamente el de hoy.

Fuera de alcance: el prompt de la temática **no** afecta a la propuesta de texto
(qué lugares se proponen), solo a la ilustración. El tipo de respuesta lo sigue
deduciendo la IA del banco de esa temática.

## Capabilities

### New Capabilities

Ninguna: el delta extiende capacidades que ya existen.

### Modified Capabilities

- `game-data-model`: `tematicas` incorpora el estilo de ilustración de la
  temática como columna opcional.
- `panel-topics-form`: el formulario de temática ofrece ese campo.
- `panel-ai-question-generation`: el wizard aplica el prompt de la temática
  elegida a todas las ilustraciones de la tanda, y lo muestra antes de generar.
- `ai-generation-edge-functions`: `generar-imagen-lugar` acepta el estilo de la
  temática además de las indicaciones de la tanda, y distingue ambos.

## Impact

**Backend**

- Migración nueva: `alter table tematicas add column prompt_imagen text`.
  Nullable, sin valor por defecto, sin cambios de RLS (las policies de
  `tematicas` ya cubren la tabla entera).
- `backend/supabase/functions/generar-imagen-lugar/index.ts`: nuevo campo en la
  petición.

**Panel**

- `panel/src/lib/tematicas.ts`: leer y guardar `prompt_imagen`.
- `panel/src/pages/Tematicas.tsx`: campo en el panel lateral del formulario.
- `panel/src/lib/preguntaForm.ts`: `fetchTematicasParaPregunta` devuelve también
  el prompt de cada temática.
- `panel/src/lib/iaPreguntas.ts` y `panel/src/pages/PreguntasGenerarIA.tsx`:
  enviarlo en cada ilustración y mostrarlo en el paso 1.

**Sin impacto**

- `app/` (Flutter) no cambia: el campo es de administración y no viaja al
  jugador.
- Las preguntas ya creadas no cambian. Nada obliga a rellenar el campo.
