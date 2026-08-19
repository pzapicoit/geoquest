## Why

Hoy la única identidad de una pregunta es `nombre_lugar`, pensado para revelarse como el lugar real al terminar el desafío. Eso ha llevado a usar ese mismo campo para cosas que no son un lugar (en "Personas de la Historia" contiene la reformulación de la pregunta, p. ej. "Lugar de nacimiento de Charles Darwin"; en "Películas" contiene el título de la película en vez de dónde se rodó). Tampoco existe ningún campo que explique al jugador qué se le pregunta en una temática dada. Este cambio separa esas tres responsabilidades — qué se pregunta (`objetivo_global` de la temática), de qué trata la pregunta (`nombre` del desafío) y cuál es la respuesta real (`nombre_lugar`, sin cambios de función) — y corrige el contenido de las 24 preguntas ya creadas que hoy mezclan esos conceptos.

## What Changes

- `tematicas` gana `objetivo_global` (texto obligatorio): la formulación fija de qué pregunta esa temática, mostrada siempre en pantalla de juego junto al contenido del desafío. Se escribe para las 6 temáticas actuales.
- `desafios` gana `nombre` (texto corto obligatorio): identificador de la pregunta en panel y juego, sustituyendo a `nombre_lugar` en ese rol.
- `desafios` gana `pista` (texto opcional, sin uso todavía): solo visible en el propio formulario de edición del panel; no se muestra en la app ni en el listado.
- Migración de datos sobre las 83 filas existentes: `nombre_lugar` se copia a `nombre` en todas ellas; para las 11 de "Personas de la Historia" y las 13 de "Películas" (24 en total) se reescribe además `nombre_lugar` con el lugar real correspondiente. Durante la investigación de esas 24 se detectaron 7 filas cuyas `lat_real`/`lng_real` ya guardadas no correspondían al lugar real (Titanic, Jurassic Park, El Resplandor, y los nacimientos de Einstein, Darwin, Mandela, Steve Jobs y Teresa de Calcuta) — **BREAKING** para el histórico de esas 7 filas: se corrigen también sus coordenadas, lo que cambia la respuesta correcta de esos desafíos (ver design.md para el detalle y el respaldo de cada valor).
- `desafios_para_jugar` y `iniciar_intento_parada` exponen `nombre` (del desafío) y, vía join a `tematicas`, `objetivo_global` — sin exponer `nombre_lugar`, igual que hoy.
- Panel: formulario de temática añade `objetivo_global` (obligatorio); formulario de pregunta añade `nombre` (obligatorio, primer campo) y `pista` (opcional), y aclara que el campo de lugar es la respuesta real; el listado de preguntas usa `nombre` como identificador de fila y lo suma a la búsqueda (que sigue matcheando también `nombre_lugar`).
- App: la pantalla de juego muestra `objetivo_global` de la temática junto al `nombre` del desafío en el toast de pista, para los tres tipos de contenido. Las tarjetas de resultado siguen mostrando `nombre_lugar` sin cambios. `pista` no se muestra todavía en la app.

## Capabilities

### New Capabilities
(ninguna — este cambio solo modifica capacidades existentes)

### Modified Capabilities
- `game-data-model`: `tematicas` gana `objetivo_global` (obligatorio); `desafios` gana `nombre` (obligatorio) y `pista` (opcional); migración de datos sobre filas existentes, incluida la corrección puntual de `lat_real`/`lng_real` en 7 filas.
- `challenge-play`: `desafios_para_jugar` expone `nombre`; `iniciar_intento_parada` expone además `objetivo_global` de la temática de la parada.
- `panel-topics-form`: nuevo campo obligatorio `objetivo_global`.
- `panel-questions-form`: nuevo campo obligatorio `nombre` (sustituye a `nombre_lugar` como identificador de la pregunta) y nuevo campo opcional `pista`; `nombre_lugar` se re-etiqueta como la respuesta real.
- `panel-questions-listing`: la fila y la búsqueda usan `nombre` como identificador principal, manteniendo también `nombre_lugar` en la búsqueda.
- `app-game-screen`: el toast de pista muestra `objetivo_global` de la temática junto con el `nombre` del desafío, para los tres tipos de contenido.

## Impact

- **Backend**: nueva migración de esquema + migración de datos (`backend/supabase/migrations/`); cambios en la vista `desafios_para_jugar` y la RPC `iniciar_intento_parada`.
- **Panel**: formularios de temática y de pregunta (`panel/src`), listado de preguntas (búsqueda y columnas).
- **App**: pantalla de juego (`app/lib`), toast de pista.
- Ningún cambio en `responder_desafio`, `cerrar_intento_parada` ni en las tarjetas de resultado (revelado/resumen), que siguen usando `nombre_lugar` tal cual.
