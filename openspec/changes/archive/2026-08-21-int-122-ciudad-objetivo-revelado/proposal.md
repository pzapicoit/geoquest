## Why

`desafios.nombre_lugar` carga con dos papeles a la vez: el punto exacto de la
respuesta y su ubicación en el mapa administrativo. Los valores reales del banco
van de `Coliseo de Roma, Italia` a
`Parque de bomberos Hook & Ladder 8, Tribeca, Nueva York`.

Tras compactar la tarjeta del revelado (INT-121) ese texto se pinta a **una
línea con ellipsis**, así que los valores largos se cortan justo en la parte que
localiza el objetivo. El jugador acaba de señalar un punto en un mapa sin
topónimos y lo que se lleva de vuelta es `Parque de bomberos Hook & Ladder 8,
Tribec…`: la información que le cierra el bucle —**dónde estaba**— es la que
desaparece.

La ciudad, además, no es solo un texto más corto: es la unidad con la que un
jugador razona sobre un mapa mundial. Y es un dato que hoy no existe en la base
ni siquiera para el panel.

## What Changes

- `desafios` gana una columna `ciudad` (texto, nullable), con el mismo
  tratamiento que `pais` (INT-119): dato del objetivo, independiente de
  `nombre_lugar`, que se queda intacto como el punto exacto.
- `responder_desafio` incluye `ciudad` en el revelado, junto a `lat_real`,
  `lng_real` y `nombre_lugar`.
- La vista `desafios_para_jugar` y la RPC `iniciar_intento_parada` **siguen sin
  exponerla**: `ciudad` es parte de la respuesta, y llega solo cuando el jugador
  ya ha gastado su jugada.
- El revelado de la app enseña la ciudad bajo `UBICACIÓN REAL`, y es también la
  que rotula el pin real sobre el mapa. Con `ciudad` a `NULL` se cae a
  `nombre_lugar`, que es el comportamiento actual.
- Backfill de `ciudad` para los 135 desafíos del banco, determinado por
  conocimiento geográfico sobre `nombre`/`nombre_lugar`/coordenadas, igual que se
  hizo con `pais` en INT-119 delta-2. Lo que no tiene ciudad real (aguas
  internacionales, parajes despoblados, un país entero como respuesta) se queda
  en `NULL` a propósito.
- El formulario de preguntas del panel gana un campo opcional `ciudad`, junto a
  `pais`.
- La generación con IA propone `ciudad` **y `pais`** por candidato, y el wizard
  los persiste. `pais` entra en el alcance aunque no lo pidiera el enunciado:
  hoy el generador no lo rellena, así que toda pregunta creada con IA nace sin
  país y deja el comodín de país (INT-119) muerto para ella. Es el mismo
  prompt, el mismo esquema de respuesta y la misma llamada — pedir solo la
  ciudad sería dejar el bug al lado.
- La descripción que genera la IA sigue sin poder nombrar la ciudad ni el país:
  es la pista que lee el jugador, y esa regla del prompt no se toca.

No hay cambios **BREAKING**: la columna es nullable, el revelado solo añade un
campo al `jsonb`, y la app cae a `nombre_lugar` cuando falte.

## Capabilities

### New Capabilities

Ninguna. El cambio amplía capacidades que ya existen.

### Modified Capabilities

- `game-data-model`: `desafios` gana la columna `ciudad`, nullable, con el país
  y el lugar exacto como campos hermanos independientes.
- `challenge-scoring`: el revelado que devuelve `responder_desafio` incluye
  `ciudad`.
- `challenge-play`: la lista de campos que la vista de juego y el arranque de
  intento no exponen nunca pasa a incluir `ciudad`.
- `app-game-screen`: la tarjeta del revelado y el rótulo del pin real muestran
  la ciudad, con `nombre_lugar` como respaldo.
- `panel-questions-form`: campo opcional `ciudad` en el formulario de preguntas.
- `ai-generation-edge-functions`: `proponer-lugares` devuelve `ciudad` y `pais`
  por candidato, y la descripción sigue prohibiendo nombrarlos.
- `panel-ai-question-generation`: el wizard arrastra `ciudad`/`pais` desde la
  propuesta hasta la fila guardada.

## Impact

**Backend**
- Migración nueva: `alter table desafios add column ciudad text` y
  `create or replace function responder_desafio(...)` (la firma no cambia, así
  que `replace` basta, a diferencia de INT-93).
- Migración de datos nueva con el backfill de `ciudad`.
- `backend/supabase/functions/proponer-lugares/index.ts`: esquema de respuesta,
  prompt y validación.

**App** (`app/`)
- `lib/services/nivel_juego_gateway.dart`: `RespuestaDesafio` gana `ciudad`
  (opcional) y su mapeo.
- `lib/screens/nivel_juego_screen.dart`: el texto bajo `UBICACIÓN REAL` y el
  `nombre` que se pasa a `revelarUbicacion`.

**Panel** (`panel/`)
- `src/lib/preguntaForm.ts` y `src/pages/PreguntaForm.tsx`: campo `ciudad`.
- `src/lib/iaPreguntas.ts`: `CandidatoIA` gana `ciudad`/`pais`.
- `src/lib/loteIA.ts`: `CandidatoParaGuardar` gana `ciudad`/`pais` y el insert
  los escribe.
- `src/pages/PreguntasGenerarIA.tsx`: los arrastra de la propuesta al guardado y
  los muestra en la revisión.

**Sin tocar**
- `desafios_para_jugar`, `iniciar_intento_parada`, `usar_comodin`: `ciudad` no
  se expone antes de responder, y no hay comodín de ciudad en este cambio.
- `src/lib/preguntas.ts` (listado) y `src/lib/dashboard.ts` (alertas): siguen
  identificando la pregunta por `nombre`/`nombre_lugar`.
- La deduplicación de `duplicadosLugar.ts` sigue comparando `nombre_lugar` y
  coordenadas. La ciudad no es señal de duplicado: dos monumentos distintos de
  Roma comparten ciudad y no son el mismo lugar.
