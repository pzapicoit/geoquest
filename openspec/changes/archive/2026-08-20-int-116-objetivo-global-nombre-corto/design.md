## Context

Hoy `desafios` no tiene nombre corto propio: `nombre_lugar` cumple dos papeles a la vez — identificar la pregunta en panel/juego y revelar el lugar real al terminar el desafío (`challenge-play`, `app-game-screen`) — y para 24 de las 83 filas existentes (11 de "Personas de la Historia", 13 de "Películas") el valor guardado no es en realidad un lugar sino la reformulación de la pregunta o el título de la película. Tampoco existe ningún campo a nivel de `tematicas` que fije qué se pregunta en cualquier desafío de esa temática.

Durante la investigación de esas 24 filas (necesaria para escribir su nuevo `nombre_lugar` real) se verificaron con fuentes externas las `lat_real`/`lng_real` ya guardadas y se encontraron 7 filas cuya coordenada no corresponde al lugar real que debería representar — 2 por un signo de coordenada invertido (Titanic, Jurassic Park) y 5 por apuntar a un lugar real pero distinto del correcto (nacimientos de Einstein, Darwin, Mandela, Steve Jobs y Teresa de Calcuta; y la localización de rodaje de "El Resplandor"). El usuario decidió corregir las 7 en esta misma migración en vez de abrirlo como issue aparte.

## Goals / Non-Goals

**Goals:**
- Separar tres responsabilidades hoy mezcladas en `nombre_lugar`: qué se pregunta en la temática (`objetivo_global`), de qué trata la pregunta (`nombre`), y cuál es la respuesta real (`nombre_lugar`, sin cambio de función).
- Migrar las 83 filas existentes sin dejar ninguna con `nombre`/`objetivo_global` vacíos.
- Corregir el contenido de las 24 filas cuyo `nombre_lugar` no es hoy un lugar real, y las 7 cuya coordenada tampoco lo es.
- `pista` queda modelada en el esquema y visible solo en el formulario de edición del panel, sin exponerse todavía en ningún otro sitio.

**Non-Goals:**
- No se audita la precisión geográfica del resto de temáticas (Monumentos, Banderas, Olimpiadas): su `nombre_lugar` ya sirve tal cual como lugar y solo se copia a `nombre`.
- No se muestra `pista` en la app ni en el listado del panel — modelarla es el único alcance de esta tarea; su uso queda para una tarea futura.
- No cambian `responder_desafio`, `cerrar_intento_parada` ni las tarjetas de resultado (revelado/resumen), que siguen leyendo `nombre_lugar` sin tocar.
- No se recalculan `distancia_km`/`puntos` de intentos ya jugados sobre las 7 filas con coordenada corregida: esas respuestas históricas quedan tal cual se calcularon en su momento; solo los intentos futuros usan la coordenada corregida.

## Decisions

### D1: Esquema — `objetivo_global`, `nombre` y `pista` se añaden como nullable y se cierran a `NOT NULL` tras el backfill
`tematicas.objetivo_global text` y `desafios.nombre text` se crean nullable, se rellenan por la migración de datos (D2/D3) y solo entonces se les añade `NOT NULL` — mismo patrón que otras columnas obligatorias añadidas sobre datos existentes en este proyecto (p. ej. `desafios.dificultad` en INT-106). `desafios.pista text` se crea nullable y se queda así de forma permanente (es opcional por diseño, no transitoriamente).
- Alternativa considerada: añadir `NOT NULL` directamente con un `DEFAULT` provisional y luego limpiarlo. Rechazada: con solo 6 temáticas y 83 desafíos, escribir el valor real de cada fila en la misma migración es más simple y no deja ningún placeholder en producción ni siquiera transitoriamente.

### D2: Migración de datos en dos pasadas — copia general y luego corrección dirigida
Primera pasada: `UPDATE desafios SET nombre = nombre_lugar` sobre las 83 filas (cubre Monumentos/Banderas/Olimpiadas, donde `nombre_lugar` ya sirve tal cual, y dota de un valor provisional válido a las 24 que se corrigen después). Segunda pasada: `UPDATE` fila a fila por `id` para las 11 de "Personas de la Historia" y las 13 de "Películas", fijando el `nombre` definitivo (persona o título identificado) y el `nombre_lugar` real correspondiente. Tercera pasada: `UPDATE` fila a fila por `id` para las 7 filas con coordenada incorrecta, fijando `lat_real`/`lng_real` a su valor correcto.

Todos los valores de las pasadas 2 y 3 se investigaron con fuentes externas (no se generan por heurística) y quedan documentados como comentario en la propia migración SQL, fila a fila, con la fuente/razonamiento y el error observado (distancia o tipo de discrepancia) para que quede trazable en el historial de migraciones.

**Personas de la Historia** (`nombre` = personaje; `nombre_lugar` = ciudad de nacimiento):

| Personaje | `nombre_lugar` nuevo | Coordenada |
|---|---|---|
| Abraham Lincoln | Hodgenville, Kentucky, EE. UU. | sin cambio |
| Albert Einstein | Ulm, Alemania | corregida (estaba en Augsburgo, ~67 km) |
| Charles Darwin | Shrewsbury, Inglaterra | corregida (estaba en Cambridgeshire, ~200 km) |
| Isabel I de Inglaterra | Londres, Reino Unido | sin cambio |
| Leonardo da Vinci | Vinci, Italia | sin cambio |
| Ludwig van Beethoven | Bonn, Alemania | sin cambio |
| Marie Curie | Varsovia, Polonia | sin cambio |
| Martin Luther King Jr. | Atlanta, Georgia, EE. UU. | sin cambio |
| Nelson Mandela | Mvezo, Sudáfrica | corregida (estaba en Mthatha, ~49 km) |
| Steve Jobs | San Francisco, California, EE. UU. | corregida (estaba en Cupertino/Sunnyvale, ~54 km) |
| Teresa de Calcuta | Skopie, Macedonia del Norte | corregida (estaba en Tirana, Albania, ~150 km) |

**Películas** (`nombre` = título identificado; `nombre_lugar` = localización real de rodaje):

| `nombre_lugar` actual (ambiguo) | `nombre` nuevo | `nombre_lugar` nuevo | Coordenada |
|---|---|---|---|
| El fugitivo | El Fugitivo | Chicago, Illinois, EE. UU. | sin cambio |
| Forrest Gump | Forrest Gump | Reflecting Pool, Lincoln Memorial, Washington D.C. | sin cambio |
| Ghostbusters | Ghostbusters | Parque de bomberos Hook & Ladder 8, Tribeca, Nueva York | sin cambio |
| Gladiator | Gladiator | Coliseo de Roma, Italia | sin cambio |
| Harry Potter y la piedra filosofal | Harry Potter y la Piedra Filosofal | Christ Church College, Oxford, Reino Unido | sin cambio |
| Hepburn | Vacaciones en Roma | Plaza de España (Piazza di Spagna), Roma, Italia | sin cambio |
| Home Alone 2 | Solo en Casa 2 | The Plaza Hotel, Nueva York, EE. UU. | sin cambio |
| Indiana | Indiana Jones y la Última Cruzada | El Tesoro (Al-Khazneh), Petra, Jordania | sin cambio |
| Jurassic Park | Jurassic Park | Cascada Manawaiopuna, Kauai, Hawái, EE. UU. | corregida (estaba en el Pacífico Sur, cerca de Islas Cook) |
| Mision Imposible | Misión Imposible | Trocadéro, París, Francia | sin cambio |
| Rocky | Rocky | Escalinata del Museo de Arte de Filadelfia, EE. UU. | sin cambio |
| The Shining | El Resplandor | Timberline Lodge, Monte Hood, Oregón, EE. UU. | corregida (estaba en Idaho Springs, Colorado, sin relación) |
| Titanic | Titanic | Naufragio del Titanic, Océano Atlántico Norte | corregida (signo de longitud invertido) |

- Alternativa considerada para "Hepburn"/"Indiana": dejarlos sin resolver y solo copiarlos literalmente a `nombre`. Rechazada: el propio issue pide identificar a qué título concreto se refieren antes de escribir el `nombre_lugar`, y dejarlos ambiguos en `nombre` perpetuaría el problema que origina esta tarea.

### D3: `objetivo_global` por temática — texto fijo decidido por el usuario, sin heurística de generación
Los 6 textos son literales acordados con el usuario, no derivados de plantilla:

| Temática | `objetivo_global` |
|---|---|
| Monumentos | Adivina dónde está este monumento |
| Banderas | La capital de este país es... |
| Películas | Esta escena, ¿a qué sitio corresponde? |
| Personas de la Historia | ¿Dónde nació esta personalidad? |
| Olimpiadas | ¿Dónde fueron estas Olimpiadas? |
| Museos | ¿Dónde está este museo? |

### D4: `desafios_para_jugar` expone `nombre`; `iniciar_intento_parada` añade `objetivo_global` de la temática al nivel de la respuesta, no por desafío
`objetivo_global` es constante para todos los desafíos de una misma parada (depende de la temática de la parada, no del desafío individual), así que viaja una sola vez en el `jsonb` de respuesta de `iniciar_intento_parada`, junto a `segundos_por_desafio` (mismo patrón ya usado por ese campo desde INT-99), en vez de repetirse en cada elemento de la lista de desafíos.
- Alternativa considerada: añadir `objetivo_global` como columna repetida en cada fila de `desafios_para_jugar`. Rechazada: es un dato de la temática, no del desafío — repetirlo por fila obligaría a un join adicional en la vista para un valor que no varía dentro del mismo intento.

### D5: Panel — `nombre` primer campo del formulario de pregunta, `nombre_lugar` re-etiquetado como respuesta real
El formulario de pregunta pasa a pedir `nombre` como primer campo (obligatorio), con `pista` como campo opcional nuevo, y el campo ya existente de lugar se re-etiqueta explícitamente (p. ej. "Respuesta real (lugar que se revela al terminar)") para dejar claro que no es el nombre de la pregunta. El formulario de temática gana `objetivo_global` como campo de texto obligatorio.

### D6: Listado de preguntas — `nombre` como identificador de fila; búsqueda combina `nombre` y `nombre_lugar`
Se mantiene la búsqueda también sobre `nombre_lugar` (decisión del usuario): las 59 preguntas de Monumentos/Banderas/Olimpiadas tienen ahí un valor idéntico a `nombre`, y para las 24 corregidas puede seguir siendo útil encontrar una pregunta buscando el lugar real que revela. `nombre` sustituye a `nombre_lugar`/`texto_pregunta` como texto mostrado en la fila.

## Risks / Trade-offs

- [Riesgo] Corregir `lat_real`/`lng_real` de 7 filas cambia la respuesta correcta de esos desafíos → Mitigación: es un cambio de contenido deliberado y aprobado, documentado fila a fila en la migración; las respuestas ya registradas en `respuestas_desafio` no se recalculan, solo los intentos futuros usan la coordenada nueva.
- [Riesgo] Los valores investigados de ubicación (D2) dependen de fuentes externas al momento de escribir esta migración, no de una fuente interna verificable por la base de datos → Mitigación: cada valor queda documentado con su razonamiento en la propia migración SQL para que sea auditable/corregible después si se detecta un error.
- [Trade-off] Se mantiene `nombre_lugar` con su nombre actual en vez de renombrarlo (p. ej. a `respuesta_real`) → se prioriza no tocar ningún código que ya lo referencia (`responder_desafio`, tarjetas de resultado) sobre la claridad de un nombre de columna más preciso; la claridad para el admin se resuelve con la etiqueta del formulario (D5), no con el nombre de columna.

## Migration Plan

1. Migración de esquema: `tematicas.objetivo_global text` (nullable), `desafios.nombre text` (nullable), `desafios.pista text` (nullable, permanente).
2. Migración de datos: copia general `nombre_lugar` → `nombre` (83 filas), corrección dirigida de `nombre`/`nombre_lugar` en las 24 filas de D2, corrección dirigida de `lat_real`/`lng_real` en las 7 filas de D2, y `UPDATE tematicas SET objetivo_global = ...` para las 6 temáticas (D3).
3. `ALTER TABLE ... ALTER COLUMN ... SET NOT NULL` para `tematicas.objetivo_global` y `desafios.nombre`, una vez verificado que no queda ninguna fila nula.
4. `create or replace view desafios_para_jugar` añadiendo `nombre`; `create or replace function iniciar_intento_parada` añadiendo `objetivo_global` (join a `tematicas` vía `camino.tematica_id`) al `jsonb` de respuesta.
5. Panel: campos nuevos en `PreguntaForm`/formulario de temática, columna y búsqueda del listado de preguntas.
6. App: `DesafioJuego` gana `nombre`; el resultado de `iniciar_intento_parada` gana `objetivoGlobal`; el toast de pista de `nivel_juego_screen.dart` los muestra para los tres tipos de contenido.
7. Sin rollback in-place: si algo falla tras desplegar, se restaura desde el backup de Supabase previo a la migración, igual que el resto de migraciones destructivas de este proyecto.

## Open Questions

Ninguna pendiente — redacción de `objetivo_global`, alcance de corrección de coordenadas y criterio de búsqueda del listado se decidieron con el usuario antes de escribir este documento.
